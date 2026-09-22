# MCP RFC Server - Python Edition

**Servidor MCP para gestión de RFCs en Python puro**

Migración de TypeScript a Python del servidor MCP que expone 8 herramientas para gestionar RFCs:

1. Control PostgreSQL
2. Convertir RFC a Markdown
3. Obtener Markdown Convertido
4. SharePoint - Crear Documento
5. SharePoint - Editar Documento
6. SharePoint - Mover Documento
7. SharePoint - Leer Documento
8. Sincronizar a SharePoint

---

## 🚀 Instalación Rápida

### Requisitos
- Python 3.11+
- PostgreSQL 16+
- Ollama (opcional, para LLM local)

### Pasos

```bash
# 1. Instalar dependencias
pip install -r requirements.txt

# 2. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus valores

# 3. Iniciar servidor
python main.py
```

### Con Docker

```bash
# Construir
docker build -t mcp-rfc-server-python .

# Ejecutar
docker run --env-file .env -p 3000:3000 mcp-rfc-server-python
```

---

## 📁 Estructura

```
mcp-rfc-server-python/
├── main.py                 ← Servidor MCP principal + 8 tools
├── requirements.txt        ← Dependencias Python
├── Dockerfile             ← Imagen Docker
├── .env.example           ← Variables de entorno (ejemplo)
│
├── config/
│   ├── __init__.py
│   └── settings.py        ← Configuración centralizada
│
├── utils/
│   ├── __init__.py
│   ├── database.py        ← Pool PostgreSQL
│   ├── sharepoint_client.py ← Cliente SharePoint (pendiente)
│   └── logger.py          ← Logging (pendiente)
│
└── tools/                 ← Herramientas (próxima fase)
    ├── __init__.py
    ├── postgres_control.py
    ├── convert_rfc.py
    ├── get_markdown.py
    ├── sharepoint_create.py
    ├── sharepoint_update.py
    ├── sharepoint_move.py
    ├── sharepoint_read.py
    └── sharepoint_sync.py
```

---

## ✨ Cambios vs TypeScript

| Aspecto | TypeScript | Python |
|--------|-----------|--------|
| **Framework** | AutoGen SDK | MCP Server Python |
| **Validación** | Zod | Pydantic (próximo) |
| **BD** | node-postgres | psycopg3 |
| **HTTP** | fetch() | requests / httpx |
| **Decorators** | N/A | @mcp.tool() |
| **Server** | Express.js | MCP puro |

---

## 🔧 Desarrollo

### Crear nueva herramienta

```python
@mcp.tool()
def tool_name(param1: str, param2: int) -> str:
    """Descripción detallada de la herramienta"""
    try:
        # Tu lógica aquí
        return json.dumps({"success": True, "data": result})
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})
```

### Testing

```bash
# Ejecutar en modo desarrollo
python -m main

# Con hot reload (instalar watchdog)
pip install watchdog[watchmedo]
watchmedo auto-restart -d . -p '*.py' -- python main.py
```

---

## 📊 Estado de Migración

- ✅ Estructura base Python
- ✅ Configuración centralizada
- ✅ Pool PostgreSQL
- ✅ MCP Server + 8 tools (versión beta)
- ⏳ Separación modular de tools
- ⏳ Client SharePoint real
- ⏳ Logging centralizado
- ⏳ Testing completo

---

## 🎯 Próximas Fases

1. **Modularizar tools** en archivos separados (tools/*.py)
2. **Implementar SharePoint real** con Azure SDK
3. **Testing unitario** para cada tool
4. **Logging centralizado** con JSON
5. **Performance optimization**

---

**Estado:** 🚀 Migración en progreso (50% completada)

**Última actualización:** 2026-09-18
