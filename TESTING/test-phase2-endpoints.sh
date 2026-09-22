#!/bin/bash

# =====================================================
# Test Script - Fase 2: Nuevos Endpoints
# =====================================================

echo "📋 Testing Fase 2 - Nuevos Endpoints..."
echo ""

BASE_URL="http://localhost:3000"
REQUESTED_BY="test@macropay.mx"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_COUNT=0
PASS_COUNT=0

# Función para ejecutar test
run_test() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"

    ((TEST_COUNT++))
    echo -n "Test $TEST_COUNT: $name ... "

    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" -X GET \
            -H "X-Requested-By: $REQUESTED_BY" \
            "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-Requested-By: $REQUESTED_BY" \
            -d "$data" \
            "$BASE_URL$endpoint")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [[ "$http_code" =~ ^(200|201|202|400|404)$ ]]; then
        echo -e "${GREEN}✓${NC} (HTTP $http_code)"
        ((PASS_COUNT++))
        echo "  Response: $(echo "$body" | cut -c1-80)..."
    else
        echo -e "${RED}✗${NC} (HTTP $http_code)"
        echo "  Response: $body"
    fi

    echo ""
}

# Test 1: Verificar que RFC existe
echo "=== Obtener información de RFCs para testing ==="
rfc_records=$(curl -s "$BASE_URL/api/rfc/records")
rfc_count=$(echo "$rfc_records" | grep -o "project_id" | wc -l)
echo "RFCs en BD: $rfc_count"
echo ""

# Obtener primer RFC para testing
first_project_id=$(echo "$rfc_records" | grep -o '"project_id":"[^"]*"' | head -1 | cut -d'"' -f4)
first_doc_id=$(curl -s "$BASE_URL/api/rfc/records" | grep -o '"index_id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$first_project_id" ]; then
    echo -e "${RED}ERROR: No se encontraron RFCs para testing${NC}"
    exit 1
fi

echo "Usando para tests:"
echo "  project_id: $first_project_id"
echo "  rfc_file_id: $first_doc_id"
echo ""

# =====================================================
# Tests de Endpoints
# =====================================================

echo "=== Endpoint Tests ==="
echo ""

# Test: POST /api/documents/convert-rfc
run_test "POST /api/documents/convert-rfc (iniciar conversión)" "POST" \
    "/api/documents/convert-rfc" \
    "{\"project_id\":\"$first_project_id\",\"rfc_file_id\":\"$first_doc_id\",\"requested_by\":\"$REQUESTED_BY\"}"

# Extraer markdown_id de respuesta anterior para tests posteriores
markdown_id=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: $REQUESTED_BY" \
    -d "{\"project_id\":\"$first_project_id\",\"rfc_file_id\":\"$first_doc_id\",\"requested_by\":\"$REQUESTED_BY\"}" \
    "$BASE_URL/api/documents/convert-rfc" | grep -o '"markdown_id":"[^"]*"' | cut -d'"' -f4)

if [ ! -z "$markdown_id" ]; then
    echo "Markdown ID obtenido: $markdown_id"
    echo ""

    # Test: GET /api/documents/markdown/:projectId
    run_test "GET /api/documents/markdown/:projectId (obtener markdown)" "GET" \
        "/api/documents/markdown/$first_project_id" ""

    # Test: POST /api/documents/sync-to-sharepoint
    run_test "POST /api/documents/sync-to-sharepoint (sincronizar)" "POST" \
        "/api/documents/sync-to-sharepoint" \
        "{\"markdown_id\":\"$markdown_id\",\"target_folder_id\":\"default\",\"requested_by\":\"$REQUESTED_BY\"}"

    # Test: POST /api/documents/sharepoint/create
    run_test "POST /api/documents/sharepoint/create (crear doc)" "POST" \
        "/api/documents/sharepoint/create" \
        "{\"markdown_id\":\"$markdown_id\",\"target_folder_id\":\"default\",\"requested_by\":\"$REQUESTED_BY\"}"

    # Test: POST /api/documents/sharepoint/update
    run_test "POST /api/documents/sharepoint/update (actualizar doc)" "POST" \
        "/api/documents/sharepoint/update" \
        "{\"markdown_id\":\"$markdown_id\",\"new_content\":\"# Updated Content\",\"requested_by\":\"$REQUESTED_BY\"}"

    # Test: POST /api/documents/sharepoint/move
    run_test "POST /api/documents/sharepoint/move (mover doc)" "POST" \
        "/api/documents/sharepoint/move" \
        "{\"markdown_id\":\"$markdown_id\",\"source_folder_id\":\"default\",\"target_folder_id\":\"moved\",\"requested_by\":\"$REQUESTED_BY\"}"
else
    echo -e "${YELLOW}⚠ No se pudo obtener markdown_id, omitiendo tests posteriores${NC}"
fi

echo ""
echo "=== Resumen ==="
echo "Tests ejecutados: $TEST_COUNT"
echo -e "Tests pasados: ${GREEN}$PASS_COUNT${NC}"
echo "Tests fallidos: $((TEST_COUNT - PASS_COUNT))"
echo ""

if [ $PASS_COUNT -eq $TEST_COUNT ]; then
    echo -e "${GREEN}✓ Todos los tests PASARON${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Algunos tests FALLARON${NC}"
    exit 1
fi
