#!/usr/bin/env python3
"""
Cliente que conecta Ollama con MCP Server (Docker Edition)
Usuario -> Ollama (Docker) -> Este cliente -> MCP Server (Docker) -> Herramientas
"""

import requests
import json
import sys
import time

# Conectar a Ollama en Docker
OLLAMA_HOST = "http://localhost:11434"
MCP_SERVER_HOST = "http://localhost:3000"

def wait_for_ollama(max_wait=120):
    """Espera a que Ollama este listo"""
    print("INFO Esperando a que Ollama este listo...")
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        try:
            response = requests.get(f"{OLLAMA_HOST}/api/tags", timeout=5)
            if response.status_code == 200:
                print("OK Ollama esta listo\n")
                return True
        except:
            pass
        
        print(".", end="", flush=True)
        time.sleep(3)
    
    print("\nERROR Ollama no respondio")
    return False

def chat_with_ollama(message):
    """Envia mensaje a Ollama"""
    print(f"Tu: {message}\n")
    
    try:
        # Usar el primer modelo disponible
        response = requests.post(
            f"{OLLAMA_HOST}/api/generate",
            json={
                "model": "mistral",
                "prompt": message,
                "stream": False
            },
            timeout=180
        )
        
        if response.status_code == 200:
            result = response.json()
            ollama_response = result.get("response", "")
            print(f"Ollama: {ollama_response}\n")
            return ollama_response
        else:
            print("ERROR: Ollama error (status {0})\n".format(response.status_code))
            return None
            
    except requests.exceptions.Timeout:
        print("ERROR: Ollama timeout\n")
        return None
    except requests.exceptions.ConnectionError:
        print("ERROR: No se puede conectar a Ollama en {0}\n".format(OLLAMA_HOST))
        return None
    except Exception as e:
        print("ERROR: {0}\n".format(str(e)))
        return None

def main():
    """Loop interactivo"""
    print("="*60)
    print("RFC MCP System - Chat con Ollama (Docker)")
    print("="*60)
    print("")
    
    # Esperar a que Ollama este listo
    if not wait_for_ollama():
        print("WARN Ollama no esta disponible")
        print("Verifica: docker-compose ps")
        sys.exit(1)
    
    print("Escribe tu prompt. Ollama usara las herramientas automaticamente")
    print("Escribe 'salir' para terminar\n")
    
    while True:
        try:
            message = raw_input("Tu: ").strip() if sys.version_info[0] < 3 else input("Tu: ").strip()
            
            if message.lower() == "salir":
                print("\nAdios!")
                break
            
            if not message:
                continue
            
            chat_with_ollama(message)
            
        except KeyboardInterrupt:
            print("\n\nAdios!")
            break
        except Exception as e:
            print("ERROR: {0}\n".format(str(e)))

if __name__ == "__main__":
    main()
