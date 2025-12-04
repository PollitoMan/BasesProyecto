

db = db.getSiblingDB('music_reviews');

db.user_activity.drop();
db.listening_history.drop();
db.recommendations.drop();
db.user_preferences.drop();

db.createCollection('user_activity', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['user_id', 'activity_type', 'timestamp'],
            properties: {
                user_id: {
                    bsonType: 'int',
                    description: 'User ID from PostgreSQL - required'
                },
                activity_type: {
                    enum: ['play', 'search', 'click', 'review', 'like', 'share'],
                    description: 'Type of activity - required'
                },
                album_id: {
                    bsonType: 'int',
                    description: 'Album ID if applicable'
                },
                track_id: {
                    bsonType: 'int',
                    description: 'Track ID if applicable'
                },
                search_query: {
                    bsonType: 'string',
                    description: 'Search query if activity_type is search'
                },
                metadata: {
                    bsonType: 'object',
                    description: 'Additional activity metadata'
                },
                timestamp: {
                    bsonType: 'date',
                    description: 'Activity timestamp - required'
                },
                version: {
                    bsonType: 'int',
                    description: 'Document version for optimistic locking'
                }
            }
        }
    }
});

db.createCollection('listening_history', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['user_id', 'album_id', 'started_at'],
            properties: {
                user_id: {
                    bsonType: 'int',
                    description: 'User ID - required'
                },
                album_id: {
                    bsonType: 'int',
                    description: 'Album ID - required'
                },
                track_id: {
                    bsonType: 'int',
                    description: 'Track ID if specific track'
                },
                started_at: {
                    bsonType: 'date',
                    description: 'Session start time - required'
                },
                ended_at: {
                    bsonType: 'date',
                    description: 'Session end time'
                },
                duration_seconds: {
                    bsonType: 'int',
                    minimum: 0,
                    description: 'Total listening duration'
                },
                completed: {
                    bsonType: 'bool',
                    description: 'Whether the album/track was fully played'
                },
                device_info: {
                    bsonType: 'object',
                    properties: {
                        device_type: { bsonType: 'string' },
                        browser: { bsonType: 'string' },
                        os: { bsonType: 'string' }
                    }
                },
                version: {
                    bsonType: 'int',
                    description: 'Document version for optimistic locking'
                }
            }
        }
    }
});

db.createCollection('recommendations', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['user_id', 'recommended_albums', 'generated_at'],
            properties: {
                user_id: {
                    bsonType: 'int',
                    description: 'User ID - required'
                },
                recommended_albums: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'object',
                        required: ['album_id', 'score'],
                        properties: {
                            album_id: { bsonType: 'int' },
                            score: { 
                                bsonType: 'double',
                                minimum: 0,
                                maximum: 1
                            },
                            reason: { bsonType: 'string' }
                        }
                    },
                    description: 'List of recommended albums - required'
                },
                generated_at: {
                    bsonType: 'date',
                    description: 'Recommendation generation timestamp - required'
                },
                algorithm_version: {
                    bsonType: 'string',
                    description: 'Version of recommendation algorithm used'
                },
                expires_at: {
                    bsonType: 'date',
                    description: 'When recommendations should be refreshed'
                },
                version: {
                    bsonType: 'int',
                    description: 'Document version for optimistic locking'
                }
            }
        }
    }
});

db.createCollection('user_preferences', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['user_id'],
            properties: {
                user_id: {
                    bsonType: 'int',
                    description: 'User ID - required'
                },
                favorite_genres: {
                    bsonType: 'array',
                    items: { bsonType: 'string' },
                    description: 'List of favorite music genres'
                },
                favorite_artists: {
                    bsonType: 'array',
                    items: { bsonType: 'int' },
                    description: 'List of favorite artist IDs'
                },
                notification_settings: {
                    bsonType: 'object',
                    properties: {
                        email_notifications: { bsonType: 'bool' },
                        new_releases: { bsonType: 'bool' },
                        recommendations: { bsonType: 'bool' }
                    }
                },
                privacy_settings: {
                    bsonType: 'object',
                    properties: {
                        public_profile: { bsonType: 'bool' },
                        show_listening_history: { bsonType: 'bool' }
                    }
                },
                updated_at: {
                    bsonType: 'date',
                    description: 'Last update timestamp'
                },
                version: {
                    bsonType: 'int',
                    description: 'Document version for optimistic locking'
                }
            }
        }
    }
});

db.user_activity.createIndex({ user_id: 1, timestamp: -1 });
db.user_activity.createIndex({ activity_type: 1 });
db.user_activity.createIndex({ album_id: 1 });
db.user_activity.createIndex({ timestamp: -1 });

db.listening_history.createIndex({ user_id: 1, started_at: -1 });
db.listening_history.createIndex({ album_id: 1 });
db.listening_history.createIndex({ started_at: -1 });

db.recommendations.createIndex({ user_id: 1 }, { unique: true });
db.recommendations.createIndex({ generated_at: -1 });
db.recommendations.createIndex({ expires_at: 1 });

db.user_preferences.createIndex({ user_id: 1 }, { unique: true });

db.user_activity.insertMany([
    {
        user_id: 2,
        activity_type: 'play',
        album_id: 1,
        track_id: 1,
        timestamp: new Date('2024-12-01T10:30:00Z'),
        metadata: { duration_played: 259 },
        version: 1
    },
    {
        user_id: 2,
        activity_type: 'search',
        search_query: 'Pink Floyd',
        timestamp: new Date('2024-12-01T11:00:00Z'),
        version: 1
    },
    {
        user_id: 3,
        activity_type: 'review',
        album_id: 1,
        timestamp: new Date('2024-12-01T12:00:00Z'),
        metadata: { rating: 5 },
        version: 1
    },
    {
        user_id: 2,
        activity_type: 'play',
        album_id: 3,
        track_id: 5,
        timestamp: new Date('2024-12-01T14:30:00Z'),
        metadata: { duration_played: 180 },
        version: 1
    }
]);

db.listening_history.insertMany([
    {
        user_id: 2,
        album_id: 1,
        track_id: 1,
        started_at: new Date('2024-12-01T10:30:00Z'),
        ended_at: new Date('2024-12-01T10:34:19Z'),
        duration_seconds: 259,
        completed: true,
        device_info: {
            device_type: 'desktop',
            browser: 'Chrome',
            os: 'Windows 11'
        },
        version: 1
    },
    {
        user_id: 3,
        album_id: 5,
        started_at: new Date('2024-12-01T15:00:00Z'),
        ended_at: new Date('2024-12-01T15:45:00Z'),
        duration_seconds: 2700,
        completed: true,
        device_info: {
            device_type: 'mobile',
            browser: 'Safari',
            os: 'iOS'
        },
        version: 1
    }
]);

db.recommendations.insertMany([
    {
        user_id: 2,
        recommended_albums: [
            { album_id: 2, score: 0.95, reason: 'Similar to Abbey Road' },
            { album_id: 4, score: 0.88, reason: 'Based on your Pink Floyd listening' },
            { album_id: 7, score: 0.82, reason: 'Popular in Rock genre' }
        ],
        generated_at: new Date('2024-12-01T00:00:00Z'),
        algorithm_version: 'v1.0',
        expires_at: new Date('2024-12-08T00:00:00Z'),
        version: 1
    },
    {
        user_id: 3,
        recommended_albums: [
            { album_id: 6, score: 0.92, reason: 'Based on your Electronic preferences' },
            { album_id: 9, score: 0.85, reason: 'Trending in Hip Hop' },
            { album_id: 1, score: 0.80, reason: 'Highly rated classic' }
        ],
        generated_at: new Date('2024-12-01T00:00:00Z'),
        algorithm_version: 'v1.0',
        expires_at: new Date('2024-12-08T00:00:00Z'),
        version: 1
    }
]);

db.user_preferences.insertMany([
    {
        user_id: 2,
        favorite_genres: ['Rock', 'Progressive Rock', 'Classic Rock'],
        favorite_artists: [1, 2],
        notification_settings: {
            email_notifications: true,
            new_releases: true,
            recommendations: true
        },
        privacy_settings: {
            public_profile: true,
            show_listening_history: true
        },
        updated_at: new Date('2024-12-01T00:00:00Z'),
        version: 1
    },
    {
        user_id: 3,
        favorite_genres: ['Electronic', 'Hip Hop'],
        favorite_artists: [3, 5],
        notification_settings: {
            email_notifications: true,
            new_releases: false,
            recommendations: true
        },
        privacy_settings: {
            public_profile: false,
            show_listening_history: false
        },
        updated_at: new Date('2024-12-01T00:00:00Z'),
        version: 1
    }
]);

print('MongoDB database initialized successfully!');
print('Collections created:');
print('  - user_activity');
print('  - listening_history');
print('  - recommendations');
print('  - user_preferences');
print('\nIndexes created for optimal query performance.');
print('Sample data inserted for testing.');

