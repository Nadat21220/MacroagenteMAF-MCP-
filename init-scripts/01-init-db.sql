-- ============================================
-- Inicialización de Base de Datos RFC
-- ============================================

-- Restaurar el schema y datos
\c rfc_management;

-- Restaurar desde backup
\i '/backups/postgres_roles_backup.sql'
\i '/backups/postgres_rfc_db_backup.sql'

-- Crear índices adicionales para optimizar consultas LLM
CREATE INDEX IF NOT EXISTS idx_rfc_project_id ON rfc_records(project_id);
CREATE INDEX IF NOT EXISTS idx_rfc_environment ON rfc_records(environment);
CREATE INDEX IF NOT EXISTS idx_personal_departamento ON directorio_personal(departamento);
CREATE INDEX IF NOT EXISTS idx_responsables_proyecto ON rfc_responsables(project_id);
CREATE INDEX IF NOT EXISTS idx_responsables_empleado ON rfc_responsables(empleado_id);

-- Crear vista para consultas comunes
CREATE OR REPLACE VIEW rfc_detail_view AS
SELECT
    r.id,
    r.project_id,
    r.project_name,
    r.environment,
    r.impacted_platforms,
    resp.rol_asignado,
    dp.nombre as empleado_nombre,
    dp.apellido as empleado_apellido,
    dp.departamento,
    dp.email
FROM rfc_records r
LEFT JOIN rfc_responsables resp ON r.project_id = resp.project_id
LEFT JOIN directorio_personal dp ON resp.empleado_id = dp.empleado_id;

-- Crear función para búsqueda de RFCs por palabra clave
CREATE OR REPLACE FUNCTION search_rfc(search_term TEXT)
RETURNS TABLE(
    id UUID,
    project_id VARCHAR,
    project_name VARCHAR,
    environment VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rfc_records.id,
        rfc_records.project_id,
        rfc_records.project_name,
        rfc_records.environment
    FROM rfc_records
    WHERE
        rfc_records.project_id ILIKE '%' || search_term || '%' OR
        rfc_records.project_name ILIKE '%' || search_term || '%';
END;
$$ LANGUAGE plpgsql;

-- Crear tabla de auditoría
CREATE TABLE IF NOT EXISTS query_audit (
    audit_id SERIAL PRIMARY KEY,
    query_type VARCHAR(50),
    executed_query TEXT,
    executed_at TIMESTAMP DEFAULT NOW(),
    execution_time_ms INTEGER,
    rows_affected INTEGER
);

-- Crear índice para auditoría
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON query_audit(executed_at);

-- Conceder permisos mínimos necesarios
GRANT SELECT ON rfc_records TO rfcadmin;
GRANT SELECT ON directorio_personal TO rfcadmin;
GRANT SELECT ON rfc_responsables TO rfcadmin;
GRANT SELECT ON rfc_document_index TO rfcadmin;
GRANT SELECT ON rfc_detail_view TO rfcadmin;
GRANT EXECUTE ON FUNCTION search_rfc TO rfcadmin;
GRANT INSERT, SELECT ON query_audit TO rfcadmin;

-- Log de inicialización
INSERT INTO query_audit (query_type, executed_query, execution_time_ms)
VALUES ('INIT', 'Database initialization completed', 0);
