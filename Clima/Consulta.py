import asyncio
import ollama
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

Modelo_actual = "qwen3.8"

async def iniciar_chat():
    print("🔄 [1/5] Preparando parámetros del servidor...")
    parametros_servidor = StdioServerParameters(
        command="/home/marquesita/Tools/Ollama/.venv/bin/python3",
        args=["servidor_mcp.py"]
    )

    print("🔄 [2/5] Lanzando subproceso de Python en segundo plano...")
    async with stdio_client(parametros_servidor) as (lectura, escritura):
        
        print("🔄 [3/5] Subproceso activo. Estableciendo sesión MCP...")
        async with ClientSession(lectura, escritura) as sesion:
            
            print("🔄 [4/5] Sesión lista. Realizando protocolo de inicio (Handshake)...")
            await sesion.initialize()
            
            print("✅ [5/5] ¡Conexión exitosa! Obteniendo herramientas...")
            respuesta_herramientas = await sesion.list_tools()
            
            herramientas_ollama = []
            for herramienta in respuesta_herramientas.tools:
                herramientas_ollama.append({
                    'type': 'function',
                    'function': {
                        'name': herramienta.name,
                        'description': herramienta.description,
                        'parameters': herramienta.input_schema
                    }
                })

            print("=========================================================")
            print("🌤️" + Modelo_actual +" + MCP Listo. Escribe 'salir' para terminar.")
            print("=========================================================")

            mis_mensajes = [{'role': 'system', 'content': 'Eres un asistente experto en el clima. Tienes acceso a herramientas mediante MCP. Úsalas cuando sea necesario y responde de forma natural sin decir que eres una IA.'}]
            
            while True:
                texto = input("\nTú: ")
                if texto.lower() in ['salir', 'exit']:
                    print("🤖 IA: ¡Nos vemos pronto!")
                    break
                    
                mis_mensajes.append({'role': 'user', 'content': texto})
                
                # Llamada a Ollama
                respuesta_ia = ollama.chat(model=Modelo_actual, messages=mis_mensajes, tools=herramientas_ollama)
                
                if respuesta_ia['message'].get('tool_calls'):
                    mis_mensajes.append(respuesta_ia['message'])
                    
                    for llamada in respuesta_ia['message']['tool_calls']:
                        print(f"[⚙️ Ejecutando herramienta MCP: {llamada['function']['name']}...]")
                        
                        resultado_mcp = await sesion.call_tool(
                            llamada['function']['name'], 
                            llamada['function']['arguments']
                        )
                        
                        texto_resultado = resultado_mcp.content[0].text if resultado_mcp.content else "Sin datos."
                        
                        mis_mensajes.append({
                            'role': 'tool',
                            'content': texto_resultado,
                            'name': llamada['function']['name']
                        })
                        
                    respuesta_final = ollama.chat(model=Modelo_actual, messages=mis_mensajes)
                    mis_mensajes.append(respuesta_final['message'])
                    print(f"🤖 IA: {respuesta_final['message']['content']}")
                else:
                    mis_mensajes.append(respuesta_ia['message'])
                    print(f"🤖 IA: {respuesta_ia['message']['content']}")

if __name__ == "__main__":
    asyncio.run(iniciar_chat())