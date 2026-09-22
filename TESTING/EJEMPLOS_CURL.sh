#!/bin/bash

# ============================================
# RFC MCP Server - cURL Examples
# ============================================

BASE_URL="http://localhost:3000"

echo "🔍 RFC MCP Server - API Examples"
echo "=================================="
echo ""
echo "Make sure the services are running first:"
echo "  docker-compose up -d"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Example function
run_example() {
    local num=$1
    local description=$2
    local method=$3
    local endpoint=$4
    local data=$5

    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Example $num: $description${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Command:"

    if [ "$method" == "GET" ]; then
        echo "curl -X GET $BASE_URL$endpoint"
        echo ""
        echo "Response:"
        curl -X GET "$BASE_URL$endpoint" | jq . 2>/dev/null || echo "(jq not installed, raw response:)" && curl -X GET "$BASE_URL$endpoint"
    else
        echo "curl -X $method $BASE_URL$endpoint \\"
        echo "  -H 'Content-Type: application/json' \\"
        echo "  -d '$data'"
        echo ""
        echo "Response:"
        curl -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" | jq . 2>/dev/null || curl -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi

    echo ""
    echo ""
}

# Health Check
run_example \
    "1" \
    "Health Check" \
    "GET" \
    "/health"

# Status Check
run_example \
    "2" \
    "System Status" \
    "GET" \
    "/status"

# Get Schema
run_example \
    "3" \
    "Database Schema" \
    "GET" \
    "/api/schema"

# Get all RFC records
run_example \
    "4" \
    "Get All RFC Records" \
    "GET" \
    "/api/rfc/records"

# Get personal directory
run_example \
    "5" \
    "Get Personal Directory" \
    "GET" \
    "/api/personal/directory"

# LLM SQL Generation - Example 1
run_example \
    "6" \
    "LLM: Generate SQL for employees count" \
    "POST" \
    "/api/llm/sql-generator" \
    '{"question": "¿Cuántos empleados hay en total?", "model": "mistral"}'

# LLM SQL Generation - Example 2
run_example \
    "7" \
    "LLM: Generate SQL for department employees" \
    "POST" \
    "/api/llm/sql-generator" \
    '{"question": "¿Cuáles son los empleados del departamento de Desarrollo?", "model": "mistral"}'

# LLM SQL Generation - Example 3
run_example \
    "8" \
    "LLM: Generate SQL for RFC information" \
    "POST" \
    "/api/llm/sql-generator" \
    '{"question": "¿Cuántos RFCs hay en ambiente PROD?", "model": "mistral"}'

# LLM SQL Generation - Example 4
run_example \
    "9" \
    "LLM: Generate SQL for project details" \
    "POST" \
    "/api/llm/sql-generator" \
    '{"question": "¿Quién es el líder técnico del proyecto td189-bf25?", "model": "mistral"}'

# Direct Query Execution
run_example \
    "10" \
    "Direct Query: Get RFC records" \
    "POST" \
    "/api/query" \
    '{"sql": "SELECT * FROM rfc_records LIMIT 5"}'

# Direct Query: Complex Join
run_example \
    "11" \
    "Direct Query: RFC with Responsible People" \
    "POST" \
    "/api/query" \
    '{"sql": "SELECT r.project_name, resp.rol_asignado, dp.nombre, dp.apellido FROM rfc_records r LEFT JOIN rfc_responsables resp ON r.project_id = resp.project_id LEFT JOIN directorio_personal dp ON resp.empleado_id = dp.empleado_id LIMIT 10"}'

# LLM Text Generation
run_example \
    "12" \
    "LLM: Generate Text" \
    "POST" \
    "/api/llm/generate-text" \
    '{"prompt": "Describe RFC management process in Spanish", "model": "mistral"}'

echo ""
echo "✅ Examples completed!"
echo ""
echo "📚 Learn more:"
echo "  • View logs: docker-compose logs -f mcp_server"
echo "  • Access pgAdmin: http://localhost:5050"
echo "  • Read documentation: cat README.md"
