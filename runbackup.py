import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

from backup import BackupManager
from config import Config

def main():
    print("="*60)
    print("SISTEMA DE RESPALDO - Music Ratings FN")
    print("="*60)
    print()

    try:
        config_obj = Config()
        config = {
            'BACKUP_DIR': config_obj.BACKUP_DIR,
            'POSTGRES_HOST': config_obj.POSTGRES_HOST,
            'POSTGRES_PORT': config_obj.POSTGRES_PORT,
            'POSTGRES_DB': config_obj.POSTGRES_DB,
            'POSTGRES_USER': config_obj.POSTGRES_ADMIN_USER,
            'POSTGRES_PASSWORD': config_obj.POSTGRES_ADMIN_PASSWORD,
            'MONGO_HOST': config_obj.MONGO_HOST,
            'MONGO_PORT': config_obj.MONGO_PORT,
            'MONGO_DB': config_obj.MONGO_DB,
            'MONGO_USER': config_obj.MONGO_USER,
            'MONGO_PASSWORD': config_obj.MONGO_PASSWORD
        }

        print("ðŸ“¦ Inicializando sistema de respaldo...")
        backup_manager = BackupManager(config)
        print("âœ… Sistema inicializado")
        print()

        print("ðŸ’¾ Creando backup de las bases de datos...")
        print("   - PostgreSQL: music_reviews")
        print("   - MongoDB: music_reviews")
        print()

        result = backup_manager.backup_all()

        print("="*60)
        if result['postgres']['success']:
            print("âœ… PostgreSQL Backup: EXITOSO")
            print(f"   Archivo: {result['postgres']['file']}")
            print(f"   TamaÃ±o: {result['postgres']['size'] / 1024:.2f} KB")
        else:
            print("âŒ PostgreSQL Backup: FALLIDO")
            print(f"   Error: {result['postgres'].get('error', 'Unknown')}")

        print()

        if result['mongodb']['success']:
            print("âœ… MongoDB Backup: EXITOSO")
            print(f"   Directorio: {result['mongodb']['directory']}")
            print(f"   TamaÃ±o: {result['mongodb']['size'] / 1024:.2f} KB")
        else:
            print("âŒ MongoDB Backup: FALLIDO")
            print(f"   Error: {result['mongodb'].get('error', 'Unknown')}")

        print()
        print(f"â° Timestamp: {result['timestamp']}")
        print("="*60)

        if result['postgres']['success'] or result['mongodb']['success']:
            print()
            print("âœ… Backup completado (al menos una base de datos respaldada)")
            return 0
        else:
            print()
            print("âŒ Backup fallÃ³ para todas las bases de datos")
            return 1

    except Exception as e:
        print()
        print(f"âŒ Error ejecutando backup: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    exit(main())
