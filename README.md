# BibliotecaBD

Aplicación web de Flask para gestionar y reseñar música.

## Requisitos Previos

- Python 3.8 o superior
- PostgreSQL 12 o superior
- MongoDB 5.0 o superior

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/PollitoMan/BasesProyecto.git
cd BasesProyecto
```

### 2. Crear entorno virtual

```bash
python -m venv venv
venv\Scripts\activate
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar bases de datos

```bash
python setup_databases.py
```

## Uso

```bash
python run.py
```

La aplicación se ejecutará en `0.0.0.0:5000` y se abrirá automáticamente en `http://localhost:5000`

### Acceso desde tu PC local
- `http://localhost:5000`
- `http://127.0.0.1:5000`

### Acceso desde otra PC en la red local
- `http://<TU_IP_LOCAL>:5000`

La IP local se mostrará en la consola cuando ejecutes `python run.py`

### Acceso desde IP pública (Internet)
Para acceder desde Internet, necesitas:
1. Obtener tu IP pública
2. Configurar port forwarding en tu router (puerto 5000)
3. Acceder a través de `http://<TU_IP_PUBLICA>:5000`

**Nota:** El acceso públicamente requiere configuración de seguridad adicional.
