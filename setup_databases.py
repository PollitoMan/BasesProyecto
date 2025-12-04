#!/usr/bin/env python

import os
import sys
import subprocess
import psycopg2
from psycopg2 import sql
import pymongo
from dotenv import load_dotenv

load_dotenv()

def get_config():
    return {
        'postgres_host': os.environ.get('POSTGRES_HOST', 'localhost'),
        'postgres_port': os.environ.get('POSTGRES_PORT', '5432'),
        'postgres_user': os.environ.get('POSTGRES_ADMIN_USER', 'postgres'),
        'postgres_password': os.environ.get('POSTGRES_ADMIN_PASSWORD', ''),
        'postgres_db': os.environ.get('POSTGRES_DB', 'music_reviews'),
        'app_user': os.environ.get('POSTGRES_USER', 'app_user'),
        'app_password': os.environ.get('POSTGRES_PASSWORD', '123'),
        'mongo_host': os.environ.get('MONGO_HOST', 'localhost'),
        'mongo_port': os.environ.get('MONGO_PORT', '27017'),
        'mongo_user': os.environ.get('MONGO_USER', 'appUser'),
        'mongo_password': os.environ.get('MONGO_PASSWORD', '123'),
        'mongo_db': os.environ.get('MONGO_DB', 'music_reviews'),
    }

def check_postgres(config):
    print("\n=== Verificando PostgreSQL ===")
    try:
        conn = psycopg2.connect(
            host=config['postgres_host'],
            port=config['postgres_port'],
            user=config['postgres_user'],
            password=config['postgres_password'],
            database='postgres'
        )
        conn.close()
        print("✓ PostgreSQL está corriendo")
        return True
    except Exception as e:
        print(f"✗ Error conectando a PostgreSQL: {e}")
        print("  Asegúrate de que PostgreSQL está corriendo")
        return False

def check_mongo(config):
    print("\n=== Verificando MongoDB ===")
    try:
        uri = f"mongodb://{config['mongo_host']}:{config['mongo_port']}/"
        client = pymongo.MongoClient(uri, serverSelectionTimeoutMS=5000)
        client.admin.command('ping')
        client.close()
        print("✓ MongoDB está corriendo")
        return True
    except Exception as e:
        print(f"✗ Error conectando a MongoDB: {e}")
        print("  Asegúrate de que MongoDB está corriendo")
        return False

def setup_postgres(config):
    print("\n=== Configurando PostgreSQL ===")
    try:
        conn = psycopg2.connect(
            host=config['postgres_host'],
            port=config['postgres_port'],
            user=config['postgres_user'],
            password=config['postgres_password'],
            database='postgres'
        )
        conn.autocommit = True
        cursor = conn.cursor()

        try:
            cursor.execute(f"CREATE DATABASE {config['postgres_db']}")
            print(f"✓ Base de datos '{config['postgres_db']}' creada")
        except psycopg2.Error:
            print(f"✓ Base de datos '{config['postgres_db']}' ya existe")

        try:
            cursor.execute(f"CREATE USER {config['app_user']} WITH PASSWORD %s",
                          (config['app_password'],))
            print(f"✓ Usuario '{config['app_user']}' creado")
        except psycopg2.Error:
            print(f"✓ Usuario '{config['app_user']}' ya existe")

        cursor.execute(f"GRANT CONNECT ON DATABASE {config['postgres_db']} TO {config['app_user']}")
        cursor.execute(f"GRANT USAGE ON SCHEMA public TO {config['app_user']}")
        cursor.execute(f"GRANT CREATE ON SCHEMA public TO {config['app_user']}")

        cursor.close()
        conn.close()

        conn = psycopg2.connect(
            host=config['postgres_host'],
            port=config['postgres_port'],
            user=config['postgres_user'],
            password=config['postgres_password'],
            database=config['postgres_db']
        )
        cursor = conn.cursor()

        script_path = os.path.join('database', 'postgres', 'init_postgres.sql')
        if os.path.exists(script_path):
            with open(script_path, 'r', encoding='utf-8') as f:
                cursor.execute(f.read())
            print(f"✓ Script '{script_path}' ejecutado")
        else:
            print(f"⚠ Script '{script_path}' no encontrado")

        conn.commit()
        cursor.close()
        conn.close()

        print("✓ PostgreSQL configurado exitosamente")
        return True
    except Exception as e:
        print(f"✗ Error configurando PostgreSQL: {e}")
        return False

def setup_mongo(config):
    print("\n=== Configurando MongoDB ===")
    try:
        uri = f"mongodb://{config['mongo_host']}:{config['mongo_port']}/"
        client = pymongo.MongoClient(uri, serverSelectionTimeoutMS=5000)
        
        try:
            client.admin.command('createUser',
                               config['mongo_user'],
                               pwd=config['mongo_password'],
                               roles=['root'])
            print(f"✓ Usuario '{config['mongo_user']}' creado")
        except pymongo.errors.OperationFailure:
            print(f"✓ Usuario '{config['mongo_user']}' ya existe")

        db = client[config['mongo_db']]
        db.create_collection('users', check_exists=False)
        print(f"✓ Base de datos '{config['mongo_db']}' creada")

        db.user_activity.create_index('user_id')
        db.user_activity.create_index('timestamp')
        db.reviews.create_index('track_id')
        db.reviews.create_index('user_id')
        print("✓ Índices de MongoDB creados")

        client.close()
        print("✓ MongoDB configurado exitosamente")
        return True
    except Exception as e:
        print(f"✗ Error configurando MongoDB: {e}")
        return False

def main():
    print("=" * 50)
    print("BibliotecaBD - Script de Inicialización")
    print("=" * 50)

    config = get_config()

    postgres_ok = check_postgres(config)
    mongo_ok = check_mongo(config)

    if not postgres_ok or not mongo_ok:
        print("\n⚠ Por favor, instala y corre PostgreSQL y MongoDB antes de continuar")
        print("\nInstrucciones:")
        print("1. PostgreSQL: https://www.postgresql.org/download/")
        print("2. MongoDB: https://www.mongodb.com/try/download/community")
        sys.exit(1)

    postgres_setup = setup_postgres(config)
    mongo_setup = setup_mongo(config)

    if postgres_setup and mongo_setup:
        print("\n" + "=" * 50)
        print("✓ ¡Inicialización completada exitosamente!")
        print("=" * 50)
        print("\nAhora puedes ejecutar la aplicación con:")
        print("  python run.py")
    else:
        print("\n" + "=" * 50)
        print("✗ Hubo errores durante la inicialización")
        print("=" * 50)
        sys.exit(1)

if __name__ == '__main__':
    main()
