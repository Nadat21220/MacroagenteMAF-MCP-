# RFC MCP System - Arquitectura Completa

## Vision General

Sistema de automatizacion para gestion de Solicitudes de Fondos (RFC) usando:
- **LLM Local**: Ollama (Mistral model)
- **Interfaz Web**: Open WebUI
- **Herramientas**: MCP Server (Python)
- **Base de Datos**: PostgreSQL
- **ECM**: Alfresco (Content Management)
- **Orquestacion**: Docker Compose

## Flujo de Usuario

```
Usuario escribe prompt
        ↓
Open WebUI (http://localhost:3000)
        ↓
Ollama (localhost:11434)
        ↓
[Chat simple - sin MCP tools aun]
        ↓
Respuesta generada
```

## Componentes Docker

### 1. PostgreSQL (puerto 5432)
Base de datos central para:
- Datos RFC
- Usuarios y permisos
- Auditoria
- Tablas Alfresco

### 2. Ollama (puerto 11434)
LLM local ejecutando modelo `mistral`
- Procesa prompts naturales
- Sin censura ni filtros
- Acceso local en Docker

### 3. Open WebUI (puerto 3000)
Interfaz web para:
- Chat con Ollama
- Gestion de conversaciones
- Historial persistente
- Sistema de plugins/tools (futuro)

### 4. MCP Server Python (puerto 3001)
8 Herramientas disponibles:
1. Control PostgreSQL (CRUD)
2. Conversion RFC a Markdown
3. Validacion RFC
4. OCR y procesamiento de imagenes
5. Lectura de SharePoint (MOCK → Alfresco)
6. Creacion de RFC
7. Busqueda en base de datos
8. Sincronizacion a SharePoint (MOCK → Alfresco)

Estado actual: MOCK MODE (sin datos reales)
Proximo: Integracion con Alfresco real

### 5. Alfresco (puerto 8080)
ECM (Enterprise Content Management):
- Gestion de documentos RFC
- Versionado y auditoria
- Workflows
- Colaboracion de equipos
- Reemplaza SharePoint mock

### 6. pgAdmin (puerto 5050)
Interfaz web para PostgreSQL:
- Ver datos en tiempo real
- Ejecutar queries
- Gestion de base de datos

## Puertos Expuestos

| Servicio | Puerto | URL |
|---|---|---|
| Open WebUI | 3000 | http://localhost:3000 |
| MCP Server | 3001 | http://localhost:3001 |
| Alfresco | 8080 | http://localhost:8080/alfresco |
| Ollama | 11434 | http://localhost:11434 |
| PostgreSQL | 5432 | localhost:5432 |
| pgAdmin | 5050 | http://localhost:5050 |

## Flujo de Datos Propuesto (Fase 2)

Una vez implementado el wrapper HTTP:

```
Usuario
    ↓
Open WebUI
    ↓
Ollama
    ↓
[Detectar intento de usar herramienta]
    ↓
HTTP Request → MCP Server Wrapper
    ↓
Ejecutar herramienta MCP
    ↓
Alfresco / PostgreSQL
    ↓
Devolver resultado a Open WebUI
```

## Instalacion y Uso

### Opcion 1: Levantar Todo
```bash
./start.sh
→ Opcion 1
```
Levanta: PostgreSQL, Ollama, MCP, Open WebUI, Alfresco, pgAdmin

### Opcion 2: Chat CLI
```bash
./start.sh
→ Opcion 2
```
Terminal interactiva con Ollama y MCP tools

### Opcion 3: Interfaz Web
```bash
./start.sh
→ Opcion 3
```
Abre Open WebUI automáticamente en navegador

### Opcion 4: Ver Estado
```bash
./start.sh
→ Opcion 4
```
Muestra estado de todos los servicios Docker

### Opcion 5: Detener Todo
```bash
./start.sh
→ Opcion 5
```
Detiene y elimina todos los containers

## Proximos Pasos

### Fase 2: Wrapper HTTP para MCP
- Crear servidor FastAPI que expone MCP tools como endpoints HTTP
- Conectar con Open WebUI via OpenAPI/plugin system
- Permitir que Ollama invoque herramientas desde Open WebUI

### Fase 3: Integracion Alfresco Real
- Migrar de MOCK mode a herramientas Alfresco reales
- Crear credenciales y autenticacion
- Implementar workflows de RFC
- Integracion de versionado y auditoria

### Fase 4: Mejoras UI
- Dashboard personalizado en Open WebUI
- Visualizacion de RFC
- Metricas y reportes
- Notificaciones en tiempo real

## Notas Tecnicas

- Todo sin acentos ni emojis en codigo
- PostgreSQL se inicia primero (dependencia)
- Ollama descarga modelos automaticamente
- Alfresco puede tomar 2-3 minutos en iniciar
- MCP Server espera a PostgreSQL y Alfresco
- Open WebUI se conecta internamente a Ollama

## Troubleshooting

### Ollama no responde
```bash
docker logs ollama_service
```

### Alfresco tarda mucho
Esperar 2-3 minutos, es normal en primer inicio

### PostgreSQL connection refused
Verificar que postgres está healthy:
```bash
./start.sh → 4
```

### Open WebUI no conecta a Ollama
Verificar que ambos contenedores están en la misma red:
```bash
docker network inspect rfc_network
```
