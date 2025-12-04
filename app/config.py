import os
from dotenv import load_dotenv
load_dotenv()
from datetime import timedelta
class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    DEBUG = True
    SESSION_COOKIE_SECURE = False
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    PERMANENT_SESSION_LIFETIME = timedelta(hours=24)
    POSTGRES_HOST = os.environ.get('POSTGRES_HOST') or 'localhost'
    POSTGRES_PORT = os.environ.get('POSTGRES_PORT') or '5432'
    POSTGRES_DB = os.environ.get('POSTGRES_DB') or 'music_reviews'
    POSTGRES_USER = os.environ.get('POSTGRES_USER') or 'app_user'
    POSTGRES_PASSWORD = os.environ.get('POSTGRES_PASSWORD') or '123'
    POSTGRES_ADMIN_USER = os.environ.get('POSTGRES_ADMIN_USER') or 'admin_user'
    POSTGRES_ADMIN_PASSWORD = os.environ.get('POSTGRES_ADMIN_PASSWORD') or 'admin123'
    POSTGRES_MIN_CONN = 2
    POSTGRES_MAX_CONN = 10
    POSTGRES_URI = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
    POSTGRES_ISOLATION_LEVEL = 'READ COMMITTED'
    MONGO_HOST = os.environ.get('MONGO_HOST') or 'localhost'
    MONGO_PORT = os.environ.get('MONGO_PORT') or '27017'
    MONGO_DB = os.environ.get('MONGO_DB') or 'music_reviews'
    MONGO_USER = os.environ.get('MONGO_USER') or 'appUser'
    MONGO_PASSWORD = os.environ.get('MONGO_PASSWORD') or '123'
    MONGO_URI = f"mongodb://{MONGO_USER}:{MONGO_PASSWORD}@{MONGO_HOST}:{MONGO_PORT}/{MONGO_DB}?authSource=admin"
    MONGO_MAX_POOL_SIZE = 10
    MONGO_MIN_POOL_SIZE = 2
    MONGO_WRITE_CONCERN = 'majority'
    MONGO_READ_CONCERN = 'majority'
    BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'backups')
    BACKUP_SCHEDULE_HOURS = 24
    POSTGRES_BACKUP_ENABLED = True
    POSTGRES_BACKUP_RETENTION_DAYS = 7
    MONGO_BACKUP_ENABLED = True
    MONGO_BACKUP_RETENTION_DAYS = 7
    REMOTE_BACKUP_ENABLED = False
    REMOTE_BACKUP_HOST = os.environ.get('REMOTE_BACKUP_HOST') or ''
    REMOTE_BACKUP_PATH = os.environ.get('REMOTE_BACKUP_PATH') or ''
    ITEMS_PER_PAGE = 12
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
    RATE_LIMIT = 60
class DevelopmentConfig(Config):
    DEBUG = True
    TESTING = False
class ProductionConfig(Config):
    DEBUG = False
    TESTING = False
    SESSION_COOKIE_SECURE = True
    SECRET_KEY = os.environ.get('SECRET_KEY')
    POSTGRES_URI = os.environ.get('DATABASE_URL')
    MONGO_URI = os.environ.get('MONGO_URL')
class TestingConfig(Config):
    TESTING = True
    DEBUG = True
    POSTGRES_DB = 'music_reviews_test'
    MONGO_DB = 'music_reviews_test'
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
def get_config(env='development'):
    return config.get(env, config['default'])
