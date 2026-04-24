-- ─────────────────────────────────────────────────────────────────────────────
-- Video Streaming Service – Database Initialisation
-- Run once:  psql -U video_user -d video_db -f init.sql
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id         BIGSERIAL    PRIMARY KEY,
    username   VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Demo user (user_id = 1)
INSERT INTO users (id, username)
VALUES (1, 'test')
ON CONFLICT (id) DO NOTHING;

-- ── Videos ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS videos (
    id               BIGSERIAL    PRIMARY KEY,
    title            VARCHAR(255) NOT NULL,
    hls_path         VARCHAR(500) NOT NULL,   -- e.g. /hls/demo/index.m3u8
    duration_seconds INTEGER      NOT NULL DEFAULT 0,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Demo video record (insert only when no rows exist)
INSERT INTO videos (id, title, hls_path, duration_seconds)
SELECT 1, 'Demo Video', '/hls/demo/index.m3u8', 0
WHERE NOT EXISTS (SELECT 1 FROM videos WHERE id = 1);

-- ── Video play progress ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS video_play_progress (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT    NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    video_id         BIGINT    NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    progress_seconds INTEGER   NOT NULL DEFAULT 0,
    duration_seconds INTEGER   NOT NULL DEFAULT 0,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_user_video UNIQUE (user_id, video_id)
);

CREATE INDEX IF NOT EXISTS idx_vpp_user_id  ON video_play_progress (user_id);
CREATE INDEX IF NOT EXISTS idx_vpp_video_id ON video_play_progress (video_id);

-- ── Trigger: keep updated_at current ────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vpp_updated_at ON video_play_progress;

CREATE TRIGGER trg_vpp_updated_at
BEFORE UPDATE ON video_play_progress
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
