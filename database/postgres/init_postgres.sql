
\restrict INezlUfS7CPvSkgWKf7jQCptCMSSOo5ZsZ6D3APBxNAjljySbful30qNgQvW0fp

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.user_roles DROP CONSTRAINT IF EXISTS user_roles_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.tracks DROP CONSTRAINT IF EXISTS tracks_artist_id_fkey;
ALTER TABLE IF EXISTS ONLY public.tracks DROP CONSTRAINT IF EXISTS tracks_album_id_fkey;
ALTER TABLE IF EXISTS ONLY public.track_ratings DROP CONSTRAINT IF EXISTS track_ratings_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.track_ratings DROP CONSTRAINT IF EXISTS track_ratings_track_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reviews DROP CONSTRAINT IF EXISTS reviews_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reviews DROP CONSTRAINT IF EXISTS reviews_album_id_fkey;
ALTER TABLE IF EXISTS ONLY public.albums DROP CONSTRAINT IF EXISTS albums_artist_id_fkey;
DROP TRIGGER IF EXISTS track_rating_update_timestamp ON public.track_ratings;
DROP TRIGGER IF EXISTS review_update_timestamp ON public.reviews;
DROP INDEX IF EXISTS public.idx_users_username;
DROP INDEX IF EXISTS public.idx_users_email;
DROP INDEX IF EXISTS public.idx_tracks_artist;
DROP INDEX IF EXISTS public.idx_tracks_album;
DROP INDEX IF EXISTS public.idx_track_ratings_track;
DROP INDEX IF EXISTS public.idx_reviews_user;
DROP INDEX IF EXISTS public.idx_reviews_album;
DROP INDEX IF EXISTS public.idx_artists_name;
DROP INDEX IF EXISTS public.idx_albums_title;
DROP INDEX IF EXISTS public.idx_albums_artist;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_username_key;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_email_key;
ALTER TABLE IF EXISTS ONLY public.user_roles DROP CONSTRAINT IF EXISTS user_roles_pkey;
ALTER TABLE IF EXISTS ONLY public.tracks DROP CONSTRAINT IF EXISTS tracks_pkey;
ALTER TABLE IF EXISTS ONLY public.track_ratings DROP CONSTRAINT IF EXISTS track_ratings_user_id_track_id_key;
ALTER TABLE IF EXISTS ONLY public.track_ratings DROP CONSTRAINT IF EXISTS track_ratings_pkey;
ALTER TABLE IF EXISTS ONLY public.reviews DROP CONSTRAINT IF EXISTS reviews_user_id_album_id_key;
ALTER TABLE IF EXISTS ONLY public.reviews DROP CONSTRAINT IF EXISTS reviews_pkey;
ALTER TABLE IF EXISTS ONLY public.artists DROP CONSTRAINT IF EXISTS artists_pkey;
ALTER TABLE IF EXISTS ONLY public.artists DROP CONSTRAINT IF EXISTS artists_artist_name_key;
ALTER TABLE IF EXISTS ONLY public.albums DROP CONSTRAINT IF EXISTS albums_pkey;
ALTER TABLE IF EXISTS public.users ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.user_roles ALTER COLUMN role_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.tracks ALTER COLUMN track_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.track_ratings ALTER COLUMN rating_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.reviews ALTER COLUMN review_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.artists ALTER COLUMN artist_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.albums ALTER COLUMN album_id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.users_user_id_seq;
DROP SEQUENCE IF EXISTS public.user_roles_role_id_seq;
DROP TABLE IF EXISTS public.user_roles;
DROP VIEW IF EXISTS public.user_review_history;
DROP TABLE IF EXISTS public.users;
DROP SEQUENCE IF EXISTS public.tracks_track_id_seq;
DROP SEQUENCE IF EXISTS public.track_ratings_rating_id_seq;
DROP SEQUENCE IF EXISTS public.reviews_review_id_seq;
DROP SEQUENCE IF EXISTS public.artists_artist_id_seq;
DROP SEQUENCE IF EXISTS public.albums_album_id_seq;
DROP VIEW IF EXISTS public.album_details;
DROP TABLE IF EXISTS public.tracks;
DROP TABLE IF EXISTS public.track_ratings;
DROP TABLE IF EXISTS public.reviews;
DROP TABLE IF EXISTS public.artists;
DROP TABLE IF EXISTS public.albums;
DROP FUNCTION IF EXISTS public.update_timestamp();
DROP FUNCTION IF EXISTS public.update_review_with_lock(p_review_id integer, p_rating integer, p_review_text text, p_expected_version integer);
DROP FUNCTION IF EXISTS public.get_album_avg_rating(p_album_id integer);

COMMENT ON SCHEMA public IS '';

CREATE FUNCTION public.get_album_avg_rating(p_album_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$

DECLARE

    v_avg_rating NUMERIC;

BEGIN

    SELECT COALESCE(AVG(tr.rating), 0)

    INTO v_avg_rating

    FROM tracks t

    LEFT JOIN track_ratings tr ON tr.track_id = t.track_id

    WHERE t.album_id = p_album_id;

    RETURN ROUND(v_avg_rating, 2);

END;

$$;

CREATE FUNCTION public.update_review_with_lock(p_review_id integer, p_rating integer, p_review_text text, p_expected_version integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

DECLARE

    v_current_version INTEGER;

BEGIN

    SELECT version INTO v_current_version

    FROM reviews

    WHERE review_id = p_review_id

    FOR UPDATE;

    IF v_current_version != p_expected_version THEN

        RAISE EXCEPTION 'Concurrency conflict: Review was modified by another user';

    END IF;

    UPDATE reviews

    SET rating = p_rating,

        review_text = p_review_text,

        updated_at = CURRENT_TIMESTAMP,

        version = version + 1

    WHERE review_id = p_review_id;

    RETURN TRUE;

END;

$$;

CREATE FUNCTION public.update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

BEGIN

    NEW.updated_at = CURRENT_TIMESTAMP;

    RETURN NEW;

END;

$$;

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE public.albums (
    album_id integer NOT NULL,
    artist_id integer,
    album_title character varying(150) NOT NULL,
    release_date date,
    genre character varying(50),
    cover_url character varying(255),
    total_tracks integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    version integer DEFAULT 1,
    CONSTRAINT positive_tracks CHECK ((total_tracks > 0))
);

CREATE TABLE public.artists (
    artist_id integer NOT NULL,
    artist_name character varying(150) NOT NULL,
    country character varying(80),
    genre character varying(80),
    bio text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.reviews (
    review_id integer NOT NULL,
    user_id integer,
    album_id integer,
    rating integer,
    review_text text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    version integer DEFAULT 1,
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);

CREATE TABLE public.track_ratings (
    rating_id integer NOT NULL,
    user_id integer,
    track_id integer,
    rating integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    version integer DEFAULT 1,
    CONSTRAINT track_ratings_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);

CREATE TABLE public.tracks (
    track_id integer NOT NULL,
    album_id integer,
    artist_id integer,
    track_number integer,
    track_title character varying(150) NOT NULL,
    duration_seconds integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT positive_duration CHECK ((duration_seconds > 0))
);

CREATE VIEW public.album_details AS
 SELECT a.album_id,
    a.album_title,
    a.release_date,
    a.genre,
    a.cover_url,
    a.total_tracks,
    COALESCE(ar.artist_name, '-'::character varying) AS artist_name,
    ar.country,
    COALESCE(ratings.avg_rating, (0)::numeric) AS avg_rating,
    COALESCE(ratings.rating_count, (0)::bigint) AS rating_count,
    COALESCE(comments.review_count, (0)::bigint) AS review_count
   FROM (((public.albums a
     LEFT JOIN public.artists ar ON ((a.artist_id = ar.artist_id)))
     LEFT JOIN ( SELECT t.album_id,
            round(avg(tr.rating), 2) AS avg_rating,
            count(tr.rating_id) AS rating_count
           FROM (public.tracks t
             LEFT JOIN public.track_ratings tr ON ((tr.track_id = t.track_id)))
          GROUP BY t.album_id) ratings ON ((ratings.album_id = a.album_id)))
     LEFT JOIN ( SELECT reviews.album_id,
            count(reviews.review_id) AS review_count
           FROM public.reviews
          GROUP BY reviews.album_id) comments ON ((comments.album_id = a.album_id)));

CREATE SEQUENCE public.albums_album_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.albums_album_id_seq OWNED BY public.albums.album_id;

CREATE SEQUENCE public.artists_artist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.artists_artist_id_seq OWNED BY public.artists.artist_id;

CREATE SEQUENCE public.reviews_review_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.reviews_review_id_seq OWNED BY public.reviews.review_id;

CREATE SEQUENCE public.track_ratings_rating_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.track_ratings_rating_id_seq OWNED BY public.track_ratings.rating_id;

CREATE SEQUENCE public.tracks_track_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.tracks_track_id_seq OWNED BY public.tracks.track_id;

CREATE TABLE public.users (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(120) NOT NULL,
    password_hash character varying(255) NOT NULL,
    full_name character varying(120),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_login timestamp without time zone,
    is_active boolean DEFAULT true
);

CREATE VIEW public.user_review_history AS
 SELECT COALESCE(u.username, '-'::character varying) AS username,
    u.full_name,
    COALESCE(a.album_title, '-'::character varying) AS album_title,
    COALESCE(ar.artist_name, '-'::character varying) AS artist_name,
    r.rating,
    r.review_text,
    r.created_at,
    r.updated_at
   FROM (((public.reviews r
     LEFT JOIN public.users u ON ((r.user_id = u.user_id)))
     LEFT JOIN public.albums a ON ((r.album_id = a.album_id)))
     LEFT JOIN public.artists ar ON ((a.artist_id = ar.artist_id)))
  ORDER BY r.created_at DESC;

CREATE TABLE public.user_roles (
    role_id integer NOT NULL,
    user_id integer,
    role_name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE SEQUENCE public.user_roles_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.user_roles_role_id_seq OWNED BY public.user_roles.role_id;

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;

ALTER TABLE ONLY public.albums ALTER COLUMN album_id SET DEFAULT nextval('public.albums_album_id_seq'::regclass);

ALTER TABLE ONLY public.artists ALTER COLUMN artist_id SET DEFAULT nextval('public.artists_artist_id_seq'::regclass);

ALTER TABLE ONLY public.reviews ALTER COLUMN review_id SET DEFAULT nextval('public.reviews_review_id_seq'::regclass);

ALTER TABLE ONLY public.track_ratings ALTER COLUMN rating_id SET DEFAULT nextval('public.track_ratings_rating_id_seq'::regclass);

ALTER TABLE ONLY public.tracks ALTER COLUMN track_id SET DEFAULT nextval('public.tracks_track_id_seq'::regclass);

ALTER TABLE ONLY public.user_roles ALTER COLUMN role_id SET DEFAULT nextval('public.user_roles_role_id_seq'::regclass);

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);

INSERT INTO public.albums VALUES (1, 8, 'DATA', '2023-01-01', NULL, NULL, 20, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (2, 1, 'DeB+ì TiRAR M+iS FOToS', '2025-01-01', NULL, NULL, 17, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (3, 1, 'Nadie Sabe Lo Que Va A Pasar Ma+¦ana', '2023-01-01', NULL, NULL, 22, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (4, 1, 'YHLQMDLG', '2020-01-01', NULL, NULL, 20, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (5, 1, 'X 100PRE', '2018-01-01', NULL, NULL, 15, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (6, 1, 'Un Verano Sin Ti', '2022-01-01', NULL, NULL, 23, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (7, 2, 'FX De La Rose', '2025-01-01', NULL, NULL, 17, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (8, 9, 'Midnights', '2022-01-01', NULL, NULL, 13, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (9, 9, '1989 (Taylor''s Version)', '2023-01-01', NULL, NULL, 22, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (10, 7, 'Short n'' Sweet', '2024-01-01', NULL, NULL, 17, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (11, 6, 'Cosa Nuestra', '2025-01-01', NULL, NULL, 18, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (12, 6, 'Vice Versa', '2021-01-01', NULL, NULL, 14, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (13, 5, 'Buenas Noches', '2024-01-01', NULL, NULL, 18, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (14, 5, 'Donde Quiero Estar', '2023-01-01', NULL, NULL, 16, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (15, 4, 'NAIKI', '2024-01-01', NULL, NULL, 9, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (16, 3, 'Lo Mismo De Siempre', '2025-01-01', NULL, NULL, 17, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (17, 3, 'Estrella', '2023-01-01', NULL, NULL, 15, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (18, 3, 'Para+¡so', '2022-01-01', NULL, NULL, 13, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (19, 3, 'Microdosis', '2022-01-01', NULL, NULL, 15, '2025-12-04 07:12:18.954956', 1);
INSERT INTO public.albums VALUES (20, 3, 'Primer D+¡a de Clases', '2021-01-01', NULL, NULL, 16, '2025-12-04 07:12:18.954956', 1);

INSERT INTO public.artists VALUES (1, 'Bad Bunny', NULL, NULL, NULL, '2025-12-04 07:05:29.644736');
INSERT INTO public.artists VALUES (2, 'De La Rose', NULL, NULL, NULL, '2025-12-04 07:05:29.646359');
INSERT INTO public.artists VALUES (3, 'Mora', NULL, NULL, NULL, '2025-12-04 07:05:29.647062');
INSERT INTO public.artists VALUES (4, 'Nicki Nicole', NULL, NULL, NULL, '2025-12-04 07:05:29.649029');
INSERT INTO public.artists VALUES (5, 'Quevedo', NULL, NULL, NULL, '2025-12-04 07:05:29.650362');
INSERT INTO public.artists VALUES (6, 'Rauw Alejandro', NULL, NULL, NULL, '2025-12-04 07:05:29.651191');
INSERT INTO public.artists VALUES (7, 'Sabrina Carpenter', NULL, NULL, NULL, '2025-12-04 07:05:29.65187');
INSERT INTO public.artists VALUES (8, 'Tainy', NULL, NULL, NULL, '2025-12-04 07:05:29.6525');
INSERT INTO public.artists VALUES (9, 'Taylor Swift', NULL, NULL, NULL, '2025-12-04 07:05:29.653034');

INSERT INTO public.reviews VALUES (1, 2, 1, 3, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (2, 2, 2, 1, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (3, 2, 3, 5, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (4, 2, 6, 5, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (5, 2, 7, 3, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (6, 2, 9, 3, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (7, 2, 10, 5, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (8, 2, 11, 4, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (9, 2, 16, 3, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (10, 2, 19, 1, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (11, 3, 1, 5, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (12, 3, 2, 1, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (13, 3, 4, 3, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (14, 3, 6, 5, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (15, 3, 7, 4, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (16, 3, 8, 1, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (17, 3, 9, 5, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (18, 3, 10, 1, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (19, 3, 12, 2, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (20, 3, 13, 3, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (21, 3, 14, 4, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (22, 3, 15, 1, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (23, 3, 16, 5, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (24, 3, 17, 3, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (25, 3, 18, 2, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (26, 3, 20, 2, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (27, 4, 1, 5, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (28, 4, 3, 1, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (29, 4, 5, 1, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (30, 4, 6, 5, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (31, 4, 7, 2, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (32, 4, 8, 3, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (33, 4, 9, 3, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (34, 4, 10, 3, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (35, 4, 12, 3, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (36, 4, 13, 5, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (37, 4, 14, 5, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (38, 4, 15, 3, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (39, 4, 17, 2, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (40, 5, 3, 2, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (41, 5, 7, 5, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (42, 5, 8, 4, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (43, 5, 9, 5, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (44, 5, 10, 4, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (45, 5, 11, 3, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (46, 5, 12, 3, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (47, 5, 13, 3, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (48, 5, 15, 4, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (49, 5, 16, 2, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (50, 5, 17, 3, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (51, 5, 20, 1, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (52, 6, 1, 1, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (53, 6, 2, 3, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (54, 6, 4, 5, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (55, 6, 5, 5, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (56, 6, 7, 1, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (57, 6, 8, 2, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (58, 6, 9, 4, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (59, 6, 10, 5, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (60, 6, 14, 3, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (61, 6, 15, 3, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (62, 6, 16, 5, 'No me convencio del todo.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (63, 6, 17, 2, 'Increible produccion y letra.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (64, 6, 18, 1, 'Algunas canciones buenas, otras no tanto.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (65, 6, 19, 5, 'Excelente album, me encanto cada cancion.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);
INSERT INTO public.reviews VALUES (66, 6, 20, 1, 'Muy bueno, aunque esperaba mas.', '2025-12-04 07:12:31.684736', '2025-12-04 07:12:31.684736', 1);

INSERT INTO public.track_ratings VALUES (1686, 2, 338, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1687, 2, 339, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1688, 2, 340, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1689, 2, 341, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1690, 2, 342, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1691, 2, 343, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1692, 2, 344, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1693, 2, 345, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1694, 2, 346, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1695, 2, 347, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1696, 2, 348, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1697, 2, 349, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1698, 2, 350, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1699, 2, 351, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1700, 2, 352, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1701, 2, 353, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1702, 2, 354, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1703, 2, 355, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1704, 2, 356, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1705, 2, 357, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1706, 2, 358, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1707, 2, 359, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1708, 2, 360, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1709, 2, 361, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1710, 2, 362, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1711, 2, 363, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1712, 2, 364, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1713, 2, 365, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1714, 2, 366, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1715, 2, 367, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1716, 2, 368, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1717, 2, 369, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1718, 2, 370, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1719, 2, 371, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1720, 2, 372, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1721, 2, 373, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1722, 2, 374, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1723, 2, 375, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1724, 2, 376, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1725, 2, 377, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1726, 2, 378, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1727, 2, 379, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1728, 2, 380, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1729, 2, 381, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1730, 2, 382, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1731, 2, 383, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1732, 2, 384, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1733, 2, 385, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1734, 2, 386, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1735, 2, 387, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1736, 2, 388, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1737, 2, 389, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1738, 2, 390, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1739, 2, 391, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1740, 2, 392, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1741, 2, 393, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1742, 2, 394, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1743, 2, 395, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1744, 2, 396, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1745, 2, 397, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1746, 2, 398, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1747, 2, 399, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1748, 2, 400, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1749, 2, 401, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1750, 2, 402, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1751, 2, 403, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1752, 2, 404, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1753, 2, 405, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1754, 2, 406, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1755, 2, 407, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1756, 2, 408, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1757, 2, 409, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1758, 2, 410, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1759, 2, 411, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1760, 2, 412, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1761, 2, 413, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1762, 2, 414, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1763, 2, 415, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1764, 2, 416, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1765, 2, 417, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1766, 2, 418, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1767, 2, 419, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1768, 2, 420, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1769, 2, 421, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1770, 2, 422, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1771, 2, 423, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1772, 2, 424, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1773, 2, 425, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1774, 2, 426, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1775, 2, 427, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1776, 2, 428, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1777, 2, 429, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1778, 2, 430, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1779, 2, 431, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1780, 2, 432, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1781, 2, 433, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1782, 2, 434, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1783, 2, 435, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1784, 2, 436, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1785, 2, 437, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1786, 2, 438, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1787, 2, 439, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1788, 2, 440, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1789, 2, 441, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1790, 2, 442, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1791, 2, 443, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1792, 2, 444, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1793, 2, 445, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1794, 2, 446, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1795, 2, 447, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1796, 2, 448, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1797, 2, 449, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1798, 2, 450, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1799, 2, 451, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1800, 2, 452, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1801, 2, 453, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1802, 2, 454, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1803, 2, 455, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1804, 2, 456, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1805, 2, 457, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1806, 2, 458, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1807, 2, 459, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1808, 2, 460, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1809, 2, 461, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1810, 2, 462, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1811, 2, 463, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1812, 2, 464, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1813, 2, 465, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1814, 2, 466, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1815, 2, 467, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1816, 2, 468, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1817, 2, 469, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1818, 2, 470, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1819, 2, 471, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1820, 2, 472, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1821, 2, 473, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1822, 2, 474, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1823, 2, 475, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1824, 2, 476, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1825, 2, 477, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1826, 2, 478, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1827, 2, 479, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1828, 2, 480, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1829, 2, 481, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1830, 2, 482, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1831, 2, 483, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1832, 2, 484, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1833, 2, 485, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1834, 2, 486, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1835, 2, 487, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1836, 2, 488, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1837, 2, 489, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1838, 2, 490, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1839, 2, 491, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1840, 2, 492, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1841, 2, 493, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1842, 2, 494, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1843, 2, 495, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1844, 2, 496, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1845, 2, 497, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1846, 2, 498, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1847, 2, 499, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1848, 2, 500, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1849, 2, 501, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1850, 2, 502, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1851, 2, 503, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1852, 2, 504, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1853, 2, 505, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1854, 2, 506, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1855, 2, 507, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1856, 2, 508, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1857, 2, 509, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1858, 2, 510, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1859, 2, 511, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1860, 2, 512, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1861, 2, 513, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1862, 2, 514, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1863, 2, 515, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1864, 2, 516, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1865, 2, 517, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1866, 2, 518, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1867, 2, 519, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1868, 2, 520, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1869, 2, 521, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1870, 2, 522, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1871, 2, 523, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1872, 2, 524, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1873, 2, 525, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1874, 2, 526, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1875, 2, 527, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1876, 2, 528, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1877, 2, 529, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1878, 2, 530, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1879, 2, 531, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1880, 2, 532, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1881, 2, 533, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1882, 2, 534, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1883, 2, 535, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1884, 2, 536, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1885, 2, 537, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1886, 2, 538, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1887, 2, 539, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1888, 2, 540, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1889, 2, 541, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1890, 2, 542, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1891, 2, 543, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1892, 2, 544, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1893, 2, 545, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1894, 2, 546, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1895, 2, 547, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1896, 2, 548, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1897, 2, 549, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1898, 2, 550, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1899, 2, 551, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1900, 2, 552, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1901, 2, 553, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1902, 2, 554, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1903, 2, 555, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1904, 2, 556, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1905, 2, 557, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1906, 2, 558, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1907, 2, 559, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1908, 2, 560, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1909, 2, 561, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1910, 2, 562, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1911, 2, 563, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1912, 2, 564, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1913, 2, 565, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1914, 2, 566, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1915, 2, 567, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1916, 2, 568, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1917, 2, 569, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1918, 2, 570, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1919, 2, 571, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1920, 2, 572, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1921, 2, 573, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1922, 2, 574, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1923, 2, 575, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1924, 2, 576, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1925, 2, 577, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1926, 2, 578, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1927, 2, 579, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1928, 2, 580, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1929, 2, 581, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1930, 2, 582, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1931, 2, 583, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1932, 2, 584, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1933, 2, 585, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1934, 2, 586, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1935, 2, 587, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1936, 2, 588, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1937, 2, 589, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1938, 2, 590, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1939, 2, 591, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1940, 2, 592, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1941, 2, 593, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1942, 2, 594, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1943, 2, 595, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1944, 2, 596, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1945, 2, 597, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1946, 2, 598, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1947, 2, 599, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1948, 2, 600, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1949, 2, 601, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1950, 2, 602, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1951, 2, 603, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1952, 2, 604, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1953, 2, 605, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1954, 2, 606, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1955, 2, 607, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1956, 2, 608, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1957, 2, 609, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1958, 2, 610, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1959, 2, 611, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1960, 2, 612, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1961, 2, 613, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1962, 2, 614, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1963, 2, 615, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1964, 2, 616, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1965, 2, 617, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1966, 2, 618, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1967, 2, 619, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1968, 2, 620, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1969, 2, 621, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1970, 2, 622, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1971, 2, 623, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1972, 2, 624, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1973, 2, 625, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1974, 2, 626, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1975, 2, 627, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1976, 2, 628, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1977, 2, 629, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1978, 2, 630, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1979, 2, 631, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1980, 2, 632, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1981, 2, 633, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1982, 2, 634, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1983, 2, 635, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1984, 2, 636, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1985, 2, 637, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1986, 2, 638, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1987, 2, 639, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1988, 2, 640, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1989, 2, 641, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1990, 2, 642, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1991, 2, 643, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1992, 2, 644, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1993, 2, 645, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1994, 2, 646, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1995, 2, 647, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1996, 2, 648, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1997, 2, 649, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1998, 2, 650, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (1999, 2, 651, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2000, 2, 652, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2001, 2, 653, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2002, 2, 654, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2003, 2, 655, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2004, 2, 656, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2005, 2, 657, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2006, 2, 658, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2007, 2, 659, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2008, 2, 660, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2009, 2, 661, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2010, 2, 662, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2011, 2, 663, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2012, 2, 664, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2013, 2, 665, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2014, 2, 666, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2015, 2, 667, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2016, 2, 668, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2017, 2, 669, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2018, 2, 670, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2019, 2, 671, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2020, 2, 672, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2021, 2, 673, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2022, 2, 674, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2023, 3, 338, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2024, 3, 339, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2025, 3, 340, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2026, 3, 341, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2027, 3, 342, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2028, 3, 343, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2029, 3, 344, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2030, 3, 345, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2031, 3, 346, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2032, 3, 347, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2033, 3, 348, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2034, 3, 349, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2035, 3, 350, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2036, 3, 351, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2037, 3, 352, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2038, 3, 353, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2039, 3, 354, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2040, 3, 355, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2041, 3, 356, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2042, 3, 357, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2043, 3, 358, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2044, 3, 359, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2045, 3, 360, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2046, 3, 361, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2047, 3, 362, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2048, 3, 363, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2049, 3, 364, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2050, 3, 365, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2051, 3, 366, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2052, 3, 367, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2053, 3, 368, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2054, 3, 369, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2055, 3, 370, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2056, 3, 371, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2057, 3, 372, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2058, 3, 373, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2059, 3, 374, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2060, 3, 375, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2061, 3, 376, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2062, 3, 377, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2063, 3, 378, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2064, 3, 379, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2065, 3, 380, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2066, 3, 381, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2067, 3, 382, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2068, 3, 383, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2069, 3, 384, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2070, 3, 385, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2071, 3, 386, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2072, 3, 387, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2073, 3, 388, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2074, 3, 389, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2075, 3, 390, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2076, 3, 391, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2077, 3, 392, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2078, 3, 393, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2079, 3, 394, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2080, 3, 395, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2081, 3, 396, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2082, 3, 397, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2083, 3, 398, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2084, 3, 399, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2085, 3, 400, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2086, 3, 401, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2087, 3, 402, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2088, 3, 403, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2089, 3, 404, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2090, 3, 405, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2091, 3, 406, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2092, 3, 407, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2093, 3, 408, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2094, 3, 409, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2095, 3, 410, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2096, 3, 411, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2097, 3, 412, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2098, 3, 413, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2099, 3, 414, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2100, 3, 415, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2101, 3, 416, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2102, 3, 417, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2103, 3, 418, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2104, 3, 419, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2105, 3, 420, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2106, 3, 421, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2107, 3, 422, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2108, 3, 423, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2109, 3, 424, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2110, 3, 425, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2111, 3, 426, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2112, 3, 427, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2113, 3, 428, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2114, 3, 429, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2115, 3, 430, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2116, 3, 431, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2117, 3, 432, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2118, 3, 433, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2119, 3, 434, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2120, 3, 435, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2121, 3, 436, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2122, 3, 437, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2123, 3, 438, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2124, 3, 439, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2125, 3, 440, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2126, 3, 441, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2127, 3, 442, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2128, 3, 443, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2129, 3, 444, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2130, 3, 445, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2131, 3, 446, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2132, 3, 447, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2133, 3, 448, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2134, 3, 449, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2135, 3, 450, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2136, 3, 451, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2137, 3, 452, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2138, 3, 453, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2139, 3, 454, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2140, 3, 455, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2141, 3, 456, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2142, 3, 457, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2143, 3, 458, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2144, 3, 459, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2145, 3, 460, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2146, 3, 461, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2147, 3, 462, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2148, 3, 463, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2149, 3, 464, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2150, 3, 465, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2151, 3, 466, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2152, 3, 467, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2153, 3, 468, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2154, 3, 469, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2155, 3, 470, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2156, 3, 471, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2157, 3, 472, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2158, 3, 473, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2159, 3, 474, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2160, 3, 475, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2161, 3, 476, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2162, 3, 477, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2163, 3, 478, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2164, 3, 479, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2165, 3, 480, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2166, 3, 481, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2167, 3, 482, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2168, 3, 483, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2169, 3, 484, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2170, 3, 485, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2171, 3, 486, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2172, 3, 487, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2173, 3, 488, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2174, 3, 489, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2175, 3, 490, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2176, 3, 491, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2177, 3, 492, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2178, 3, 493, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2179, 3, 494, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2180, 3, 495, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2181, 3, 496, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2182, 3, 497, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2183, 3, 498, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2184, 3, 499, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2185, 3, 500, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2186, 3, 501, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2187, 3, 502, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2188, 3, 503, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2189, 3, 504, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2190, 3, 505, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2191, 3, 506, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2192, 3, 507, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2193, 3, 508, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2194, 3, 509, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2195, 3, 510, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2196, 3, 511, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2197, 3, 512, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2198, 3, 513, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2199, 3, 514, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2200, 3, 515, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2201, 3, 516, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2202, 3, 517, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2203, 3, 518, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2204, 3, 519, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2205, 3, 520, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2206, 3, 521, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2207, 3, 522, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2208, 3, 523, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2209, 3, 524, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2210, 3, 525, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2211, 3, 526, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2212, 3, 527, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2213, 3, 528, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2214, 3, 529, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2215, 3, 530, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2216, 3, 531, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2217, 3, 532, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2218, 3, 533, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2219, 3, 534, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2220, 3, 535, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2221, 3, 536, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2222, 3, 537, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2223, 3, 538, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2224, 3, 539, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2225, 3, 540, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2226, 3, 541, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2227, 3, 542, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2228, 3, 543, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2229, 3, 544, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2230, 3, 545, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2231, 3, 546, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2232, 3, 547, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2233, 3, 548, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2234, 3, 549, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2235, 3, 550, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2236, 3, 551, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2237, 3, 552, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2238, 3, 553, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2239, 3, 554, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2240, 3, 555, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2241, 3, 556, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2242, 3, 557, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2243, 3, 558, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2244, 3, 559, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2245, 3, 560, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2246, 3, 561, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2247, 3, 562, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2248, 3, 563, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2249, 3, 564, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2250, 3, 565, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2251, 3, 566, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2252, 3, 567, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2253, 3, 568, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2254, 3, 569, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2255, 3, 570, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2256, 3, 571, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2257, 3, 572, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2258, 3, 573, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2259, 3, 574, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2260, 3, 575, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2261, 3, 576, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2262, 3, 577, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2263, 3, 578, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2264, 3, 579, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2265, 3, 580, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2266, 3, 581, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2267, 3, 582, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2268, 3, 583, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2269, 3, 584, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2270, 3, 585, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2271, 3, 586, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2272, 3, 587, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2273, 3, 588, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2274, 3, 589, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2275, 3, 590, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2276, 3, 591, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2277, 3, 592, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2278, 3, 593, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2279, 3, 594, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2280, 3, 595, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2281, 3, 596, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2282, 3, 597, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2283, 3, 598, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2284, 3, 599, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2285, 3, 600, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2286, 3, 601, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2287, 3, 602, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2288, 3, 603, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2289, 3, 604, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2290, 3, 605, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2291, 3, 606, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2292, 3, 607, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2293, 3, 608, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2294, 3, 609, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2295, 3, 610, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2296, 3, 611, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2297, 3, 612, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2298, 3, 613, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2299, 3, 614, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2300, 3, 615, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2301, 3, 616, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2302, 3, 617, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2303, 3, 618, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2304, 3, 619, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2305, 3, 620, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2306, 3, 621, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2307, 3, 622, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2308, 3, 623, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2309, 3, 624, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2310, 3, 625, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2311, 3, 626, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2312, 3, 627, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2313, 3, 628, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2314, 3, 629, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2315, 3, 630, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2316, 3, 631, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2317, 3, 632, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2318, 3, 633, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2319, 3, 634, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2320, 3, 635, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2321, 3, 636, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2322, 3, 637, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2323, 3, 638, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2324, 3, 639, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2325, 3, 640, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2326, 3, 641, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2327, 3, 642, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2328, 3, 643, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2329, 3, 644, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2330, 3, 645, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2331, 3, 646, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2332, 3, 647, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2333, 3, 648, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2334, 3, 649, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2335, 3, 650, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2336, 3, 651, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2337, 3, 652, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2338, 3, 653, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2339, 3, 654, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2340, 3, 655, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2341, 3, 656, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2342, 3, 657, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2343, 3, 658, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2344, 3, 659, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2345, 3, 660, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2346, 3, 661, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2347, 3, 662, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2348, 3, 663, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2349, 3, 664, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2350, 3, 665, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2351, 3, 666, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2352, 3, 667, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2353, 3, 668, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2354, 3, 669, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2355, 3, 670, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2356, 3, 671, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2357, 3, 672, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2358, 3, 673, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2359, 3, 674, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2360, 4, 338, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2361, 4, 339, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2362, 4, 340, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2363, 4, 341, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2364, 4, 342, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2365, 4, 343, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2366, 4, 344, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2367, 4, 345, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2368, 4, 346, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2369, 4, 347, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2370, 4, 348, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2371, 4, 349, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2372, 4, 350, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2373, 4, 351, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2374, 4, 352, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2375, 4, 353, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2376, 4, 354, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2377, 4, 355, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2378, 4, 356, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2379, 4, 357, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2380, 4, 358, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2381, 4, 359, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2382, 4, 360, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2383, 4, 361, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2384, 4, 362, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2385, 4, 363, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2386, 4, 364, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2387, 4, 365, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2388, 4, 366, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2389, 4, 367, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2390, 4, 368, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2391, 4, 369, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2392, 4, 370, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2393, 4, 371, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2394, 4, 372, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2395, 4, 373, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2396, 4, 374, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2397, 4, 375, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2398, 4, 376, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2399, 4, 377, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2400, 4, 378, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2401, 4, 379, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2402, 4, 380, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2403, 4, 381, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2404, 4, 382, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2405, 4, 383, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2406, 4, 384, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2407, 4, 385, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2408, 4, 386, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2409, 4, 387, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2410, 4, 388, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2411, 4, 389, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2412, 4, 390, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2413, 4, 391, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2414, 4, 392, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2415, 4, 393, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2416, 4, 394, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2417, 4, 395, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2418, 4, 396, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2419, 4, 397, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2420, 4, 398, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2421, 4, 399, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2422, 4, 400, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2423, 4, 401, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2424, 4, 402, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2425, 4, 403, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2426, 4, 404, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2427, 4, 405, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2428, 4, 406, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2429, 4, 407, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2430, 4, 408, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2431, 4, 409, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2432, 4, 410, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2433, 4, 411, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2434, 4, 412, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2435, 4, 413, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2436, 4, 414, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2437, 4, 415, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2438, 4, 416, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2439, 4, 417, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2440, 4, 418, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2441, 4, 419, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2442, 4, 420, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2443, 4, 421, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2444, 4, 422, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2445, 4, 423, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2446, 4, 424, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2447, 4, 425, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2448, 4, 426, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2449, 4, 427, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2450, 4, 428, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2451, 4, 429, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2452, 4, 430, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2453, 4, 431, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2454, 4, 432, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2455, 4, 433, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2456, 4, 434, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2457, 4, 435, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2458, 4, 436, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2459, 4, 437, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2460, 4, 438, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2461, 4, 439, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2462, 4, 440, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2463, 4, 441, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2464, 4, 442, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2465, 4, 443, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2466, 4, 444, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2467, 4, 445, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2468, 4, 446, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2469, 4, 447, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2470, 4, 448, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2471, 4, 449, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2472, 4, 450, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2473, 4, 451, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2474, 4, 452, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2475, 4, 453, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2476, 4, 454, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2477, 4, 455, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2478, 4, 456, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2479, 4, 457, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2480, 4, 458, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2481, 4, 459, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2482, 4, 460, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2483, 4, 461, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2484, 4, 462, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2485, 4, 463, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2486, 4, 464, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2487, 4, 465, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2488, 4, 466, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2489, 4, 467, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2490, 4, 468, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2491, 4, 469, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2492, 4, 470, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2493, 4, 471, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2494, 4, 472, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2495, 4, 473, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2496, 4, 474, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2497, 4, 475, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2498, 4, 476, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2499, 4, 477, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2500, 4, 478, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2501, 4, 479, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2502, 4, 480, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2503, 4, 481, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2504, 4, 482, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2505, 4, 483, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2506, 4, 484, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2507, 4, 485, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2508, 4, 486, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2509, 4, 487, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2510, 4, 488, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2511, 4, 489, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2512, 4, 490, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2513, 4, 491, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2514, 4, 492, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2515, 4, 493, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2516, 4, 494, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2517, 4, 495, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2518, 4, 496, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2519, 4, 497, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2520, 4, 498, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2521, 4, 499, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2522, 4, 500, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2523, 4, 501, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2524, 4, 502, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2525, 4, 503, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2526, 4, 504, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2527, 4, 505, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2528, 4, 506, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2529, 4, 507, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2530, 4, 508, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2531, 4, 509, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2532, 4, 510, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2533, 4, 511, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2534, 4, 512, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2535, 4, 513, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2536, 4, 514, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2537, 4, 515, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2538, 4, 516, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2539, 4, 517, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2540, 4, 518, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2541, 4, 519, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2542, 4, 520, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2543, 4, 521, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2544, 4, 522, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2545, 4, 523, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2546, 4, 524, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2547, 4, 525, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2548, 4, 526, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2549, 4, 527, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2550, 4, 528, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2551, 4, 529, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2552, 4, 530, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2553, 4, 531, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2554, 4, 532, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2555, 4, 533, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2556, 4, 534, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2557, 4, 535, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2558, 4, 536, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2559, 4, 537, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2560, 4, 538, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2561, 4, 539, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2562, 4, 540, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2563, 4, 541, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2564, 4, 542, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2565, 4, 543, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2566, 4, 544, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2567, 4, 545, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2568, 4, 546, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2569, 4, 547, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2570, 4, 548, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2571, 4, 549, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2572, 4, 550, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2573, 4, 551, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2574, 4, 552, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2575, 4, 553, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2576, 4, 554, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2577, 4, 555, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2578, 4, 556, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2579, 4, 557, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2580, 4, 558, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2581, 4, 559, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2582, 4, 560, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2583, 4, 561, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2584, 4, 562, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2585, 4, 563, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2586, 4, 564, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2587, 4, 565, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2588, 4, 566, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2589, 4, 567, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2590, 4, 568, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2591, 4, 569, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2592, 4, 570, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2593, 4, 571, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2594, 4, 572, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2595, 4, 573, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2596, 4, 574, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2597, 4, 575, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2598, 4, 576, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2599, 4, 577, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2600, 4, 578, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2601, 4, 579, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2602, 4, 580, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2603, 4, 581, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2604, 4, 582, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2605, 4, 583, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2606, 4, 584, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2607, 4, 585, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2608, 4, 586, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2609, 4, 587, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2610, 4, 588, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2611, 4, 589, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2612, 4, 590, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2613, 4, 591, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2614, 4, 592, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2615, 4, 593, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2616, 4, 594, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2617, 4, 595, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2618, 4, 596, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2619, 4, 597, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2620, 4, 598, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2621, 4, 599, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2622, 4, 600, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2623, 4, 601, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2624, 4, 602, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2625, 4, 603, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2626, 4, 604, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2627, 4, 605, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2628, 4, 606, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2629, 4, 607, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2630, 4, 608, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2631, 4, 609, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2632, 4, 610, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2633, 4, 611, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2634, 4, 612, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2635, 4, 613, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2636, 4, 614, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2637, 4, 615, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2638, 4, 616, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2639, 4, 617, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2640, 4, 618, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2641, 4, 619, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2642, 4, 620, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2643, 4, 621, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2644, 4, 622, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2645, 4, 623, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2646, 4, 624, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2647, 4, 625, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2648, 4, 626, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2649, 4, 627, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2650, 4, 628, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2651, 4, 629, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2652, 4, 630, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2653, 4, 631, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2654, 4, 632, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2655, 4, 633, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2656, 4, 634, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2657, 4, 635, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2658, 4, 636, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2659, 4, 637, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2660, 4, 638, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2661, 4, 639, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2662, 4, 640, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2663, 4, 641, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2664, 4, 642, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2665, 4, 643, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2666, 4, 644, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2667, 4, 645, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2668, 4, 646, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2669, 4, 647, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2670, 4, 648, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2671, 4, 649, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2672, 4, 650, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2673, 4, 651, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2674, 4, 652, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2675, 4, 653, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2676, 4, 654, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2677, 4, 655, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2678, 4, 656, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2679, 4, 657, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2680, 4, 658, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2681, 4, 659, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2682, 4, 660, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2683, 4, 661, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2684, 4, 662, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2685, 4, 663, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2686, 4, 664, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2687, 4, 665, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2688, 4, 666, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2689, 4, 667, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2690, 4, 668, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2691, 4, 669, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2692, 4, 670, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2693, 4, 671, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2694, 4, 672, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2695, 4, 673, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2696, 4, 674, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2697, 5, 338, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2698, 5, 339, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2699, 5, 340, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2700, 5, 341, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2701, 5, 342, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2702, 5, 343, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2703, 5, 344, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2704, 5, 345, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2705, 5, 346, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2706, 5, 347, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2707, 5, 348, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2708, 5, 349, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2709, 5, 350, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2710, 5, 351, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2711, 5, 352, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2712, 5, 353, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2713, 5, 354, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2714, 5, 355, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2715, 5, 356, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2716, 5, 357, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2717, 5, 358, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2718, 5, 359, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2719, 5, 360, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2720, 5, 361, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2721, 5, 362, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2722, 5, 363, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2723, 5, 364, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2724, 5, 365, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2725, 5, 366, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2726, 5, 367, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2727, 5, 368, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2728, 5, 369, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2729, 5, 370, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2730, 5, 371, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2731, 5, 372, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2732, 5, 373, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2733, 5, 374, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2734, 5, 375, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2735, 5, 376, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2736, 5, 377, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2737, 5, 378, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2738, 5, 379, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2739, 5, 380, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2740, 5, 381, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2741, 5, 382, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2742, 5, 383, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2743, 5, 384, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2744, 5, 385, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2745, 5, 386, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2746, 5, 387, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2747, 5, 388, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2748, 5, 389, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2749, 5, 390, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2750, 5, 391, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2751, 5, 392, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2752, 5, 393, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2753, 5, 394, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2754, 5, 395, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2755, 5, 396, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2756, 5, 397, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2757, 5, 398, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2758, 5, 399, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2759, 5, 400, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2760, 5, 401, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2761, 5, 402, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2762, 5, 403, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2763, 5, 404, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2764, 5, 405, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2765, 5, 406, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2766, 5, 407, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2767, 5, 408, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2768, 5, 409, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2769, 5, 410, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2770, 5, 411, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2771, 5, 412, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2772, 5, 413, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2773, 5, 414, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2774, 5, 415, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2775, 5, 416, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2776, 5, 417, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2777, 5, 418, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2778, 5, 419, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2779, 5, 420, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2780, 5, 421, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2781, 5, 422, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2782, 5, 423, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2783, 5, 424, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2784, 5, 425, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2785, 5, 426, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2786, 5, 427, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2787, 5, 428, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2788, 5, 429, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2789, 5, 430, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2790, 5, 431, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2791, 5, 432, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2792, 5, 433, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2793, 5, 434, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2794, 5, 435, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2795, 5, 436, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2796, 5, 437, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2797, 5, 438, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2798, 5, 439, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2799, 5, 440, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2800, 5, 441, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2801, 5, 442, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2802, 5, 443, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2803, 5, 444, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2804, 5, 445, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2805, 5, 446, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2806, 5, 447, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2807, 5, 448, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2808, 5, 449, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2809, 5, 450, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2810, 5, 451, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2811, 5, 452, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2812, 5, 453, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2813, 5, 454, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2814, 5, 455, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2815, 5, 456, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2816, 5, 457, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2817, 5, 458, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2818, 5, 459, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2819, 5, 460, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2820, 5, 461, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2821, 5, 462, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2822, 5, 463, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2823, 5, 464, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2824, 5, 465, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2825, 5, 466, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2826, 5, 467, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2827, 5, 468, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2828, 5, 469, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2829, 5, 470, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2830, 5, 471, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2831, 5, 472, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2832, 5, 473, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2833, 5, 474, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2834, 5, 475, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2835, 5, 476, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2836, 5, 477, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2837, 5, 478, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2838, 5, 479, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2839, 5, 480, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2840, 5, 481, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2841, 5, 482, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2842, 5, 483, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2843, 5, 484, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2844, 5, 485, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2845, 5, 486, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2846, 5, 487, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2847, 5, 488, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2848, 5, 489, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2849, 5, 490, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2850, 5, 491, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2851, 5, 492, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2852, 5, 493, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2853, 5, 494, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2854, 5, 495, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2855, 5, 496, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2856, 5, 497, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2857, 5, 498, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2858, 5, 499, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2859, 5, 500, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2860, 5, 501, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2861, 5, 502, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2862, 5, 503, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2863, 5, 504, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2864, 5, 505, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2865, 5, 506, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2866, 5, 507, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2867, 5, 508, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2868, 5, 509, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2869, 5, 510, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2870, 5, 511, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2871, 5, 512, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2872, 5, 513, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2873, 5, 514, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2874, 5, 515, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2875, 5, 516, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2876, 5, 517, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2877, 5, 518, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2878, 5, 519, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2879, 5, 520, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2880, 5, 521, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2881, 5, 522, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2882, 5, 523, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2883, 5, 524, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2884, 5, 525, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2885, 5, 526, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2886, 5, 527, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2887, 5, 528, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2888, 5, 529, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2889, 5, 530, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2890, 5, 531, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2891, 5, 532, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2892, 5, 533, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2893, 5, 534, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2894, 5, 535, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2895, 5, 536, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2896, 5, 537, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2897, 5, 538, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2898, 5, 539, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2899, 5, 540, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2900, 5, 541, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2901, 5, 542, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2902, 5, 543, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2903, 5, 544, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2904, 5, 545, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2905, 5, 546, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2906, 5, 547, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2907, 5, 548, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2908, 5, 549, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2909, 5, 550, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2910, 5, 551, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2911, 5, 552, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2912, 5, 553, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2913, 5, 554, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2914, 5, 555, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2915, 5, 556, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2916, 5, 557, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2917, 5, 558, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2918, 5, 559, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2919, 5, 560, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2920, 5, 561, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2921, 5, 562, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2922, 5, 563, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2923, 5, 564, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2924, 5, 565, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2925, 5, 566, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2926, 5, 567, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2927, 5, 568, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2928, 5, 569, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2929, 5, 570, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2930, 5, 571, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2931, 5, 572, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2932, 5, 573, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2933, 5, 574, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2934, 5, 575, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2935, 5, 576, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2936, 5, 577, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2937, 5, 578, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2938, 5, 579, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2939, 5, 580, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2940, 5, 581, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2941, 5, 582, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2942, 5, 583, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2943, 5, 584, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2944, 5, 585, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2945, 5, 586, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2946, 5, 587, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2947, 5, 588, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2948, 5, 589, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2949, 5, 590, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2950, 5, 591, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2951, 5, 592, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2952, 5, 593, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2953, 5, 594, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2954, 5, 595, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2955, 5, 596, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2956, 5, 597, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2957, 5, 598, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2958, 5, 599, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2959, 5, 600, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2960, 5, 601, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2961, 5, 602, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2962, 5, 603, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2963, 5, 604, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2964, 5, 605, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2965, 5, 606, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2966, 5, 607, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2967, 5, 608, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2968, 5, 609, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2969, 5, 610, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2970, 5, 611, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2971, 5, 612, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2972, 5, 613, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2973, 5, 614, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2974, 5, 615, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2975, 5, 616, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2976, 5, 617, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2977, 5, 618, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2978, 5, 619, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2979, 5, 620, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2980, 5, 621, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2981, 5, 622, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2982, 5, 623, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2983, 5, 624, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2984, 5, 625, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2985, 5, 626, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2986, 5, 627, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2987, 5, 628, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2988, 5, 629, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2989, 5, 630, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2990, 5, 631, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2991, 5, 632, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2992, 5, 633, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2993, 5, 634, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2994, 5, 635, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2995, 5, 636, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2996, 5, 637, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2997, 5, 638, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2998, 5, 639, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (2999, 5, 640, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3000, 5, 641, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3001, 5, 642, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3002, 5, 643, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3003, 5, 644, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3004, 5, 645, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3005, 5, 646, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3006, 5, 647, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3007, 5, 648, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3008, 5, 649, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3009, 5, 650, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3010, 5, 651, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3011, 5, 652, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3012, 5, 653, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3013, 5, 654, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3014, 5, 655, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3015, 5, 656, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3016, 5, 657, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3017, 5, 658, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3018, 5, 659, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3019, 5, 660, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3020, 5, 661, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3021, 5, 662, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3022, 5, 663, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3023, 5, 664, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3024, 5, 665, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3025, 5, 666, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3026, 5, 667, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3027, 5, 668, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3028, 5, 669, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3029, 5, 670, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3030, 5, 671, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3031, 5, 672, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3032, 5, 673, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3033, 5, 674, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3034, 6, 338, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3035, 6, 339, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3036, 6, 340, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3037, 6, 341, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3038, 6, 342, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3039, 6, 343, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3040, 6, 344, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3041, 6, 345, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3042, 6, 346, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3043, 6, 347, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3044, 6, 348, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3045, 6, 349, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3046, 6, 350, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3047, 6, 351, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3048, 6, 352, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3049, 6, 353, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3050, 6, 354, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3051, 6, 355, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3052, 6, 356, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3053, 6, 357, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3054, 6, 358, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3055, 6, 359, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3056, 6, 360, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3057, 6, 361, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3058, 6, 362, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3059, 6, 363, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3060, 6, 364, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3061, 6, 365, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3062, 6, 366, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3063, 6, 367, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3064, 6, 368, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3065, 6, 369, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3066, 6, 370, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3067, 6, 371, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3068, 6, 372, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3069, 6, 373, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3070, 6, 374, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3071, 6, 375, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3072, 6, 376, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3073, 6, 377, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3074, 6, 378, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3075, 6, 379, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3076, 6, 380, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3077, 6, 381, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3078, 6, 382, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3079, 6, 383, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3080, 6, 384, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3081, 6, 385, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3082, 6, 386, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3083, 6, 387, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3084, 6, 388, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3085, 6, 389, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3086, 6, 390, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3087, 6, 391, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3088, 6, 392, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3089, 6, 393, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3090, 6, 394, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3091, 6, 395, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3092, 6, 396, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3093, 6, 397, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3094, 6, 398, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3095, 6, 399, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3096, 6, 400, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3097, 6, 401, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3098, 6, 402, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3099, 6, 403, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3100, 6, 404, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3101, 6, 405, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3102, 6, 406, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3103, 6, 407, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3104, 6, 408, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3105, 6, 409, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3106, 6, 410, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3107, 6, 411, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3108, 6, 412, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3109, 6, 413, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3110, 6, 414, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3111, 6, 415, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3112, 6, 416, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3113, 6, 417, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3114, 6, 418, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3115, 6, 419, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3116, 6, 420, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3117, 6, 421, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3118, 6, 422, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3119, 6, 423, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3120, 6, 424, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3121, 6, 425, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3122, 6, 426, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3123, 6, 427, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3124, 6, 428, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3125, 6, 429, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3126, 6, 430, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3127, 6, 431, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3128, 6, 432, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3129, 6, 433, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3130, 6, 434, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3131, 6, 435, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3132, 6, 436, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3133, 6, 437, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3134, 6, 438, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3135, 6, 439, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3136, 6, 440, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3137, 6, 441, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3138, 6, 442, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3139, 6, 443, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3140, 6, 444, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3141, 6, 445, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3142, 6, 446, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3143, 6, 447, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3144, 6, 448, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3145, 6, 449, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3146, 6, 450, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3147, 6, 451, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3148, 6, 452, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3149, 6, 453, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3150, 6, 454, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3151, 6, 455, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3152, 6, 456, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3153, 6, 457, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3154, 6, 458, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3155, 6, 459, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3156, 6, 460, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3157, 6, 461, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3158, 6, 462, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3159, 6, 463, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3160, 6, 464, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3161, 6, 465, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3162, 6, 466, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3163, 6, 467, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3164, 6, 468, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3165, 6, 469, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3166, 6, 470, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3167, 6, 471, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3168, 6, 472, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3169, 6, 473, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3170, 6, 474, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3171, 6, 475, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3172, 6, 476, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3173, 6, 477, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3174, 6, 478, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3175, 6, 479, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3176, 6, 480, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3177, 6, 481, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3178, 6, 482, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3179, 6, 483, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3180, 6, 484, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3181, 6, 485, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3182, 6, 486, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3183, 6, 487, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3184, 6, 488, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3185, 6, 489, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3186, 6, 490, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3187, 6, 491, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3188, 6, 492, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3189, 6, 493, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3190, 6, 494, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3191, 6, 495, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3192, 6, 496, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3193, 6, 497, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3194, 6, 498, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3195, 6, 499, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3196, 6, 500, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3197, 6, 501, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3198, 6, 502, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3199, 6, 503, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3200, 6, 504, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3201, 6, 505, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3202, 6, 506, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3203, 6, 507, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3204, 6, 508, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3205, 6, 509, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3206, 6, 510, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3207, 6, 511, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3208, 6, 512, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3209, 6, 513, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3210, 6, 514, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3211, 6, 515, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3212, 6, 516, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3213, 6, 517, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3214, 6, 518, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3215, 6, 519, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3216, 6, 520, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3217, 6, 521, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3218, 6, 522, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3219, 6, 523, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3220, 6, 524, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3221, 6, 525, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3222, 6, 526, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3223, 6, 527, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3224, 6, 528, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3225, 6, 529, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3226, 6, 530, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3227, 6, 531, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3228, 6, 532, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3229, 6, 533, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3230, 6, 534, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3231, 6, 535, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3232, 6, 536, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3233, 6, 537, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3234, 6, 538, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3235, 6, 539, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3236, 6, 540, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3237, 6, 541, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3238, 6, 542, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3239, 6, 543, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3240, 6, 544, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3241, 6, 545, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3242, 6, 546, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3243, 6, 547, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3244, 6, 548, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3245, 6, 549, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3246, 6, 550, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3247, 6, 551, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3248, 6, 552, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3249, 6, 553, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3250, 6, 554, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3251, 6, 555, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3252, 6, 556, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3253, 6, 557, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3254, 6, 558, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3255, 6, 559, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3256, 6, 560, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3257, 6, 561, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3258, 6, 562, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3259, 6, 563, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3260, 6, 564, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3261, 6, 565, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3262, 6, 566, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3263, 6, 567, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3264, 6, 568, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3265, 6, 569, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3266, 6, 570, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3267, 6, 571, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3268, 6, 572, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3269, 6, 573, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3270, 6, 574, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3271, 6, 575, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3272, 6, 576, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3273, 6, 577, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3274, 6, 578, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3275, 6, 579, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3276, 6, 580, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3277, 6, 581, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3278, 6, 582, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3279, 6, 583, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3280, 6, 584, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3281, 6, 585, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3282, 6, 586, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3283, 6, 587, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3284, 6, 588, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3285, 6, 589, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3286, 6, 590, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3287, 6, 591, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3288, 6, 592, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3289, 6, 593, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3290, 6, 594, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3291, 6, 595, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3292, 6, 596, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3293, 6, 597, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3294, 6, 598, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3295, 6, 599, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3296, 6, 600, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3297, 6, 601, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3298, 6, 602, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3299, 6, 603, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3300, 6, 604, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3301, 6, 605, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3302, 6, 606, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3303, 6, 607, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3304, 6, 608, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3305, 6, 609, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3306, 6, 610, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3307, 6, 611, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3308, 6, 612, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3309, 6, 613, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3310, 6, 614, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3311, 6, 615, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3312, 6, 616, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3313, 6, 617, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3314, 6, 618, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3315, 6, 619, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3316, 6, 620, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3317, 6, 621, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3318, 6, 622, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3319, 6, 623, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3320, 6, 624, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3321, 6, 625, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3322, 6, 626, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3323, 6, 627, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3324, 6, 628, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3325, 6, 629, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3326, 6, 630, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3327, 6, 631, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3328, 6, 632, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3329, 6, 633, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3330, 6, 634, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3331, 6, 635, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3332, 6, 636, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3333, 6, 637, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3334, 6, 638, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3335, 6, 639, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3336, 6, 640, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3337, 6, 641, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3338, 6, 642, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3339, 6, 643, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3340, 6, 644, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3341, 6, 645, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3342, 6, 646, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3343, 6, 647, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3344, 6, 648, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3345, 6, 649, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3346, 6, 650, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3347, 6, 651, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3348, 6, 652, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3349, 6, 653, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3350, 6, 654, 3, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3351, 6, 655, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3352, 6, 656, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3353, 6, 657, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3354, 6, 658, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3355, 6, 659, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3356, 6, 660, 4, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3357, 6, 661, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3358, 6, 662, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3359, 6, 663, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3360, 6, 664, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3361, 6, 665, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3362, 6, 666, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3363, 6, 667, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3364, 6, 668, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3365, 6, 669, 2, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3366, 6, 670, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3367, 6, 671, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3368, 6, 672, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3369, 6, 673, 1, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);
INSERT INTO public.track_ratings VALUES (3370, 6, 674, 5, '2025-12-04 07:28:24.623392', '2025-12-04 07:28:24.623392', 1);

INSERT INTO public.tracks VALUES (338, 1, 8, 1, 'obstaculo (feat. Myke Towers)', 135, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (339, 1, 8, 2, 'PASIEMPRE (feat. Arcangel, Jhayco, Myke Towers)', 355, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (340, 1, 8, 3, 'Todavia (feat. Wisin & Yandel)', 203, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (341, 1, 8, 4, 'FANTASMA AVC (feat. Jhayco)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (342, 1, 8, 5, 'MOJABI GHOST (feat. Bad Bunny)', 232, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (343, 1, 8, 6, '11 Y ONCE (feat. Sech, E.VAX)', 196, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (344, 1, 8, 7, 'desde las 10 (KANY''S INTERLUDE) (feat. Kany Garcia)', 60, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (345, 1, 8, 8, 'manana (feat. Young Miko, The Marias)', 175, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (346, 1, 8, 9, 'BUENOS AIRES (feat. Mora, Zion)', 118, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (347, 1, 8, 10, 'COLMILLO (feat. J. Balvin, Young Miko, Jowell & Randy)', 265, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (348, 1, 8, 11, 'LA BABY (feat. Daddy Yankee, Feid, Sech)', 182, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (349, 1, 8, 12, 'me jodi... (feat. Arcangel)', 201, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (350, 1, 8, 13, 'VOLVER (feat. Skrillex, Four Tet, Rauw Alejandro)', 185, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (351, 1, 8, 14, 'EN VISTO (feat. Ozuna)', 153, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (352, 1, 8, 15, 'Lo Siento BB:/ (feat. Bad Bunny, Julieta Venegas)', 206, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (353, 1, 8, 16, 'si preguntas por mi (feat. Kris Floyd, Judeline)', 215, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (354, 1, 8, 17, 'Sci-Fi (feat. Rauw Alejandro)', 197, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (355, 1, 8, 18, 'CORLEONE INTERLUDE (feat. Chencho Corleone)', 90, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (356, 1, 8, 19, 'PARANORMAL (feat. Alvaro Diaz)', 197, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (357, 1, 8, 20, 'SACRIFICIO (feat. Xantos)', 149, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (358, 2, 1, 1, 'NUEVAYoL', 169, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (359, 2, 1, 2, 'VOY A LLeVARTE PA PR', 115, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (360, 2, 1, 3, 'BAILE INoLVIDABLE', 251, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (361, 2, 1, 4, 'PERFuMITO NUEVO', 94, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (362, 2, 1, 5, 'WELTiTA', 124, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (363, 2, 1, 6, 'VeLDA', 151, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (364, 2, 1, 7, 'EL CLuB', 72, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (365, 2, 1, 8, 'KETU TeCRe', 87, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (366, 2, 1, 9, 'BOKeTE', 106, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (367, 2, 1, 10, 'KLOuFRENS', 68, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (368, 2, 1, 11, 'TURiSTA', 29, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (369, 2, 1, 12, 'CAFe CON RON', 173, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (370, 2, 1, 13, 'PIToRRO DE COCO', 59, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (371, 2, 1, 14, 'LO QUE LE PASO A HAWAii', 80, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (372, 2, 1, 15, 'EoO', 196, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (373, 2, 1, 16, 'DtMF', 257, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (374, 2, 1, 17, 'LA MuDANZA', 191, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (375, 3, 1, 1, 'NADIE SABE', 380, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (376, 3, 1, 2, 'MONACO', 267, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (377, 3, 1, 3, 'FINA (feat. Young Miko)', 216, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (378, 3, 1, 4, 'HIBIKI (feat. Mora)', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (379, 3, 1, 5, 'MR. OCTOBER', 190, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (380, 3, 1, 6, 'CYBERTRUCK', 192, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (381, 3, 1, 7, 'VOU 787', 123, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (382, 3, 1, 8, 'SEDA (feat. Bryant Myers)', 191, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (383, 3, 1, 9, 'GRACIAS POR NADA', 176, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (384, 3, 1, 10, 'TELEFONO NUEVO (feat. Luar La L)', 355, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (385, 3, 1, 11, 'BABY NUEVA', 241, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (386, 3, 1, 12, 'MERCEDES CAROTA (feat. YOVNGCHIMI)', 201, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (387, 3, 1, 13, 'LOS PITS', 251, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (388, 3, 1, 14, 'VUELVE CANDY B', 266, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (389, 3, 1, 15, 'BATICANO', 250, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (390, 3, 1, 16, 'NO ME QUIERO CASAR', 226, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (391, 3, 1, 17, 'WHERE SHE GOES', 231, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (392, 3, 1, 18, 'THUNDER Y LIGHTNING (feat. Eladio Carrion)', 218, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (393, 3, 1, 19, 'PERRO NEGRO (feat. Feid)', 163, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (394, 3, 1, 20, 'EUROPA :( (Interludio)', 12, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (395, 3, 1, 21, 'ACHO PR (feat. Arcangel, Nengo Flow y De la Ghetto)', 360, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (396, 3, 1, 22, 'UN PREVIEW', 165, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (397, 4, 1, 1, 'Si Veo a Tu Mama', 170, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (398, 4, 1, 2, 'La Dificil', 163, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (399, 4, 1, 3, 'Pero Ya No', 160, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (400, 4, 1, 4, 'La Santa (feat. Daddy Yankee)', 206, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (401, 4, 1, 5, 'Yo Perreo Sola', 172, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (402, 4, 1, 6, 'Bichiyal (feat. Yaviah)', 196, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (403, 4, 1, 7, 'Solia', 159, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (404, 4, 1, 8, 'La Zona', 136, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (405, 4, 1, 9, 'Que Malo (feat. Nengo Flow)', 167, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (406, 4, 1, 10, 'Vete', 192, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (407, 4, 1, 11, 'Ignorantes (feat. Sech)', 210, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (408, 4, 1, 12, 'A Tu Merced', 175, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (409, 4, 1, 13, 'Una Vez (feat. Mora)', 232, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (410, 4, 1, 14, 'Safaera (feat. Jowell & Randy, Nengo Flow)', 295, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (411, 4, 1, 15, '25/8', 243, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (412, 4, 1, 16, 'Esta Cabron Ser Yo (feat. Anuel AA)', 227, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (413, 4, 1, 17, 'Puesto Pa'' Guerrial (feat. Myke Towers)', 190, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (414, 4, 1, 18, 'P FKN R (feat. Kendo Kaponi, Arcangel)', 258, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (415, 4, 1, 19, 'Hablamos Manana (feat. Duki, Pablo Chill-E)', 240, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (416, 4, 1, 20, '<3', 158, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (417, 5, 1, 1, 'NI BIEN NI MAL', 236, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (418, 5, 1, 2, '200 MPH (feat. Diplo)', 170, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (419, 5, 1, 3, 'Quien Tu Eres?', 159, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (420, 5, 1, 4, 'Caro', 229, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (421, 5, 1, 5, 'Tenemos Que Hablar', 224, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (422, 5, 1, 6, 'Otra Noche en Miami', 233, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (423, 5, 1, 7, 'Ser Bichote', 193, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (424, 5, 1, 8, 'Si Estuviesemos Juntos', 169, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (425, 5, 1, 9, 'Solo de Mi', 197, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (426, 5, 1, 10, 'Cuando Perriabas', 188, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (427, 5, 1, 11, 'La Romana (feat. El Alfa)', 300, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (428, 5, 1, 12, 'Como Antes', 230, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (429, 5, 1, 13, 'RLNDT', 284, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (430, 5, 1, 14, 'Estamos Bien', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (431, 5, 1, 15, 'MIA (feat. Drake)', 210, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (432, 6, 1, 1, 'Moscow Mule', 245, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (433, 6, 1, 2, 'Despues de la Playa', 230, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (434, 6, 1, 3, 'Me Porto Bonito (feat. Chencho Corleone)', 178, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (435, 6, 1, 4, 'Titi Me Pregunto', 243, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (436, 6, 1, 5, 'Un Ratito', 176, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (437, 6, 1, 6, 'Yo No Soy Celoso', 230, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (438, 6, 1, 7, 'Tarot (feat. Jhay Cortez)', 237, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (439, 6, 1, 8, 'Neverita', 173, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (440, 6, 1, 9, 'La Corriente (feat. Tony Dize)', 198, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (441, 6, 1, 10, 'Efecto', 213, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (442, 6, 1, 11, 'Party (feat. Rauw Alejandro)', 227, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (443, 6, 1, 12, 'Aguacero', 210, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (444, 6, 1, 13, 'Ensename a Bailar', 176, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (445, 6, 1, 14, 'Ojitos Lindos (feat. Bomba Estereo)', 258, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (446, 6, 1, 15, 'Dos Mil 16', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (447, 6, 1, 16, 'El Apagon', 201, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (448, 6, 1, 17, 'Otro Atardecer (feat. The Marias)', 244, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (449, 6, 1, 18, 'Un Coco', 196, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (450, 6, 1, 19, 'Andrea (feat. Buscabulla)', 339, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (451, 6, 1, 20, 'Me Fui de Vacaciones', 180, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (452, 6, 1, 21, 'Un Verano Sin Ti', 150, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (453, 6, 1, 22, 'Agosto', 139, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (454, 6, 1, 23, 'Callaita', 250, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (455, 7, 2, 1, 'INTRO', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (456, 7, 2, 2, 'Yo Te Conozco', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (457, 7, 2, 3, '1204 (feat. MORA)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (458, 7, 2, 4, 'peldio', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (459, 7, 2, 5, 'CHALET', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (460, 7, 2, 6, 'YA YO ME ENTERE', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (461, 7, 2, 7, 'BRINCAR', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (462, 7, 2, 8, 'ALL TIME', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (463, 7, 2, 9, 'Nubes (feat. Omar Courtz)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (464, 7, 2, 10, 'Nebuleo', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (465, 7, 2, 11, '5 minutos', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (466, 7, 2, 12, 'PALGO', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (467, 7, 2, 13, 'FINDE', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (468, 7, 2, 14, '$ extape (feat. Eladio Carrion)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (469, 7, 2, 15, 'Cobro', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (470, 7, 2, 16, 'VICIO MIO (feat. Yan Block)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (471, 7, 2, 17, 'SIEMPRE BB', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (472, 8, 9, 1, 'Lavender Haze', 202, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (473, 8, 9, 2, 'Maroon', 218, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (474, 8, 9, 3, 'Anti-Hero', 228, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (475, 8, 9, 4, 'Snow On The Beach (feat. Lana Del Rey)', 256, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (476, 8, 9, 5, 'You''re On Your Own, Kid', 194, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (477, 8, 9, 6, 'Midnight Rain', 174, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (478, 8, 9, 7, 'Question...?', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (479, 8, 9, 8, 'Vigilante Shit', 164, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (480, 8, 9, 9, 'Bejeweled', 194, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (481, 8, 9, 10, 'Labyrinth', 247, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (482, 8, 9, 11, 'Karma', 204, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (483, 8, 9, 12, 'Sweet Nothing', 188, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (484, 8, 9, 13, 'Mastermind', 191, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (485, 9, 9, 1, 'Welcome To New York (Taylor''s Version)', 212, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (486, 9, 9, 2, 'Blank Space (Taylor''s Version)', 231, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (487, 9, 9, 3, 'Style (Taylor''s Version)', 231, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (488, 9, 9, 4, 'Out Of The Woods (Taylor''s Version)', 235, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (489, 9, 9, 5, 'All You Had To Do Was Stay (Taylor''s Version)', 193, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (490, 9, 9, 6, 'Shake It Off (Taylor''s Version)', 219, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (491, 9, 9, 7, 'I Wish You Would (Taylor''s Version)', 207, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (492, 9, 9, 8, 'Bad Blood (Taylor''s Version)', 211, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (493, 9, 9, 9, 'Wildest Dreams (Taylor''s Version)', 220, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (494, 9, 9, 10, 'How You Get The Girl (Taylor''s Version)', 247, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (495, 9, 9, 11, 'This Love (Taylor''s Version)', 250, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (496, 9, 9, 12, 'I Know Places (Taylor''s Version)', 195, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (497, 9, 9, 13, 'Clean (Taylor''s Version)', 271, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (498, 9, 9, 14, 'Wonderland (Taylor''s Version)', 245, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (499, 9, 9, 15, 'You Are In Love (Taylor''s Version)', 267, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (500, 9, 9, 16, 'New Romantics (Taylor''s Version)', 230, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (501, 9, 9, 17, 'Slut! (From The Vault)', 180, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (502, 9, 9, 18, 'Say Don''t Go (From The Vault)', 279, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (503, 9, 9, 19, 'Now That We Don''t Talk (From The Vault)', 197, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (504, 9, 9, 20, 'Suburban Legends (From The Vault)', 171, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (505, 9, 9, 21, 'Is It Over Now? (From The Vault)', 229, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (506, 9, 9, 22, 'Bad Blood (feat. Kendrick Lamar) (Taylor''s Version)', 228, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (507, 10, 7, 1, 'Taste', 157, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (508, 10, 7, 2, 'Please Please Please', 186, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (509, 10, 7, 3, 'Good Graces', 185, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (510, 10, 7, 4, 'Sharpest Tool', 218, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (511, 10, 7, 5, 'Coincidence', 164, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (512, 10, 7, 6, 'Bed Chem', 171, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (513, 10, 7, 7, 'Espresso', 175, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (514, 10, 7, 8, 'Dumb & Poetic', 133, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (515, 10, 7, 9, 'Slim Pickins', 152, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (516, 10, 7, 10, 'Juno', 223, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (517, 10, 7, 11, 'Lie To Girls', 202, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (518, 10, 7, 12, 'Don''t Smile', 206, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (519, 10, 7, 13, '15 Minutes', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (520, 10, 7, 14, 'Please Please Please (feat. Dolly Parton)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (521, 10, 7, 15, 'Can''t Make It Any Harder', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (522, 10, 7, 16, 'Busy Woman', 186, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (523, 10, 7, 17, 'Bad Review', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (524, 11, 6, 1, 'Cosa Nuestra', 260, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (525, 11, 6, 2, 'Dejame Entrar', 254, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (526, 11, 6, 3, 'Que Pasaria... (feat. Bad Bunny)', 191, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (527, 11, 6, 4, 'Tu Con El', 289, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (528, 11, 6, 5, 'Committed (feat. Pharrell Williams)', 159, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (529, 11, 6, 6, 'Espresso Martini (feat. Marconi Impara)', 191, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (530, 11, 6, 7, 'Baja Pa'' Aca (feat. Alexis y Fido)', 200, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (531, 11, 6, 8, 'Ni Me Conozco', 229, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (532, 11, 6, 9, 'IL Capo', 249, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (533, 11, 6, 10, 'Revolu (feat. Feid)', 215, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (534, 11, 6, 11, 'Mil Mujeres', 168, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (535, 11, 6, 12, 'Khe? (feat. Romeo Santos)', 206, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (536, 11, 6, 13, 'Se Fue (feat. Laura Pausini)', 240, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (537, 11, 6, 14, 'Pasaporte (feat. Mr. Naisgai)', 263, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (538, 11, 6, 15, 'Touching The Sky', 185, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (539, 11, 6, 16, 'Amar De Nuevo', 268, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (540, 11, 6, 17, '2:12 AM (feat. LATIN MAFIA)', 211, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (541, 11, 6, 18, 'SEXXXMACHINE', 236, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (542, 12, 6, 1, 'Todo De Ti', 199, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (543, 12, 6, 2, 'Sexo Virtual', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (544, 12, 6, 3, 'Nubes', 178, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (545, 12, 6, 4, 'Desesperados (feat. Chencho Corleone)', 224, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (546, 12, 6, 5, '2/Catorce (feat. Mr. Naisgai)', 205, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (547, 12, 6, 6, 'Aquel Nap ZzZz', 295, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (548, 12, 6, 7, 'Curame', 164, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (549, 12, 6, 8, 'Cosa Guapa', 255, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (550, 12, 6, 9, 'Desenfocao''', 170, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (551, 12, 6, 10, 'Cuando Fue? (feat. Tainy)', 168, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (552, 12, 6, 11, 'La Old Skul', 214, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (553, 12, 6, 12, 'Y Eso?', 200, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (554, 12, 6, 13, 'Tengo un Pal (feat. Lyanno)', 195, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (555, 12, 6, 14, 'Brazilera (feat. Anitta)', 184, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (556, 13, 5, 1, 'Kassandra', 183, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (557, 13, 5, 2, 'Duro', 162, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (558, 13, 5, 3, 'Iguales', 183, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (559, 13, 5, 4, 'Gran Via (feat. Aitana)', 213, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (560, 13, 5, 5, 'Chapiadora.com', 197, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (561, 13, 5, 6, 'Por Atras', 171, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (562, 13, 5, 7, '14 Febreros (feat. Sin Nombre)', 172, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (563, 13, 5, 8, 'La 125 (feat Yung Beef)', 194, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (564, 13, 5, 9, 'Halo (feat La Pantera)', 181, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (565, 13, 5, 10, 'Mr. Moondial (feat. Pitbull)', 165, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (566, 13, 5, 11, 'Que Asco De Todo', 190, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (567, 13, 5, 12, 'Noemu', 206, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (568, 13, 5, 13, 'Shibatto', 138, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (569, 13, 5, 14, 'Los Dias Contados (feat. Rels B)', 161, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (570, 13, 5, 15, 'El Estribillo', 161, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (571, 13, 5, 16, 'Amanecio (feat. De La Rose, De La Guetto)', 255, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (572, 13, 5, 17, 'Te Falle (feat Sech)', 219, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (573, 13, 5, 18, 'Buenas Noches', 238, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (574, 14, 5, 1, 'Intro - Speech cruzzi (feat. Cruz Cafune)', 61, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (575, 14, 5, 2, 'Ahora Que', 171, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (576, 14, 5, 3, 'Yankee', 194, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (577, 14, 5, 4, 'Vista Al Mar', 181, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (578, 14, 5, 5, 'Playa del Ingles (feat. Myke Towers)', 238, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (579, 14, 5, 6, 'Sin Senal (feat. Ovy On The Drums)', 185, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (580, 14, 5, 7, 'Dame (feat. Omar Montes)', 231, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (581, 14, 5, 8, 'Cuentale', 198, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (582, 14, 5, 9, 'Luces Azules', 161, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (583, 14, 5, 10, 'Punto G', 151, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (584, 14, 5, 11, 'Muneca (feat. JC Reyes)', 211, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (585, 14, 5, 12, 'Wanda', 161, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (586, 14, 5, 13, 'Me Falta Algo', 193, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (587, 14, 5, 14, 'Lisboa', 151, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (588, 14, 5, 15, 'Eramos Dos', 174, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (589, 14, 5, 16, 'Donde Quiero Estar', 201, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (590, 15, 4, 1, 'Seis y Seis', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (591, 15, 4, 2, 'Enamorate', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (592, 15, 4, 3, 'Me Enredo', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (593, 15, 4, 4, 'Ya No Mas', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (594, 15, 4, 5, 'Vente', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (595, 15, 4, 6, 'No Voy a Llorar', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (596, 15, 4, 7, 'Ojos Negros', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (597, 15, 4, 8, 'Como Estas', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (598, 15, 4, 9, 'El Que La Sigue La Consigue', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (599, 16, 3, 1, 'Lo mismo de siempre', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (600, 16, 3, 2, 'Bandida', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (601, 16, 3, 3, 'Tema de Jory', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (602, 16, 3, 4, 'De paquete (feat. Jory Boy)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (603, 16, 3, 5, 'Droga (feat. C. Tangana)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (604, 16, 3, 6, 'De inmediato', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (605, 16, 3, 7, 'Aurora (feat. De la Rose)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (606, 16, 3, 8, 'Pista de aterrizaje', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (607, 16, 3, 9, 'Mil vidas (feat. Ryan Castro)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (608, 16, 3, 10, 'Mas que algo (feat. Omar Courtz)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (609, 16, 3, 11, 'Otra noche sin dormir', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (610, 16, 3, 12, 'El ultimo beso (feat. Sech)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (611, 16, 3, 13, 'Toa (feat. Young Miko)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (612, 16, 3, 14, 'Salu', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (613, 16, 3, 15, 'La presidencial (feat. Dei V)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (614, 16, 3, 16, 'Detras de tu alma', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (615, 16, 3, 17, 'Cuando me vaya', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (616, 17, 3, 1, 'Media luna', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (617, 17, 3, 2, 'Pasajero', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (618, 17, 3, 3, 'Polvora (feat. Yandel)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (619, 17, 3, 4, 'Donde se aprende a querer?', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (620, 17, 3, 5, 'Reina (feat. Saiko)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (621, 17, 3, 6, 'Fantasias', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (622, 17, 3, 7, 'El Chacal', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (623, 17, 3, 8, 'Laguna (feat. Arcangel)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (624, 17, 3, 9, 'Lokita', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (625, 17, 3, 10, 'Pide (feat. RaiNao)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (626, 17, 3, 11, 'Un deseo (feat. RaiNao)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (627, 17, 3, 12, 'Diamonds (feat. Dei V)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (628, 17, 3, 13, 'Corcega (feat. Alvaro Diaz)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (629, 17, 3, 14, 'Marea', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (630, 17, 3, 15, 'Ayer y hoy', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (631, 18, 3, 1, 'Bienvenida al paraiso', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (632, 18, 3, 2, 'Domingo de bote', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (633, 18, 3, 3, 'Apa (feat. Quevedo)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (634, 18, 3, 4, 'Calenton', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (635, 18, 3, 5, 'Cositas (feat. Paopao)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (636, 18, 3, 6, 'En la orilla', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (637, 18, 3, 7, 'Modelito (feat. YOVNGCHIMI)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (638, 18, 3, 8, 'Casualidad', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (639, 18, 3, 9, 'Airbnb (feat. De La Ghetto)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (640, 18, 3, 10, 'Tu sabes donde vivo', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (641, 18, 3, 11, 'Eivissa (feat. Danny Ocean)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (642, 18, 3, 12, 'Como has estau?', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (643, 18, 3, 13, 'Malafama', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (644, 19, 3, 1, 'Bad Trip', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (645, 19, 3, 2, '2010', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (646, 19, 3, 3, 'Memorias (feat. Jhay Cortez)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (647, 19, 3, 4, 'Robert de Niro', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (648, 19, 3, 5, 'Pecado', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (649, 19, 3, 6, 'Lindor', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (650, 19, 3, 7, 'Tus Lagrimas (feat. Sech)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (651, 19, 3, 8, 'Escalofrios', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (652, 19, 3, 9, 'Playa Privada (feat. Elena Rose)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (653, 19, 3, 10, 'Lejos de Ti', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (654, 19, 3, 11, 'Quieren Ser Yo', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (655, 19, 3, 12, 'Tu Amigo (feat. Zion)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (656, 19, 3, 13, 'Oro Rosado', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (657, 19, 3, 14, 'La Inocente (feat. Feid)', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (658, 19, 3, 15, 'Ojos Colorau', NULL, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (659, 20, 3, 1, 'Primer Dia de Clases', 146, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (660, 20, 3, 2, 'La Receta (feat. Juliito)', 232, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (661, 20, 3, 3, 'Tuyo', 269, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (662, 20, 3, 4, 'Cuando Sera (feat. Lunay)', 176, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (663, 20, 3, 5, 'Volando', 188, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (664, 20, 3, 6, '512 (feat. Jhayco)', 193, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (665, 20, 3, 7, 'La Carita', 192, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (666, 20, 3, 8, 'Que Tu Dices? (feat. Omy de Oro)', 222, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (667, 20, 3, 9, 'Te Conoci Perriando', 190, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (668, 20, 3, 10, 'Afuego (feat. Mariah)', 192, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (669, 20, 3, 11, 'Vacio', 208, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (670, 20, 3, 12, 'Fin del Mundo', 220, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (671, 20, 3, 13, 'En un Avion (feat. Arcangel)', 220, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (672, 20, 3, 14, 'Desaparecer', 165, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (673, 20, 3, 15, 'No Digas Nada (feat. Farruko)', 180, '2025-12-04 07:28:24.567065');
INSERT INTO public.tracks VALUES (674, 20, 3, 16, 'Pegate (Remix) (feat. Jhayco)', 204, '2025-12-04 07:28:24.567065');

INSERT INTO public.user_roles VALUES (1, 1, 'admin', '2025-12-04 07:05:29.642269');

INSERT INTO public.users VALUES (1, 'admin', 'admin@example.com', '$2b$12$CJKQTHJiXYKG362O6B5.Le2jyVqn0X7gMFlZ.bdznQ0y0hHTIGpX.', 'Admin User', '2025-12-04 07:05:29.637951', NULL, true);
INSERT INTO public.users VALUES (2, 'Anonimo1', 'anonimo1@example.com', '$2b$12$hash1', 'Usuario Anonimo 1', '2025-12-04 07:05:29.637951', NULL, true);
INSERT INTO public.users VALUES (3, 'Anonimo2', 'anonimo2@example.com', '$2b$12$hash2', 'Usuario Anonimo 2', '2025-12-04 07:05:29.637951', NULL, true);
INSERT INTO public.users VALUES (4, 'Anonimo3', 'anonimo3@example.com', '$2b$12$hash3', 'Usuario Anonimo 3', '2025-12-04 07:05:29.637951', NULL, true);
INSERT INTO public.users VALUES (5, 'Anonimo4', 'anonimo4@example.com', '$2b$12$hash4', 'Usuario Anonimo 4', '2025-12-04 07:05:29.637951', NULL, true);
INSERT INTO public.users VALUES (6, 'Anonimo5', 'anonimo5@example.com', '$2b$12$hash5', 'Usuario Anonimo 5', '2025-12-04 07:05:29.637951', NULL, true);

SELECT pg_catalog.setval('public.albums_album_id_seq', 20, true);

SELECT pg_catalog.setval('public.artists_artist_id_seq', 9, true);

SELECT pg_catalog.setval('public.reviews_review_id_seq', 66, true);

SELECT pg_catalog.setval('public.track_ratings_rating_id_seq', 3370, true);

SELECT pg_catalog.setval('public.tracks_track_id_seq', 674, true);

SELECT pg_catalog.setval('public.user_roles_role_id_seq', 1, true);

SELECT pg_catalog.setval('public.users_user_id_seq', 6, true);

ALTER TABLE ONLY public.albums
    ADD CONSTRAINT albums_pkey PRIMARY KEY (album_id);

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_artist_name_key UNIQUE (artist_name);

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (artist_id);

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id);

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_album_id_key UNIQUE (user_id, album_id);

ALTER TABLE ONLY public.track_ratings
    ADD CONSTRAINT track_ratings_pkey PRIMARY KEY (rating_id);

ALTER TABLE ONLY public.track_ratings
    ADD CONSTRAINT track_ratings_user_id_track_id_key UNIQUE (user_id, track_id);

ALTER TABLE ONLY public.tracks
    ADD CONSTRAINT tracks_pkey PRIMARY KEY (track_id);

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (role_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);

CREATE INDEX idx_albums_artist ON public.albums USING btree (artist_id);

CREATE INDEX idx_albums_title ON public.albums USING btree (album_title);

CREATE INDEX idx_artists_name ON public.artists USING btree (artist_name);

CREATE INDEX idx_reviews_album ON public.reviews USING btree (album_id);

CREATE INDEX idx_reviews_user ON public.reviews USING btree (user_id);

CREATE INDEX idx_track_ratings_track ON public.track_ratings USING btree (track_id);

CREATE INDEX idx_tracks_album ON public.tracks USING btree (album_id);

CREATE INDEX idx_tracks_artist ON public.tracks USING btree (artist_id);

CREATE INDEX idx_users_email ON public.users USING btree (email);

CREATE INDEX idx_users_username ON public.users USING btree (username);

CREATE TRIGGER review_update_timestamp BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

CREATE TRIGGER track_rating_update_timestamp BEFORE UPDATE ON public.track_ratings FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

ALTER TABLE ONLY public.albums
    ADD CONSTRAINT albums_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(artist_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_album_id_fkey FOREIGN KEY (album_id) REFERENCES public.albums(album_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.track_ratings
    ADD CONSTRAINT track_ratings_track_id_fkey FOREIGN KEY (track_id) REFERENCES public.tracks(track_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.track_ratings
    ADD CONSTRAINT track_ratings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.tracks
    ADD CONSTRAINT tracks_album_id_fkey FOREIGN KEY (album_id) REFERENCES public.albums(album_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.tracks
    ADD CONSTRAINT tracks_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(artist_id) ON DELETE SET NULL;

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO app_user;

GRANT ALL ON TABLE public.albums TO app_user;

GRANT ALL ON TABLE public.artists TO app_user;

GRANT ALL ON TABLE public.reviews TO app_user;

GRANT ALL ON TABLE public.track_ratings TO app_user;

GRANT ALL ON TABLE public.tracks TO app_user;

GRANT ALL ON TABLE public.album_details TO app_user;

GRANT ALL ON SEQUENCE public.albums_album_id_seq TO app_user;

GRANT ALL ON SEQUENCE public.artists_artist_id_seq TO app_user;

GRANT ALL ON SEQUENCE public.reviews_review_id_seq TO app_user;

GRANT ALL ON SEQUENCE public.track_ratings_rating_id_seq TO app_user;

GRANT ALL ON SEQUENCE public.tracks_track_id_seq TO app_user;

GRANT ALL ON TABLE public.users TO app_user;

GRANT ALL ON TABLE public.user_review_history TO app_user;

GRANT ALL ON TABLE public.user_roles TO app_user;

GRANT ALL ON SEQUENCE public.user_roles_role_id_seq TO app_user;

GRANT ALL ON SEQUENCE public.users_user_id_seq TO app_user;

\unrestrict INezlUfS7CPvSkgWKf7jQCptCMSSOo5ZsZ6D3APBxNAjljySbful30qNgQvW0fp


