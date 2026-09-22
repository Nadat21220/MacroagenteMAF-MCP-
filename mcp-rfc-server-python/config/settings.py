"""
Configuración centralizada para el MCP Server RFC
"""
import os
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# ===== CONFIGURACIÓN DE BASE DE DATOS =====
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://rfcadmin:rfcsecurepass@localhost:5432/rfc_system_db"
)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_USER = os.getenv("DB_USER", "rfcadmin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "rfcsecurepass")
DB_NAME = os.getenv("DB_NAME", "rfc_system_db")

# ===== CONFIGURACIÓN DE OLLAMA =====
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mistral")

# ===== CONFIGURACIÓN DE SHAREPOINT =====
SHAREPOINT_MODE = os.getenv("SHAREPOINT_MODE", "mock")  # "mock" o "real"
SHAREPOINT_SITE_URL = os.getenv("SHAREPOINT_SITE_URL", "")
AZURE_CLIENT_ID = os.getenv("AZURE_CLIENT_ID", "")
AZURE_CLIENT_SECRET = os.getenv("AZURE_CLIENT_SECRET", "")
AZURE_TENANT_ID = os.getenv("AZURE_TENANT_ID", "")

# ===== CONFIGURACIÓN DE MCP =====
MCP_SERVER_NAME = "RFC Management System - Python"
MCP_SERVER_VERSION = "2.0.0"

# ===== CONFIGURACIÓN DE LOGGING =====
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = os.getenv("LOG_FORMAT", "json")  # "json" o "text"

# ===== CONFIGURACIÓN DE API =====
API_TIMEOUT = int(os.getenv("API_TIMEOUT", "30"))
MAX_RETRIES = int(os.getenv("MAX_RETRIES", "3"))

# ===== ARCHIVOS RFC ORIGINALES (Excel/Docx) =====
RFC_FILES_DIR = os.getenv("RFC_FILES_DIR", "/app/RFC")

# ===== CONFIGURACIÓN DE ALMACENAMIENTO =====
# Usar rutas relativas en desarrollo, /data en producción
_default_storage = "./data/rfc_storage" if not os.getenv("STORAGE_PATH") else "/data/rfc_storage"
STORAGE_PATH = os.getenv("STORAGE_PATH", _default_storage)
MARKDOWN_STORAGE_PATH = os.path.join(STORAGE_PATH, "markdown")
DOCUMENT_CACHE_PATH = os.path.join(STORAGE_PATH, "cache")

# Crear directorios si no existen (con manejo de errores)
try:
    os.makedirs(MARKDOWN_STORAGE_PATH, exist_ok=True)
    os.makedirs(DOCUMENT_CACHE_PATH, exist_ok=True)
except PermissionError:
    # En caso de error de permisos, usar carpeta local
    STORAGE_PATH = "./data/rfc_storage"
    MARKDOWN_STORAGE_PATH = os.path.join(STORAGE_PATH, "markdown")
    DOCUMENT_CACHE_PATH = os.path.join(STORAGE_PATH, "cache")
    os.makedirs(MARKDOWN_STORAGE_PATH, exist_ok=True)
    os.makedirs(DOCUMENT_CACHE_PATH, exist_ok=True)

# ===== VALIDACIÓN DE CONFIGURACIÓN =====
def validate_config():
    """Validar que la configuración esté correcta"""
    required_vars = ["DATABASE_URL"]
    missing = [var for var in required_vars if not os.getenv(var)]

    if missing:
        raise ValueError(f"Variables de entorno requeridas faltantes: {missing}")

    return True
