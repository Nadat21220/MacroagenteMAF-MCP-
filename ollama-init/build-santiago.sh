#!/bin/bash
# Reconstruye el modelo "santiago" en Ollama a partir de santiago.Modelfile.
# Reproducible: reemplaza el paso manual de "ollama create santiago -f Modelfile".
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker cp "$SCRIPT_DIR/santiago.Modelfile" ollama_service:/tmp/santiago.Modelfile
docker exec ollama_service ollama create santiago -f /tmp/santiago.Modelfile

echo "Modelo santiago reconstruido."
docker exec ollama_service ollama show santiago --modelfile | grep -E "temperature|num_ctx"
