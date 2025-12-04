import psycopg2
from psycopg2 import pool, sql, errors
from psycopg2.extensions import ISOLATION_LEVEL_READ_COMMITTED
from contextlib import contextmanager
import logging
from app.config import Config
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
class PostgresDB:
    def __init__(self, config=None):
        self.config = config or Config()
        self.connection_pool = None
        self._initialize_pool()
    def _initialize_pool(self):
        """Create connection pool"""
        try:
            def cfg_get(name, default=None):
                if hasattr(self.config, 'get'):
                    return self.config.get(name, default)
                return getattr(self.config, name, default)
            min_conn = int(cfg_get('POSTGRES_MIN_CONN', 2))
            max_conn = int(cfg_get('POSTGRES_MAX_CONN', 10))
            host = cfg_get('POSTGRES_HOST', 'localhost')
            port = cfg_get('POSTGRES_PORT', '5432')
            db_name = cfg_get('POSTGRES_DB', 'music_reviews')
            username = cfg_get('POSTGRES_USER', 'app_user')
            password = cfg_get('POSTGRES_PASSWORD', '123')
            
            self.connection_pool = psycopg2.pool.ThreadedConnectionPool(
                min_conn,
                max_conn,
                host=host,
                port=port,
                database=db_name,
                user=username,
                password=password
            )
            logger.info(f"PostgreSQL connection pool created: {host}:{port}/{db_name}")
        except psycopg2.OperationalError as e:
            error_msg = (
                f"\n❌ ERROR: No se puede conectar a PostgreSQL\n"
                f"   Host: {cfg_get('POSTGRES_HOST', 'localhost')}\n"
                f"   Puerto: {cfg_get('POSTGRES_PORT', '5432')}\n"
                f"   Base de datos: {cfg_get('POSTGRES_DB', 'music_reviews')}\n"
                f"   Usuario: {cfg_get('POSTGRES_USER', 'app_user')}\n\n"
                f"   Asegúrate de que:\n"
                f"   1. PostgreSQL está corriendo\n"
                f"   2. La base de datos '{db_name}' existe\n"
                f"   3. Las credenciales en config.py o .env son correctas\n\n"
                f"   Detalles del error: {e}"
            )
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e
        except Exception as e:
            error_msg = (
                f"\n❌ ERROR inesperado conectando a PostgreSQL: {e}\n"
                f"   Ejecuta 'python setup_databases.py' para inicializar las bases de datos"
            )
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e
    @contextmanager
    def get_connection(self):
        """Get connection from pool with context manager"""
        conn = None
        try:
            conn = self.connection_pool.getconn()
            conn.set_isolation_level(ISOLATION_LEVEL_READ_COMMITTED)
            yield conn
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            raise
        finally:
            if conn:
                self.connection_pool.putconn(conn)
    @contextmanager
    def get_cursor(self, commit=True):
        """Get cursor with automatic transaction management"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            try:
                yield cursor
                if commit:
                    conn.commit()
            except Exception as e:
                conn.rollback()
                logger.error(f"Transaction rolled back: {e}")
                raise
            finally:
                cursor.close()
    def create_user(self, username, email, password_hash, full_name=None):
        """Create a new user with transaction support"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO users (username, email, password_hash, full_name)
                    VALUES (%s, %s, %s, %s)
                    RETURNING user_id, username, email, created_at
                    """,
                    (username, email, password_hash, full_name)
                )
                result = cursor.fetchone()
                logger.info(f"User created: {username}")
                return {
                    'user_id': result[0],
                    'username': result[1],
                    'email': result[2],
                    'created_at': result[3]
                }
        except errors.UniqueViolation as e:
            logger.warning(f"User already exists: {username}")
            raise ValueError("Username or email already exists")
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            raise
    def get_user_by_username(self, username):
        """Get user by username"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT user_id, username, email, password_hash, full_name, 
                           created_at, last_login, is_active
                    FROM users
                    WHERE username = %s AND is_active = TRUE
                    """,
                    (username,)
                )
                result = cursor.fetchone()
                if result:
                    return {
                        'user_id': result[0],
                        'username': result[1],
                        'email': result[2],
                        'password_hash': result[3],
                        'full_name': result[4],
                        'created_at': result[5],
                        'last_login': result[6],
                        'is_active': result[7]
                    }
                return None
        except Exception as e:
            logger.error(f"Error getting user: {e}")
            raise
    def update_last_login(self, user_id):
        """Update user's last login timestamp"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = %s",
                    (user_id,)
                )
        except Exception as e:
            logger.error(f"Error updating last login: {e}")
            raise
    def get_albums(self, limit=12, offset=0, genre=None, search=None, order='release_desc'):
        """Get albums with pagination and filtering"""
        try:
            with self.get_cursor(commit=False) as cursor:
                query = """
                    SELECT ad.album_id, ad.album_title, ad.artist_name, ad.release_date, 
                           ad.genre, ad.cover_url, ad.avg_rating, ad.rating_count, ad.review_count,
                           a.total_tracks, a.artist_id
                    FROM album_details ad
                    JOIN albums a ON ad.album_id = a.album_id
                    WHERE 1=1
                """
                params = []
                if genre:
                    query += " AND ad.genre = %s"
                    params.append(genre)
                if search:
                    query += " AND (ad.album_title ILIKE %s OR ad.artist_name ILIKE %s)"
                    params.extend([f'%{search}%', f'%{search}%'])
                order_clause = {
                    'rating_desc': " ORDER BY ad.avg_rating DESC, ad.rating_count DESC, ad.release_date DESC",
                    'rating_asc': " ORDER BY ad.avg_rating ASC, ad.rating_count ASC, ad.release_date DESC",
                    'title_asc': " ORDER BY ad.album_title ASC",
                    'title_desc': " ORDER BY ad.album_title DESC",
                    'release_desc': " ORDER BY ad.release_date DESC NULLS LAST",
                    'release_asc': " ORDER BY ad.release_date ASC NULLS LAST"
                }.get(order, " ORDER BY ad.release_date DESC NULLS LAST")
                query += f"{order_clause} LIMIT %s OFFSET %s"
                params.extend([limit, offset])
                cursor.execute(query, params)
                results = cursor.fetchall()
                albums = []
                for row in results:
                    albums.append({
                        'album_id': row[0],
                        'album_title': row[1],
                        'artist_name': row[2],
                        'release_date': row[3],
                        'genre': row[4],
                        'cover_url': row[5],
                        'avg_rating': float(row[6]) if row[6] else 0,
                        'rating_count': row[7] or 0,
                        'review_count': row[8] or 0,
                        'total_tracks': row[9] or 0,
                        'artist_id': row[10]
                    })
                return albums
        except Exception as e:
            logger.error(f"Error getting albums: {e}")
            raise
    def get_top_albums(self, limit=10, order='rating_desc', search=None):
        """Get top albums ordered by configurable metric"""
        try:
            return self.get_albums(limit=limit, offset=0, genre=None, search=search, order=order)
        except Exception as e:
            logger.error(f"Error getting top albums: {e}")
            raise
    def get_album_by_id(self, album_id):
        """Get album details by ID"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT a.album_id, a.album_title, a.artist_id, COALESCE(ar.artist_name, '-'), a.release_date, 
                           a.genre, a.cover_url, a.total_tracks, COALESCE(ad.avg_rating,0), COALESCE(ad.rating_count,0), COALESCE(ad.review_count,0)
                    FROM albums a
                    LEFT JOIN artists ar ON a.artist_id = ar.artist_id
                    LEFT JOIN album_details ad ON ad.album_id = a.album_id
                    WHERE a.album_id = %s
                    """,
                    (album_id,)
                )
                result = cursor.fetchone()
                if result:
                    album_data = {
                        'album_id': result[0],
                        'album_title': result[1],
                        'artist_id': result[2],
                        'artist_name': result[3],
                        'release_date': result[4],
                        'genre': result[5],
                        'cover_url': result[6],
                        'total_tracks': result[7],
                        'avg_rating': float(result[8]) if result[8] else 0,
                        'rating_count': result[9] or 0,
                        'review_count': result[10] or 0
                    }
                    logger.info(f"Album {album_id} data: avg_rating={album_data['avg_rating']}, rating_count={album_data['rating_count']}, review_count={album_data['review_count']}")
                    return album_data
                return None
        except Exception as e:
            logger.error(f"Error getting album: {e}")
            raise
    def get_album_tracks(self, album_id, user_id=None):
        """Get all tracks for an album including rating aggregates"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        t.track_id,
                        t.track_number,
                        t.track_title,
                        t.duration_seconds,
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count,
                        MAX(CASE WHEN tr.user_id = %s THEN tr.rating END) AS user_rating
                    FROM tracks t
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE t.album_id = %s
                    GROUP BY t.track_id, t.track_number, t.track_title, t.duration_seconds
                    ORDER BY t.track_number
                    """,
                    (user_id, album_id)
                )
                results = cursor.fetchall()
                tracks = []
                for row in results:
                    tracks.append({
                        'track_id': row[0],
                        'track_number': row[1],
                        'track_title': row[2],
                        'duration_seconds': row[3],
                        'avg_rating': float(row[4]) if row[4] else 0,
                        'rating_count': row[5] or 0,
                        'user_rating': row[6]
                    })
                return tracks
        except Exception as e:
            logger.error(f"Error getting tracks: {e}")
            raise
    def get_track_by_id(self, track_id, user_id=None):
        """Get a single track with album, artist and rating info"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        t.track_id,
                        t.track_number,
                        t.track_title,
                        t.duration_seconds,
                        a.album_id,
                        COALESCE(a.album_title, '-'),
                        ar.artist_id,
                        COALESCE(ar.artist_name, '-'),
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count,
                        MAX(CASE WHEN tr.user_id = %s THEN tr.rating END) AS user_rating
                    FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.album_id
                    LEFT JOIN artists ar ON a.artist_id = ar.artist_id
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE t.track_id = %s
                    GROUP BY t.track_id, t.track_number, t.track_title, t.duration_seconds,
                             a.album_id, a.album_title, ar.artist_id, ar.artist_name
                    """,
                    (user_id, track_id)
                )
                row = cursor.fetchone()
                if not row:
                    return None
                return {
                    'track_id': row[0],
                    'track_number': row[1],
                    'track_title': row[2],
                    'duration_seconds': row[3],
                    'album_id': row[4],
                    'album_title': row[5],
                    'artist_id': row[6],
                    'artist_name': row[7],
                    'avg_rating': float(row[8]) if row[8] else 0,
                    'rating_count': row[9] or 0,
                    'user_rating': row[10]
                }
        except Exception as e:
            logger.error(f"Error getting track by id: {e}")
            raise
    def upsert_track_rating(self, user_id, track_id, rating):
        """Insert or update a user's rating for a track"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO track_ratings (user_id, track_id, rating)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (user_id, track_id)
                    DO UPDATE SET 
                        rating = EXCLUDED.rating,
                        updated_at = CURRENT_TIMESTAMP,
                        version = track_ratings.version + 1
                    RETURNING rating_id
                    """,
                    (user_id, track_id, rating)
                )
                rating_id = cursor.fetchone()[0]
                logger.info(f"Track rating saved: user={user_id}, track={track_id}")
                return rating_id
        except Exception as e:
            logger.error(f"Error upserting track rating: {e}")
            raise
    def get_track_album(self, track_id):
        """Get the album ID for a given track"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    "SELECT album_id FROM tracks WHERE track_id = %s",
                    (track_id,)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Error getting album for track {track_id}: {e}")
            raise
    def get_album_rating_metrics(self, album_id):
        """Get aggregated rating metrics for an album based on track ratings"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count
                    FROM tracks t
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE t.album_id = %s
                    """,
                    (album_id,)
                )
                result = cursor.fetchone()
                return {
                    'avg_rating': float(result[0]) if result and result[0] is not None else 0,
                    'rating_count': result[1] or 0
                }
        except Exception as e:
            logger.error(f"Error getting album rating metrics: {e}")
            raise
    def get_user_album_rating(self, user_id, album_id):
        """Calculate a user's average rating for an album based on their track ratings"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT AVG(tr.rating)
                    FROM tracks t
                    JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE tr.user_id = %s AND t.album_id = %s
                    """,
                    (user_id, album_id)
                )
                result = cursor.fetchone()
                return float(result[0]) if result and result[0] is not None else None
        except Exception as e:
            logger.error(f"Error getting user album rating: {e}")
            raise
    def get_tracks(self, limit=None, offset=0, search=None, order='rating_desc'):
        """
        Get tracks with album/artist, ratings and ordering options.
        order: rating_desc, rating_asc, title_asc, title_desc, artist_asc, artist_desc, duration_asc, duration_desc
        """
        try:
            with self.get_cursor(commit=False) as cursor:
                base = """
                    SELECT 
                        t.track_id,
                        t.track_title,
                        t.duration_seconds,
                        a.album_id,
                        a.album_title,
                        ar.artist_id,
                        ar.artist_name,
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count
                    FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.album_id
                    LEFT JOIN artists ar ON a.artist_id = ar.artist_id
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE 1=1
                """
                params = []
                if search:
                    base += " AND (t.track_title ILIKE %s OR a.album_title ILIKE %s OR ar.artist_name ILIKE %s)"
                    like = f"%{search}%"
                    params.extend([like, like, like])
                base += " GROUP BY t.track_id, t.track_title, t.duration_seconds, a.album_id, a.album_title, ar.artist_id, ar.artist_name"
                order_clause = {
                    'rating_desc': " ORDER BY avg_rating DESC, rating_count DESC, t.track_title ASC",
                    'rating_asc': " ORDER BY avg_rating ASC, rating_count ASC, t.track_title ASC",
                    'title_asc': " ORDER BY t.track_title ASC",
                    'title_desc': " ORDER BY t.track_title DESC",
                    'artist_asc': " ORDER BY ar.artist_name ASC, t.track_title ASC",
                    'artist_desc': " ORDER BY ar.artist_name DESC, t.track_title ASC",
                    'duration_asc': " ORDER BY t.duration_seconds ASC, t.track_title ASC",
                    'duration_desc': " ORDER BY t.duration_seconds DESC, t.track_title ASC"
                }.get(order, " ORDER BY avg_rating DESC, rating_count DESC")
                if limit is not None:
                    base += order_clause + " LIMIT %s OFFSET %s"
                    params.extend([limit, offset])
                else:
                    base += order_clause
                cursor.execute(base, params)
                rows = cursor.fetchall()
                tracks = []
                for row in rows:
                    tracks.append({
                        'track_id': row[0],
                        'track_title': row[1],
                        'duration_seconds': row[2],
                        'album_id': row[3],
                        'album_title': row[4],
                        'artist_id': row[5],
                        'artist_name': row[6],
                        'avg_rating': float(row[7]) if row[7] else 0,
                        'rating_count': row[8] or 0
                    })
                return tracks
        except Exception as e:
            logger.error(f"Error getting tracks list: {e}")
            raise
    def get_top_tracks(self, limit=None):
        """Get best rated tracks globally. If limit is None, return all tracks ordered by rating."""
        return self.get_tracks(limit=limit, offset=0, search=None, order='rating_desc')
    def get_top_artists(self, limit=10, order='rating_desc', search=None):
        """Get best artists based on configurable ordering"""
        try:
            with self.get_cursor(commit=False) as cursor:
                base_query = """
                    SELECT 
                        ar.artist_id,
                        ar.artist_name,
                        ar.country,
                        ar.genre,
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count,
                        COUNT(DISTINCT a.album_id) AS album_count,
                        COUNT(DISTINCT t.track_id) AS track_count
                    FROM artists ar
                    LEFT JOIN albums a ON a.artist_id = ar.artist_id
                    LEFT JOIN tracks t ON t.album_id = a.album_id
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE 1=1
                """
                params = []
                if search:
                    base_query += " AND ar.artist_name ILIKE %s"
                    params.append(f'%{search}%')
                base_query += """
                    GROUP BY ar.artist_id, ar.artist_name, ar.country, ar.genre
                """
                order_clause = {
                    'rating_desc': " ORDER BY avg_rating DESC, rating_count DESC, ar.artist_name ASC",
                    'rating_asc': " ORDER BY avg_rating ASC, rating_count ASC, ar.artist_name ASC",
                    'name_asc': " ORDER BY ar.artist_name ASC",
                    'name_desc': " ORDER BY ar.artist_name DESC"
                }.get(order, " ORDER BY avg_rating DESC, rating_count DESC, ar.artist_name ASC")
                base_query += order_clause + " LIMIT %s"
                params.append(limit)
                cursor.execute(base_query, params)
                rows = cursor.fetchall()
                artists = []
                for row in rows:
                    artists.append({
                        'artist_id': row[0],
                        'artist_name': row[1],
                        'country': row[2],
                        'genre': row[3],
                        'avg_rating': float(row[4]) if row[4] else 0,
                        'rating_count': row[5] or 0,
                        'album_count': row[6] or 0,
                        'track_count': row[7] or 0
                    })
                return artists
        except Exception as e:
            logger.error(f"Error getting top artists: {e}")
            raise
    def get_all_artists(self, order='name_asc', search=None):
        """Get all artists for admin management with album and track counts"""
        try:
            with self.get_cursor(commit=False) as cursor:
                order_clause = {
                    'name_asc': " ORDER BY ar.artist_name ASC",
                    'name_desc': " ORDER BY ar.artist_name DESC",
                    'rating_desc': " ORDER BY avg_rating DESC NULLS LAST, ar.artist_name ASC",
                    'rating_asc': " ORDER BY avg_rating ASC NULLS LAST, ar.artist_name ASC"
                }.get(order, " ORDER BY ar.artist_name ASC")
                search_clause = ""
                params = []
                if search:
                    search_clause = " WHERE ar.artist_name ILIKE %s"
                    params.append(f"%{search}%")
                query = f"""
                    SELECT 
                        ar.artist_id,
                        ar.artist_name,
                        ar.country,
                        ar.genre,
                        ar.bio,
                        COUNT(DISTINCT a.album_id) as album_count,
                        COUNT(DISTINCT t.track_id) as track_count,
                        AVG(r.rating) as avg_rating,
                        COUNT(DISTINCT r.rating_id) as rating_count
                    FROM artists ar
                    LEFT JOIN albums a ON ar.artist_id = a.artist_id
                    LEFT JOIN tracks t ON a.album_id = t.album_id
                    LEFT JOIN track_ratings r ON t.track_id = r.track_id
                    {search_clause}
                    GROUP BY ar.artist_id, ar.artist_name, ar.country, ar.genre, ar.bio
                    {order_clause}
                """
                cursor.execute(query, params)
                results = cursor.fetchall()
                artists = []
                for row in results:
                    artists.append({
                        'artist_id': row[0],
                        'artist_name': row[1],
                        'country': row[2],
                        'genre': row[3],
                        'bio': row[4],
                        'album_count': row[5],
                        'track_count': row[6],
                        'avg_rating': row[7],
                        'rating_count': row[8]
                    })
                return artists
        except Exception as e:
            logger.error(f"Error getting all artists: {e}")
            raise
    def search_artists(self, search, limit=20):
        """Search artists by name"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        artist_id,
                        artist_name,
                        country,
                        genre
                    FROM artists
                    WHERE artist_name ILIKE %s
                    ORDER BY artist_name ASC
                    LIMIT %s
                    """,
                    (f"%{search}%", limit)
                )
                rows = cursor.fetchall()
                artists = []
                for row in rows:
                    artists.append({
                        'artist_id': row[0],
                        'artist_name': row[1],
                        'country': row[2],
                        'genre': row[3]
                    })
                return artists
        except Exception as e:
            logger.error(f"Error searching artists: {e}")
            raise
    def get_artist_by_id(self, artist_id):
        """Get basic artist info"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT artist_id, artist_name, country, genre, bio
                    FROM artists
                    WHERE artist_id = %s
                    """,
                    (artist_id,)
                )
                row = cursor.fetchone()
                if not row:
                    return None
                return {
                    'artist_id': row[0],
                    'artist_name': row[1],
                    'country': row[2],
                    'genre': row[3],
                    'bio': row[4]
                }
        except Exception as e:
            logger.error(f"Error getting artist by id: {e}")
            raise
    def get_artist_albums(self, artist_id):
        """Get all albums for an artist with rating info"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        a.album_id,
                        a.album_title,
                        a.release_date,
                        a.genre,
                        a.cover_url,
                        ad.avg_rating,
                        ad.rating_count,
                        ad.review_count
                    FROM albums a
                    LEFT JOIN album_details ad ON ad.album_id = a.album_id
                    WHERE a.artist_id = %s
                    ORDER BY a.release_date DESC, a.album_title ASC
                    """,
                    (artist_id,)
                )
                rows = cursor.fetchall()
                albums = []
                for row in rows:
                    albums.append({
                        'album_id': row[0],
                        'album_title': row[1],
                        'release_date': row[2],
                        'genre': row[3],
                        'cover_url': row[4],
                        'avg_rating': float(row[5]) if row[5] else 0,
                        'rating_count': row[6] or 0,
                        'review_count': row[7] or 0
                    })
                return albums
        except Exception as e:
            logger.error(f"Error getting artist albums: {e}")
            raise
    def get_artist_tracks(self, artist_id):
        """Get all tracks for an artist with ratings"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT 
                        t.track_id,
                        t.track_title,
                        t.duration_seconds,
                        a.album_id,
                        a.album_title,
                        COALESCE(AVG(tr.rating), 0) AS avg_rating,
                        COUNT(tr.rating_id) AS rating_count
                    FROM tracks t
                    JOIN albums a ON t.album_id = a.album_id
                    JOIN artists ar ON a.artist_id = ar.artist_id
                    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id
                    WHERE ar.artist_id = %s
                    GROUP BY t.track_id, t.track_title, t.duration_seconds, a.album_id, a.album_title
                    ORDER BY a.release_date DESC, a.album_title ASC, t.track_number ASC
                    """,
                    (artist_id,)
                )
                rows = cursor.fetchall()
                tracks = []
                for row in rows:
                    tracks.append({
                        'track_id': row[0],
                        'track_title': row[1],
                        'duration_seconds': row[2],
                        'album_id': row[3],
                        'album_title': row[4],
                        'avg_rating': float(row[5]) if row[5] else 0,
                        'rating_count': row[6] or 0
                    })
                return tracks
        except Exception as e:
            logger.error(f"Error getting artist tracks: {e}")
            raise
    def create_review(self, user_id, album_id, rating, review_text):
        """Create a new review with transaction support"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO reviews (user_id, album_id, rating, review_text)
                    VALUES (%s, %s, %s, %s)
                    RETURNING review_id, created_at, version
                    """,
                    (user_id, album_id, rating, review_text)
                )
                result = cursor.fetchone()
                logger.info(f"Review created: user={user_id}, album={album_id}")
                return {
                    'review_id': result[0],
                    'created_at': result[1],
                    'version': result[2]
                }
        except errors.UniqueViolation:
            logger.warning(f"User {user_id} already reviewed album {album_id}")
            raise ValueError("You have already reviewed this album")
        except Exception as e:
            logger.error(f"Error creating review: {e}")
            raise
    def update_review(self, review_id, rating, review_text, expected_version):
        """Update review with optimistic locking"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    "SELECT update_review_with_lock(%s, %s, %s, %s)",
                    (review_id, rating, review_text, expected_version)
                )
                logger.info(f"Review updated: {review_id}")
                return True
        except errors.RaiseException as e:
            logger.warning(f"Concurrency conflict: {e}")
            raise ValueError("Review was modified by another user. Please refresh and try again.")
        except Exception as e:
            logger.error(f"Error updating review: {e}")
            raise
    def get_album_reviews(self, album_id, limit=10, offset=0):
        """Get reviews for an album"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT r.review_id, r.rating, r.review_text, r.created_at, 
                           r.updated_at, r.version, u.username, u.full_name
                    FROM reviews r
                    JOIN users u ON r.user_id = u.user_id
                    WHERE r.album_id = %s
                    ORDER BY r.created_at DESC
                    LIMIT %s OFFSET %s
                    """,
                    (album_id, limit, offset)
                )
                results = cursor.fetchall()
                reviews = []
                for row in results:
                    reviews.append({
                        'review_id': row[0],
                        'rating': row[1],
                        'review_text': row[2],
                        'created_at': row[3],
                        'updated_at': row[4],
                        'version': row[5],
                        'username': row[6],
                        'full_name': row[7]
                    })
                return reviews
        except Exception as e:
            logger.error(f"Error getting reviews: {e}")
            raise
    def get_user_review_for_album(self, user_id, album_id):
        """Check if user has already reviewed an album"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT review_id, rating, review_text, version
                    FROM reviews
                    WHERE user_id = %s AND album_id = %s
                    """,
                    (user_id, album_id)
                )
                result = cursor.fetchone()
                if result:
                    return {
                        'review_id': result[0],
                        'rating': result[1],
                        'review_text': result[2],
                        'version': result[3]
                    }
                return None
        except Exception as e:
            logger.error(f"Error checking user review: {e}")
            raise
    def add_artist(self, artist_name, country=None, genre=None, bio=None):
        """Add a new artist"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute(
                    """
                    INSERT INTO artists (artist_name, country, genre, bio)
                    VALUES (%s, %s, %s, %s)
                    RETURNING artist_id
                    """,
                    (artist_name, country, genre, bio)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except errors.IntegrityError as e:
            logger.error(f"Artist already exists: {e}")
            raise Exception(f"El artista '{artist_name}' ya existe")
        except Exception as e:
            logger.error(f"Error adding artist: {e}")
            raise
    def get_artist_by_id(self, artist_id):
        """Get artist details by ID"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    """
                    SELECT artist_id, artist_name, country, genre, bio
                    FROM artists
                    WHERE artist_id = %s
                    """,
                    (artist_id,)
                )
                result = cursor.fetchone()
                if result:
                    return {
                        'artist_id': result[0],
                        'artist_name': result[1],
                        'country': result[2],
                        'genre': result[3],
                        'bio': result[4]
                    }
                return None
        except Exception as e:
            logger.error(f"Error getting artist by ID: {e}")
            raise
    def edit_artist(self, artist_id, artist_name, country=None, genre=None, bio=None):
        """Edit an existing artist"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute(
                    """
                    UPDATE artists
                    SET artist_name = %s, country = %s, genre = %s, bio = %s
                    WHERE artist_id = %s
                    """,
                    (artist_name, country, genre, bio, artist_id)
                )
        except Exception as e:
            logger.error(f"Error editing artist: {e}")
            raise
    def delete_artist(self, artist_id):
        """Delete an artist (cascades to tracks)"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute("DELETE FROM artists WHERE artist_id = %s", (artist_id,))
        except Exception as e:
            logger.error(f"Error deleting artist: {e}")
            raise
    def add_album(self, artist_id, album_title, release_date=None, genre=None):
        """Add a new album"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute(
                    """
                    INSERT INTO albums (artist_id, album_title, release_date, genre, total_tracks)
                    VALUES (%s, %s, %s, %s, NULL)
                    RETURNING album_id
                    """,
                    (artist_id, album_title, release_date, genre)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Error adding album: {e}")
            raise
    def edit_album(self, album_id, album_title, release_date=None, genre=None):
        """Edit an existing album"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute(
                    """
                    UPDATE albums
                    SET album_title = %s, release_date = %s, genre = %s
                    WHERE album_id = %s
                    """,
                    (album_title, release_date, genre, album_id)
                )
        except Exception as e:
            logger.error(f"Error editing album: {e}")
            raise
    def delete_album(self, album_id):
        """Delete an album (tracks remain but lose album reference)"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute("UPDATE tracks SET album_id = NULL WHERE album_id = %s", (album_id,))
                cursor.execute("DELETE FROM albums WHERE album_id = %s", (album_id,))
        except Exception as e:
            logger.error(f"Error deleting album: {e}")
            raise
    def _reorder_tracks(self, cursor, album_id, insert_position, exclude_track_id=None):
        """
        Shift track numbers to make room for a new track at insert_position.
        All tracks with track_number >= insert_position will be incremented by 1.
        exclude_track_id: track to exclude from shifting (when updating existing track)
        """
        try:
            if exclude_track_id:
                cursor.execute(
                    """
                    UPDATE tracks
                    SET track_number = track_number + 1
                    WHERE album_id = %s AND track_number >= %s AND track_id != %s
                    """,
                    (album_id, insert_position, exclude_track_id)
                )
            else:
                cursor.execute(
                    """
                    UPDATE tracks
                    SET track_number = track_number + 1
                    WHERE album_id = %s AND track_number >= %s
                    """,
                    (album_id, insert_position)
                )
        except Exception as e:
            logger.error(f"Error reordering tracks: {e}")
            raise
    def _get_next_track_number(self, cursor, album_id):
        """Get the next available track number for an album"""
        try:
            cursor.execute(
                """
                SELECT COALESCE(MAX(track_number), 0) + 1
                FROM tracks
                WHERE album_id = %s
                """,
                (album_id,)
            )
            result = cursor.fetchone()
            return result[0] if result else 1
        except Exception as e:
            logger.error(f"Error getting next track number: {e}")
            raise
    def add_track(self, track_title, artist_id, album_id=None, track_number=None, duration_seconds=None):
        """Add a new track (album_id is optional, artist_id is required)"""
        try:
            if artist_id is None:
                raise ValueError("artist_id is required for tracks")
            with self.get_cursor(commit=True) as cursor:
                if album_id:
                    if not track_number or track_number == 0:
                        track_number = self._get_next_track_number(cursor, album_id)
                    else:
                        self._reorder_tracks(cursor, album_id, track_number)
                else:
                    track_number = None
                cursor.execute(
                    """
                    INSERT INTO tracks (album_id, track_number, track_title, duration_seconds, artist_id)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING track_id
                    """,
                    (album_id, track_number, track_title, duration_seconds, artist_id)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Error adding track: {e}")
            raise
    def get_track_basic(self, track_id):
        """Get track details by ID, including artist name (without ratings)"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(
                    """
                    SELECT t.track_id, t.album_id, t.artist_id, ar.artist_name, t.track_number, t.track_title, t.duration_seconds
                    FROM tracks t
                    LEFT JOIN artists ar ON t.artist_id = ar.artist_id
                    WHERE t.track_id = %s
                    """,
                    (track_id,)
                )
                result = cursor.fetchone()
                if result:
                    return {
                        'track_id': result[0],
                        'album_id': result[1],
                        'artist_id': result[2],
                        'artist_name': result[3],
                        'track_number': result[4],
                        'track_title': result[5],
                        'duration_seconds': result[6]
                    }
                return None
        except Exception as e:
            logger.error(f"Error getting track by ID: {e}")
            raise
    def edit_track(self, track_id, track_title, artist_id, album_id=None, track_number=None, duration_seconds=None):
        """Edit an existing track (artist_id is required, album_id is optional)"""
        try:
            if artist_id is None:
                raise ValueError("artist_id is required for tracks")
            with self.get_cursor(commit=True) as cursor:
                cursor.execute(
                    "SELECT album_id, track_number, artist_id FROM tracks WHERE track_id = %s",
                    (track_id,)
                )
                current = cursor.fetchone()
                if not current:
                    raise ValueError(f"Track {track_id} not found")
                old_album_id, old_track_number, old_artist_id = current[0], current[1], current[2]
                if album_id:
                    if not track_number or track_number == 0:
                        track_number = self._get_next_track_number(cursor, album_id)
                    elif old_album_id == album_id and old_track_number != track_number:
                        cursor.execute(
                            "UPDATE tracks SET track_number = NULL WHERE track_id = %s",
                            (track_id,)
                        )
                        self._reorder_tracks(cursor, album_id, track_number, exclude_track_id=track_id)
                    elif old_album_id != album_id:
                        self._reorder_tracks(cursor, album_id, track_number, exclude_track_id=track_id)
                else:
                    track_number = None
                cursor.execute(
                    """
                    UPDATE tracks
                    SET track_title = %s, artist_id = %s, album_id = %s, track_number = %s, duration_seconds = %s
                    WHERE track_id = %s
                    """,
                    (track_title, artist_id, album_id, track_number, duration_seconds, track_id)
                )
        except Exception as e:
            logger.error(f"Error editing track: {e}")
            raise
    def delete_track(self, track_id):
        """Delete a track"""
        try:
            with self.get_cursor(commit=True) as cursor:
                cursor.execute("DELETE FROM tracks WHERE track_id = %s", (track_id,))
        except Exception as e:
            logger.error(f"Error deleting track: {e}")
            raise
    def is_admin(self, user_id):
        """Check if user is admin"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute(
                    """
                    SELECT COUNT(*) FROM user_roles
                    WHERE user_id = %s AND role_name = 'admin'
                    """,
                    (user_id,)
                )
                result = cursor.fetchone()
                return result[0] > 0 if result else False
        except Exception as e:
            logger.error(f"Error checking admin status: {e}")
            return False
    def get_statistics(self):
        """Get database statistics"""
        try:
            with self.get_cursor(commit=False) as cursor:
                cursor.execute("""
                    SELECT 
                        (SELECT COUNT(*) FROM users WHERE is_active = TRUE) as total_users,
                        (SELECT COUNT(*) FROM albums) as total_albums,
                        (SELECT COUNT(*) FROM reviews) as total_reviews,
                        (SELECT AVG(rating) FROM track_ratings) as avg_rating
                """)
                result = cursor.fetchone()
                return {
                    'total_users': result[0],
                    'total_albums': result[1],
                    'total_reviews': result[2],
                    'avg_rating': float(result[3]) if result[3] else 0
                }
        except Exception as e:
            logger.error(f"Error getting statistics: {e}")
            raise
    def close(self):
        """Close all connections in the pool"""
        if self.connection_pool:
            self.connection_pool.closeall()
            logger.info("PostgreSQL connection pool closed")
db = None
def init_db(config=None):
    """Initialize database connection"""
    global db
    db = PostgresDB(config)
    return db
def get_db():
    """Get database instance"""
    global db
    if db is None:
        db = init_db()
    return db
