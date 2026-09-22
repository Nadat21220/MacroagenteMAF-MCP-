-- =====================================================
-- RFC Markdown Index & SharePoint Sync Audit Tables
-- Created: 2026-09-17
-- Purpose: Store MD conversions and track SharePoint operations
-- =====================================================

-- =====================================================
-- Table 1: rfc_markdown_index
-- Stores mapping: RFC file → Markdown conversion
-- Almacenamiento: Contenido MD en BYTEA (PostgreSQL)
-- =====================================================

CREATE TABLE IF NOT EXISTS rfc_markdown_index (
    -- Identificadores
    markdown_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfc_file_id UUID NOT NULL UNIQUE,
    project_id VARCHAR(100) NOT NULL,

    -- Archivo información
    original_file_name VARCHAR(255) NOT NULL,
    markdown_file_name VARCHAR(255) NOT NULL,
    markdown_content BYTEA NOT NULL,  -- Contenido actual del MD

    -- Estado de conversión
    conversion_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    -- Estados permitidos: pending | converting | converted | error | deprecated

    -- Estado de sincronización con SharePoint
    sync_status VARCHAR(50) NOT NULL DEFAULT 'not_synced',
    -- Estados permitidos: not_synced | syncing | synced | failed

    -- SharePoint información
    sharepoint_file_id VARCHAR(255),
    sharepoint_file_url TEXT,
    sharepoint_folder_id VARCHAR(255),

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    conversion_completed_at TIMESTAMP,
    last_synced_at TIMESTAMP,
    last_modified_at TIMESTAMP DEFAULT NOW(),

    -- Auditoría: quién y cuándo
    created_by VARCHAR(150) NOT NULL,
    last_modified_by VARCHAR(150),

    -- Error handling
    conversion_error_message TEXT,

    -- Estadísticas de contenido
    markdown_size_bytes INTEGER,
    markdown_lines INTEGER,
    content_hash VARCHAR(64),  -- SHA256 del contenido (para detectar cambios)

    -- Constraints: Validaciones de integridad referencial
    CONSTRAINT fk_rfc_markdown_rfc_file_id
        FOREIGN KEY (rfc_file_id)
        REFERENCES rfc_document_index(index_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_rfc_markdown_project_id
        FOREIGN KEY (project_id)
        REFERENCES rfc_records(project_id)
        ON DELETE CASCADE,

    -- Validaciones de estados
    CONSTRAINT ck_rfc_markdown_conversion_status
        CHECK (conversion_status IN ('pending', 'converting', 'converted', 'error', 'deprecated')),

    CONSTRAINT ck_rfc_markdown_sync_status
        CHECK (sync_status IN ('not_synced', 'syncing', 'synced', 'failed'))
);

-- Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_rfc_markdown_project_id
    ON rfc_markdown_index(project_id);

CREATE INDEX IF NOT EXISTS idx_rfc_markdown_conversion_status
    ON rfc_markdown_index(conversion_status);

CREATE INDEX IF NOT EXISTS idx_rfc_markdown_sync_status
    ON rfc_markdown_index(sync_status);

CREATE INDEX IF NOT EXISTS idx_rfc_markdown_created_by
    ON rfc_markdown_index(created_by);

CREATE INDEX IF NOT EXISTS idx_rfc_markdown_created_at
    ON rfc_markdown_index(created_at);

CREATE INDEX IF NOT EXISTS idx_rfc_markdown_content_hash
    ON rfc_markdown_index(content_hash);

-- Permisos para usuario rfcadmin
GRANT SELECT, INSERT, UPDATE ON rfc_markdown_index TO rfcadmin;
GRANT USAGE, SELECT ON SEQUENCE rfc_markdown_index_id_seq TO rfcadmin;

-- =====================================================
-- Table 2: sharepoint_sync_log
-- Auditoría de todas las operaciones en SharePoint
-- Permite rastrear quién hizo qué, cuándo y con qué resultado
-- =====================================================

CREATE TABLE IF NOT EXISTS sharepoint_sync_log (
    -- Identificador
    sync_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    markdown_id UUID NOT NULL,

    -- Tipo de operación realizada
    operation_type VARCHAR(50) NOT NULL,
    -- Valores: create | update | move | delete_attempt (siempre bloqueado)

    -- Estado de la operación
    operation_status VARCHAR(50) NOT NULL,
    -- Valores: success | pending | failed | cancelled

    -- Rutas de archivo
    source_path VARCHAR(512),          -- Ruta anterior (para move/update)
    target_path VARCHAR(512),          -- Ruta destino/actual
    target_folder_id VARCHAR(255),     -- ID de carpeta en SharePoint

    -- Autorización y usuario
    requested_by VARCHAR(150) NOT NULL,    -- Email de quién solicita
    authorized_by VARCHAR(150),             -- Email de quién aprueba (si aplica)
    authorization_token_expires_at TIMESTAMP,

    -- Respuesta de SharePoint/Mock
    sharepoint_response_code INTEGER,
    sharepoint_error_message TEXT,
    sharepoint_request_id VARCHAR(255),    -- Para debugging con Microsoft Support

    -- Timestamps
    requested_at TIMESTAMP NOT NULL DEFAULT NOW(),
    authorized_at TIMESTAMP,
    executed_at TIMESTAMP,
    completed_at TIMESTAMP,

    -- Metadata de archivo
    file_size_bytes INTEGER,
    document_type VARCHAR(100),         -- 'markdown' | otros
    additional_metadata JSONB,          -- Datos flexibles en JSON

    -- Constraints
    CONSTRAINT fk_sharepoint_sync_markdown_id
        FOREIGN KEY (markdown_id)
        REFERENCES rfc_markdown_index(markdown_id)
        ON DELETE CASCADE,

    -- Validaciones de operación
    CONSTRAINT ck_sharepoint_sync_operation_type
        CHECK (operation_type IN ('create', 'update', 'move', 'delete_attempt')),

    CONSTRAINT ck_sharepoint_sync_status
        CHECK (operation_status IN ('success', 'pending', 'failed', 'cancelled'))
);

-- Índices para búsqueda y auditoría
CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_markdown_id
    ON sharepoint_sync_log(markdown_id);

CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_operation_type
    ON sharepoint_sync_log(operation_type);

CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_status
    ON sharepoint_sync_log(operation_status);

CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_requested_by
    ON sharepoint_sync_log(requested_by);

CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_executed_at
    ON sharepoint_sync_log(executed_at);

CREATE INDEX IF NOT EXISTS idx_sharepoint_sync_operation_status_idx
    ON sharepoint_sync_log(operation_type, operation_status);

-- Permisos
GRANT SELECT, INSERT, UPDATE ON sharepoint_sync_log TO rfcadmin;
GRANT USAGE, SELECT ON SEQUENCE sharepoint_sync_log_id_seq TO rfcadmin;

-- =====================================================
-- Vista: rfc_markdown_status
-- Proporciona overview de estado de conversión
-- Útil para dashboards y monitoreo
-- =====================================================

CREATE OR REPLACE VIEW rfc_markdown_status AS
SELECT
    rmd.markdown_id,
    rmd.project_id,
    rmd.original_file_name,
    rmd.conversion_status,
    rmd.sync_status,
    rmd.created_at,
    rmd.conversion_completed_at,
    rmd.last_synced_at,
    rmd.created_by,
    COUNT(ssl.sync_log_id) as sync_attempt_count,
    MAX(ssl.executed_at) as last_sync_attempt_at
FROM rfc_markdown_index rmd
LEFT JOIN sharepoint_sync_log ssl ON rmd.markdown_id = ssl.markdown_id
GROUP BY
    rmd.markdown_id,
    rmd.project_id,
    rmd.original_file_name,
    rmd.conversion_status,
    rmd.sync_status,
    rmd.created_at,
    rmd.conversion_completed_at,
    rmd.last_synced_at,
    rmd.created_by;

-- Permisos para vista
GRANT SELECT ON rfc_markdown_status TO rfcadmin;

-- =====================================================
-- Log de creación
-- =====================================================

INSERT INTO query_audit (query_type, executed_query, execution_time_ms, rows_affected)
VALUES (
    'INIT',
    'Created tables: rfc_markdown_index, sharepoint_sync_log, rfc_markdown_status view',
    0,
    1
) ON CONFLICT DO NOTHING;

-- =====================================================
-- FIN: Tablas de Sincronización de Documentos
-- =====================================================
