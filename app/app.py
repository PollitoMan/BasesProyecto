from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
def _resolve_track_order(order_key, direction):
    order_key = (order_key or 'rating').lower()
    direction = (direction or 'desc').lower()
    mapping = {
        ('rating', 'desc'): 'rating_desc',
        ('rating', 'asc'): 'rating_asc',
        ('alfabetico', 'asc'): 'title_asc',
        ('alfabetico', 'desc'): 'title_desc',
        ('artista', 'asc'): 'artist_asc',
        ('artista', 'desc'): 'artist_desc',
        ('duracion', 'asc'): 'duration_asc',
        ('duracion', 'desc'): 'duration_desc'
    }
    return mapping.get((order_key, direction), 'rating_desc')
def _resolve_album_order(order_key, direction):
    order_key = (order_key or 'rating').lower()
    direction = (direction or 'desc').lower()
    mapping = {
        ('rating', 'desc'): 'rating_desc',
        ('rating', 'asc'): 'rating_asc',
        ('alfabetico', 'asc'): 'title_asc',
        ('alfabetico', 'desc'): 'title_desc',
        ('fecha', 'desc'): 'release_desc',
        ('fecha', 'asc'): 'release_asc'
    }
    return mapping.get((order_key, direction), 'rating_desc')
def _resolve_artist_order(order_key, direction):
    order_key = (order_key or 'rating').lower()
    direction = (direction or 'desc').lower()
    mapping = {
        ('rating', 'desc'): 'rating_desc',
        ('rating', 'asc'): 'rating_asc',
        ('alfabetico', 'asc'): 'name_asc',
        ('alfabetico', 'desc'): 'name_desc'
    }
    return mapping.get((order_key, direction), 'rating_desc')
from functools import wraps
try:
    import bcrypt
except ImportError as e:
    raise RuntimeError(
        "Missing dependency 'bcrypt'. Please install project dependencies: `pip install -r requirements.txt`"
    ) from e
import logging
from datetime import datetime
from app.config import Config
from app.db_postgres import init_db, get_db
from app.db_mongo import init_mongo, get_mongo
from app.backup import BackupManager
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
app = Flask(__name__)
app.config.from_object(Config)
postgres_db = None
mongo_db = None
backup_manager = None
def initialize_databases():
    """Initialize database connections"""
    global postgres_db, mongo_db, backup_manager
    try:
        postgres_db = init_db(app.config)
        logger.info("PostgreSQL initialized")
        mongo_db = init_mongo(app.config)
        logger.info("MongoDB initialized")
        backup_manager = BackupManager(app.config)
        logger.info("Backup manager initialized")
        return True
    except Exception as e:
        logger.error(f"Error initializing databases: {e}")
        return False
def login_required(f):
    """Decorator to require login"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Por favor, inicia sesion para acceder a esta pagina', 'warning')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function
@app.route('/')
def index():
    """Pagina de inicio con rankings principales"""
    try:
        db = get_db()
        top_tracks = db.get_top_tracks(limit=10)
        top_albums = db.get_top_albums(limit=6)
        top_artists = db.get_top_artists(limit=10)
        return render_template('index.html',
                               top_tracks=top_tracks,
                               top_albums=top_albums,
                               top_artists=top_artists)
    except Exception as e:
        logger.error(f"Error cargando la pagina de inicio: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/canciones')
def songs():
    """Ranking de mejores canciones"""
    try:
        db = get_db()
        tracks = db.get_top_tracks(limit=None)
        return render_template('songs.html', canciones=tracks)
    except Exception as e:
        logger.error(f"Error cargando listado de canciones: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/buscar')
def search():
    """Busqueda global: canciones, albumes y artistas"""
    try:
        query = request.args.get('search', '').strip()
        if not query:
            return redirect(url_for('index'))
        track_order = request.args.get('track_order', 'rating')
        track_dir = request.args.get('track_dir', 'desc')
        album_order = request.args.get('album_order', 'rating')
        album_dir = request.args.get('album_dir', 'desc')
        artist_order = request.args.get('artist_order', 'rating')
        artist_dir = request.args.get('artist_dir', 'desc')
        db = get_db()
        tracks = db.get_tracks(
            limit=None,
            offset=0,
            search=query,
            order=_resolve_track_order(track_order, track_dir)
        )
        albums = db.get_albums(
            limit=None,
            offset=0,
            genre=None,
            search=query,
            order=_resolve_album_order(album_order, album_dir)
        )
        artists = db.get_top_artists(
            limit=None,
            order=_resolve_artist_order(artist_order, artist_dir),
            search=query
        )
        return render_template('search.html',
                               search=query,
                               canciones=tracks,
                               albumes=albums,
                               artistas=artists,
                               track_order=track_order,
                               track_dir=track_dir,
                               album_order=album_order,
                               album_dir=album_dir,
                               artist_order=artist_order,
                               artist_dir=artist_dir)
    except Exception as e:
        logger.error(f"Error ejecutando busqueda: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/buscar/canciones')
def search_tracks_page():
    """Busqueda especifica de canciones con filtros"""
    try:
        query = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'rating')
        direction = request.args.get('direction', 'desc')
        db = get_db()
        tracks = db.get_tracks(
            limit=None,
            offset=0,
            search=query if query else None,
            order=_resolve_track_order(order_key, direction)
        )
        return render_template('search_tracks.html',
                               search=query,
                               canciones=tracks,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error buscando canciones: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/buscar/albumes')
def search_albums_page():
    """Busqueda especifica de albumes con filtros"""
    try:
        query = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'rating')
        direction = request.args.get('direction', 'desc')
        db = get_db()
        albums = db.get_albums(
            limit=None,
            offset=0,
            genre=None,
            search=query if query else None,
            order=_resolve_album_order(order_key, direction)
        )
        return render_template('search_albums.html',
                               search=query,
                               albumes=albums,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error buscando albumes: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/buscar/artistas')
def search_artists_page():
    """Busqueda especifica de artistas con filtros"""
    try:
        query = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'rating')
        direction = request.args.get('direction', 'desc')
        db = get_db()
        artists = db.get_top_artists(
            limit=None,
            order=_resolve_artist_order(order_key, direction),
            search=query if query else None
        )
        return render_template('search_artists.html',
                               search=query,
                               artistas=artists,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error buscando artistas: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/album/<int:album_id>')
def album_detail(album_id):
    """Pagina de detalle de album con resenas"""
    try:
        db = get_db()
        mongo = get_mongo()
        album = db.get_album_by_id(album_id)
        if not album:
            return render_template('error.html', error='i�lbum no encontrado'), 404
        logger.info(f"Album detail page - Album ID: {album_id}, Rating: {album.get('avg_rating')}, Count: {album.get('rating_count')}, Reviews: {album.get('review_count')}")
        user_id = session.get('user_id')
        tracks = db.get_album_tracks(album_id, user_id=user_id)
        reviews = db.get_album_reviews(album_id, limit=20)
        user_review = None
        user_album_rating = None
        if 'user_id' in session:
            user_review = db.get_user_review_for_album(session['user_id'], album_id)
            user_album_rating = db.get_user_album_rating(session['user_id'], album_id)
            mongo.log_activity(session['user_id'], 'click', album_id=album_id)
        return render_template('album.html',
                             albumes=album,
                             canciones=tracks,
                             resenas=reviews,
                             user_review=user_review,
                             user_album_rating=user_album_rating)
    except Exception as e:
        logger.error(f"Error cargando detalle de album: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/cancion/<int:track_id>')
def track_detail(track_id):
    """Pagina de detalle de una cancion individual"""
    try:
        db = get_db()
        user_id = session.get('user_id')
        track = db.get_track_by_id(track_id, user_id)
        if not track:
            return render_template('error.html', error='Cancion no encontrada'), 404
        album = db.get_album_by_id(track['album_id'])
        return render_template('song.html',
                               canciones=track,
                               album=album)
    except Exception as e:
        logger.error(f"Error cargando detalle de cancion: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/artistas')
def artists():
    """Ranking de mejores artistas por rating"""
    try:
        db = get_db()
        top_artists = db.get_top_artists(limit=20)
        return render_template('artists.html', artistas=top_artists)
    except Exception as e:
        logger.error(f"Error cargando listado de artistas: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/albumes')
def albums():
    """Listado de mejores albumes en formato tabla"""
    try:
        db = get_db()
        top_albums = db.get_top_albums(limit=50)
        return render_template('albums.html', albumes=top_albums)
    except Exception as e:
        logger.error(f"Error cargando listado de albumes: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/artista/<int:artist_id>')
def artist_detail(artist_id):
    """Detalle de artista con sus canciones y albumes"""
    try:
        db = get_db()
        artist = db.get_artist_by_id(artist_id)
        if not artist:
            return render_template('error.html', error='Artista no encontrado'), 404
        albums = db.get_artist_albums(artist_id)
        tracks = db.get_artist_tracks(artist_id)
        return render_template('artist.html',
                               artistas=artist,
                               albumes=albums,
                               canciones=tracks)
    except Exception as e:
        logger.error(f"Error cargando detalle de artista: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/login', methods=['GET', 'POST'])
def login():
    """Pagina de inicio de sesion"""
    if request.method == 'POST':
        try:
            username = request.form.get('username')
            password = request.form.get('password')
            if not username or not password:
                flash('Introduce usuario y contrasena', 'error')
                return render_template('login.html')
            db = get_db()
            user = db.get_user_by_username(username)
            if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
                session['user_id'] = user['user_id']
                session['username'] = user['username']
                session['is_admin'] = db.is_admin(user['user_id'])
                session.permanent = True
                db.update_last_login(user['user_id'])
                flash(f'Bienvenido de nuevo, {user["username"]}!', 'success')
                return redirect(url_for('index'))
            else:
                flash('Usuario o contrasena incorrectos', 'error')
        except Exception as e:
            logger.error(f"Login error: {e}")
            flash('Ocurrio un error al iniciar sesion', 'error')
    return render_template('login.html')
@app.route('/register', methods=['GET', 'POST'])
def register():
    """Pagina de registro"""
    if request.method == 'POST':
        try:
            username = request.form.get('username')
            email = request.form.get('email')
            password = request.form.get('password')
            full_name = request.form.get('full_name')
            if not username or not email or not password:
                flash('Por favor, rellena todos los campos obligatorios', 'error')
                return render_template('register.html')
            password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            db = get_db()
            user = db.create_user(username, email, password_hash, full_name)
            session['user_id'] = user['user_id']
            session['username'] = user['username']
            session['is_admin'] = db.is_admin(user['user_id'])
            session.permanent = True
            flash('Registro completado! Bienvenido a Music Ratings FN.', 'success')
            return redirect(url_for('index'))
        except ValueError as e:
            flash(str(e), 'error')
        except Exception as e:
            logger.error(f"Registration error: {e}")
            flash('Ocurrio un error durante el registro', 'error')
    return render_template('register.html')
@app.route('/logout')
def logout():
    """Cerrar sesion"""
    session.clear()
    flash('Has cerrado sesion correctamente', 'info')
    return redirect(url_for('index'))
@app.route('/admin')
@login_required
def admin_panel():
    """Admin panel"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        return render_template('admin.html')
    except Exception as e:
        logger.error(f"Error loading admin panel: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/artista/agregar', methods=['GET', 'POST'])
@login_required
def add_artist():
    """Add a new artist"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        if request.method == 'POST':
            artist_name = request.form.get('artist_name', '').strip()
            country = request.form.get('country', '').strip() or None
            genre = request.form.get('genre', '').strip() or None
            bio = request.form.get('bio', '').strip() or None
            if not artist_name:
                flash('El nombre del artista es requerido', 'error')
                return redirect(url_for('add_artist'))
            try:
                artist_id = db.add_artist(artist_name, country, genre, bio)
                flash(f'Artista "{artist_name}" agregado exitosamente', 'success')
                return redirect(url_for('edit_artist', artist_id=artist_id))
            except Exception as e:
                flash(f'Error al agregar artista: {str(e)}', 'error')
                return redirect(url_for('add_artist'))
        return render_template('admin_add_artist.html')
    except Exception as e:
        logger.error(f"Error in add_artist: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/album/agregar', methods=['GET', 'POST'])
@login_required
def add_album():
    """Add a new album"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        artist_id = request.args.get('artist_id') or request.form.get('artist_id')
        if request.method == 'POST':
            artist_id = request.form.get('artist_id')
            album_title = request.form.get('album_title', '').strip()
            release_date = request.form.get('release_date') or None
            genre = request.form.get('genre', '').strip() or None
            if not artist_id or not album_title:
                flash('El ID del artista y el nombre del album son requeridos', 'error')
                return redirect(url_for('add_album'))
            try:
                album_id = db.add_album(int(artist_id), album_title, release_date, genre)
                flash(f'i�lbum "{album_title}" creado exitosamente. Ahora puedes agregar canciones.', 'success')
                return redirect(url_for('edit_album', album_id=album_id))
            except Exception as e:
                flash(f'Error al agregar album: {str(e)}', 'error')
                return redirect(url_for('add_album', artist_id=artist_id))
        artists = db.get_all_artists(order='name_asc') if not artist_id else None
        return render_template('admin_add_album.html', artist_id=artist_id, artistas=artists)
    except Exception as e:
        logger.error(f"Error in add_album: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/cancion/agregar', methods=['GET', 'POST'])
@login_required
def add_track():
    """Add a new track"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        album_id = request.args.get('album_id') or request.form.get('album_id')
        if request.method == 'POST':
            artist_id = request.form.get('artist_id')
            album_id_form = request.form.get('album_id') or None
            track_title = request.form.get('track_title', '').strip()
            track_number = request.form.get('track_number')
            duration_seconds = request.form.get('duration_seconds')
            if not artist_id or not track_title:
                flash('El artista y nombre de la cancion son requeridos', 'error')
                return redirect(url_for('add_track', album_id=album_id_form))
            if not duration_seconds:
                flash('La duracion es requerida', 'error')
                return redirect(url_for('add_track', album_id=album_id_form))
            try:
                track_number = int(track_number) if track_number else None
                duration_seconds = int(duration_seconds)
                if duration_seconds < 1:
                    flash('La duracion debe ser al menos 1 segundo', 'error')
                    return redirect(url_for('add_track', album_id=album_id_form))
                album_id_int = int(album_id_form) if album_id_form else None
                track_id = db.add_track(track_title, int(artist_id), album_id_int, track_number, duration_seconds)
                flash(f'Cancion "{track_title}" agregada exitosamente', 'success')
                return redirect(url_for('edit_track', track_id=track_id))
            except Exception as e:
                flash(f'Error al agregar cancion: {str(e)}', 'error')
                return redirect(url_for('add_track', album_id=album_id_form))
        album = None
        artists = None
        albums = None
        if album_id:
            album = db.get_album_by_id(int(album_id))
        artists = db.get_all_artists(order='name_asc')
        albums = db.get_albums(limit=None, order='title_asc')
        return render_template('admin_add_track.html', album_id=album_id, albumes=album, artistas=artists, todos_albums=albums)
    except Exception as e:
        logger.error(f"Error in add_track: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/artistas')
@login_required
def admin_artists_list():
    """List all artists for admin management"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        search = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'alfabetico')
        direction = request.args.get('direction', 'asc')
        artists = db.get_all_artists(
            order=_resolve_artist_order(order_key, direction),
            search=search if search else None
        )
        return render_template('admin_artists_list.html', 
                               artistas=artists,
                               search=search,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error in admin_artists_list: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/artista/editar/<int:artist_id>', methods=['GET', 'POST'])
@login_required
def edit_artist(artist_id):
    """Edit an artist"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        if request.method == 'POST':
            artist_name = request.form.get('artist_name', '').strip()
            country = request.form.get('country', '').strip() or None
            genre = request.form.get('genre', '').strip() or None
            bio = request.form.get('bio', '').strip() or None
            if not artist_name:
                flash('El nombre del artista es requerido', 'error')
                return redirect(url_for('edit_artist', artist_id=artist_id))
            try:
                db.edit_artist(artist_id, artist_name, country, genre, bio)
                flash(f'Artista "{artist_name}" actualizado exitosamente', 'success')
                return redirect(url_for('admin_artists_list'))
            except Exception as e:
                flash(f'Error al actualizar artista: {str(e)}', 'error')
                return redirect(url_for('edit_artist', artist_id=artist_id))
        artist = db.get_artist_by_id(artist_id)
        if not artist:
            flash('Artista no encontrado', 'error')
            return redirect(url_for('admin_artists_list'))
        return render_template('admin_edit_artist.html', artistas=artist)
    except Exception as e:
        logger.error(f"Error in edit_artist: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/artista/eliminar/<int:artist_id>', methods=['POST'])
@login_required
def delete_artist(artist_id):
    """Delete an artist"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        artist = db.get_artist_by_id(artist_id)
        if not artist:
            flash('Artista no encontrado', 'error')
        else:
            try:
                db.delete_artist(artist_id)
                flash(f'Artista "{artist["artist_name"]}" eliminado exitosamente', 'success')
            except Exception as e:
                flash(f'Error al eliminar artista: {str(e)}', 'error')
        return redirect(url_for('admin_artists_list'))
    except Exception as e:
        logger.error(f"Error in delete_artist: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/albumes')
@login_required
def admin_albums_list():
    """List all albums for admin management"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        search = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'alfabetico')
        direction = request.args.get('direction', 'asc')
        albums = db.get_albums(
            limit=1000,
            offset=0,
            search=search if search else None,
            order=_resolve_album_order(order_key, direction)
        )
        return render_template('admin_albums_list.html', 
                               albumes=albums,
                               search=search,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error in admin_albums_list: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/album/editar/<int:album_id>', methods=['GET', 'POST'])
@login_required
def edit_album(album_id):
    """Edit an album and manage its tracks"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        if request.method == 'POST':
            action = request.form.get('action')
            if action == 'edit_album':
                album_title = request.form.get('album_title', '').strip()
                release_date = request.form.get('release_date') or None
                genre = request.form.get('genre', '').strip() or None
                if not album_title:
                    flash('El nombre del album es requerido', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
                try:
                    db.edit_album(album_id, album_title, release_date, genre)
                    flash(f'i�lbum "{album_title}" actualizado exitosamente', 'success')
                    return redirect(url_for('edit_album', album_id=album_id))
                except Exception as e:
                    flash(f'Error al actualizar album: {str(e)}', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
            elif action == 'add_track':
                track_title = request.form.get('track_title', '').strip()
                track_number = request.form.get('track_number')
                duration_seconds = request.form.get('duration_seconds')
                if not track_title:
                    flash('El nombre de la cancion es requerido', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
                if not duration_seconds:
                    flash('La duracion es requerida', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
                album = db.get_album_by_id(album_id)
                if not album:
                    flash('i�lbum no encontrado', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
                try:
                    track_number = int(track_number) if track_number else None
                    duration_seconds = int(duration_seconds)
                    if duration_seconds < 1:
                        flash('La duracion debe ser al menos 1 segundo', 'error')
                        return redirect(url_for('edit_album', album_id=album_id))
                    db.add_track(track_title, album['artist_id'], album_id, track_number, duration_seconds)
                    flash(f'Cancion "{track_title}" agregada exitosamente', 'success')
                    return redirect(url_for('edit_album', album_id=album_id))
                except Exception as e:
                    flash(f'Error al agregar cancion: {str(e)}', 'error')
                    return redirect(url_for('edit_album', album_id=album_id))
        album = db.get_album_by_id(album_id)
        if not album:
            flash('i�lbum no encontrado', 'error')
            return redirect(url_for('admin_albums_list'))
        tracks = db.get_album_tracks(album_id)
        return render_template('admin_edit_album.html', albumes=album, canciones=tracks)
    except Exception as e:
        logger.error(f"Error in edit_album: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/album/eliminar/<int:album_id>', methods=['POST'])
@login_required
def delete_album(album_id):
    """Delete an album"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        album = db.get_album_by_id(album_id)
        if not album:
            flash('i�lbum no encontrado', 'error')
        else:
            try:
                db.delete_album(album_id)
                flash(f'i�lbum "{album["album_title"]}" eliminado exitosamente', 'success')
            except Exception as e:
                flash(f'Error al eliminar album: {str(e)}', 'error')
        return redirect(url_for('admin_albums_list'))
    except Exception as e:
        logger.error(f"Error in delete_album: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/canciones')
@login_required
def admin_tracks_list():
    """List all tracks for admin management"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        search = request.args.get('search', '').strip()
        order_key = request.args.get('order', 'alfabetico')
        direction = request.args.get('direction', 'asc')
        tracks = db.get_tracks(
            limit=None,
            offset=0,
            search=search if search else None,
            order=_resolve_track_order(order_key, direction)
        )
        return render_template('admin_tracks_list.html', 
                               canciones=tracks,
                               search=search,
                               order=order_key,
                               direction=direction)
    except Exception as e:
        logger.error(f"Error in admin_tracks_list: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/cancion/editar/<int:track_id>', methods=['GET', 'POST'])
@login_required
def edit_track(track_id):
    """Edit a track"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        if request.method == 'POST':
            track_title = request.form.get('track_title', '').strip()
            artist_id = request.form.get('artist_id')
            album_id = request.form.get('album_id') or None
            track_number = request.form.get('track_number')
            duration_seconds = request.form.get('duration_seconds')
            if not track_title or not artist_id:
                flash('El nombre de la cancion y el artista son requeridos', 'error')
                return redirect(url_for('edit_track', track_id=track_id))
            try:
                track_number = int(track_number) if track_number else None
                duration_seconds = int(duration_seconds) if duration_seconds else None
                album_id = int(album_id) if album_id else None
                db.edit_track(track_id, track_title, int(artist_id), album_id, track_number, duration_seconds)
                flash(f'Cancion "{track_title}" actualizada exitosamente', 'success')
                return redirect(url_for('admin_tracks_list'))
            except Exception as e:
                flash(f'Error al actualizar cancion: {str(e)}', 'error')
                return redirect(url_for('edit_track', track_id=track_id))
        track = db.get_track_basic(track_id)
        if not track:
            flash('Cancion no encontrada', 'error')
            return redirect(url_for('admin_tracks_list'))
        artists = db.get_all_artists(order='name_asc')
        albums = db.get_albums(limit=None, order='title_asc')
        return render_template('admin_edit_track.html', canciones=track, artistas=artists, albumes=albums)
    except Exception as e:
        logger.error(f"Error in edit_track: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/admin/cancion/eliminar/<int:track_id>', methods=['POST'])
@login_required
def delete_track(track_id):
    """Delete a track"""
    try:
        db = get_db()
        if not db.is_admin(session['user_id']):
            return render_template('error.html', error='No tienes permisos de administrador'), 403
        track = db.get_track_basic(track_id)
        if not track:
            flash('Cancion no encontrada', 'error')
        else:
            try:
                db.delete_track(track_id)
                flash(f'Cancion "{track["track_title"]}" eliminada exitosamente', 'success')
            except Exception as e:
                flash(f'Error al eliminar cancion: {str(e)}', 'error')
        return redirect(url_for('admin_tracks_list'))
    except Exception as e:
        logger.error(f"Error in delete_track: {e}")
        return render_template('error.html', error=str(e)), 500
@app.route('/api/review', methods=['POST'])
@login_required
def submit_review():
    """Submit a review (API endpoint)"""
    try:
        data = request.get_json()
        album_id = data.get('album_id')
        rating = data.get('rating')
        review_text = data.get('review_text', '')
        if not album_id:
            return jsonify({'error': 'Missing required fields'}), 400
        if rating is not None and not (1 <= rating <= 5):
            return jsonify({'error': 'Rating must be between 1 and 5'}), 400
        db = get_db()
        if rating is None:
            rating = db.get_user_album_rating(session['user_id'], album_id)
            if rating is not None:
                rating = round(rating)  # Convertir a entero
        if rating is None:
            return jsonify({'error': 'Please rate at least one track from this album before submitting a review'}), 400
        review = db.create_review(session['user_id'], album_id, rating, review_text)
        mongo = get_mongo()
        mongo.log_activity(session['user_id'], 'review', album_id=album_id, metadata={'rating': rating})
        return jsonify({
            'success': True,
            'review_id': review['review_id'],
            'message': 'Review submitted successfully'
        }), 201
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Error submitting review: {e}")
        return jsonify({'error': 'An error occurred'}), 500
@app.route('/api/review/<int:review_id>', methods=['PUT'])
@login_required
def update_review(review_id):
    """Update a review (API endpoint)"""
    try:
        data = request.get_json()
        rating = data.get('rating')
        review_text = data.get('review_text', '')
        version = data.get('version')
        album_id = data.get('album_id')
        if version is None:
            return jsonify({'error': 'Missing required fields'}), 400
        if rating is not None and not (1 <= rating <= 5):
            return jsonify({'error': 'Rating must be between 1 and 5'}), 400
        db = get_db()
        if rating is None and album_id:
            rating = db.get_user_album_rating(session['user_id'], album_id)
            if rating is not None:
                rating = round(rating)  # Convertir a entero
        if rating is None:
            return jsonify({'error': 'No rating available'}), 400
        db.update_review(review_id, rating, review_text, version)
        return jsonify({
            'success': True,
            'message': 'Review updated successfully'
        }), 200
    except ValueError as e:
        return jsonify({'error': str(e)}), 409
    except Exception as e:
        logger.error(f"Error updating review: {e}")
        return jsonify({'error': 'An error occurred'}), 500
@app.route('/api/track-rating', methods=['POST'])
@login_required
def submit_track_rating():
    """Submit or update a track rating"""
    try:
        data = request.get_json()
        track_id = data.get('track_id')
        rating = data.get('rating')
        logger.info(f"Received rating request: track_id={track_id}, rating={rating}, type={type(rating)}")
        if not track_id or rating is None:
            return jsonify({'error': 'Missing required fields'}), 400
        try:
            rating = int(rating)
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid rating value'}), 400
        if not (1 <= rating <= 5):
            return jsonify({'error': 'Rating must be between 1 and 5'}), 400
        db = get_db()
        album_id = db.get_track_album(track_id)
        if not album_id:
            return jsonify({'error': 'Track not found'}), 404
        db.upsert_track_rating(session['user_id'], track_id, rating)
        metrics = db.get_album_rating_metrics(album_id)
        user_album_rating = db.get_user_album_rating(session['user_id'], album_id)
        logger.info(f"Rating saved successfully: track_id={track_id}, rating={rating}")
        return jsonify({
            'success': True,
            'message': 'Track rating saved',
            'album_id': album_id,
            'avg_rating': metrics['avg_rating'],
            'rating_count': metrics['rating_count'],
            'user_album_rating': user_album_rating
        }), 200
    except Exception as e:
        logger.error(f"Error saving track rating: {e}")
        return jsonify({'error': 'An error occurred'}), 500
@app.route('/api/play', methods=['POST'])
@login_required
def play_track():
    """Log track play (API endpoint)"""
    try:
        data = request.get_json()
        album_id = data.get('album_id')
        track_id = data.get('track_id')
        mongo = get_mongo()
        mongo.log_activity(session['user_id'], 'play', album_id=album_id, track_id=track_id)
        session_id = mongo.start_listening_session(session['user_id'], album_id, track_id)
        return jsonify({
            'success': True,
            'session_id': session_id
        }), 200
    except Exception as e:
        logger.error(f"Error logging play: {e}")
        return jsonify({'error': 'An error occurred'}), 500
@app.route('/api/statistics', methods=['GET'])
def get_statistics():
    """Get platform statistics (API endpoint)"""
    try:
        db = get_db()
        stats = db.get_statistics()
        return jsonify(stats), 200
    except Exception as e:
        logger.error(f"Error getting statistics: {e}")
        return jsonify({'error': 'An error occurred'}), 500
@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error='Page not found'), 404
@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error='Internal server error'), 500
if __name__ == '__main__':
    if initialize_databases():
        logger.info("Starting Flask application...")
        app.run(
            host='0.0.0.0',
            port=5000,
            debug=app.config.get('DEBUG', True)
        )
    else:
        logger.error("Failed to initialize databases. Exiting.")
