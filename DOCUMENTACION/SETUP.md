# 🔧 SETUP: Instalación y Configuración

**Guía completa para levantar el MCP Server localmente o en S2**

---

## 📋 Requisitos Previos

### Hardware
- **RAM:** 8GB mínimo (16GB recomendado)
- **CPU:** 4 cores mínimo (8+ para óptimo)
- **Espacio disco:** 20GB (PostgreSQL + Ollama models)

### Software
```bash
# Verificar versiones
docker --version        # >= 20.10
docker-compose --version  # >= 1.29
git --version           # Para clonar repo (opcional)
```

### Instalar si no tienes
- **Ubuntu/Debian:** `sudo apt install docker.io docker-compose`
- **MacOS:** Instalar Docker Desktop
- **Windows:** Instalar Docker Desktop

---

## 🚀 Instalación Local (Desarrollo)

### Paso 1: Preparar directorio
```bash
cd /home/nadat21220/Documentos/Proyecto_Macropay

# Verificar estructura
ls -la
# Debe haber: docker-compose.yml, mcp-server/, MacroagenteMAF-MCP-/, init-scripts/
```

### Paso 2: Configurar variables de entorno
```bash
# Copiar plantilla
cp .env.example .env

# Editar si necesitas cambios (opcional - por defecto está bien)
nano .env

# Contenido esperado:
# POSTGRES_PASSWORD=your_secure_password
# MCP_SERVER_PORT=3000
# OLLAMA_MODEL=mistral
```

### Paso 3: Levantar servicios
```bash
# Construir imagen MCP Server
docker-compose build

# Iniciar todos (en background)
docker-compose up -d

# Verificar que estén levantados
docker-compose ps
# Debe mostrar 4 servicios: postgres-core, mcp-server, ollama, pgAdmin (todos "Up")
```

### Paso 4: Descargar modelo LLM (Primera vez)
```bash
# Descargar Mistral (~4 GB)
docker-compose exec ollama ollama pull mistral

# Para otros modelos (opcional):
# docker-compose exec ollama ollama pull orca-mini
# docker-compose exec ollama ollama pull neural-hermes

# Verificar modelo descargado
docker-compose exec ollama ollama list
```

### Paso 5: Validar instalación
```bash
# Health check
curl http://localhost:3000/health
# Respuesta esperada: {"status":"ok"}

# Verificar BD
curl http://localhost:3000/api/rfc/records
# Respuesta: Array JSON con RFCs

# Acceder a pgAdmin
# Abrir browser: http://localhost:5050
# Usuario: admin@rfc.local
# Contraseña: password123
```

**✅ ¡Listo! Sistema completamente operativo.**

---

## 🛑 Detener y Reiniciar

### Parar servicios (sin eliminar datos)
```bash
docker-compose stop

# Ver logs antes de parar
docker-compose logs -f mcp-server
```

### Reiniciar
```bash
docker-compose up -d
# Los datos persisten automáticamente
```

### Eliminar todo (incluyendo datos)
```bash
# ⚠️ CUIDADO: Esto elimina BD
docker-compose down -v

# Solo contenedores (sin eliminar volúmenes):
docker-compose down
```

---

## 📊 Monitorear Sistema

### Ver logs en tiempo real
```bash
# Todos los servicios
docker-compose logs -f

# Solo MCP Server
docker-compose logs -f mcp-server

# Solo PostgreSQL
docker-compose logs -f postgres-core

# Últimas 50 líneas de Ollama
docker-compose logs --tail=50 ollama
```

### Ver estado de recursos
```bash
# CPU, memoria, disco de contenedores
docker stats

# Espacio usado por Docker
docker system df
```

### Ejecutar comandos en contenedores
```bash
# Conectar a psql de PostgreSQL
docker-compose exec postgres-core psql -U rfcadmin -d rfc_system_db

# Entrar al shell de MCP Server
docker-compose exec mcp-server /bin/bash

# Ver archivos del Ollama
docker-compose exec ollama ls -la /root/.ollama/models
```

---

## 🧪 Testing de Endpoints

### Script de pruebas rápidas
```bash
# Ir a directorio de testing
cd TESTING

# Ejecutar ejemplos (requiere curl)
bash EJEMPLOS_CURL.sh

# O pruebas individuales:
curl -X POST http://localhost:3000/api/documents/convert-rfc \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","projectId":"test-123"}'
```

### Testing con Postman (opcional)
- Importar colecciones de `/Informacion extra/macropay-rfc-export/collections/`
- Configurar variable `BASE_URL = http://localhost:3000`
- Ejecutar requests

---

## ☁️ Deployment en S2 (Servidor)

### Pre-requisitos S2
- Ubuntu 20.04+ con Docker instalado
- SSH access
- IP pública o VPN para acceder a servicios

### Paso 1: Preparar código
```bash
# En tu máquina local, asegurar que:
# 1. No haya node_modules/ (están en .gitignore)
# 2. .env NO esté en Git (está en .gitignore)
# 3. Backups sensibles estén en .gitignore

# Verificar
git status
# No debe mostrar node_modules/ ni .env
```

### Paso 2: Subir a S2
```bash
# Opción 1: Git (si tienes repo)
git push origin main

# Opción 2: SCP/rsync
rsync -avz --exclude=node_modules --exclude=.env \
  . usuario@s2:/opt/macropay-rfc-mcp/

# Opción 3: Tar
tar --exclude=node_modules --exclude=.env -czf macropay-rfc.tar.gz .
scp macropay-rfc.tar.gz usuario@s2:/opt/
ssh usuario@s2 'cd /opt && tar -xzf macropay-rfc.tar.gz -C /opt/macropay-rfc-mcp/'
```

### Paso 3: Configurar S2
```bash
# En S2:
cd /opt/macropay-rfc-mcp

# Crear .env con variables de producción
cp .env.example .env
# Editar .env con credenciales de PROD:
# - Contraseña PostgreSQL fuerte
# - Puertos accesibles
# - Variables de integración con SQL Server

nano .env
```

### Paso 4: Instalar dependencias
```bash
# Regenerar node_modules
cd mcp-server && npm install
cd ../MacroagenteMAF-MCP- && npm install
cd ..
```

### Paso 5: Levantar en S2
```bash
# Construir
docker-compose build

# Iniciar
docker-compose up -d

# Verificar
docker-compose ps
curl http://localhost:3000/health
```

### Paso 6: Configurar reverse proxy (nginx/Apache)
```nginx
# /etc/nginx/sites-enabled/macropay-rfc-mcp
server {
    listen 80;
    server_name api-rfc-mcp.s2.example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Luego:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🔒 Seguridad en Producción

### Checklist de seguridad

- [ ] `.env` contiene contraseñas fuertes
- [ ] `.env` NO está en Git (verificar `.gitignore`)
- [ ] PostgreSQL solo accesible desde dentro de Docker (no expongas puerto 5432)
- [ ] MCP Server expuesto solo bajo HTTPS (reverse proxy con certificado)
- [ ] Credenciales de SQL Server seguras
- [ ] Logs monitoreados para accesos no autorizados
- [ ] Backups automáticos programados

### Variables de entorno críticas
```bash
# Debe estar en .env (nunca hardcodeado):
POSTGRES_PASSWORD=<contraseña-fuerte>
JWT_SECRET=<secreto-aleatorio-largo>
API_KEY_SHAREPOINT=<credencial-azure>
DATABASE_URL=postgresql://rfcadmin:XXXXX@postgres-core:5432/rfc_system_db
```

---

## 🐛 Troubleshooting

### Puerto 3000 ya en uso
```bash
# Encontrar qué usa el puerto
lsof -i :3000

# O cambiar puerto en docker-compose.yml:
# ports: ["3001:3000"]
```

### PostgreSQL no inicia
```bash
# Ver logs
docker-compose logs postgres-core

# Revisar volumen
docker volume ls | grep rfc

# Si está corrupto, eliminar:
docker-compose down -v
docker-compose up -d
```

### Ollama tarda en descargar modelos
```bash
# Es normal, ver progreso
docker-compose logs -f ollama

# Cambiar modelo más ligero:
docker-compose exec ollama ollama pull orca-mini
```

### MCP Server en error
```bash
# Ver detalles
docker-compose logs mcp-server

# Reiniciar
docker-compose restart mcp-server

# Verificar node_modules no falta
docker-compose exec mcp-server npm install
```

---

## 📈 Optimización

### Performance
- Asignar más RAM a Ollama en `docker-compose.yml` si es posible
- Usar GPU si disponible (requiere nvidia-docker)
- Configurar índices adicionales en PostgreSQL según queries

### Escalabilidad
- Usar load balancer si hay múltiples MCP Servers
- Replicar PostgreSQL con read replicas
- Cache con Redis (próximo paso)

---

## 📝 Verificación Final

Después de instalación, verificar:

```bash
# 1. Todos servicios up
docker-compose ps | grep Up

# 2. MCP responde
curl http://localhost:3000/health

# 3. BD tiene datos
psql -h localhost -U rfcadmin -d rfc_system_db -c "SELECT COUNT(*) FROM rfc_records;"

# 4. Ollama tiene modelo
curl http://localhost:11434/api/tags

# 5. pgAdmin accesible
curl http://localhost:5050
```

---

**Status:** ✅ Sistema completamente instalado y verificado
