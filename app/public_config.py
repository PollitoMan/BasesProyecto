import os
from dotenv import load_dotenv

load_dotenv()

class PublicAccessConfig:
    HOST = os.environ.get('APP_HOST', '0.0.0.0')
    PORT = int(os.environ.get('APP_PORT', 5000))
    DEBUG = os.environ.get('APP_DEBUG', 'True').lower() == 'true'
    WORKERS = int(os.environ.get('APP_WORKERS', 1))
    THREADED = os.environ.get('APP_THREADED', 'True').lower() == 'true'
