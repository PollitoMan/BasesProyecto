from pymongo import MongoClient, ASCENDING, DESCENDING
from pymongo.errors import ConnectionFailure, DuplicateKeyError, OperationFailure
from datetime import datetime, timedelta
from contextlib import contextmanager
import logging
from app.config import Config
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
class MongoDB:
    def __init__(self, config=None):
        self.config = config or Config()
        self.client = None
        self.db = None
        self._connect()
    def _connect(self):
        """Establish MongoDB connection"""
        try:
            def cfg_get(name, default=None):
                if hasattr(self.config, 'get'):
                    return self.config.get(name, default)
                return getattr(self.config, name, default)
            
            uri = cfg_get('MONGO_URI')
            max_pool = int(cfg_get('MONGO_MAX_POOL_SIZE', 10))
            min_pool = int(cfg_get('MONGO_MIN_POOL_SIZE', 2))
            host = cfg_get('MONGO_HOST', 'localhost')
            port = cfg_get('MONGO_PORT', '27017')
            dbname = cfg_get('MONGO_DB', 'music_reviews')
            
            self.client = MongoClient(
                uri,
                maxPoolSize=max_pool,
                minPoolSize=min_pool,
                serverSelectionTimeoutMS=5000
            )
            self.client.admin.command('ping')
            self.db = self.client[dbname]
            logger.info(f"MongoDB connected: {host}:{port}/{dbname}")
        except ConnectionFailure as e:
            error_msg = (
                f"\n❌ ERROR: No se puede conectar a MongoDB\n"
                f"   Host: {cfg_get('MONGO_HOST', 'localhost')}\n"
                f"   Puerto: {cfg_get('MONGO_PORT', '27017')}\n"
                f"   Base de datos: {cfg_get('MONGO_DB', 'music_reviews')}\n\n"
                f"   Asegúrate de que:\n"
                f"   1. MongoDB está corriendo\n"
                f"   2. El usuario está creado correctamente\n"
                f"   3. Las credenciales en config.py o .env son correctas\n\n"
                f"   Detalles del error: {e}"
            )
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e
        except Exception as e:
            error_msg = (
                f"\n❌ ERROR inesperado conectando a MongoDB: {e}\n"
                f"   Ejecuta 'python setup_databases.py' para inicializar las bases de datos"
            )
            logger.error(error_msg)
            raise RuntimeError(error_msg) from e
    @contextmanager
    def start_session(self):
        """Start a MongoDB session for transactions"""
        session = self.client.start_session()
        try:
            yield session
        finally:
            session.end_session()
    def log_activity(self, user_id, activity_type, **kwargs):
        """Log user activity"""
        try:
            activity = {
                'user_id': user_id,
                'activity_type': activity_type,
                'timestamp': datetime.utcnow(),
                'version': 1
            }
            if 'album_id' in kwargs:
                activity['album_id'] = kwargs['album_id']
            if 'track_id' in kwargs:
                activity['track_id'] = kwargs['track_id']
            if 'search_query' in kwargs:
                activity['search_query'] = kwargs['search_query']
            if 'metadata' in kwargs:
                activity['metadata'] = kwargs['metadata']
            result = self.db.user_activity.insert_one(activity)
            logger.info(f"Activity logged: {activity_type} for user {user_id}")
            return str(result.inserted_id)
        except Exception as e:
            logger.error(f"Error logging activity: {e}")
            raise
    def get_user_activity(self, user_id, limit=50, activity_type=None):
        """Get user activity history"""
        try:
            query = {'user_id': user_id}
            if activity_type:
                query['activity_type'] = activity_type
            activities = list(
                self.db.user_activity
                .find(query)
                .sort('timestamp', DESCENDING)
                .limit(limit)
            )
            for activity in activities:
                activity['_id'] = str(activity['_id'])
            return activities
        except Exception as e:
            logger.error(f"Error getting user activity: {e}")
            raise
    def get_popular_searches(self, limit=10, days=7):
        """Get popular search queries"""
        try:
            start_date = datetime.utcnow() - timedelta(days=days)
            pipeline = [
                {
                    '$match': {
                        'activity_type': 'search',
                        'timestamp': {'$gte': start_date}
                    }
                },
                {
                    '$group': {
                        '_id': '$search_query',
                        'count': {'$sum': 1}
                    }
                },
                {
                    '$sort': {'count': -1}
                },
                {
                    '$limit': limit
                }
            ]
            results = list(self.db.user_activity.aggregate(pipeline))
            return [{'query': r['_id'], 'count': r['count']} for r in results]
        except Exception as e:
            logger.error(f"Error getting popular searches: {e}")
            raise
    def start_listening_session(self, user_id, album_id, track_id=None, device_info=None):
        """Start a listening session"""
        try:
            session = {
                'user_id': user_id,
                'album_id': album_id,
                'started_at': datetime.utcnow(),
                'completed': False,
                'version': 1
            }
            if track_id:
                session['track_id'] = track_id
            if device_info:
                session['device_info'] = device_info
            result = self.db.listening_history.insert_one(session)
            logger.info(f"Listening session started: user={user_id}, album={album_id}")
            return str(result.inserted_id)
        except Exception as e:
            logger.error(f"Error starting listening session: {e}")
            raise
    def end_listening_session(self, session_id, duration_seconds, completed=True):
        """End a listening session"""
        try:
            from bson.objectid import ObjectId
            update = {
                '$set': {
                    'ended_at': datetime.utcnow(),
                    'duration_seconds': duration_seconds,
                    'completed': completed
                },
                '$inc': {'version': 1}
            }
            result = self.db.listening_history.update_one(
                {'_id': ObjectId(session_id)},
                update
            )
            if result.modified_count > 0:
                logger.info(f"Listening session ended: {session_id}")
                return True
            return False
        except Exception as e:
            logger.error(f"Error ending listening session: {e}")
            raise
    def get_listening_history(self, user_id, limit=20):
        """Get user's listening history"""
        try:
            history = list(
                self.db.listening_history
                .find({'user_id': user_id})
                .sort('started_at', DESCENDING)
                .limit(limit)
            )
            for item in history:
                item['_id'] = str(item['_id'])
            return history
        except Exception as e:
            logger.error(f"Error getting listening history: {e}")
            raise
    def get_most_played_albums(self, user_id, limit=10):
        """Get user's most played albums"""
        try:
            pipeline = [
                {
                    '$match': {'user_id': user_id, 'completed': True}
                },
                {
                    '$group': {
                        '_id': '$album_id',
                        'play_count': {'$sum': 1},
                        'total_duration': {'$sum': '$duration_seconds'}
                    }
                },
                {
                    '$sort': {'play_count': -1}
                },
                {
                    '$limit': limit
                }
            ]
            results = list(self.db.listening_history.aggregate(pipeline))
            return [
                {
                    'album_id': r['_id'],
                    'play_count': r['play_count'],
                    'total_duration': r['total_duration']
                }
                for r in results
            ]
        except Exception as e:
            logger.error(f"Error getting most played albums: {e}")
            raise
    def save_recommendations(self, user_id, recommended_albums, algorithm_version='v1.0'):
        """Save personalized recommendations for a user"""
        try:
            recommendation = {
                'user_id': user_id,
                'recommended_albums': recommended_albums,
                'generated_at': datetime.utcnow(),
                'expires_at': datetime.utcnow() + timedelta(days=7),
                'algorithm_version': algorithm_version,
                'version': 1
            }
            result = self.db.recommendations.update_one(
                {'user_id': user_id},
                {'$set': recommendation},
                upsert=True
            )
            logger.info(f"Recommendations saved for user {user_id}")
            return True
        except Exception as e:
            logger.error(f"Error saving recommendations: {e}")
            raise
    def get_recommendations(self, user_id):
        """Get recommendations for a user"""
        try:
            recommendation = self.db.recommendations.find_one({'user_id': user_id})
            if recommendation:
                if recommendation.get('expires_at') and recommendation['expires_at'] < datetime.utcnow():
                    logger.info(f"Recommendations expired for user {user_id}")
                    return None
                recommendation['_id'] = str(recommendation['_id'])
                return recommendation
            return None
        except Exception as e:
            logger.error(f"Error getting recommendations: {e}")
            raise
    def generate_recommendations(self, user_id, album_data):
        """Generate recommendations based on user activity and album data"""
        try:
            history = self.get_most_played_albums(user_id, limit=5)
            if not history:
                recommended = [
                    {'album_id': album['album_id'], 'score': 0.8, 'reason': 'Popular album'}
                    for album in album_data[:10]
                ]
            else:
                played_album_ids = [h['album_id'] for h in history]
                recommended = []
                for album in album_data:
                    if album['album_id'] not in played_album_ids:
                        score = 0.7
                        reason = 'Recommended for you'
                        recommended.append({
                            'album_id': album['album_id'],
                            'score': score,
                            'reason': reason
                        })
                recommended = sorted(recommended, key=lambda x: x['score'], reverse=True)[:10]
            self.save_recommendations(user_id, recommended)
            return recommended
        except Exception as e:
            logger.error(f"Error generating recommendations: {e}")
            raise
    def save_user_preferences(self, user_id, preferences):
        """Save or update user preferences"""
        try:
            pref_doc = {
                'user_id': user_id,
                'updated_at': datetime.utcnow(),
                'version': 1
            }
            pref_doc.update(preferences)
            result = self.db.user_preferences.update_one(
                {'user_id': user_id},
                {'$set': pref_doc},
                upsert=True
            )
            logger.info(f"Preferences saved for user {user_id}")
            return True
        except Exception as e:
            logger.error(f"Error saving preferences: {e}")
            raise
    def get_user_preferences(self, user_id):
        """Get user preferences"""
        try:
            preferences = self.db.user_preferences.find_one({'user_id': user_id})
            if preferences:
                preferences['_id'] = str(preferences['_id'])
                return preferences
            return {
                'user_id': user_id,
                'favorite_genres': [],
                'favorite_artists': [],
                'notification_settings': {
                    'email_notifications': True,
                    'new_releases': True,
                    'recommendations': True
                },
                'privacy_settings': {
                    'public_profile': True,
                    'show_listening_history': True
                }
            }
        except Exception as e:
            logger.error(f"Error getting preferences: {e}")
            raise
    def multi_document_transaction_example(self, user_id, album_id):
        """Example of multi-document transaction in MongoDB"""
        with self.start_session() as session:
            try:
                with session.start_transaction():
                    self.db.user_activity.insert_one(
                        {
                            'user_id': user_id,
                            'activity_type': 'play',
                            'album_id': album_id,
                            'timestamp': datetime.utcnow(),
                            'version': 1
                        },
                        session=session
                    )
                    self.db.listening_history.insert_one(
                        {
                            'user_id': user_id,
                            'album_id': album_id,
                            'started_at': datetime.utcnow(),
                            'completed': False,
                            'version': 1
                        },
                        session=session
                    )
                    logger.info(f"Multi-document transaction completed for user {user_id}")
                    return True
            except Exception as e:
                logger.error(f"Transaction failed: {e}")
                raise
    def close(self):
        """Close MongoDB connection"""
        if self.client:
            self.client.close()
            logger.info("MongoDB connection closed")
mongo_db = None
def init_mongo(config=None):
    """Initialize MongoDB connection"""
    global mongo_db
    mongo_db = MongoDB(config)
    return mongo_db
def get_mongo():
    """Get MongoDB instance"""
    global mongo_db
    if mongo_db is None:
        mongo_db = init_mongo()
    return mongo_db
