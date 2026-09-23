"""
Validacion de seguridad para SQL generado por el LLM en tool_postgres_control.

No es un parser SQL completo -- es proporcional a la amenaza real (alucinacion
del modelo o prompt injection casual desde contenido de documentos indexados,
no un atacante con acceso directo a la API). Combina varias capas baratas:
verbo debe coincidir con la accion declarada, denylist de palabras peligrosas,
una sola sentencia por llamada, y allowlist de tablas del esquema RFC.
"""
import re

ALLOWED_TABLES = {
    "rfc_records",
    "directorio_personal",
    "rfc_responsables",
    "rfc_document_index",
    "rfc_markdown_index",
    "query_audit",
    "rfc_audit_logs",
}  # sharepoint_sync_log queda deliberadamente fuera (fuera de alcance por ahora)

_DENYLIST = re.compile(
    r"\b(DROP|DELETE|ALTER|TRUNCATE|GRANT|REVOKE|CREATE|EXEC|EXECUTE|COPY|VACUUM)\b",
    re.IGNORECASE,
)
_TABLE_REF = re.compile(
    r"\b(?:FROM|JOIN|INTO|UPDATE)\s+\"?([a-zA-Z_][a-zA-Z0-9_]*)\"?",
    re.IGNORECASE,
)
_SELECT_START = re.compile(r"^\s*(WITH|SELECT)\b", re.IGNORECASE)
_INSERT_START = re.compile(r"^\s*(INSERT|UPDATE)\b", re.IGNORECASE)


class SQLGuardError(ValueError):
    """SQL rechazado por sql_guard antes de tocar la base de datos."""


def validate_query(action: str, query: str) -> None:
    q = query.strip()

    if not q:
        raise SQLGuardError("query vacío")

    if q.rstrip(";").count(";") > 0:
        raise SQLGuardError("Solo se permite una sentencia SQL por llamada")

    if _DENYLIST.search(q):
        raise SQLGuardError("Sentencia no permitida (operación bloqueada)")

    if action == "select" and not _SELECT_START.match(q):
        raise SQLGuardError("action=select requiere una sentencia SELECT")

    if action == "insert" and not _INSERT_START.match(q):
        raise SQLGuardError("action=insert requiere INSERT o UPDATE")

    tables = {t.lower() for t in _TABLE_REF.findall(q)}
    invalid = tables - ALLOWED_TABLES
    if invalid:
        raise SQLGuardError(f"Tabla(s) no permitida(s): {', '.join(sorted(invalid))}")
