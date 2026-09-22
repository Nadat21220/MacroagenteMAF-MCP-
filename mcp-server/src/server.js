// ============================================
// MCP Server: PostgreSQL + Ollama Bridge
// ============================================

const express = require('express');
const { Pool } = require('pg');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

// Nuevos módulos para documentos
const MarkItDownConverter = require('./markitdown-converter');
const SharePointClient = require('./sharepoint-client');
const authMiddleware = require('./auth-middleware');

const app = express();
app.use(express.json());

// ============================================
// Configuración
// ============================================

const DB_CONFIG = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USER || 'rfcadmin',
    password: process.env.DB_PASSWORD || 'rfc_secure_2024',
    database: process.env.DB_NAME || 'rfc_management',
};

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://ollama:11434';
const MCP_PORT = process.env.MCP_PORT || 3000;
const MCP_HOST = process.env.MCP_HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Log directory
const LOG_DIR = '/app/logs';
if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
}

// ============================================
// Logger
// ============================================

const logger = {
    log: (message, level = 'INFO') => {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] [${level}] ${message}`;
        console.log(logMessage);

        const logFile = path.join(LOG_DIR, `mcp-server.log`);
        fs.appendFileSync(logFile, logMessage + '\n');
    },
    error: (message) => logger.log(message, 'ERROR'),
    warn: (message) => logger.log(message, 'WARN'),
    debug: (message) => NODE_ENV === 'development' && logger.log(message, 'DEBUG'),
};

// ============================================
// PostgreSQL Pool
// ============================================

const pool = new Pool(DB_CONFIG);

pool.on('error', (err) => {
    logger.error(`Unexpected error on idle client: ${err.message}`);
});

// ============================================
// Ollama Integration
// ============================================

const ollamaClient = {
    isHealthy: false,

    async checkHealth() {
        try {
            const response = await axios.get(`${OLLAMA_URL}/api/tags`, { timeout: 5000 });
            this.isHealthy = true;
            return true;
        } catch (error) {
            logger.warn(`Ollama health check failed: ${error.message}`);
            this.isHealthy = false;
            return false;
        }
    },

    async generateSQL(question, model = 'mistral') {
        try {
            logger.debug(`Generating SQL for question: ${question}`);

            const systemPrompt = `You are a SQL expert. Generate ONLY a valid PostgreSQL SELECT query (no explanations, no markdown, just the SQL).

Database schema:
- directorio_personal: empleado_id (uuid), nombre, apellido, departamento, email
- rfc_records: id (uuid), project_id, environment (Dev/QA/PROD), project_name, impacted_platforms
- rfc_responsables: asignacion_id (uuid), project_id, empleado_id (uuid), rol_asignado
- rfc_document_index: index_id (uuid), file_name, file_type, project_id
- rfc_detail_view: id, project_id, project_name, environment, impacted_platforms, rol_asignado, empleado_nombre, empleado_apellido, departamento, email

Important:
- Return ONLY the SQL query, nothing else
- Use lowercase for SQL keywords
- Use appropriate JOINs
- Add WHERE clauses as needed
- Include column aliases if needed for clarity`;

            const response = await axios.post(
                `${OLLAMA_URL}/api/generate`,
                {
                    model: model,
                    prompt: `${systemPrompt}\n\nQuestion: ${question}`,
                    stream: false,
                },
                { timeout: 30000 }
            );

            const generatedSQL = response.data.response.trim();
            logger.debug(`Generated SQL: ${generatedSQL}`);

            return generatedSQL;
        } catch (error) {
            logger.error(`Ollama SQL generation failed: ${error.message}`);
            throw new Error(`Failed to generate SQL: ${error.message}`);
        }
    },

    async generateText(prompt, model = 'mistral') {
        try {
            const response = await axios.post(
                `${OLLAMA_URL}/api/generate`,
                {
                    model: model,
                    prompt: prompt,
                    stream: false,
                },
                { timeout: 30000 }
            );

            return response.data.response.trim();
        } catch (error) {
            logger.error(`Ollama text generation failed: ${error.message}`);
            throw new Error(`Failed to generate text: ${error.message}`);
        }
    },
};

// ============================================
// SharePoint Client (Mock + Real modes)
// ============================================

const spClient = new SharePointClient({
    mockMode: process.env.SHAREPOINT_MOCK_MODE !== 'false', // Default: true (mock)
    mockPath: process.env.SHAREPOINT_MOCK_PATH || '/app/sharepoint_mock',
    tenantId: process.env.AZURE_TENANT_ID,
    clientId: process.env.AZURE_CLIENT_ID,
    clientSecret: process.env.AZURE_CLIENT_SECRET,
    tenant: process.env.SHAREPOINT_TENANT,
    siteName: process.env.SHAREPOINT_SITE_NAME,
});

logger.log(`SharePoint client initialized (Mode: ${spClient.isRealMode() ? 'AZURE' : 'MOCK'})`);

// ============================================
// Routes - Health & Status
// ============================================

app.get('/health', async (req, res) => {
    try {
        const dbHealthy = await pool.query('SELECT 1');
        const ollamaHealthy = await ollamaClient.checkHealth();

        res.json({
            status: 'ok',
            timestamp: new Date().toISOString(),
            database: dbHealthy ? 'connected' : 'disconnected',
            ollama: ollamaHealthy ? 'connected' : 'disconnected',
        });
    } catch (error) {
        logger.error(`Health check failed: ${error.message}`);
        res.status(503).json({
            status: 'error',
            error: error.message,
        });
    }
});

app.get('/status', async (req, res) => {
    try {
        const dbStats = await pool.query('SELECT COUNT(*) FROM rfc_records');
        const ollamaModels = await axios.get(`${OLLAMA_URL}/api/tags`);

        res.json({
            status: 'running',
            timestamp: new Date().toISOString(),
            environment: NODE_ENV,
            database: {
                host: DB_CONFIG.host,
                port: DB_CONFIG.port,
                name: DB_CONFIG.database,
                rfc_count: parseInt(dbStats.rows[0].count),
            },
            ollama: {
                url: OLLAMA_URL,
                models: ollamaModels.data.models?.length || 0,
            },
            mcp_server: {
                version: '1.0.0',
                port: MCP_PORT,
            },
        });
    } catch (error) {
        logger.error(`Status check failed: ${error.message}`);
        res.status(500).json({
            status: 'error',
            error: error.message,
        });
    }
});

// ============================================
// Routes - LLM SQL Generation
// ============================================

app.post('/api/llm/sql-generator', async (req, res) => {
    const { question, model = 'mistral' } = req.body;

    if (!question) {
        return res.status(400).json({
            success: false,
            error: 'Missing required field: question',
        });
    }

    try {
        const startTime = Date.now();

        // Generate SQL using LLM
        const generated_sql = await ollamaClient.generateSQL(question, model);

        // Validate and execute SQL
        const result = await pool.query(generated_sql);

        const executionTime = Date.now() - startTime;

        logger.log(`LLM SQL Query - Question: "${question}" | Time: ${executionTime}ms | Rows: ${result.rowCount}`);

        // Log to audit table
        await pool.query(
            `INSERT INTO query_audit (query_type, executed_query, execution_time_ms, rows_affected)
             VALUES ($1, $2, $3, $4)`,
            ['LLM_GENERATED', generated_sql, executionTime, result.rowCount]
        );

        res.json({
            success: true,
            question: question,
            generated_sql: generated_sql,
            results: result.rows,
            row_count: result.rowCount,
            execution_time_ms: executionTime,
            model: model,
        });
    } catch (error) {
        logger.error(`LLM SQL Generation error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
            question: question,
        });
    }
});

// ============================================
// Routes - Direct Query Execution
// ============================================

app.post('/api/query', async (req, res) => {
    const { sql } = req.body;

    if (!sql) {
        return res.status(400).json({
            success: false,
            error: 'Missing required field: sql',
        });
    }

    try {
        const startTime = Date.now();
        const result = await pool.query(sql);
        const executionTime = Date.now() - startTime;

        logger.log(`Direct Query - Time: ${executionTime}ms | Rows: ${result.rowCount}`);

        await pool.query(
            `INSERT INTO query_audit (query_type, executed_query, execution_time_ms, rows_affected)
             VALUES ($1, $2, $3, $4)`,
            ['DIRECT', sql, executionTime, result.rowCount]
        );

        res.json({
            success: true,
            results: result.rows,
            row_count: result.rowCount,
            execution_time_ms: executionTime,
        });
    } catch (error) {
        logger.error(`Direct query error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ============================================
// Routes - RFC Data Access
// ============================================

app.get('/api/rfc/records', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM rfc_records ORDER BY project_id');
        res.json({
            success: true,
            records: result.rows,
            count: result.rowCount,
        });
    } catch (error) {
        logger.error(`RFC records fetch error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

app.get('/api/rfc/records/:projectId', async (req, res) => {
    const { projectId } = req.params;

    try {
        const result = await pool.query(
            'SELECT * FROM rfc_detail_view WHERE project_id = $1',
            [projectId]
        );

        res.json({
            success: true,
            project_id: projectId,
            details: result.rows,
            count: result.rowCount,
        });
    } catch (error) {
        logger.error(`RFC detail fetch error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

app.get('/api/personal/directory', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM directorio_personal ORDER BY apellido, nombre'
        );

        res.json({
            success: true,
            employees: result.rows,
            count: result.rowCount,
        });
    } catch (error) {
        logger.error(`Directory fetch error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ============================================
// Routes - Schema Inspection
// ============================================

app.get('/api/schema', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                table_name,
                array_agg(
                    jsonb_build_object(
                        'name', column_name,
                        'type', data_type,
                        'nullable', is_nullable
                    )
                ) as columns
            FROM information_schema.columns
            WHERE table_schema = 'public'
            GROUP BY table_name
            ORDER BY table_name
        `);

        const schema = {};
        result.rows.forEach(row => {
            schema[row.table_name] = row.columns;
        });

        res.json({
            success: true,
            schema: schema,
        });
    } catch (error) {
        logger.error(`Schema inspection error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ============================================
// Routes - Text Generation (Future)
// ============================================

app.post('/api/llm/generate-text', async (req, res) => {
    const { prompt, model = 'mistral' } = req.body;

    if (!prompt) {
        return res.status(400).json({
            success: false,
            error: 'Missing required field: prompt',
        });
    }

    try {
        const generated_text = await ollamaClient.generateText(prompt, model);

        logger.log(`LLM Text Generation - Model: ${model}`);

        res.json({
            success: true,
            prompt: prompt,
            generated_text: generated_text,
            model: model,
        });
    } catch (error) {
        logger.error(`LLM text generation error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ============================================
// Routes - Document Processing (NEW ENDPOINTS)
// ============================================

/**
 * POST /api/documents/convert-rfc
 * Disparar conversión de RFC Excel a Markdown
 */
app.post('/api/documents/convert-rfc', authMiddleware, async (req, res) => {
    const { project_id, rfc_file_id, requested_by, convert_options = {} } = req.body;

    try {
        // Validar inputs
        if (!project_id || !rfc_file_id || !requested_by) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: project_id, rfc_file_id, requested_by'
            });
        }

        const startTime = Date.now();

        // 1. Validar que RFC existe
        const rfcResult = await pool.query(
            'SELECT file_name FROM rfc_document_index WHERE index_id = $1 AND project_id = $2',
            [rfc_file_id, project_id]
        );

        if (rfcResult.rowCount === 0) {
            return res.status(404).json({
                success: false,
                error: `RFC file not found: ${rfc_file_id}`
            });
        }

        const rfcFile = rfcResult.rows[0];

        // 2. Verificar si ya existe conversión reciente
        const existingResult = await pool.query(
            'SELECT markdown_id, conversion_status FROM rfc_markdown_index WHERE rfc_file_id = $1',
            [rfc_file_id]
        );

        if (existingResult.rowCount > 0 && existingResult.rows[0].conversion_status === 'converted') {
            return res.status(200).json({
                success: true,
                message: 'Conversion already exists',
                markdown_id: existingResult.rows[0].markdown_id,
                status: 'converted'
            });
        }

        // 3. Crear registro en rfc_markdown_index
        const markdownId = uuidv4();

        await pool.query(
            `INSERT INTO rfc_markdown_index
             (markdown_id, rfc_file_id, project_id, original_file_name, markdown_file_name,
              markdown_content, conversion_status, created_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
            [
                markdownId,
                rfc_file_id,
                project_id,
                rfcFile.file_name,
                `${project_id}_${Date.now()}.md`,
                Buffer.from(''),  // Contenido vacío al inicio
                'converting',
                requested_by
            ]
        );

        // 4. Enqueue async job
        (async () => {
            try {
                const rfcPath = `/app/RFC/${rfcFile.file_name}`;

                // Convertir con MarkItDown
                const { content, metadata } = await MarkItDownConverter.convertToMarkdown(
                    rfcPath,
                    convert_options
                );

                // Calcular hash
                const contentHash = MarkItDownConverter.calculateContentHash(content);
                const contentBuffer = MarkItDownConverter.contentToBuffer(content);
                const stats = MarkItDownConverter.getContentStats(content);

                // Actualizar DB
                await pool.query(
                    `UPDATE rfc_markdown_index SET
                     conversion_status = 'converted',
                     conversion_completed_at = NOW(),
                     markdown_content = $1,
                     markdown_size_bytes = $2,
                     markdown_lines = $3,
                     content_hash = $4
                     WHERE markdown_id = $5`,
                    [
                        contentBuffer,
                        stats.size_bytes,
                        stats.lines,
                        contentHash,
                        markdownId
                    ]
                );

                logger.log(`Markdown conversion completed for ${project_id}: ${markdownId}`);

                // Auditoría
                await pool.query(
                    `INSERT INTO query_audit (query_type, executed_query, execution_time_ms, rows_affected)
                     VALUES ('MARKDOWN_CONVERT', 'RFC to Markdown conversion', $1, 1)`,
                    [Date.now() - startTime]
                );

            } catch (error) {
                logger.error(`Markdown conversion failed for ${markdownId}: ${error.message}`);

                await pool.query(
                    `UPDATE rfc_markdown_index SET
                     conversion_status = 'error',
                     conversion_error_message = $1
                     WHERE markdown_id = $2`,
                    [error.message, markdownId]
                );
            }
        })();

        // Responder inmediatamente (202 Accepted)
        res.status(202).json({
            success: true,
            message: 'Conversion started',
            markdown_id: markdownId,
            status: 'converting',
            estimated_completion_seconds: 30
        });

    } catch (error) {
        logger.error(`Convert RFC error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * GET /api/documents/markdown/:projectId
 * Obtener markdown convertido de un RFC
 */
app.get('/api/documents/markdown/:projectId', authMiddleware, async (req, res) => {
    const { projectId } = req.params;

    try {
        const result = await pool.query(
            `SELECT markdown_id, original_file_name, conversion_status, sync_status,
                    markdown_content, markdown_size_bytes, markdown_lines,
                    created_at, conversion_completed_at, last_synced_at, created_by,
                    sharepoint_file_url
             FROM rfc_markdown_index
             WHERE project_id = $1 AND conversion_status = 'converted'
             ORDER BY created_at DESC LIMIT 1`,
            [projectId]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                success: false,
                error: `No converted markdown found for project_id: ${projectId}`
            });
        }

        const row = result.rows[0];
        const markdownContent = row.markdown_content.toString('utf-8');

        res.json({
            success: true,
            project_id: projectId,
            markdown_id: row.markdown_id,
            original_file_name: row.original_file_name,
            conversion_status: row.conversion_status,
            sync_status: row.sync_status,
            markdown_content: markdownContent,
            markdown_lines: row.markdown_lines,
            sharepoint_file_url: row.sharepoint_file_url,
            converted_at: row.conversion_completed_at,
            last_synced_at: row.last_synced_at,
            created_by: row.created_by
        });

        // Auditoría
        await pool.query(
            `INSERT INTO query_audit (query_type, executed_query, execution_time_ms, rows_affected)
             VALUES ('GET_MARKDOWN', $1, 0, 1)`,
            [`Retrieved markdown for ${projectId}`]
        );

    } catch (error) {
        logger.error(`Get markdown error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * POST /api/documents/sync-to-sharepoint
 * Sincronizar markdown a SharePoint
 */
app.post('/api/documents/sync-to-sharepoint', authMiddleware, async (req, res) => {
    const { markdown_id, target_folder_id, requested_by } = req.body;

    try {
        if (!markdown_id || !requested_by) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: markdown_id, requested_by'
            });
        }

        const startTime = Date.now();

        // Obtener documento markdown
        const mdResult = await pool.query(
            `SELECT markdown_id, project_id, markdown_file_name, markdown_content,
                    conversion_status FROM rfc_markdown_index WHERE markdown_id = $1`,
            [markdown_id]
        );

        if (mdResult.rowCount === 0 || mdResult.rows[0].conversion_status !== 'converted') {
            return res.status(404).json({
                success: false,
                error: 'Markdown not found or not yet converted'
            });
        }

        const md = mdResult.rows[0];
        const markdownContent = md.markdown_content.toString('utf-8');

        // Crear entrada en sync_log
        const syncLogId = uuidv4();

        await pool.query(
            `INSERT INTO sharepoint_sync_log
             (sync_log_id, markdown_id, operation_type, operation_status, target_folder_id,
              requested_by, file_size_bytes, document_type)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
            [
                syncLogId,
                markdown_id,
                'create',
                'pending',
                target_folder_id || 'default',
                requested_by,
                Buffer.byteLength(markdownContent, 'utf-8'),
                'markdown'
            ]
        );

        // Async upload
        (async () => {
            try {
                const uploadResult = await spClient.uploadMarkdownFile(
                    target_folder_id || 'default',
                    md.markdown_file_name,
                    markdownContent
                );

                // Actualizar rfc_markdown_index
                await pool.query(
                    `UPDATE rfc_markdown_index SET
                     sync_status = 'synced',
                     sharepoint_file_id = $1,
                     sharepoint_file_url = $2,
                     last_synced_at = NOW()
                     WHERE markdown_id = $3`,
                    [
                        uploadResult.file_id,
                        uploadResult.file_url,
                        markdown_id
                    ]
                );

                // Actualizar sync_log
                await pool.query(
                    `UPDATE sharepoint_sync_log SET
                     operation_status = 'success',
                     executed_at = NOW(),
                     completed_at = NOW(),
                     sharepoint_response_code = 200
                     WHERE sync_log_id = $1`,
                    [syncLogId]
                );

                logger.log(`SharePoint sync completed for ${markdown_id}`);

            } catch (error) {
                logger.error(`SharePoint sync failed for ${markdown_id}: ${error.message}`);

                await pool.query(
                    `UPDATE sharepoint_sync_log SET
                     operation_status = 'failed',
                     executed_at = NOW(),
                     sharepoint_error_message = $1
                     WHERE sync_log_id = $2`,
                    [error.message, syncLogId]
                );
            }
        })();

        res.status(202).json({
            success: true,
            message: 'Sync to SharePoint initiated',
            sync_log_id: syncLogId,
            operation_type: 'create',
            status: 'pending',
            estimated_completion_seconds: 20
        });

    } catch (error) {
        logger.error(`Sync SharePoint error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * POST /api/documents/sharepoint/create
 * Crear documento en SharePoint
 */
app.post('/api/documents/sharepoint/create', authMiddleware, async (req, res) => {
    const { markdown_id, target_folder_id, document_name, requested_by } = req.body;

    try {
        if (!markdown_id || !requested_by) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: markdown_id, requested_by'
            });
        }

        // Obtener documento
        const mdResult = await pool.query(
            'SELECT markdown_content, markdown_file_name FROM rfc_markdown_index WHERE markdown_id = $1',
            [markdown_id]
        );

        if (mdResult.rowCount === 0) {
            return res.status(404).json({
                success: false,
                error: 'Markdown document not found'
            });
        }

        const md = mdResult.rows[0];
        const content = md.markdown_content.toString('utf-8');
        const filename = document_name || md.markdown_file_name;

        // Realizar upload
        const uploadResult = await spClient.uploadMarkdownFile(
            target_folder_id || 'default',
            filename,
            content
        );

        res.json({
            success: true,
            file_id: uploadResult.file_id,
            file_url: uploadResult.file_url,
            size: uploadResult.size,
            created_at: uploadResult.created_at
        });

    } catch (error) {
        logger.error(`Create SharePoint document error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * POST /api/documents/sharepoint/update
 * Actualizar documento en SharePoint
 */
app.post('/api/documents/sharepoint/update', authMiddleware, async (req, res) => {
    const { markdown_id, new_content, requested_by } = req.body;

    try {
        if (!markdown_id || !new_content || !requested_by) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: markdown_id, new_content, requested_by'
            });
        }

        // Obtener sharepoint_file_id
        const mdResult = await pool.query(
            'SELECT sharepoint_file_id FROM rfc_markdown_index WHERE markdown_id = $1',
            [markdown_id]
        );

        if (mdResult.rowCount === 0 || !mdResult.rows[0].sharepoint_file_id) {
            return res.status(404).json({
                success: false,
                error: 'Document not found or not synced to SharePoint'
            });
        }

        const fileId = mdResult.rows[0].sharepoint_file_id;

        // Actualizar en SharePoint
        const updateResult = await spClient.updateFile(fileId, new_content);

        res.json({
            success: true,
            message: 'Document updated',
            updated_at: updateResult.updated_at
        });

    } catch (error) {
        logger.error(`Update SharePoint document error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * POST /api/documents/sharepoint/move
 * Mover documento en SharePoint
 */
app.post('/api/documents/sharepoint/move', authMiddleware, async (req, res) => {
    const { markdown_id, source_folder_id, target_folder_id, new_name, requested_by } = req.body;

    try {
        if (!markdown_id || !target_folder_id || !requested_by) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: markdown_id, target_folder_id, requested_by'
            });
        }

        // Obtener sharepoint_file_id
        const mdResult = await pool.query(
            'SELECT sharepoint_file_id FROM rfc_markdown_index WHERE markdown_id = $1',
            [markdown_id]
        );

        if (mdResult.rowCount === 0 || !mdResult.rows[0].sharepoint_file_id) {
            return res.status(404).json({
                success: false,
                error: 'Document not found or not synced to SharePoint'
            });
        }

        const fileId = mdResult.rows[0].sharepoint_file_id;

        // Mover en SharePoint
        const moveResult = await spClient.moveFile(fileId, target_folder_id, new_name);

        res.json({
            success: true,
            message: 'Document moved',
            moved_at: moveResult.moved_at
        });

    } catch (error) {
        logger.error(`Move SharePoint document error: ${error.message}`);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================
// Error Handling Middleware
// ============================================

app.use((err, req, res, next) => {
    logger.error(`Unhandled error: ${err.message}`);
    res.status(500).json({
        success: false,
        error: err.message,
    });
});

// ============================================
// Startup
// ============================================

async function startup() {
    try {
        // Test database connection
        logger.log('Connecting to PostgreSQL...');
        await pool.query('SELECT NOW()');
        logger.log('✓ PostgreSQL connected');

        // Test Ollama connection
        logger.log('Checking Ollama connection...');
        const ollamaOk = await ollamaClient.checkHealth();
        if (ollamaOk) {
            logger.log('✓ Ollama connected');
        } else {
            logger.warn('⚠ Ollama not available (will retry on requests)');
        }

        // Start server
        app.listen(MCP_PORT, MCP_HOST, () => {
            logger.log(`🚀 MCP Server running on ${MCP_HOST}:${MCP_PORT}`);
            logger.log(`Environment: ${NODE_ENV}`);
            logger.log(`Database: ${DB_CONFIG.database}`);
            logger.log(`Ollama: ${OLLAMA_URL}`);
        });
    } catch (error) {
        logger.error(`Startup error: ${error.message}`);
        process.exit(1);
    }
}

startup();

// Graceful shutdown
process.on('SIGTERM', async () => {
    logger.log('SIGTERM received, shutting down gracefully...');
    await pool.end();
    process.exit(0);
});
