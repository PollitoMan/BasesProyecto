
\c music_reviews;

DROP USER IF EXISTS admin_user;
CREATE USER admin_user WITH SUPERUSER PASSWORD 'admin123';

DROP USER IF EXISTS app_user;
CREATE USER app_user WITH PASSWORD '123';

DROP USER IF EXISTS readonly_user;
CREATE USER readonly_user WITH PASSWORD '123';

GRANT ALL PRIVILEGES ON DATABASE music_reviews TO admin_user;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_user;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO admin_user;

GRANT CONNECT ON DATABASE music_reviews TO app_user;

GRANT USAGE ON SCHEMA public TO app_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE user_roles TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE artists TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE albums TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE tracks TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reviews TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE track_ratings TO app_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO app_user;

GRANT EXECUTE ON FUNCTION update_review_with_lock(INTEGER, INTEGER, TEXT, INTEGER) TO app_user;
GRANT EXECUTE ON FUNCTION get_album_avg_rating(INTEGER) TO app_user;
GRANT EXECUTE ON FUNCTION update_timestamp() TO app_user;

GRANT SELECT ON album_details TO app_user;
GRANT SELECT ON user_review_history TO app_user;

GRANT CONNECT ON DATABASE music_reviews TO readonly_user;

GRANT USAGE ON SCHEMA public TO readonly_user;

GRANT SELECT ON TABLE users TO readonly_user;
GRANT SELECT ON TABLE user_roles TO readonly_user;
GRANT SELECT ON TABLE artists TO readonly_user;
GRANT SELECT ON TABLE albums TO readonly_user;
GRANT SELECT ON TABLE tracks TO readonly_user;
GRANT SELECT ON TABLE reviews TO readonly_user;
GRANT SELECT ON TABLE track_ratings TO readonly_user;

GRANT SELECT ON album_details TO readonly_user;
GRANT SELECT ON user_review_history TO readonly_user;

GRANT EXECUTE ON FUNCTION get_album_avg_rating(INTEGER) TO readonly_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO admin_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

REVOKE ALL ON DATABASE music_reviews FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO PUBLIC;

SELECT 
    grantee,
    table_schema,
    table_name,
    string_agg(privilege_type, ', ') as privileges
FROM information_schema.table_privileges
WHERE table_schema = 'public'
GROUP BY grantee, table_schema, table_name
ORDER BY grantee, table_name;

\du

COMMENT ON ROLE admin_user IS 'Administrator with full database access';
COMMENT ON ROLE app_user IS 'Application user with CRUD privileges';
COMMENT ON ROLE readonly_user IS 'Read-only user for reporting and analytics';
