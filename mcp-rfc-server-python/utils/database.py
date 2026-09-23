"""
Database connection management para PostgreSQL
"""
import psycopg
from psycopg_pool import ConnectionPool
import logging
from config.settings import DATABASE_URL

logger = logging.getLogger(__name__)

# Pool singleton
_db_pool = None

def get_db_pool() -> ConnectionPool:
    """Obtener o crear el pool de conexiones a PostgreSQL"""
    global _db_pool

    if _db_pool is None:
        try:
            _db_pool = ConnectionPool(
                conninfo=DATABASE_URL,
                max_size=20,
                min_size=5,
                open=True,
                timeout=10,
                check=ConnectionPool.check_connection,
                kwargs={"options": "-c statement_timeout=8000"}
            )
            logger.info("✓ Pool de PostgreSQL inicializado")
        except Exception as e:
            logger.error(f"✗ Error inicializando pool: {e}")
            raise

    return _db_pool

def query_select(sql: str, params: list = None) -> list:
    """
    Ejecutar SELECT y retornar resultados como lista de diccionarios
    """
    try:
        with get_db_pool().connection() as conn:
            with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
                cur.execute(sql, params or [])
                return cur.fetchall()
    except Exception as e:
        logger.error(f"Error en SELECT: {e}")
        raise

def query_insert(sql: str, params: list = None) -> int:
    """
    Ejecutar INSERT/UPDATE/DELETE y retornar número de filas afectadas
    """
    try:
        with get_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params or [])
                conn.commit()
                return cur.rowcount
    except Exception as e:
        logger.error(f"Error en INSERT/UPDATE/DELETE: {e}")
        raise

def query_insert_returning(sql: str, params: list = None) -> dict:
    """
    Ejecutar INSERT RETURNING y retornar el registro insertado
    """
    try:
        with get_db_pool().connection() as conn:
            with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
                cur.execute(sql, params or [])
                conn.commit()
                return cur.fetchone()
    except Exception as e:
        logger.error(f"Error en INSERT RETURNING: {e}")
        raise

def close_db_pool():
    """Cerrar el pool de conexiones"""
    global _db_pool
    if _db_pool:
        _db_pool.close()
        _db_pool = None
        logger.info("✓ Pool de PostgreSQL cerrado")

# Funciones auxiliares comunes
def log_audit(
    project_id: str,
    action_type: str,
    performed_by: str,
    details: dict = None
) -> bool:
    """
    Registrar operación en rfc_audit_logs
    """
    import json
    import hashlib
    from datetime import datetime

    try:
        details_json = json.dumps(details or {})
        changes_hash = hashlib.md5(details_json.encode()).hexdigest()

        sql = """
        INSERT INTO rfc_audit_logs
        (project_id, action_type, performed_by, changes_hash, details_json)
        VALUES (%s, %s, %s, %s, %s)
        """

        query_insert(sql, [project_id, action_type, performed_by, changes_hash, details_json])
        return True
    except Exception as e:
        logger.error(f"Error logging audit: {e}")
        return False
