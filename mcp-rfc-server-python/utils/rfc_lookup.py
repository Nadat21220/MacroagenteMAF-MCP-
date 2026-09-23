"""
Lookups estructurados de RFC que van directo a PostgreSQL, sin pasar por
el LLM/MCP (0 tokens). SQL fijo escrito aqui, parametrizado -- no pasa por
sql_guard porque no es SQL generado por un modelo.
"""
from utils.database import query_select


def get_rfc_full(project_id: str) -> dict:
    """Datos del RFC + responsables + documentos indexados + estado de conversion markdown."""
    rfc = query_select(
        "SELECT project_id, project_name, environment, impacted_platforms "
        "FROM rfc_records WHERE project_id = %s",
        [project_id],
    )
    if not rfc:
        return {"found": False, "project_id": project_id}

    responsables = query_select(
        """
        SELECT dp.nombre, dp.apellido, dp.email, dp.departamento, rr.rol_asignado
        FROM rfc_responsables rr
        JOIN directorio_personal dp ON dp.empleado_id = rr.empleado_id
        WHERE rr.project_id = %s
        """,
        [project_id],
    )

    documentos = query_select(
        "SELECT file_name, file_type FROM rfc_document_index WHERE project_id = %s",
        [project_id],
    )

    markdown_status = query_select(
        """
        SELECT original_file_name, conversion_status, sync_status, created_by, created_at
        FROM rfc_markdown_index WHERE project_id = %s ORDER BY created_at DESC
        """,
        [project_id],
    )

    return {
        "found": True,
        "rfc": rfc[0],
        "responsables": responsables,
        "documentos": documentos,
        "markdown_status": markdown_status,
    }


def search_rfc(term: str) -> list:
    """Reusa la funcion SQL search_rfc() ya creada en init-scripts/01-init-db.sql."""
    return query_select("SELECT * FROM search_rfc(%s)", [term])
