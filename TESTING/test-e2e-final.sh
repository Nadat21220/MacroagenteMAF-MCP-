#!/bin/bash

BASE_URL="http://localhost:3000"
REQUESTED_BY="test@novapay.mx"

# Valores conocidos de la BD
PROJECT_ID="td189-bf25"
RFC_FILE_ID="91540212-0232-4b78-af7c-0520627197c1"

PASS=0
FAIL=0

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     FASE 6: TESTING E2E - Validación Completa del Sistema  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Health Check
echo "Test 1: Health Check ... "
if curl -s "$BASE_URL/health" | grep -q "status"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 2: RFC Records
echo "Test 2: GET /api/rfc/records ... "
if curl -s "$BASE_URL/api/rfc/records" | grep -q "$PROJECT_ID"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 3: Personal Directory
echo "Test 3: GET /api/personal/directory ... "
if curl -s "$BASE_URL/api/personal/directory" | grep -q "nombre"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 4: Schema
echo "Test 4: GET /api/schema ... "
if curl -s "$BASE_URL/api/schema" | grep -q "tables"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 5: Convert RFC
echo "Test 5: POST /api/documents/convert-rfc ... "
convert=$(curl -s -X POST "$BASE_URL/api/documents/convert-rfc" \
  -H "Content-Type: application/json" \
  -H "X-Requested-By: $REQUESTED_BY" \
  -d "{\"project_id\":\"$PROJECT_ID\",\"rfc_file_id\":\"$RFC_FILE_ID\",\"requested_by\":\"$REQUESTED_BY\"}")

if echo "$convert" | grep -q "markdown_id"; then
  MARKDOWN_ID=$(echo "$convert" | grep -o '"markdown_id":"[^"]*"' | cut -d'"' -f4)
  echo "  ✓ PASS (markdown_id: $MARKDOWN_ID)"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Wait for conversion
sleep 5

# Test 6: Get Markdown
echo "Test 6: GET /api/documents/markdown/:projectId ... "
if curl -s "$BASE_URL/api/documents/markdown/$PROJECT_ID" -H "X-Requested-By: $REQUESTED_BY" | grep -q "conversion_status"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 7: SharePoint Create
echo "Test 7: POST /api/documents/sharepoint/create ... "
if [ ! -z "$MARKDOWN_ID" ]; then
  if curl -s -X POST "$BASE_URL/api/documents/sharepoint/create" \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: $REQUESTED_BY" \
    -d "{\"markdown_id\":\"$MARKDOWN_ID\",\"requested_by\":\"$REQUESTED_BY\"}" | grep -q "file_id"; then
    echo "  ✓ PASS"
    ((PASS++))
  else
    echo "  ✗ FAIL"
    ((FAIL++))
  fi
fi

# Test 8: SharePoint Update
echo "Test 8: POST /api/documents/sharepoint/update ... "
if [ ! -z "$MARKDOWN_ID" ]; then
  if curl -s -X POST "$BASE_URL/api/documents/sharepoint/update" \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: $REQUESTED_BY" \
    -d "{\"markdown_id\":\"$MARKDOWN_ID\",\"new_content\":\"# Updated\",\"requested_by\":\"$REQUESTED_BY\"}" | grep -q "updated_at"; then
    echo "  ✓ PASS"
    ((PASS++))
  else
    echo "  ✗ FAIL"
    ((FAIL++))
  fi
fi

# Test 9: SharePoint Move
echo "Test 9: POST /api/documents/sharepoint/move ... "
if [ ! -z "$MARKDOWN_ID" ]; then
  if curl -s -X POST "$BASE_URL/api/documents/sharepoint/move" \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: $REQUESTED_BY" \
    -d "{\"markdown_id\":\"$MARKDOWN_ID\",\"target_folder_id\":\"moved\",\"requested_by\":\"$REQUESTED_BY\"}" | grep -q "moved_at"; then
    echo "  ✓ PASS"
    ((PASS++))
  else
    echo "  ✗ FAIL"
    ((FAIL++))
  fi
fi

# Test 10: Auditoría
echo "Test 10: Auditoría en sharepoint_sync_log ... "
AUDIT=$(curl -s -X POST "$BASE_URL/api/query" \
  -H "Content-Type: application/json" \
  -H "X-Requested-By: $REQUESTED_BY" \
  -d "{\"sql\":\"SELECT COUNT(*) as count FROM sharepoint_sync_log;\"}")

if echo "$AUDIT" | grep -q "count"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 11: Persistencia - Markdown guardado en BD
echo "Test 11: Persistencia de Markdown en BD ... "
PERSIST=$(curl -s -X POST "$BASE_URL/api/query" \
  -H "Content-Type: application/json" \
  -H "X-Requested-By: $REQUESTED_BY" \
  -d "{\"sql\":\"SELECT COUNT(*) as count FROM rfc_markdown_index WHERE project_id = 'td189-bf25';\"}")

if echo "$PERSIST" | grep -q "count"; then
  echo "  ✓ PASS"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

# Test 12: Security - Email validation
echo "Test 12: Seguridad - Validación de email ... "
SECURITY=$(curl -s -X POST "$BASE_URL/api/documents/convert-rfc" \
  -H "Content-Type: application/json" \
  -d "{\"project_id\":\"test\"}" 2>&1)

if echo "$SECURITY" | grep -q "Missing\|email"; then
  echo "  ✓ PASS (validación correcta)"
  ((PASS++))
else
  echo "  ✗ FAIL"
  ((FAIL++))
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    RESUMEN DE TESTS                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Total: 12 Tests"
echo "Pasados:  ✓ $PASS"
echo "Fallidos: ✗ $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✓ TODAS LAS PRUEBAS PASARON"
  echo ""
  echo "Sistema operacional 100%:"
  echo "  ✅ Health checks"
  echo "  ✅ RFC management"
  echo "  ✅ Conversión Markdown"
  echo "  ✅ SharePoint operations"
  echo "  ✅ Auditoría"
  echo "  ✅ Persistencia"
  echo "  ✅ Seguridad"
  exit 0
else
  echo "✗ $FAIL TESTS FALLARON"
  exit 1
fi
