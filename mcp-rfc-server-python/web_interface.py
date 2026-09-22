#!/usr/bin/env python3
"""
Interfaz Web para MCP RFC Server
Permite probar las 8 herramientas desde el navegador
Uso: python web_interface.py
Accede a: http://localhost:8000
"""

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import json
import uuid
from datetime import datetime
from config.settings import SHAREPOINT_MODE, OLLAMA_MODEL
# from utils.database import db_pool

app = FastAPI(title="MCP RFC Server - Web Interface")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Simulacion de Herramientas (sin servidor MCP)
# ============================================================

class ToolSimulator:
    """Simula las 8 herramientas MCP"""

    @staticmethod
    def postgresql_control(action: str, query: str, params: list = None):
        """Tool 1: PostgreSQL Control"""
        if not query:
            return {"error": "Query es requerido"}

        return {
            "id": str(uuid.uuid4())[:8],
            "action": action,
            "query": query[:50] + "..." if len(query) > 50 else query,
            "params": params or [],
            "status": "success",
            "timestamp": datetime.now().isoformat(),
            "rows_affected": 0
        }

    @staticmethod
    def convert_rfc_to_markdown(project_id: str, rfc_file_id: str, requested_by: str):
        """Tool 2: Convert RFC to Markdown"""
        return {
            "markdown_id": str(uuid.uuid4()),
            "project_id": project_id,
            "rfc_file_id": rfc_file_id,
            "requested_by": requested_by,
            "status": "conversion_complete",
            "size_bytes": 2048,
            "timestamp": datetime.now().isoformat()
        }

    @staticmethod
    def get_markdown(project_id: str, requested_by: str):
        """Tool 3: Get Markdown"""
        return {
            "project_id": project_id,
            "requested_by": requested_by,
            "content": f"# RFC {project_id}\n\nContenido Markdown del RFC...",
            "format": "markdown",
            "size": 2048,
            "timestamp": datetime.now().isoformat()
        }

    @staticmethod
    def sharepoint_create(markdown_id: str, target_folder_id: str, document_name: str, requested_by: str):
        """Tool 4: SharePoint Create"""
        return {
            "file_id": str(uuid.uuid4())[:12],
            "markdown_id": markdown_id,
            "target_folder_id": target_folder_id,
            "document_name": document_name,
            "requested_by": requested_by,
            "url": f"https://sharepoint.example.com/sites/rfc/{document_name}",
            "status": "created",
            "timestamp": datetime.now().isoformat()
        }

    @staticmethod
    def sharepoint_update(markdown_id: str, new_content: str, requested_by: str):
        """Tool 5: SharePoint Update"""
        return {
            "markdown_id": markdown_id,
            "requested_by": requested_by,
            "status": "updated",
            "content_size": len(new_content),
            "modified_timestamp": datetime.now().isoformat(),
            "version": 2
        }

    @staticmethod
    def sharepoint_move(markdown_id: str, source_folder: str, target_folder: str, new_name: str = None):
        """Tool 6: SharePoint Move"""
        return {
            "markdown_id": markdown_id,
            "source_folder_id": source_folder,
            "target_folder_id": target_folder,
            "new_name": new_name or "documento",
            "status": "moved",
            "new_path": f"/sites/rfc/{target_folder}/{new_name or 'documento'}",
            "timestamp": datetime.now().isoformat()
        }

    @staticmethod
    def sharepoint_read(markdown_id: str, requested_by: str):
        """Tool 7: SharePoint Read"""
        return {
            "markdown_id": markdown_id,
            "requested_by": requested_by,
            "content": f"Contenido del documento {markdown_id[:8]}...",
            "format": "markdown",
            "last_modified": datetime.now().isoformat(),
            "size": 1024
        }

    @staticmethod
    def sharepoint_sync(markdown_id: str, target_folder_id: str, requested_by: str):
        """Tool 8: SharePoint Sync"""
        return {
            "sync_id": str(uuid.uuid4()),
            "markdown_id": markdown_id,
            "target_folder_id": target_folder_id,
            "requested_by": requested_by,
            "status": "in_progress",
            "files_synced": 1,
            "timestamp": datetime.now().isoformat()
        }

# ============================================================
# Rutas API
# ============================================================

@app.post("/api/tools/{tool_name}")
async def call_tool(tool_name: str, params: dict):
    """Ejecuta una herramienta"""

    tools = {
        "postgresql_control": ToolSimulator.postgresql_control,
        "convert_rfc": ToolSimulator.convert_rfc_to_markdown,
        "get_markdown": ToolSimulator.get_markdown,
        "sharepoint_create": ToolSimulator.sharepoint_create,
        "sharepoint_update": ToolSimulator.sharepoint_update,
        "sharepoint_move": ToolSimulator.sharepoint_move,
        "sharepoint_read": ToolSimulator.sharepoint_read,
        "sharepoint_sync": ToolSimulator.sharepoint_sync,
    }

    if tool_name not in tools:
        raise HTTPException(status_code=404, detail=f"Herramienta {tool_name} no encontrada")

    try:
        result = tools[tool_name](**params)
        return {"success": True, "result": result}
    except TypeError as e:
        raise HTTPException(status_code=400, detail=f"Parametros inválidos: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/tools")
async def list_tools():
    """Lista todas las herramientas disponibles"""
    return {
        "tools": [
            {
                "name": "postgresql_control",
                "display_name": "PostgreSQL Control",
                "description": "Ejecutar operaciones en PostgreSQL",
                "group": "Transformacion",
                "params": {
                    "action": {"type": "string", "required": True, "options": ["select", "insert", "update", "delete"]},
                    "query": {"type": "string", "required": True},
                    "params": {"type": "array", "required": False}
                }
            },
            {
                "name": "convert_rfc",
                "display_name": "Convertir RFC a Markdown",
                "description": "Convierte archivos RFC a Markdown",
                "group": "Transformacion",
                "params": {
                    "project_id": {"type": "string", "required": True},
                    "rfc_file_id": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            },
            {
                "name": "get_markdown",
                "display_name": "Obtener Markdown",
                "description": "Recupera contenido Markdown de un RFC",
                "group": "Transformacion",
                "params": {
                    "project_id": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            },
            {
                "name": "sharepoint_create",
                "display_name": "SharePoint - Crear",
                "description": "Crear documento en SharePoint",
                "group": "SharePoint",
                "mode": "MOCK",
                "params": {
                    "markdown_id": {"type": "string", "required": True},
                    "target_folder_id": {"type": "string", "required": True},
                    "document_name": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            },
            {
                "name": "sharepoint_update",
                "display_name": "SharePoint - Editar",
                "description": "Actualizar documento en SharePoint",
                "group": "SharePoint",
                "mode": "MOCK",
                "params": {
                    "markdown_id": {"type": "string", "required": True},
                    "new_content": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            },
            {
                "name": "sharepoint_move",
                "display_name": "SharePoint - Mover",
                "description": "Mover documento entre carpetas",
                "group": "SharePoint",
                "mode": "MOCK",
                "params": {
                    "markdown_id": {"type": "string", "required": True},
                    "source_folder_id": {"type": "string", "required": True},
                    "target_folder_id": {"type": "string", "required": True},
                    "new_name": {"type": "string", "required": False}
                }
            },
            {
                "name": "sharepoint_read",
                "display_name": "SharePoint - Leer",
                "description": "Leer contenido de documento",
                "group": "SharePoint",
                "mode": "MOCK",
                "params": {
                    "markdown_id": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            },
            {
                "name": "sharepoint_sync",
                "display_name": "SharePoint - Sincronizar",
                "description": "Sincronizar contenido a SharePoint",
                "group": "SharePoint",
                "mode": "MOCK",
                "params": {
                    "markdown_id": {"type": "string", "required": True},
                    "target_folder_id": {"type": "string", "required": True},
                    "requested_by": {"type": "string", "required": True}
                }
            }
        ]
    }

@app.get("/api/status")
async def get_status():
    """Estado del servidor"""
    return {
        "status": "running",
        "tools_count": 8,
        "sharepoint_mode": SHAREPOINT_MODE,
        "ollama_model": OLLAMA_MODEL,
        "timestamp": datetime.now().isoformat()
    }

# ============================================================
# Interfaz Web HTML
# ============================================================

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MCP RFC Server - Interface Web</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        header {
            background: rgba(255,255,255,0.95);
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }

        h1 {
            color: #333;
            margin-bottom: 10px;
        }

        .status {
            display: flex;
            gap: 20px;
            font-size: 14px;
            color: #666;
        }

        .status-item {
            display: flex;
            align-items: center;
            gap: 5px;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #4CAF50;
        }

        .tools-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .tool-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .tool-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.15);
        }

        .tool-card.active {
            background: #667eea;
            color: white;
        }

        .tool-name {
            font-weight: bold;
            font-size: 16px;
            margin-bottom: 5px;
        }

        .tool-desc {
            font-size: 12px;
            opacity: 0.7;
            margin-bottom: 10px;
        }

        .tool-group {
            display: inline-block;
            font-size: 11px;
            padding: 3px 8px;
            background: #f0f0f0;
            border-radius: 3px;
            margin-top: 10px;
        }

        .tool-card.active .tool-group {
            background: rgba(255,255,255,0.2);
        }

        .tool-mode {
            display: inline-block;
            font-size: 10px;
            padding: 2px 6px;
            background: #FFC107;
            color: #333;
            border-radius: 2px;
            margin-left: 5px;
        }

        .editor-section {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        .editor-section h2 {
            color: #333;
            margin-bottom: 20px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }

        .form-group {
            margin-bottom: 15px;
        }

        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #333;
        }

        input, textarea, select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-family: monospace;
            font-size: 13px;
        }

        textarea {
            min-height: 100px;
            resize: vertical;
        }

        .required::after {
            content: " *";
            color: red;
        }

        .button-group {
            display: flex;
            gap: 10px;
            margin-top: 20px;
        }

        button {
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .btn-primary {
            background: #667eea;
            color: white;
        }

        .btn-primary:hover {
            background: #5568d3;
        }

        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }

        .btn-secondary:hover {
            background: #e0e0e0;
        }

        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .result-section {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 4px;
            margin-top: 20px;
            border-left: 4px solid #667eea;
        }

        .result-section h3 {
            color: #333;
            margin-bottom: 10px;
            font-size: 14px;
        }

        pre {
            background: #fff;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            font-size: 12px;
            color: #333;
        }

        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f0f0f0;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .error {
            color: #d32f2f;
            padding: 10px;
            background: #ffebee;
            border-radius: 4px;
            margin-top: 10px;
        }

        .success {
            color: #388e3c;
            padding: 10px;
            background: #e8f5e9;
            border-radius: 4px;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 MCP RFC Server - Interfaz Web</h1>
            <div class="status">
                <div class="status-item">
                    <div class="status-dot"></div>
                    <span>Servidor: En linea</span>
                </div>
                <div class="status-item">
                    <span>Herramientas: 8 disponibles</span>
                </div>
                <div class="status-item">
                    <span>SharePoint: MOCK mode</span>
                </div>
            </div>
        </header>

        <div class="tools-grid" id="toolsGrid"></div>

        <div class="editor-section" id="editorSection" style="display: none;">
            <h2 id="toolTitle">Selecciona una herramienta</h2>
            <form id="toolForm">
                <div id="paramsContainer"></div>
                <div class="button-group">
                    <button type="submit" class="btn-primary">Ejecutar Herramienta</button>
                    <button type="button" class="btn-secondary" onclick="resetForm()">Limpiar</button>
                </div>
            </form>
            <div id="resultContainer"></div>
        </div>
    </div>

    <script>
        let tools = [];
        let selectedTool = null;

        // Cargar herramientas
        async function loadTools() {
            try {
                const res = await fetch('/api/tools');
                const data = await res.json();
                tools = data.tools;
                renderTools();
            } catch (e) {
                console.error('Error cargando herramientas:', e);
            }
        }

        // Renderizar tarjetas de herramientas
        function renderTools() {
            const grid = document.getElementById('toolsGrid');
            grid.innerHTML = tools.map((tool, idx) => `
                <div class="tool-card" onclick="selectTool(${idx})">
                    <div class="tool-name">${tool.display_name}</div>
                    <div class="tool-desc">${tool.description}</div>
                    <div>
                        <span class="tool-group">${tool.group}</span>
                        ${tool.mode ? `<span class="tool-mode">${tool.mode}</span>` : ''}
                    </div>
                </div>
            `).join('');
        }

        // Seleccionar herramienta
        function selectTool(idx) {
            selectedTool = tools[idx];
            document.getElementById('editorSection').style.display = 'block';
            document.getElementById('toolTitle').textContent = selectedTool.display_name;

            // Renderizar formulario
            const container = document.getElementById('paramsContainer');
            container.innerHTML = Object.entries(selectedTool.params || {}).map(([key, param]) => {
                const required = param.required ? ' required' : '';
                const requiredClass = param.required ? 'required' : '';

                if (param.type === 'string' && param.options) {
                    return `
                        <div class="form-group">
                            <label class="${requiredClass}">${key}</label>
                            <select name="${key}"${required}>
                                <option value="">-- Seleccionar --</option>
                                ${param.options.map(o => `<option value="${o}">${o}</option>`).join('')}
                            </select>
                        </div>
                    `;
                } else if (param.type === 'array') {
                    return `
                        <div class="form-group">
                            <label class="${requiredClass}">${key} (JSON array)</label>
                            <textarea name="${key}"${required} placeholder='["valor1", "valor2"]'></textarea>
                        </div>
                    `;
                } else {
                    return `
                        <div class="form-group">
                            <label class="${requiredClass}">${key}</label>
                            <input type="text" name="${key}"${required} placeholder="${key}">
                        </div>
                    `;
                }
            }).join('');

            // Marcar tarjeta activa
            document.querySelectorAll('.tool-card').forEach((card, i) => {
                card.classList.toggle('active', i === idx);
            });

            // Limpiar resultado anterior
            document.getElementById('resultContainer').innerHTML = '';
        }

        // Ejecutar herramienta
        document.getElementById('toolForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const btn = e.target.querySelector('button[type="submit"]');
            const resultDiv = document.getElementById('resultContainer');

            // Recopilar parametros
            const params = {};
            const form = new FormData(e.target);
            for (let [key, value] of form) {
                if (value) {
                    try {
                        params[key] = JSON.parse(value);
                    } catch {
                        params[key] = value;
                    }
                }
            }

            // Mostrar loading
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Ejecutando...';
            resultDiv.innerHTML = '';

            try {
                const res = await fetch(`/api/tools/${selectedTool.name}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(params)
                });

                const data = await res.json();

                if (res.ok) {
                    resultDiv.innerHTML = `
                        <div class="result-section">
                            <h3>✅ Resultado</h3>
                            <pre>${JSON.stringify(data.result, null, 2)}</pre>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `<div class="error">❌ Error: ${data.detail}</div>`;
                }
            } catch (e) {
                resultDiv.innerHTML = `<div class="error">❌ Error: ${e.message}</div>`;
            } finally {
                btn.disabled = false;
                btn.innerHTML = 'Ejecutar Herramienta';
            }
        });

        function resetForm() {
            document.getElementById('toolForm').reset();
            document.getElementById('resultContainer').innerHTML = '';
        }

        // Cargar herramientas al iniciar
        loadTools();
    </script>
</body>
</html>
"""

@app.get("/", response_class=HTMLResponse)
async def get_interface():
    """Servir interfaz web"""
    return HTML_TEMPLATE

# ============================================================
# Main
# ============================================================

if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("🌐 MCP RFC Server - Interfaz Web")
    print("="*60)
    print("\n📍 Abre tu navegador en: http://localhost:8000")
    print("⏹️  Para detener: Ctrl+C\n")

    uvicorn.run(app, host="0.0.0.0", port=8000)
