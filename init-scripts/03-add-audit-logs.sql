-- Tabla de auditoria de acciones (usada por utils/database.py log_audit)
-- Nota: query_audit ya existente audita ejecucion de queries SQL crudas;
-- esta tabla audita acciones de negocio (creacion, conversion, sync, etc.)
CREATE TABLE IF NOT EXISTS rfc_audit_logs (
    audit_log_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id      VARCHAR(100) NOT NULL,
    action_type     VARCHAR(100) NOT NULL,
    performed_by    VARCHAR(150) NOT NULL,
    changes_hash    VARCHAR(64),
    details_json    JSONB,
    performed_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rfc_audit_logs_project_id ON rfc_audit_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_rfc_audit_logs_action_type ON rfc_audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_rfc_audit_logs_performed_at ON rfc_audit_logs(performed_at);
