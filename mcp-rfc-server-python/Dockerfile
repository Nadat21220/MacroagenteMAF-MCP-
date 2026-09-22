FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements y instalar dependencias Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY . .

# Variables de entorno por defecto
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO

# Permisos de ejecución
RUN chmod +x main.py

# Health check: verifica que mcpo expone el OpenAPI de las herramientas MCP
HEALTHCHECK --interval=15s --timeout=10s --start-period=20s --retries=5 \
    CMD curl -f http://localhost:3001/openapi.json || exit 1

# mcpo envuelve el servidor MCP (stdio) y lo expone como API HTTP/OpenAPI
# que Open WebUI puede registrar como "Tool Server"
CMD ["mcpo", "--host", "0.0.0.0", "--port", "3001", "--", "python", "main.py"]
