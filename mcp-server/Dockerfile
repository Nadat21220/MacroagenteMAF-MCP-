FROM node:18-alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache curl

# Copiar package.json
COPY package*.json ./
RUN npm install --production

# Copiar código
COPY src/ ./src/

# Crear directorio de logs
RUN mkdir -p /app/logs && chmod 755 /app/logs

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD curl -f http://localhost:${MCP_PORT:-3000}/health || exit 1

# Ejecutar servidor
CMD ["node", "src/server.js"]
