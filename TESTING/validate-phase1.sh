#!/bin/bash

# =====================================================
# Validación Fase 1: Base de Datos
# Script para verificar que todos los cambios están listos
# =====================================================

echo "📋 Validando Fase 1: Base de Datos..."
echo ""

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# =====================================================
# Test 1: Verificar archivos SQL nuevos
# =====================================================
echo "Test 1: Archivo SQL de migración"
if [ -f "./init-scripts/02-create-document-sync-tables.sql" ]; then
    echo -e "${GREEN}✓${NC} Archivo existe: init-scripts/02-create-document-sync-tables.sql"
    LINES=$(wc -l < "./init-scripts/02-create-document-sync-tables.sql")
    echo "  Líneas: $LINES"
else
    echo -e "${RED}✗${NC} FALTA: init-scripts/02-create-document-sync-tables.sql"
    ((ERRORS++))
fi
echo ""

# =====================================================
# Test 2: Verificar docker-compose.yml modificado
# =====================================================
echo "Test 2: Modificaciones en docker-compose.yml"
if grep -q "RFC:/app/RFC:ro" ./docker-compose.yml; then
    echo -e "${GREEN}✓${NC} Volumen RFC montado (read-only)"
else
    echo -e "${RED}✗${NC} FALTA: Volumen RFC en docker-compose.yml"
    ((ERRORS++))
fi

if grep -q "converted_docs:/app/converted_docs" ./docker-compose.yml; then
    echo -e "${GREEN}✓${NC} Volumen converted_docs montado"
else
    echo -e "${RED}✗${NC} FALTA: Volumen converted_docs en docker-compose.yml"
    ((ERRORS++))
fi

# Validar sintaxis
if docker-compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Sintaxis docker-compose válida"
else
    echo -e "${RED}✗${NC} ERROR en sintaxis docker-compose.yml"
    ((ERRORS++))
fi
echo ""

# =====================================================
# Test 3: Verificar directorios
# =====================================================
echo "Test 3: Estructura de directorios"
if [ -d "./RFC" ]; then
    RFC_COUNT=$(ls ./RFC/*.xlsx 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Directorio RFC existe"
    echo "  Archivos Excel: $RFC_COUNT"
else
    echo -e "${YELLOW}⚠${NC} Directorio RFC no encontrado"
fi

if [ -d "./converted_docs" ]; then
    echo -e "${GREEN}✓${NC} Directorio converted_docs creado"
else
    echo -e "${RED}✗${NC} FALTA: Directorio converted_docs"
    ((ERRORS++))
fi

if [ -d "./init-scripts" ]; then
    echo -e "${GREEN}✓${NC} Directorio init-scripts existe"
else
    echo -e "${RED}✗${NC} FALTA: Directorio init-scripts"
    ((ERRORS++))
fi
echo ""

# =====================================================
# Test 4: Verificar plantilla de variables
# =====================================================
echo "Test 4: Archivos de configuración"
if [ -f "./.env.sharepoint.template" ]; then
    echo -e "${GREEN}✓${NC} Template .env.sharepoint creado"
else
    echo -e "${YELLOW}⚠${NC} Template .env.sharepoint no encontrado"
fi

if [ -f "./.env" ]; then
    echo -e "${GREEN}✓${NC} Archivo .env existe"
else
    echo -e "${RED}✗${NC} FALTA: Archivo .env"
    ((ERRORS++))
fi
echo ""

# =====================================================
# Test 5: Verificar contenido SQL
# =====================================================
echo "Test 5: Contenido del archivo SQL"
if grep -q "rfc_markdown_index" ./init-scripts/02-create-document-sync-tables.sql; then
    echo -e "${GREEN}✓${NC} Tabla rfc_markdown_index definida"
else
    echo -e "${RED}✗${NC} FALTA: Definición de tabla rfc_markdown_index"
    ((ERRORS++))
fi

if grep -q "sharepoint_sync_log" ./init-scripts/02-create-document-sync-tables.sql; then
    echo -e "${GREEN}✓${NC} Tabla sharepoint_sync_log definida"
else
    echo -e "${RED}✗${NC} FALTA: Definición de tabla sharepoint_sync_log"
    ((ERRORS++))
fi

if grep -q "FOREIGN KEY" ./init-scripts/02-create-document-sync-tables.sql; then
    FK_COUNT=$(grep -c "FOREIGN KEY" ./init-scripts/02-create-document-sync-tables.sql)
    echo -e "${GREEN}✓${NC} Constraints de integridad referencial: $FK_COUNT"
else
    echo -e "${YELLOW}⚠${NC} Sin constraints FOREIGN KEY"
fi

if grep -q "CREATE INDEX" ./init-scripts/02-create-document-sync-tables.sql; then
    INDEX_COUNT=$(grep -c "CREATE INDEX" ./init-scripts/02-create-document-sync-tables.sql)
    echo -e "${GREEN}✓${NC} Índices de búsqueda: $INDEX_COUNT"
else
    echo -e "${RED}✗${NC} FALTA: Índices de búsqueda"
    ((ERRORS++))
fi
echo ""

# =====================================================
# Resumen
# =====================================================
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ FASE 1: LISTA PARA APLICAR${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "1. Ejecutar: docker-compose down"
    echo "2. Ejecutar: docker-compose up -d"
    echo "3. Esperar a que PostgreSQL esté healthy"
    echo "4. Verificar: docker exec postgres_rfc_db psql -U rfcadmin -d rfc_management -c '\\dt'"
    echo ""
    echo "Las nuevas tablas deberían aparecer:"
    echo "  - rfc_markdown_index"
    echo "  - sharepoint_sync_log"
    echo ""
    exit 0
else
    echo -e "${RED}✗ ERRORES ENCONTRADOS: $ERRORS${NC}"
    echo ""
    echo "Por favor, revisa los errores arriba y corrígelos"
    echo ""
    exit 1
fi
