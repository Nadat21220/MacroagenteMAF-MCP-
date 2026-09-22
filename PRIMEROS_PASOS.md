# RFC MCP System - Primeros Pasos

## Que se cambio?

Has migracion COMPLETA de arquitectura:
- ❌ Antes: MCP Server TypeScript sin interfaz
- ✓ Ahora: MCP Server Python + Open WebUI + Alfresco + Docker Compose

## 1. Levantar Sistema (Opcion Recomendada)

```bash
cd ~/Documentos/Proyecto_Macropay
./start.sh
```

Selecciona **Opcion 1**: "Levantar Todo (Docker)"

**Tiempo esperado**: 20-60 segundos (primera vez puede ser lento)

### Que pasa automaticamente:
1. Docker Compose inicia 6 servicios
2. PostgreSQL se levanta primero
3. Ollama se conecta a PostgreSQL
4. MCP Server espera a ambos
5. Open WebUI se conecta a Ollama
6. Alfresco inicia (toma 2-3 minutos)

## 2. Acceder a la Interfaz Web

**URL**: http://localhost:3000

**En el navegador deberias ver**:
- Logo de Open WebUI
- Campo de texto para escribir prompts
- Historial de conversaciones (vacio en primer acceso)

**Primer login**:
1. Click en "Sign in"
2. Click en "Sign up" (crear cuenta)
3. Usuario: Tu email (ej: diego@test.com)
4. Contraseña: Lo que quieras
5. Click en "Create Account"

## 3. Tu Primer Prompt

Escribe en el chat:

```
Hola, soy Diego. Cual es mi nombre?
```

Ollama deberia responder algo como:
```
Tu nombre es Diego. Encantado de conocerte!
```

**Si esto funciona**: OK sistema base operacional!

## 4. Verificar que Todo Esta Correcto

```bash
./start.sh
→ Opcion 4
```

Deberias ver:

```
postgres_rfc_db           Up (healthy)
ollama_service            Up (healthy)
pgadmin_interface         Up (healthy)
mcp_postgresql_bridge     Up (healthy)
open_webui_interface      Up (healthy)
alfresco_content_repo     Up (health: starting)
```

- **healthy**: OK, servicio correcto
- **health: starting**: Normal, espera un poco
- **Up**: OK, servicio corriendo
- **Exit**: ERROR, revisar logs

## 5. Acceder a Otros Servicios

### pgAdmin (Gestionar PostgreSQL)
- URL: http://localhost:5050
- Email: admin@rfc.local
- Contraseña: pgadmin_2024

### Alfresco (Gestionar Documentos)
- URL: http://localhost:8080/alfresco
- Usuario: admin
- Contraseña: admin
- Nota: Toma 2-3 minutos en iniciar

### Verificar MCP Server
- URL: http://localhost:3001/health
- Deberia mostrar: {"status": "ok"}

## 6. Si Algo No Funciona

### Open WebUI no responde
```bash
docker logs open_webui_interface
```

### Ollama no conecta
```bash
docker logs ollama_service
```

### MCP Server error
```bash
docker logs mcp_postgresql_bridge
```

### Todo falla
```bash
# Reiniciar todo
./start.sh → Opcion 5
sleep 5
./start.sh → Opcion 1
```

## 7. Proximas Fases (Roadmap)

### Fase 2: MCP Tools en Open WebUI (Proxima semana)
- Crear wrapper HTTP para MCP
- Conectar Open WebUI con herramientas
- Permitir que Ollama use las 8 funciones

### Fase 3: Integracion Alfresco Real (2 semanas)
- Migrar de MOCK a herramientas Alfresco reales
- Implementar workflows RFC
- Versionado y auditoria

### Fase 4: Dashboard Personalizado (3 semanas)
- Interfaz custom en Open WebUI
- Visualizacion de RFC
- Reportes y metricas

## 8. Comandos Utiles

```bash
# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio especifico
docker-compose logs -f open_webui_interface

# Entrar a la terminal del MCP Server
docker exec -it mcp_postgresql_bridge bash

# Ver uso de recursos
docker stats

# Limpiar todo (NO hacer si tienes datos importantes)
docker-compose down -v

# Reiniciar un servicio
docker-compose restart open_webui_interface
```

## 9. Estructura de Datos

### PostgreSQL
- Base de datos: `rfc_management`
- Tablas: rfc_records, usuarios, auditoria, etc.
- Usuario: rfcadmin
- Puerto: 5432

### Alfresco
- Documentos RFC
- Versionado automatico
- Permisos por usuario
- Puerto: 8080

### MCP Server
- 8 herramientas activas
- Conecta PostgreSQL con Alfresco
- Puerto: 3001

## 10. Troubleshooting

### Error: "Port 8080 already in use"
Alfresco no puede iniciar porque el puerto esta ocupado. Opciones:
1. Cambiar puerto en docker-compose.yml (8080:8080 → 8081:8080)
2. Detener servicio que usa 8080

### Error: "Connection refused" en Ollama
Esperar 30 segundos y reintentar. Ollama tarda en iniciar.

### Alfresco muy lento
Normal. Primera vez toma 2-3 minutos. Despues es rapido.

### Open WebUI se cuelga
Reiniciar servicio:
```bash
docker-compose restart open_webui_interface
```

### PostgreSQL password error
Verificar archivo .env:
```bash
cat /home/nadat21220/Documentos/Proyecto_Macropay/mcp-rfc-server-python/.env
```

Debe coincidir con docker-compose.yml

## Resumen

| Paso | Comando | Resultado |
|---|---|---|
| 1 | ./start.sh → 1 | Levanta todo |
| 2 | Abre http://localhost:3000 | Open WebUI en navegador |
| 3 | Escribe prompt | Chat con Ollama |
| 4 | ./start.sh → 4 | Verifica servicios OK |
| 5 | Explora otros puertos | pgAdmin, Alfresco |

---

Listo? Comienza con:
```bash
cd ~/Documentos/Proyecto_Macropay
./start.sh
```

Selecciona **Opcion 1** y espera a que se estabilice todo.
