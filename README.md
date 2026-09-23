# RFC MCP Management System - Docker Edition

Estado: Sistema completamente operacional con Docker Compose
Version: 2.0.0 (Python + Open WebUI + Alfresco)
Ultima actualizacion: 2026-09-21

---

## Tabla de Contenidos

1. [Que es?](#que-es-este-sistema)
2. [Iniciar Sistema](#como-inicializar)
3. [3 Formas de Usar](#3-formas-de-usar)
4. [8 Herramientas](#8-herramientas-disponibles)
5. [Estructura](#estructura-de-carpetas)
6. [Arquitectura](#arquitectura)

---

## Que es este sistema?

Sistema de automatizacion para gestion de Solicitudes de Fondos (RFC) con:
- **Interfaz Web**: Open WebUI (chat visual)
- **LLM Local**: Ollama (Mistral model, sin censura)
- **Herramientas**: MCP Server con 8 funciones
- **Base de datos**: PostgreSQL
- **ECM**: Alfresco (reemplaza SharePoint)
- **Orquestacion**: Docker Compose (todo en containers)

```
Usuario → Open WebUI:3000 → Ollama → [MCP Tools] → PostgreSQL/Alfresco
```

---

## 3 Formas de Usar

### Forma 1: Interfaz Web (Recomendada)
```bash
./start.sh → Opcion 3
```
- Abre automaticamente http://localhost:3000
- Chat visual con Ollama
- Interfaz moderna y responsive
- Guardar conversaciones
- Proxima fase: MCP tools integrados

### Forma 2: Terminal CLI
```bash
./start.sh → Opcion 2
```
- Chat interactivo en terminal
- Acceso a MCP tools directamente
- Ideal para scripting/automatizacion
- Escribe `salir` para terminar

### Forma 3: Desarrollo
```bash
# Terminal 1: Levantar todo
./start.sh → Opcion 1

# Terminal 2: Ejecutar tests
./TESTING_COMPLETO.sh

# Terminal 3: Ver logs en tiempo real
docker-compose logs -f
```

---

## 8 Herramientas Disponibles

### Transformacion (3)

| # | Herramienta | Funcion | Estado |
|---|---|---|---|
| 1 | PostgreSQL Control | Ejecutar queries (SELECT, INSERT, UPDATE, DELETE) | OK |
| 2 | RFC → Markdown | Convertir archivos RFC a Markdown | OK |
| 3 | Get Markdown | Recuperar contenido Markdown | OK |

### Alfresco / ECM (5)

| # | Herramienta | Funcion | Estado |
|---|---|---|---|
| 4 | Create | Crear documentos en Alfresco | MOCK → Real (Fase 2) |
| 5 | Update | Editar documentos | MOCK → Real (Fase 2) |
| 6 | Move | Mover entre carpetas | MOCK → Real (Fase 2) |
| 7 | Read | Leer documentos | MOCK → Real (Fase 2) |
| 8 | Sync | Sincronizar contenido | MOCK → Real (Fase 2) |

Estado actual: MOCK (simulado, pruebas funcionales OK)
Fase 2: Integracion con Alfresco REST API (real)

---

## Como Inicializar

### Prerequisitos
- Docker instalado
- Docker Compose v2+
- Minimo 4GB RAM disponible

### 1. Comando Unico
```bash
cd ~/Documentos/Proyecto_NovaPay
./start.sh
```

### 2. Selecciona Opcion

```
OPCION 1: Levantar Todo (Docker)
  - PostgreSQL + Ollama + MCP + Open WebUI + Alfresco

OPCION 2: Chat CLI con Ollama
  - Terminal interactiva -> Ollama -> MCP

OPCION 3: Interfaz Web (Open WebUI)
  - http://localhost:3000 (navegador web)

OPCION 4: Ver Estado
  - Estado de todos los servicios

OPCION 5: Detener Todo
  - Detiene containers y elimina volumen temporal
```

### 3. Resultado
```
OK Servicios levantados:
  PostgreSQL:     localhost:5432
  Ollama:         localhost:11434
  Open WebUI:     http://localhost:3000
  MCP Server:     localhost:3001
  Alfresco:       http://localhost:8080/alfresco
  pgAdmin:        http://localhost:5050
```

---

## Estructura de Carpetas

```
Proyecto_NovaPay/
├── README.md ........................ Este archivo
├── ARCHITECTURE.md .................. Arquitectura completa
├── docker-compose.yml ............... Todos los servicios
├── start.sh ......................... Script principal (5 opciones)
│
├── mcp-rfc-server-python/ ........... SERVIDOR MCP PYTHON
│   ├── main.py ..................... 8 herramientas
│   ├── requirements.txt ............ Dependencias Python
│   ├── Dockerfile .................. Para Docker
│   ├── .env ......................... Configuracion
│   ├── ollama_client.py ............ CLI chat con Ollama
│   ├── run_tests.py ................ Pruebas de herramientas
│   ├── config/
│   │   └── settings.py ............. Config centralizada
│   └── utils/
│       └── database.py ............. Pool PostgreSQL
│
├── alfresco-config/ ................ Configuraciones Alfresco
├── init-scripts/ ................... Scripts inicializacion BD
├── venv/ ............................ Python virtual environment
│
└── mcp-rfc-server-python/data/ ..... Almacenamiento local
    ├── rfc_storage/
    ├── markdown/
    └── cache/
```

### Componentes principales:

- **docker-compose.yml**: Define PostgreSQL, Ollama, MCP, Open WebUI, Alfresco, pgAdmin
- **start.sh**: Menu interactivo (5 opciones)
- **mcp-rfc-server-python/**: Servidor MCP con 8 herramientas
- **ARCHITECTURE.md**: Diagrama de flujos y puertos
- **README.md**: Este archivo (guia de uso)

---

## Open WebUI - Interfaz Web Moderna

### Que es Open WebUI?
Interfaz web profesional para chatear con modelos LLM locales.
- Chat visual (similar a ChatGPT)
- Historial de conversaciones
- Sistema de plugins (futuro para MCP tools)
- Responsive (desktop y movil)

### Como Iniciar

```bash
./start.sh
→ Opcion 3
```

Abre automaticamente: http://localhost:3000

### Acceso Manual
```
URL: http://localhost:3000
Usuario: (crear en primer acceso)
```

### Caracteristicas Actuales
- Chat con Ollama (modelo Mistral)
- Conversaciones guardadas
- Sin censura ni filtros
- Funcionamiento completamente local

### Proxima Fase (Fase 2)
- Integracion de MCP tools como plugins
- Invocar herramientas desde el chat
- Contexto compartido entre chat y herramientas
- Flujos automatizados

---

## Arquitectura

Para detalles completos ver: **ARCHITECTURE.md**

```
┌─────────────────────────────────────────────────────┐
│                   USUARIO                           │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │   Open WebUI:3000       │ ← Interfaz web
        │   (Chat visual)         │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │   Ollama:11434          │ ← LLM local
        │   (Mistral model)       │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │  MCP Server:3001        │ ← Herramientas
        │  (8 funciones)          │
        └─┬──────────┬────────────┘
          │          │
    ┌─────▼─┐   ┌────▼──────────┐
    │Postgre │   │  Alfresco:8080│ ← ECM
    │SQL:5432│   │ (Documentos)   │
    └────────┘   └────────────────┘
```

### Puertos Expuestos

| Servicio | Puerto | URL |
|---|---|---|
| Open WebUI | 3000 | http://localhost:3000 |
| Ollama | 11434 | http://localhost:11434 |
| MCP Server | 3001 | http://localhost:3001 |
| Alfresco | 8080 | http://localhost:8080/alfresco |
| PostgreSQL | 5432 | localhost:5432 |
| pgAdmin | 5050 | http://localhost:5050 |

---

## Configuracion

Archivo: mcp-rfc-server-python/.env

```env
# Base de datos
DB_HOST=postgres
DB_PORT=5432
DB_USER=rfcadmin
DB_PASSWORD=rfc_secure_2024
DB_NAME=rfc_management

# Ollama
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=mistral

# MCP Server
MCP_PORT=3001
MCP_HOST=0.0.0.0
```

---

## Roadmap

### Fase 1: OK (Esta sesion)
- Docker Compose con todos servicios
- Open WebUI como interfaz
- Ollama funcionando
- MCP Server Python

### Fase 2: Proxima
- Wrapper HTTP para MCP
- Integracion Open WebUI ↔ MCP tools
- Herramientas Alfresco reales

### Fase 3: Avanzado
- Dashboard personalizado
- Workflows de RFC
- Reportes y analisis
- Notificaciones en tiempo real

---

## Primeros Pasos

```bash
# 1. Navega al proyecto
cd ~/Documentos/Proyecto_NovaPay

# 2. Levanta todo (5-30 seg segun sistema)
./start.sh → Opcion 1

# 3. Abre Open WebUI en navegador (espera 15 seg)
http://localhost:3000

# 4. Escribe tu primer prompt en el chat
"Hola, cual es mi nombre?"
```

---

Documentacion completa: Ver **ARCHITECTURE.md**

