import sys
import os
import webbrowser
import threading
import logging
import socket

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_ip_address():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def open_browser():
    threading.Timer(2.0, lambda: webbrowser.open('http://localhost:5000')).start()

if __name__ == '__main__':
    print("=" * 60)
    print("BibliotecaBD - Iniciando Aplicación")
    print("=" * 60)
    
    try:
        from app.app import app
        
        local_ip = get_ip_address()
        
        print("\n✓ Módulos importados correctamente")
        print("✓ Abriendo navegador en 2 segundos...")
        print("\nAccede a la aplicación en:")
        print(f"  • http://localhost:5000")
        print(f"  • http://127.0.0.1:5000")
        print(f"  • http://{local_ip}:5000 (IP Local)")
        print("\nPara acceder desde otra PC en la red:")
        print(f"  • http://{local_ip}:5000")
        print("\nPara detener la aplicación, presiona Ctrl+C")
        print("=" * 60 + "\n")
        
        open_browser()
        app.run(debug=True, host='0.0.0.0', port=5000)
    except RuntimeError as e:
        print(f"\n{e}")
        print("\n" + "=" * 60)
        print("Para solucionar este problema:")
        print("=" * 60)
        print("\n1. Asegúrate de que PostgreSQL y MongoDB estén corriendo")
        print("\n2. Copia .env.example a .env y ajusta las credenciales si es necesario:")
        print("   cp .env.example .env  (en Linux/Mac)")
        print("   copy .env.example .env  (en Windows)")
        print("\n3. Ejecuta el script de inicialización:")
        print("   python setup_databases.py")
        print("\n4. Intenta nuevamente:")
        print("   python run.py")
        print("\n" + "=" * 60)
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error inesperado: {e}")
        print(f"\n❌ Error inesperado: {e}")
        sys.exit(1)
