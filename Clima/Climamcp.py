from mcp.server.mcpserver import MCPServer
import requests

mcp = MCPServer("ServidorClimaYTraduccion")

# --- HERRAMIENTA 1: CLIMA ---
@mcp.tool()
def obtener_clima(ciudad: str) -> str:
    """Busca en internet el clima exacto y en tiempo real de cualquier ciudad.
    Úsalo solo cuando el usuario pregunte por el clima, tiempo o temperatura."""
    try:
        ciudad_formateada = ciudad.strip().replace(' ', '+')
        url = f"https://wttr.in/{ciudad_formateada}?format=%l:+%C+%c+%t"
        respuesta = requests.get(url, timeout=10)
        
        if respuesta.status_code == 200:
            return respuesta.text 
        else:
            return f"Error: No se encontró la ciudad {ciudad}."
            
    except Exception as e:
        return f"Error de conexión a internet: {str(e)}"

# --- HERRAMIENTA 2: TRADUCCIÓN ---
@mcp.tool()
def traducir_texto(texto: str, idioma_destino: str) -> str:
    """Traduce palabras o frases de cualquier idioma a un idioma especificado.
    Úsalo CADA VEZ que el usuario pida traducir algo.
    El idioma_destino debe ser un código de dos letras (ejemplo: 'es' para español, 'en' para inglés, 'fr' para francés)."""
    try:
        # Usamos una API gratuita que no requiere registro
        url = f"https://api.mymemory.translated.net/get?q={texto}&langpair=autodetect|{idioma_destino}"
        respuesta = requests.get(url, timeout=10)
        
        if respuesta.status_code == 200:
            datos = respuesta.json()
            return datos['responseData']['translatedText']
        else:
            return "Error: No se pudo traducir el texto."
            
    except Exception as e:
        return f"Error de conexión a internet: {str(e)}"

if __name__ == "__main__":
    mcp.run()