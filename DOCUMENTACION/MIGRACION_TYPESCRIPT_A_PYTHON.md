# 🔄 PLAN DE MIGRACIÓN: TypeScript → Python

**Objetivo:** Migrar el MCP Server de Express.js (TypeScript) a Python puro

**Fecha inicio:** 2026-09-18  
**Estimado:** 4-6 horas  
**Estado:** EN PROGRESO

---

## 📋 LAS 8 HERRAMIENTAS A MIGRAR

| # | Nombre (TypeScript) | Función | Ubicación nueva |
|---|-------------------|---------|-----------------|
| 1 | `Tool_PostgresSQL_Control` | Ejecutar consultas SQL | `tools/postgres_control.py` |
| 2 | `Tool_Convert_RFC_To_Markdown` | Convertir Excel → Markdown | `tools/convert_rfc.py` |
| 3 | `Tool_Get_Markdown` | Obtener Markdown convertido | `tools/get_markdown.py` |
| 4 | `Tool_SharePoint_Create` | Crear documento | `tools/sharepoint_create.py` |
| 5 | `Tool_SharePoint_Update` | Editar documento | `tools/sharepoint_update.py` |
| 6 | `Tool_SharePoint_Move` | Mover documento | `tools/sharepoint_move.py` |
| 7 | `Tool_SharePoint_Read` | Leer documento | `tools/sharepoint_read.py` |
| 8 | `Tool_Sync_To_SharePoint` | Sincronizar a SharePoint | `tools/sharepoint_sync.py` |

---

## 🏗️ ESTRUCTURA NUEVA (Python)

```
MacroagenteMAF-MCP-/  (renombrar a: mcp-rfc-server-python/)
├── main.py                    ← Servidor MCP principal
├── requirements.txt           ← Dependencias Python
├── .env.example              
├── Dockerfile                ← Actualizar para Python
│
├── tools/                     ← Paquete de herramientas
│   ├── __init__.py
│   ├── postgres_control.py
│   ├── convert_rfc.py
│   ├── get_markdown.py
│   ├── sharepoint_create.py
│   ├── sharepoint_update.py
│   ├── sharepoint_move.py
│   ├── sharepoint_read.py
│   └── sharepoint_sync.py
│
├── utils/                     ← Utilidades compartidas
│   ├── __init__.py
│   ├── database.py           ← Pool PostgreSQL
│   ├── sharepoint_client.py  ← Cliente SharePoint
│   └── logger.py             ← Logging
│
├── config/
│   ├── __init__.py
│   └── settings.py           ← Configuración centralizada
│
└── README.md
```

---

## 📦 DEPENDENCIAS PYTHON REQUERIDAS

```
mcp>=0.1.0                 # MCP Protocol
psycopg[binary]>=3.1.0     # PostgreSQL
python-dotenv>=1.0.0       # Variables de entorno
openpyxl>=3.11.0          # Lectura Excel
python-pptx>=0.6.21       # PowerPoint (si es necesario)
markdownify>=0.11.0        # Conversión a Markdown
requests>=2.31.0           # HTTP requests
pydantic>=2.0.0            # Validación de datos
```

---

## 🔄 COMPARACIÓN: TypeScript vs Python

### TypeScript (Actual)
```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import pg from "pg";

const server = new McpServer({ name: "RFC Management System" });

server.tool("Tool_Name", "description", { params }, async (args) => {
  // implementación
});

server.connect(transport);
```

### Python (Nuevo)
```python
from mcp.server.mcpserver import MCPServer

mcp = MCPServer("RFC Management System")

@mcp.tool()
def tool_name(param1: str, param2: str) -> str:
    """Descripción detallada de la herramienta"""
    # implementación
    return result

if __name__ == "__main__":
    mcp.run()
```

---

## ✅ LISTA DE TAREAS

### Fase 1: Setup (30 min)
- [ ] Renombrar carpeta a `mcp-rfc-server-python`
- [ ] Crear estructura de directorios
- [ ] Crear `requirements.txt`
- [ ] Crear `Dockerfile` para Python
- [ ] Crear `main.py` base

### Fase 2: Migraciones de Tools (2-3 horas)
- [ ] Tool 1: PostgreSQL Control
- [ ] Tool 2: Convert RFC to Markdown
- [ ] Tool 3: Get Markdown
- [ ] Tool 4: SharePoint Create
- [ ] Tool 5: SharePoint Update
- [ ] Tool 6: SharePoint Move
- [ ] Tool 7: SharePoint Read
- [ ] Tool 8: SharePoint Sync

### Fase 3: Testing (1 hora)
- [ ] Testing local (docker-compose)
- [ ] Verificar cada tool
- [ ] Auditoría de errores

### Fase 4: Documentación (30 min)
- [ ] Actualizar README
- [ ] Documentar cambios
- [ ] Actualizar DOCUMENTACION/

---

## 🔑 PUNTOS CRÍTICOS DE MIGRACIÓN

### 1. PostgreSQL Connection
```python
# TypeScript: pool.query(sql, params)
# Python: connection.cursor().execute(sql, params)

import psycopg
from psycopg_pool import ConnectionPool

# Pool singleton
DB_POOL = None

def get_db_pool():
    global DB_POOL
    if not DB_POOL:
        DB_POOL = ConnectionPool(conninfo=DATABASE_URL)
    return DB_POOL
```

### 2. HTTP Requests (Antes llamaba al MCP Server en Express)
```python
# TypeScript: fetch() → Express endpoint
# Python: requests.post() o eliminar si lógica se mueve aquí

import requests

# Ya NO llamaremos al Express server
# La lógica VIENE AQUÍ directamente
```

### 3. Validación de Parámetros
```python
# TypeScript: z.string(), z.enum() → Zod
# Python: pydantic.BaseModel o type hints

from pydantic import BaseModel, Field

class ConvertRFCRequest(BaseModel):
    project_id: str = Field(..., description="ID del proyecto")
    requested_by: str = Field(..., description="Email del usuario")
```

### 4. Respuestas MCP
```python
# Todas retornan: { content: [{ type: "text", text: "..." }] }

def create_response(text: str) -> dict:
    return {
        "content": [{
            "type": "text",
            "text": text
        }]
    }
```

---

## 📝 EJEMPLO: Migración Tool 1 (PostgreSQL Control)

### TypeScript Original
```typescript
server.tool(
    "Tool_PostgresSQL_Control",
    "Ejecutar consultas en base de datos PostgreSQL para RFC",
    {
        action: z.enum(["select", "insert"]),
        query: z.string(),
        params: z.array(z.any()).optional()
    },
    async ({ action, query, params }) => {
        const client = await pool.connect();
        const result = await client.query(query, params || []);
        client.release();
        return { content: [{ type: "text", text: JSON.stringify(result.rows) }] };
    }
);
```

### Python Migrado
```python
from pydantic import BaseModel
from typing import Optional

class PostgresControlRequest(BaseModel):
    action: str  # "select" | "insert"
    query: str
    params: Optional[list] = None

@mcp.tool()
def tool_postgres_control(action: str, query: str, params: Optional[list] = None) -> str:
    """Ejecutar consultas en base de datos PostgreSQL para RFC"""
    try:
        with get_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params or [])
                if action == "select":
                    rows = cur.fetchall()
                    return json.dumps(rows, indent=2, default=str)
                else:
                    conn.commit()
                    return "✓ Inserción exitosa"
    except Exception as e:
        return f"Error BD: {str(e)}"
```

---

## 🚀 PRÓXIMOS PASOS

1. **Ahora:** Crear estructura base
2. **Luego:** Migrar herramientas una por una
3. **Después:** Testing y validación
4. **Finalmente:** Docker y deployment

---

**Status:** Listo para comenzar migración

**Siguiente documento:** IMPLEMENTACION_PYTHON_MCP.md (se creará durante ejecución)
