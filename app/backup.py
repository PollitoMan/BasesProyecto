import os
import subprocess
from datetime import datetime
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BackupManager:

    def __init__(self, config):
        self.config = config
        self.backup_dir = Path(config.get('BACKUP_DIR', 'backups'))
        self.backup_dir.mkdir(parents=True, exist_ok=True)

        self.pg_host = config.get('POSTGRES_HOST', 'localhost')
        self.pg_port = config.get('POSTGRES_PORT', '5432')
        self.pg_db = config.get('POSTGRES_DB', 'music_reviews')
        self.pg_user = config.get('POSTGRES_USER', 'app_user')
        self.pg_password = config.get('POSTGRES_PASSWORD', 'app_pass_2024')

        self.mongo_host = config.get('MONGO_HOST', 'localhost')
        self.mongo_port = config.get('MONGO_PORT', '27017')
        self.mongo_db = config.get('MONGO_DB', 'music_reviews')
        self.mongo_user = config.get('MONGO_USER', 'appUser')
        self.mongo_password = config.get('MONGO_PASSWORD', 'app_mongo_2024')

    def backup_postgres(self):
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = self.backup_dir / f'postgres_backup_{timestamp}.sql'

            env = os.environ.copy()
            env['PGPASSWORD'] = self.pg_password

            cmd = [
                'pg_dump',
                '-h', self.pg_host,
                '-p', str(self.pg_port),
                '-U', self.pg_user,
                '-d', self.pg_db,
                '-F', 'p',
                '-f', str(backup_file)
            ]

            result = subprocess.run(cmd, env=env, capture_output=True, text=True)

            if result.returncode == 0:
                logger.info(f"PostgreSQL backup successful: {backup_file}")
                return {'success': True, 'file': str(backup_file), 'size': backup_file.stat().st_size}
            else:
                logger.error(f"PostgreSQL backup failed: {result.stderr}")
                return {'success': False, 'error': result.stderr}

        except Exception as e:
            logger.error(f"Error backing up PostgreSQL: {e}")
            return {'success': False, 'error': str(e)}

    def backup_mongodb(self):
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_dir = self.backup_dir / f'mongodb_backup_{timestamp}'

            mongodump_path = r'C:\Program Files\MongoDB\Tools\100\bin\mongodump.exe'

            cmd = [
                mongodump_path,
                '--host', self.mongo_host,
                '--port', str(self.mongo_port),
                '--db', self.mongo_db,
                '--username', self.mongo_user,
                '--password', self.mongo_password,
                '--authenticationDatabase', 'admin',
                '--out', str(backup_dir)
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                logger.info(f"MongoDB backup successful: {backup_dir}")
                total_size = sum(f.stat().st_size for f in backup_dir.rglob('*') if f.is_file())
                return {'success': True, 'directory': str(backup_dir), 'size': total_size}
            else:
                logger.error(f"MongoDB backup failed: {result.stderr}")
                return {'success': False, 'error': result.stderr}

        except Exception as e:
            logger.error(f"Error backing up MongoDB: {e}")
            return {'success': False, 'error': str(e)}

    def backup_all(self):
        results = {
            'postgres': self.backup_postgres(),
            'mongodb': self.backup_mongodb(),
            'timestamp': datetime.now().isoformat()
        }

        logger.info(f"Backup completed: PostgreSQL={results['postgres']['success']}, MongoDB={results['mongodb']['success']}")
        return results

    def restore_postgres(self, backup_file):
        try:
            env = os.environ.copy()
            env['PGPASSWORD'] = self.pg_password

            cmd = [
                'psql',
                '-h', self.pg_host,
                '-p', str(self.pg_port),
                '-U', self.pg_user,
                '-d', self.pg_db,
                '-f', backup_file
            ]

            result = subprocess.run(cmd, env=env, capture_output=True, text=True)

            if result.returncode == 0:
                logger.info(f"PostgreSQL restore successful from: {backup_file}")
                return {'success': True}
            else:
                logger.error(f"PostgreSQL restore failed: {result.stderr}")
                return {'success': False, 'error': result.stderr}

        except Exception as e:
            logger.error(f"Error restoring PostgreSQL: {e}")
            return {'success': False, 'error': str(e)}

    def restore_mongodb(self, backup_dir):
        try:
            cmd = [
                'mongorestore',
                '--host', self.mongo_host,
                '--port', str(self.mongo_port),
                '--db', self.mongo_db,
                '--username', self.mongo_user,
                '--password', self.mongo_password,
                '--authenticationDatabase', 'admin',
                '--drop',
                backup_dir
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                logger.info(f"MongoDB restore successful from: {backup_dir}")
                return {'success': True}
            else:
                logger.error(f"MongoDB restore failed: {result.stderr}")
                return {'success': False, 'error': result.stderr}

        except Exception as e:
            logger.error(f"Error restoring MongoDB: {e}")
            return {'success': False, 'error': str(e)}

    def cleanup_old_backups(self, days=7):
        try:
            cutoff = datetime.now().timestamp() - (days * 24 * 60 * 60)
            deleted = []

            for item in self.backup_dir.iterdir():
                if item.stat().st_mtime < cutoff:
                    if item.is_file():
                        item.unlink()
                    elif item.is_dir():
                        import shutil
                        shutil.rmtree(item)
                    deleted.append(str(item))

            logger.info(f"Cleaned up {len(deleted)} old backups")
            return {'success': True, 'deleted': deleted}

        except Exception as e:
            logger.error(f"Error cleaning up backups: {e}")
            return {'success': False, 'error': str(e)}
