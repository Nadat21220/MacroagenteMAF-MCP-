# 🔗 INTEGRACIÓN CON PLATAFORMA MACROPAY RFC

**Guía para integrar el MCP Server en rfc.macropay.mx (Next.js + FastAPI)**

---

## 📌 CONTEXTO

La plataforma RFC de Macropay está compuesta por:

| Componente | Tech | Ubicación |
|-----------|------|-----------|
| **Frontend** | Next.js 16 + React 19 | rfc.macropay.mx |
| **Backend Principal** | FastAPI (Python 3.12) | api-rfc.macropay.mx |
| **Infra Reader** | FastAPI (read-only) | api-rfc-infra-reader |
| **Bridge** | FastAPI | api-rfc-bridge |
| **BD** | SQL Server | PlataformaRFC, InfraDevopsMacropay |
| **Almacenamiento** | S3 | rfc-documents-macropay |

**El MCP Server es un ASISTENTE que genera/valida RFCs** antes de que se creen en la plataforma real.

---

## 🎯 Objetivo de Integración

```
Usuario en rfc.macropay.mx:
  "Ayuda, necesito crear un RFC para migrar a RDS"
     │
     ▼
Frontend llama al MCP:
  POST /api/rfc/assistant
  { prompt: "migrar a RDS", context: {...} }
     │
     ▼
MCP (LLM local) genera:
  - Estructura RFC validada
  - Campos completados automáticamente
  - Recomendaciones
     │
     ▼
Frontend muestra en formulario:
  "¿Usar estos datos? [Editar] [Crear RFC] [Cancelar]"
     │
     ▼
Usuario confirma y se crea en FastAPI/SQL Server
```

---

## 🔌 Puntos de Integración

### 1. Frontend → MCP (Next.js → Node.js)

#### Endpoint MCP propuesto:
```
POST /api/rfc/assistant/generate
Content-Type: application/json

{
  "prompt": "crear RFC para cambiar configuración de S3",
  "context": {
    "userId": "user@macropay.mx",
    "department": "Infraestructura",
    "environment": "PROD",
    "platforms": ["AWS", "Kubernetes"]
  }
}
```

#### Respuesta esperada:
```json
{
  "success": true,
  "rfc": {
    "title": "Cambio de configuración de S3",
    "description": "...",
    "impactedPlatforms": ["AWS S3"],
    "riskLevel": "MEDIUM",
    "approvalPath": ["Arquitectura", "Seguridad"],
    "estimatedDuration": "2 horas",
    "rollbackPlan": "..."
  },
  "generatedAt": "2026-09-18T10:30:00Z",
  "confidence": 0.92
}
```

#### Implementación en Next.js:
```typescript
// pages/rfc/assistant.tsx
import { useState } from 'react';

export default function RFCAssistant() {
  const [prompt, setPrompt] = useState('');
  const [generated, setGenerated] = useState(null);

  const handleGenerate = async () => {
    const res = await fetch('http://localhost:3000/api/rfc/assistant/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt,
        context: {
          userId: session.user.email,
          department: user.department
        }
      })
    });
    
    const data = await res.json();
    setGenerated(data.rfc);
  };

  return (
    <div>
      <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} />
      <button onClick={handleGenerate}>Generar RFC</button>
      {generated && (
        <div>
          <h3>{generated.title}</h3>
          <p>{generated.description}</p>
          <button onClick={() => createRFCInPlatform(generated)}>
            Crear en Plataforma
          </button>
        </div>
      )}
    </div>
  );
}
```

### 2. MCP → SQL Server (Sincronización)

#### Opción A: MCP lee de SQL Server (NO escribe)
```typescript
// mcp-server/src/sql-server-client.js
const sqlConfig = {
  server: process.env.SQL_SERVER_HOST,
  authentication: { type: 'default', options: { userName: '', password: '' }},
  options: { encrypt: true, database: 'PlataformaRFC' }
};

// Leer metadatos de RFC existentes
async function getExistingRFCs() {
  const pool = new mssql.ConnectionPool(sqlConfig);
  await pool.connect();
  const result = await pool.request()
    .query('SELECT TOP 100 id, title, status FROM dbo.RFC ORDER BY createdAt DESC');
  return result.recordset;
}
```

#### Opción B: Backend FastAPI sincroniza (MCP → FastAPI → SQL Server)
```typescript
// MCP genera RFC, lo envía a FastAPI
async function createRFCInPlatform(rfcData) {
  const res = await fetch('https://api-rfc.macropay.mx/api/rfc/create', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${serviceToken}`
    },
    body: JSON.stringify({
      source: 'mcp-assistant',
      rfcData,
      generatedBy: email
    })
  });
  
  return res.json();
}
```

**RECOMENDACIÓN:** Opción B es más segura (no expone credenciales SQL Server)

### 3. Auditoría Integrada

El MCP registra en `rfc_audit_logs` cada operación:

```sql
SELECT * FROM rfc_audit_logs 
WHERE action_type = 'RFC_GENERATED_BY_MCP'
  AND created_at >= CURRENT_TIMESTAMP - INTERVAL '1 day'
ORDER BY created_at DESC;
```

Backend FastAPI puede consultar esta auditoría:
```python
# backend/app/routers/rfc.py
@app.get("/api/rfc/{rfc_id}/mcp-generation-log")
async def get_mcp_generation_log(rfc_id: str):
    # Consultar MCP audit log
    response = requests.get(
        f'http://localhost:3000/api/audit',
        params={'projectId': rfc_id, 'actionType': 'RFC_GENERATED_BY_MCP'}
    )
    return response.json()
```

---

## 🛠️ GUÍA DE IMPLEMENTACIÓN

### Paso 1: Crear nuevo endpoint en MCP Server

**Ubicación:** `mcp-server/src/endpoints/rfc-assistant.js`

```javascript
const express = require('express');
const { Ollama } = require('ollama');
const { z } = require('zod');

const router = express.Router();

// Schema de validación
const GenerateRFCSchema = z.object({
  prompt: z.string().min(10).max(1000),
  context: z.object({
    userId: z.string().email(),
    department: z.string(),
    environment: z.enum(['Dev', 'QA', 'PROD']).optional(),
    platforms: z.array(z.string()).optional()
  })
});

// Endpoint
router.post('/assistant/generate', async (req, res) => {
  try {
    // Validar input
    const input = GenerateRFCSchema.parse(req.body);
    
    // Construir prompt para LLM
    const systemPrompt = `Eres un asistente experto en RFCs de Macropay.
    El usuario solicita crear un RFC. 
    Genera una estructura RFC válida con todos los campos requeridos.
    Responde SIEMPRE en JSON formato.`;
    
    const userPrompt = `${input.prompt}
    Contexto: ${JSON.stringify(input.context)}
    Generar estructura RFC completa.`;
    
    // Llamar LLM
    const ollama = new Ollama({ host: process.env.OLLAMA_HOST });
    const response = await ollama.generate({
      model: process.env.OLLAMA_MODEL,
      prompt: userPrompt,
      system: systemPrompt,
      stream: false
    });
    
    // Parsear respuesta JSON
    const rfcData = JSON.parse(response.response);
    
    // Validar estructura RFC
    const validationErrors = validateRFCStructure(rfcData);
    if (validationErrors.length > 0) {
      return res.status(400).json({
        success: false,
        errors: validationErrors,
        suggestion: "Formato inválido, revisa los campos obligatorios"
      });
    }
    
    // Registrar en auditoría
    await logAudit({
      actionType: 'RFC_GENERATED_BY_MCP',
      performedBy: input.context.userId,
      details: {
        prompt: input.prompt,
        rfcTitle: rfcData.title
      }
    });
    
    // Responder
    res.json({
      success: true,
      rfc: rfcData,
      generatedAt: new Date().toISOString(),
      confidence: 0.92
    });
    
  } catch (error) {
    res.status(400).json({ 
      success: false, 
      error: error.message 
    });
  }
});

module.exports = router;
```

### Paso 2: Integrar en FastAPI Backend

**Ubicación:** `backend/app/services/mcp_client.py`

```python
import httpx
import json
from typing import Dict, Any

class MCPClient:
    def __init__(self, mcp_url: str = "http://localhost:3000"):
        self.mcp_url = mcp_url
        self.client = httpx.AsyncClient()
    
    async def generate_rfc_from_prompt(
        self, 
        prompt: str, 
        user_email: str,
        department: str,
        environment: str = "PROD"
    ) -> Dict[str, Any]:
        """
        Generar RFC usando MCP assistant
        """
        try:
            response = await self.client.post(
                f"{self.mcp_url}/api/rfc/assistant/generate",
                json={
                    "prompt": prompt,
                    "context": {
                        "userId": user_email,
                        "department": department,
                        "environment": environment
                    }
                },
                timeout=30.0
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"Error connecting to MCP: {str(e)}"
            }

# En router
from app.services.mcp_client import MCPClient

mcp_client = MCPClient()

@app.post("/api/rfc/create-with-assistant")
async def create_rfc_with_assistant(
    prompt: str,
    current_user: User = Depends(get_current_user)
):
    """
    1. Generar RFC usando MCP
    2. Validar estructura
    3. Crear en plataforma
    """
    
    # Paso 1: Generar con MCP
    mcp_result = await mcp_client.generate_rfc_from_prompt(
        prompt=prompt,
        user_email=current_user.email,
        department=current_user.department
    )
    
    if not mcp_result.get('success'):
        raise HTTPException(status_code=400, detail=mcp_result.get('error'))
    
    # Paso 2: Crear RFC en BD
    rfc_data = mcp_result.get('rfc')
    new_rfc = await create_rfc_in_database(
        title=rfc_data.get('title'),
        description=rfc_data.get('description'),
        created_by=current_user.id,
        mcp_metadata={
            'generated_by_mcp': True,
            'confidence': mcp_result.get('confidence'),
            'generation_prompt': prompt
        }
    )
    
    return {
        "success": True,
        "rfc_id": new_rfc.id,
        "message": "RFC creado con asistencia del MCP"
    }
```

### Paso 3: Configurar en docker-compose para deployment

```yaml
version: '3.8'

services:
  # Servicios existentes...
  mcp-server:
    build:
      context: ./mcp-server
    container_name: macropay_mcp_server
    restart: always
    environment:
      DATABASE_URL: postgresql://rfcadmin:${DB_PASSWORD}@postgres-core:5432/rfc_system_db
      OLLAMA_HOST: http://ollama:11434
      OLLAMA_MODEL: mistral
      SERVICE_TOKEN: ${MCP_SERVICE_TOKEN}  # Para auth con FastAPI
      SQL_SERVER_HOST: ${SQL_SERVER_HOST}  # Próxima integración
    ports:
      - "3000:3000"
    depends_on:
      - postgres-core
      - ollama
    networks:
      - macropay_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
```

---

## 🌐 CONFIGURACIÓN EN PRODUCCIÓN (S2)

### 1. Variables de entorno para S2
```bash
# En Servidor S2
MCP_SERVICE_TOKEN=<token-aleatorio-fuerte>
SQL_SERVER_HOST=sql-prod.macropay.internal
SQL_SERVER_USER=mcp-service
SQL_SERVER_PASSWORD=<contraseña-fuerte>
FASTAPI_BACKEND_URL=https://api-rfc.macropay.mx
FASTAPI_SERVICE_TOKEN=<mismo-token-coordinado>
OLLAMA_MODEL=mistral
```

### 2. Nginx Reverse Proxy
```nginx
upstream mcp_backend {
    server localhost:3000;
}

server {
    listen 443 ssl;
    server_name api-rfc-mcp.s2.internal;
    
    ssl_certificate /etc/letsencrypt/live/api-rfc-mcp.s2.internal/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api-rfc-mcp.s2.internal/privkey.pem;
    
    location /api/ {
        proxy_pass http://mcp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # Rate limiting
        limit_req zone=mcp burst=10 nodelay;
    }
    
    location /health {
        access_log off;
        proxy_pass http://mcp_backend;
    }
}

# Definir zona de rate limiting
limit_req_zone $binary_remote_addr zone=mcp:10m rate=5r/s;
```

### 3. Monitoreo y Logging
```bash
# En S2, configurar logs centralizados
docker-compose logs -f mcp-server | tee /var/log/macropay-mcp.log

# Nginx access logs
tail -f /var/log/nginx/access.log | grep "api-rfc-mcp"

# Alertas (Prometheus, DataDog, etc.)
# Métricas a monitorear:
# - api/rfc/assistant/generate - latencia y tasa de error
# - ollama inference time
# - postgresql connection pool
```

---

## 📊 FLUJO E2E COMPLETO

```
┌────────────────────────────────────────────────────────────────┐
│ 1. Usuario abre rfc.macropay.mx                                │
│    → Navega a "Crear RFC" → "Con Asistencia"                  │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────┐
│ 2. Frontend Next.js                                            │
│    → Muestra formulario de prompt                              │
│    → Usuario escribe: "RFC para cambiar BD a RDS"             │
│    → POST /api/rfc/create-with-assistant                       │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────┐
│ 3. Backend FastAPI                                             │
│    → Valida permiso de usuario                                 │
│    → Llama MCP: POST http://localhost:3000/api/rfc/...        │
│    → Espera respuesta (~3-5 seg)                              │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────┐
│ 4. MCP Server                                                  │
│    → Recibe prompt                                             │
│    → Llama Ollama (LLM local)                                 │
│    → Genera estructura RFC validada                            │
│    → Registra en rfc_audit_logs                               │
│    → Retorna JSON con RFC generado                            │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────┐
│ 5. Backend FastAPI (continúa)                                 │
│    → Recibe RFC de MCP                                        │
│    → Crea en BD SQL Server                                    │
│    → Registra que fue generado por MCP                        │
│    → Retorna RFC ID y link                                    │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────┐
│ 6. Frontend Next.js                                            │
│    → Muestra RFC generado                                      │
│    → Usuario puede editar, revisar, aprobar                   │
│    → Procede con workflow normal de RFC                        │
└────────────────────────────────────────────────────────────────┘
```

---

## ✅ CHECKLIST DE INTEGRACIÓN

- [ ] Endpoint `/api/rfc/assistant/generate` implementado en MCP
- [ ] FastAPI client para MCP creado
- [ ] Ruta `/api/rfc/create-with-assistant` en FastAPI
- [ ] Frontend Next.js tiene página "Crear con Asistencia"
- [ ] Variables de entorno configuradas
- [ ] Testing E2E completo (prompt → RFC creado en BD)
- [ ] Auditoría registrando operaciones MCP
- [ ] Rate limiting configurado
- [ ] Logs centralizados
- [ ] Monitoreo de latencia MCP
- [ ] Documentación para usuarios finales
- [ ] Training para equipo de infraestructura

---

## 🔄 PRÓXIMOS PASOS

1. **Semana 1-2:** Implementar endpoint `generate` en MCP
2. **Semana 2-3:** Integrar FastAPI client
3. **Semana 3-4:** Frontend React component
4. **Semana 4-5:** Testing E2E y refinamiento
5. **Semana 5-6:** Deployment a S2
6. **Semana 6-7:** Monitoreo y optimización

---

**Status:** Documentación de integración v1.0  
**Próximo:** Implementación en Sprint actual
