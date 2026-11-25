SET ROLE evl_owner;

CREATE TABLE IF NOT EXISTS evidence (
    id            BIGSERIAL PRIMARY KEY,
    case_no       TEXT        NOT NULL,
    title         TEXT        NOT NULL,
    filename      TEXT        NOT NULL,
    size_bytes    INTEGER     NOT NULL,
    sha256        CHAR(64)    NOT NULL,
    nonce         BYTEA       NOT NULL,
    ciphertext    BYTEA       NOT NULL,
    registered_by TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS evidence_case_idx ON evidence (case_no);

CREATE TABLE IF NOT EXISTS custody_events (
    id          BIGSERIAL PRIMARY KEY,
    evidence_id BIGINT      NOT NULL REFERENCES evidence (id),
    action      TEXT        NOT NULL,
    actor       TEXT        NOT NULL,
    node        TEXT        NOT NULL,
    detail      TEXT,
    prev_hash   CHAR(64)    NOT NULL,
    event_hash  CHAR(64)    NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS custody_evidence_idx ON custody_events (evidence_id, id);

CREATE OR REPLACE FUNCTION evl_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END
$$;

DROP TRIGGER IF EXISTS evidence_no_change ON evidence;
CREATE TRIGGER evidence_no_change BEFORE UPDATE OR DELETE ON evidence
    FOR EACH ROW EXECUTE FUNCTION evl_append_only();

DROP TRIGGER IF EXISTS evidence_no_truncate ON evidence;
CREATE TRIGGER evidence_no_truncate BEFORE TRUNCATE ON evidence
    FOR EACH STATEMENT EXECUTE FUNCTION evl_append_only();

DROP TRIGGER IF EXISTS custody_no_change ON custody_events;
CREATE TRIGGER custody_no_change BEFORE UPDATE OR DELETE ON custody_events
    FOR EACH ROW EXECUTE FUNCTION evl_append_only();

DROP TRIGGER IF EXISTS custody_no_truncate ON custody_events;
CREATE TRIGGER custody_no_truncate BEFORE TRUNCATE ON custody_events
    FOR EACH STATEMENT EXECUTE FUNCTION evl_append_only();

REVOKE ALL ON evidence, custody_events FROM PUBLIC;
GRANT SELECT, INSERT ON evidence, custody_events TO evl_app;
GRANT USAGE ON SEQUENCE evidence_id_seq, custody_events_id_seq TO evl_app;

RESET ROLE;
