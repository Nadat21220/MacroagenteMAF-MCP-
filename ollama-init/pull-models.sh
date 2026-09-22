#!/bin/bash

# ============================================
# Ollama Models Initialization
# ============================================

set -e

# Set Ollama models directory to external drive
export OLLAMA_MODELS="/run/media/nadat21220/Conexiones/Model"

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
MODELS=("mistral" "neural-hermes" "orca-mini")

echo "🚀 Starting Ollama models initialization..."
echo "Ollama URL: $OLLAMA_HOST"

# Esperar a que Ollama esté disponible
wait_for_ollama() {
    local max_attempts=30
    local attempt=0

    echo "⏳ Waiting for Ollama to be ready..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$OLLAMA_HOST/api/tags" > /dev/null 2>&1; then
            echo "✓ Ollama is ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
    done

    echo "✗ Ollama failed to start after $max_attempts attempts"
    return 1
}

# Descargar modelos
pull_models() {
    echo ""
    echo "📥 Pulling models..."

    for model in "${MODELS[@]}"; do
        echo ""
        echo "Downloading: $model"

        if curl -X POST "$OLLAMA_HOST/api/pull" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$model\"}" \
            --progress-bar; then
            echo "✓ $model downloaded successfully"
        else
            echo "⚠ Failed to download $model (this is not critical)"
        fi
    done
}

# Listar modelos disponibles
list_models() {
    echo ""
    echo "📋 Available models:"
    curl -s "$OLLAMA_HOST/api/tags" | grep -o '"name":"[^"]*' | cut -d'"' -f4 || echo "  (No models found)"
}

# Main
if wait_for_ollama; then
    pull_models
    list_models
    echo ""
    echo "✅ Ollama initialization completed!"
else
    echo "❌ Ollama initialization failed"
    exit 1
fi
