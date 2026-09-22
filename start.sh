#!/bin/bash

# RFC MCP System - Docker Edition
# Todo levantado con Docker Compose

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=========================================="
echo "RFC MCP System - Docker"
echo "=========================================="
echo ""

echo "OPCION 1: Levantar Todo (Docker)"
echo "PostgreSQL + Ollama + MCP + Open WebUI"
echo ""

echo "OPCION 2: Chat CLI con Ollama"
echo "Terminal interactiva -> Ollama -> MCP -> Herramientas"
echo ""

echo "OPCION 3: Interfaz Web (Open WebUI)"
echo "http://localhost:3000"
echo ""

echo "OPCION 4: Ver Estado"
echo ""

echo "OPCION 5: Detener Todo"
echo ""

read -p "Selecciona (1/2/3/4/5): " choice

case $choice in
    1)
        echo ""
        echo "INFO Levantando servicios Docker..."
        cd "$PROJECT_ROOT"
        docker-compose up -d
        echo ""
        echo "INFO Esperando a que los servicios esten listos..."
        sleep 10
        echo ""
        echo "=========================================="
        echo "SERVICIOS LEVANTADOS"
        echo "=========================================="
        echo ""
        echo "PostgreSQL:     localhost:5432"
        echo "Ollama:         localhost:11434"
        echo "pgAdmin:        http://localhost:5050"
        echo "MCP Server:     localhost:3001"
        echo "Open WebUI:     http://localhost:3000"
        echo ""
        echo "Ver logs: docker-compose logs -f"
        echo "Chat CLI: ./start.sh -> 2"
        echo "Interfaz Web: ./start.sh -> 3"
        echo "Detener: ./start.sh -> 5"
        echo ""
        ;;
    2)
        echo ""
        echo "INFO Verificando servicios Docker..."

        if ! command -v docker &> /dev/null; then
            echo "ERROR Docker no esta instalado"
            exit 1
        fi

        # Levantar servicios si no estan corriendo
        if ! docker-compose ps | grep -q "ollama.*Up"; then
            echo "INFO Levantando servicios..."
            docker-compose up -d
            sleep 10
        fi

        echo "OK Servicios listos"
        echo ""
        echo "Iniciando Chat CLI..."
        echo ""

        cd "$PROJECT_ROOT/mcp-rfc-server-python"
        python ollama_client.py
        ;;
    3)
        echo ""
        echo "INFO Verificando servicios Docker..."

        if ! command -v docker &> /dev/null; then
            echo "ERROR Docker no esta instalado"
            exit 1
        fi

        # Levantar servicios si no estan corriendo
        if ! docker-compose ps | grep -q "open_webui.*Up"; then
            echo "INFO Levantando servicios..."
            docker-compose up -d
            sleep 15
        fi

        echo "OK Servicios listos"
        echo ""
        echo "=========================================="
        echo "OPEN WEBUI - Interfaz Web"
        echo "=========================================="
        echo ""
        echo "Abriendo navegador..."
        sleep 2

        # Intentar abrir navegador segun el SO
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:3000"
        elif command -v open &> /dev/null; then
            open "http://localhost:3000"
        else
            echo "Accede manualmente a: http://localhost:3000"
        fi
        echo ""
        echo "Ver logs: docker-compose logs -f open_webui"
        echo ""
        ;;
    4)
        echo ""
        echo "Estado de servicios:"
        echo ""
        docker-compose ps
        echo ""
        ;;
    5)
        echo ""
        echo "INFO Deteniendo servicios..."
        docker-compose down
        echo "OK Servicios detenidos"
        echo ""
        ;;
    *)
        echo "ERROR Opcion invalida"
        exit 1
        ;;
esac
