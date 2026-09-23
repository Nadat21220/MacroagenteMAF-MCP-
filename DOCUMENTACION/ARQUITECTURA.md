# 🏗️ ARQUITECTURA: Diseño Técnico del MCP

**Documento técnico detallado de la arquitectura del NovaPay RFC MCP Server**

---

## 📐 Visión Conceptual

```
┌──────────────────────────────────────────────────────────┐
│                    CAPA DE USUARIO                       │
│  (Aplicación Next.js, agente MAF, o cliente REST)        │
└──────────────────────┬───────────────────────────────────┘
                       │ HTTP/JSON
                       ▼
┌──────────────────────────────────────────────────────────┐
│          MCP SERVER (Express.js + 8 Tools)               │
│  ├─ Conversión RFC (Excel → Markdown)                    │
│  ├─ Validación RFC                                       │
│  ├─ Operaciones de documentos (create, edit, move)       │
│  ├─ Auditoría y logging                                  │
│  └─ Integración con SQL Server (próximo)                 │
└──────────────────────┬───────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    ┌─────────┐  ┌──────────┐  ┌──────────┐
    │ Ollama  │  │PostgreSQL│  │SharePoint│
    │ (LLM)   │  │  (BD)    │  │ (Docs)   │
    └─────────┘  └──────────┘  └──────────┘
```

---

## 🔌 Componentes Principales

### 1. MCP Server (Express.js)

**Ubicación:** `mcp-server/src/server.js`

**Responsabilidades:**
- Exponer endpoints REST
- Ejecutar tools solicitadas por LLM
- Orquestar llamadas a BD y SharePoint
- Mantener auditoría

**Tecnología:**
- Framework: Express.js 4.x
- Runtime: Node.js 18+
- Validación: Zod schemas
- BD: node-postgres (pg)

**Endpoints Principales:**

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/documents/convert-rfc` | Convertir Excel RFC → Markdown |
| POST | `/api/documents/create` | Crear documento en BD |
| POST | `/api/documents/edit` | Editar documento existente |
| GET | `/api/documents/markdown/:id` | Obtener markdown convertido |
| POST | `/api/sharepoint/create` | Crear doc en SharePoint |
| POST | `/api/sharepoint/update` | Actualizar doc SharePoint |
| GET | `/api/audit` | Ver auditoría de operaciones |
| GET | `/health` | Health check |

### 2. Base de Datos (PostgreSQL 16)

**Ubicación:** `init-scripts/01-init-db.sql` y `02-create-document-sync-tables.sql`

**Tablas Principales:**

#### `rfc_records` (Registro central de RFCs)
```sql
┌─────────────────────────────────────┐
│ id (UUID) [PK]                      │
│ project_id (VARCHAR) [UNIQUE]       │ ← Llave natural
│ environment (VARCHAR)               │ ← Dev/QA/PROD
│ project_name (VARCHAR)              │
│ impacted_platform (VARCHAR)         │
│ created_at (TIMESTAMP)              │
│ updated_at (TIMESTAMP)              │
└─────────────────────────────────────┘
```

#### `directorio_personal` (Catálogo maestro de personas)
```sql
┌─────────────────────────────────────┐
│ empleado_id (UUID) [PK]             │
│ nombre (VARCHAR) [UNIQUE con apellido]
│ apellido (VARCHAR) [UNIQUE con nombre]
│ departamento (VARCHAR)              │
│ email (VARCHAR)                     │
│ registrado_en (TIMESTAMP)           │
└─────────────────────────────────────┘
```

#### `rfc_responsables` (Asignaciones N-a-M)
```sql
┌─────────────────────────────────────┐
│ asignacion_id (UUID) [PK]           │
│ project_id (VARCHAR) [FK]           │
│ empleado_id (UUID) [FK]             │
│ rol_asignado (VARCHAR)              │
│ asignado_en (TIMESTAMP)             │
└─────────────────────────────────────┘
```

#### `rfc_markdown_index` (Índice de conversiones)
```sql
┌─────────────────────────────────────┐
│ index_id (UUID) [PK]                │
│ project_id (VARCHAR) [FK]           │
│ markdown_content (BYTEA)            │ ← Contenido convertido
│ file_hash (VARCHAR)                 │ ← Para validar cambios
│ created_at (TIMESTAMP)              │
└─────────────────────────────────────┘
```

#### `rfc_audit_logs` (Auditoría inmutable - Append Only)
```sql
┌─────────────────────────────────────┐
│ log_id (UUID) [PK]                  │
│ project_id (VARCHAR) [FK]           │
│ action_type (VARCHAR)               │ ← CREATE, UPDATE, DELETE, etc.
│ performed_by (VARCHAR)              │ ← Email de quién actuó
│ timestamp (TIMESTAMP)               │
│ changes_hash (VARCHAR)              │ ← Hash de cambios
│ details_json (JSONB)                │ ← Detalles adicionales
└─────────────────────────────────────┘
```

**Índices Optimizados:**
```sql
CREATE INDEX idx_rfc_records_project_id ON rfc_records(project_id);
CREATE INDEX idx_rfc_audit_logs_project_id ON rfc_audit_logs(project_id);
CREATE INDEX idx_rfc_markdown_project_id ON rfc_markdown_index(project_id);
-- ... 10 índices más para optimización
```

### 3. Agente MAF (TypeScript/AutoGen)

**Ubicación:** `MacroagenteMAF-MCP-/main.ts`

**Responsabilidades:**
- Orquestar tools del MCP
- Mantener contexto conversacional
- Resolver ambigüedades
- Ejecutar flujos multi-step

**Tools Disponibles:**

| Tool | Parámetros | Retorna |
|------|-----------|---------|
| `convert_rfc_to_markdown` | `filePath, projectId` | `{ markdown, wordCount, status }` |
| `create_rfc_document` | `title, content, projectId` | `{ documentId, url, timestamp }` |
| `edit_rfc_document` | `documentId, newContent` | `{ updated, version, timestamp }` |
| `move_rfc_document` | `documentId, newFolder` | `{ success, newPath }` |
| `query_rfc_database` | `sqlQuery, params` | `{ rows, count, executionTime }` |
| `audit_operation` | `action, projectId, details` | `{ logId, timestamp }` |
| `sync_to_sharepoint` | `documentId, folderPath` | `{ syncId, status }` |
| `validate_rfc_schema` | `rfcData` | `{ valid, errors[] }` |

### 4. Ollama LLM (Local)

**Ubicación:** Docker service `ollama`

**Modelos Soportados:**
- Mistral (7B - recomendado)
- Orca-mini (3.8B - más ligero)
- Neural-Hermes (7B)

**Características:**
- ✅ Zero-latency (local)
- ✅ Sin tokens de API
- ✅ Privacidad garantizada
- ✅ Offline-first

**Selección de modelo:**
```bash
# Para máquinas con 8GB RAM:
ollama pull orca-mini  # Más rápido

# Para máquinas con 16GB+ RAM:
ollama pull mistral    # Mejor precisión
```

### 5. SharePoint Client (Mock + Real)

**Ubicación:** `mcp-server/src/sharepoint-client.js`

**Estados:**

#### Modo Mock (Desarrollo)
```javascript
// Simula operaciones sin Azure
// Útil para testing sin credenciales
{
  mode: 'mock',
  // Retorna respuestas simuladas
}
```

#### Modo Real (Producción)
```javascript
// Requiere credenciales Azure
{
  mode: 'real',
  credentials: {
    clientId: 'XXXXX',
    clientSecret: 'XXXXX',
    tenantId: 'XXXXX'
  }
}
```

---

## 🔄 Flujo de Procesamiento

### Escenario: Crear RFC automáticamente

```
1. Usuario: "Crear RFC para migrar BD a RDS"
   │
2. LLM (Ollama): 
   ├─ Entiende intención
   ├─ Propone estructura RFC
   └─ Ejecuta tools:
   │
3. Tool: create_rfc_document
   ├─ Valida estructura (schema)
   ├─ Inserta en rfc_records
   ├─ Registra en rfc_audit_logs
   └─ Retorna documentId
   │
4. Tool: sync_to_sharepoint
   ├─ Convierte a formato SharePoint
   ├─ Sube a SharePoint (si credenciales disponibles)
   └─ Retorna sync_id
   │
5. Respuesta al usuario:
   "✅ RFC creado (ID: proj-123) - Listo para revisión"
```

### Flujo de auditoría

```
Operación del usuario
       │
       ▼
Validar autorización (email)
       │
       ▼
Ejecutar operación (BD)
       │
       ▼
Registrar en rfc_audit_logs
  ├─ Qué operación (action_type)
  ├─ Quién la hizo (performed_by)
  ├─ Cuándo (timestamp)
  └─ Qué cambió (changes_hash)
       │
       ▼
Retornar resultado a usuario
```

---

## 🔐 Seguridad por Capas

### Capa 1: Entrada (Validación)
```typescript
// Zod schema valida tipos y rangos
const rfcSchema = z.object({
  projectId: z.string().min(3).max(100),
  environment: z.enum(['Dev', 'QA', 'PROD']),
  email: z.string().email(),
  // ... más campos
});
```

### Capa 2: SQL Injection Prevention
```typescript
// Parámetros siempre separados de SQL
const result = await pool.query(
  'SELECT * FROM rfc_records WHERE project_id = $1',
  [projectId]  // ← Parámetro seguro
);
// NUNCA: 'WHERE project_id = ' + projectId
```

### Capa 3: Autorización
```typescript
// Email requerido en cada operación
if (!email) {
  throw new Error('Email requerido para auditoría');
}
// Registra en audit_logs quién hizo qué
```

### Capa 4: Auditoría Inmutable
```typescript
// INSERT-only en audit_logs
// NO se puede borrar, solo leer
await insertAuditLog({
  action: 'CREATE_RFC',
  performedBy: email,
  timestamp: new Date(),
  changeHash: hash(changes)
});
```

---

## 📦 Estructura de Carpetas

```
mcp-server/
├── src/
│   ├── server.js              ← Servidor Express principal
│   ├── markitdown-converter.js ← Conversión Excel → Markdown
│   ├── sharepoint-client.js   ← Cliente SharePoint (Mock/Real)
│   ├── auth-middleware.js     ← Validación de email
│   └── database.js            ← Pool conexiones PostgreSQL
├── Dockerfile                 ← Imagen Docker
├── package.json               ← Dependencias
└── .dockerignore              ← Archivos a excluir en imagen

MacroagenteMAF-MCP-/
├── main.ts                    ← Definición de tools
├── package.json               ← Dependencias @autogen
└── tsconfig.json              ← Config TypeScript

init-scripts/
├── 01-init-db.sql             ← Schema inicial
└── 02-create-document-sync-tables.sql ← Tablas adicionales

docker-compose.yml             ← Orquestación de servicios
```

---

## 🚀 Decisiones Arquitectónicas

### 1. PostgreSQL en lugar de SQL Server (NovaPay)
**Por qué:**
- MCP es independiente, no debe replicar datos de producción
- Facilita testing sin acceso a BD corporativa
- Permite datos de RFC en entorno controlado

**Próximo paso:**
- Integración bidireccional: MCP ↔ SQL Server mediante APIs

### 2. Ollama local en lugar de OpenAI/Claude
**Por qué:**
- Privacidad: datos RFC nunca salen del servidor
- Costo: $0 vs cientos de dólares/mes
- Independencia: sin vendor lock-in

**Tradeoff:**
- Menos precisión que modelos cloud
- Requiere GPU para performance óptima

### 3. SharePoint Mock + Real mode
**Por qué:**
- Desarrollo sin credenciales Azure
- Testing antes de integración real
- Fail-safe si credenciales expiran

---

## 📊 Rendimiento Esperado

### Latencias típicas (en local, sin GPU)

| Operación | Tiempo |
|-----------|--------|
| Convertir RFC Excel (50 KB) → Markdown | 2-3 seg |
| Query simple a BD | < 100 ms |
| LLM genera respuesta (sin GPU) | 5-15 seg |
| LLM genera respuesta (con GPU) | 1-2 seg |
| Crear documento en SharePoint | 2-5 seg |
| Registrar auditoría | < 50 ms |

### Throughput esperado
- **Queries concurrentes:** 10-20 (limitado por Ollama)
- **RFCs por minuto:** 3-5 (limitado por LLM)
- **Usuarios simultáneos:** 2-3 (en máquina de desarrollo)

### Escalabilidad
- **Horizontal:** Load balancer + múltiples MCP Servers
- **Vertical:** Usar GPU para Ollama
- **Caché:** Redis para queries frecuentes

---

## 🔄 Integración Futura

### Fase 4: SharePoint Real (En pausa, espera Azure)
- Integrar credenciales Azure AD
- Sincronizar documentos bidireccionales

### Fase 6: SQL Server Integration
- Leer metadatos RFC de SQL Server de NovaPay
- Escribir RFCs creados por MCP en SQL Server
- Sincronización de cambios

### Fase 7: Frontend Integration
- Consumir endpoints MCP desde Next.js app
- Mostrar RFC generados en dashboard
- Edición colaborativa

---

## 📚 Referencias

- [Express.js](https://expressjs.com/)
- [PostgreSQL 16](https://www.postgresql.org/docs/16/)
- [Ollama Models](https://ollama.ai)
- [MCP Spec](https://spec.modelcontextprotocol.io/)
- [Zod Validation](https://zod.dev/)

---

**Última actualización:** 2026-09-18  
**Versión arquitectura:** 1.0.0
