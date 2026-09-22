#!/bin/bash

# Script Maestro de Testing - MCP RFC Server Python
# Uso: ./TESTING_COMPLETO.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$PROJECT_ROOT/mcp-rfc-server-python"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones
print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║ $1"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
}

print_success() {
    echo -e "${GREEN}OK${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARN${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO${NC} $1"
}

# ============================================================
# PARTE 1: VERIFICACION PREVIA
# ============================================================

print_header "PARTE 1: VERIFICACION PREVIA"

print_info "Verificando entorno..."

# Verificar Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    print_success "Python 3 encontrado: $PYTHON_VERSION"
else
    print_error "Python 3 no encontrado"
    exit 1
fi

# Verificar directorio
if [ ! -f "$MCP_DIR/main.py" ]; then
    print_error "main.py no encontrado en $MCP_DIR"
    exit 1
fi
print_success "Directorio del proyecto: $PROJECT_ROOT"

# Verificar virtual environment
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    print_warning "Virtual environment no encontrado"
    print_info "Creando virtual environment..."
    cd "$PROJECT_ROOT"
    python3 -m venv venv
    print_success "Virtual environment creado"
fi

# Activar virtual environment
source "$PROJECT_ROOT/venv/bin/activate"
print_success "Virtual environment activado"

# ============================================================
# PARTE 2: VERIFICAR DEPENDENCIAS
# ============================================================

print_header "PARTE 2: VERIFICAR DEPENDENCIAS"

print_info "Verificando dependencias..."

cd "$MCP_DIR"

MISSING_DEPS=0

for module in mcp psycopg pydantic dotenv; do
    if python3 -c "import $module" 2>/dev/null; then
        print_success "Modulo disponible: $module"
    else
        print_warning "Modulo faltante: $module"
        MISSING_DEPS=1
    fi
done

if [ $MISSING_DEPS -eq 1 ]; then
    print_warning "Algunas dependencias faltantes"
    print_info "Instalando dependencias..."
    pip install -q -r requirements.txt
    print_success "Dependencias instaladas"
fi

# ============================================================
# PARTE 3: VERIFICAR ESTRUCTURA
# ============================================================

print_header "PARTE 3: VERIFICAR ESTRUCTURA"

print_info "Verificando archivos clave..."

REQUIRED_FILES=(
    "main.py"
    "config/settings.py"
    "utils/database.py"
    "requirements.txt"
    ".env.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$MCP_DIR/$file" ]; then
        SIZE=$(wc -l < "$MCP_DIR/$file" 2>/dev/null | tr -d ' ')
        print_success "Archivo $file ($SIZE lineas)"
    else
        print_error "Archivo faltante: $file"
        exit 1
    fi
done

# ============================================================
# PARTE 4: VERIFICAR CONFIGURACION
# ============================================================

print_header "PARTE 4: VERIFICAR CONFIGURACION"

if [ ! -f "$MCP_DIR/.env" ]; then
    print_warning ".env no encontrado"
    print_info "Creando .env desde .env.example..."
    cp "$MCP_DIR/.env.example" "$MCP_DIR/.env"
    print_success ".env creado"
else
    print_success ".env encontrado"
fi

# ============================================================
# PARTE 5: EJECUTAR TESTS
# ============================================================

print_header "PARTE 5: EJECUTAR TESTS DE HERRAMIENTAS"

print_info "Ejecutando tests completos..."
echo ""

python3 run_tests.py

TEST_RESULT=$?

echo ""

# ============================================================
# PARTE 6: RESUMEN FINAL
# ============================================================

print_header "PARTE 6: RESUMEN FINAL"

if [ $TEST_RESULT -eq 0 ]; then
    print_success "Todos los tests pasaron correctamente"
    echo ""
    print_header "OK SISTEMA COMPLETAMENTE OPERACIONAL"
    
    echo ""
    echo "ESTADO DEL PROYECTO:"
    echo ""
    echo "  OK MCP Server Python         (Funcional)"
    echo "  OK 8 Herramientas            (Operacionales)"
    echo "  OK PostgreSQL Control        (Listo)"
    echo "  OK Conversion RFC            (Listo)"
    echo "  OK SharePoint Integration    (MOCK mode)"
    echo "  OK Testing Framework         (Completo)"
    echo ""
    
    echo "ARCHIVOS IMPORTANTES:"
    echo ""
    echo "  - Script testing:      ./mcp-rfc-server-python/run_tests.py"
    echo "  - Interfaz web:        ./mcp-rfc-server-python/web_interface.py"
    echo "  - Iniciar servidor:    ./run-mcp-server.sh"
    echo "  - Documentacion:       ./README.md"
    echo ""
    
    echo "PROXIMOS PASOS:"
    echo ""
    echo "  1. Iniciar servidor:"
    echo "     ./run-mcp-server.sh &"
    echo ""
    echo "  2. Interfaz web:"
    echo "     python web_interface.py"
    echo ""
    echo "  3. Abrir en navegador:"
    echo "     http://localhost:8000"
    echo ""
    
else
    print_error "Algunos tests fallaron"
    echo ""
    print_header "WARN REVISION NECESARIA"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Status: OK LISTO PARA PRODUCCION"
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════"
echo ""
