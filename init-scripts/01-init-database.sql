-- ============================================================================
-- DATA1500 - Oblig 1: Arbeidskrav I våren 2026
-- Initialiserings-skript for PostgreSQL
-- ============================================================================

BEGIN;

-- Opprett grunnleggende tabeller

DROP TABLE IF EXISTS utleie CASCADE;
DROP TABLE IF EXISTS sykkel CASCADE;
DROP TABLE IF EXISTS las CASCADE;
DROP TABLE IF EXISTS stasjon CASCADE;
DROP TABLE IF EXISTS kunde CASCADE;
DROP TABLE IF EXISTS kunde_login_map CASCADE;

CREATE TABLE kunde (
  kunde_id   BIGSERIAL PRIMARY KEY,
  mobil      VARCHAR(15) NOT NULL UNIQUE,
  epost      TEXT NOT NULL UNIQUE,
  fornavn    TEXT NOT NULL,
  etternavn  TEXT NOT NULL,
  CONSTRAINT chk_mobil_format CHECK (mobil ~ '^[0-9]{8,15}$'),
  CONSTRAINT chk_epost_format CHECK (epost ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

CREATE TABLE stasjon (
  stasjon_id  BIGSERIAL PRIMARY KEY,
  navn        TEXT NOT NULL,
  adresse     TEXT NOT NULL,
  breddegrad  NUMERIC(9,6),
  lengdegrad  NUMERIC(9,6)
);

CREATE TABLE las (
  las_id     BIGSERIAL PRIMARY KEY,
  stasjon_id BIGINT NOT NULL REFERENCES stasjon(stasjon_id) ON DELETE RESTRICT,
  lock_nr    INTEGER NOT NULL,
  CONSTRAINT uq_las_per_stasjon UNIQUE (stasjon_id, lock_nr),
  CONSTRAINT chk_lock_nr CHECK (lock_nr > 0)
);

CREATE TABLE sykkel (
  sykkel_id     BIGSERIAL PRIMARY KEY,
  tatt_i_bruk   DATE NOT NULL,
  las_id        BIGINT NULL REFERENCES las(las_id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX ux_sykkel_las_id ON sykkel(las_id) WHERE las_id IS NOT NULL;

CREATE TABLE utleie (
  utleie_id            BIGSERIAL PRIMARY KEY,
  kunde_id             BIGINT NOT NULL REFERENCES kunde(kunde_id) ON DELETE RESTRICT,
  sykkel_id            BIGINT NOT NULL REFERENCES sykkel(sykkel_id) ON DELETE RESTRICT,
  utlevert_tid         TIMESTAMPTZ NOT NULL,
  innlevert_tid        TIMESTAMPTZ NULL,
  beloep               NUMERIC(10,2) NOT NULL DEFAULT 0,
  utlevert_stasjon_id  BIGINT NOT NULL REFERENCES stasjon(stasjon_id) ON DELETE RESTRICT,
  innlevert_las_id     BIGINT NULL REFERENCES las(las_id) ON DELETE SET NULL,
  CONSTRAINT chk_beloep CHECK (beloep >= 0),
  CONSTRAINT chk_tid CHECK (innlevert_tid IS NULL OR innlevert_tid >= utlevert_tid)
);

-- Sett inn testdata

INSERT INTO kunde (mobil, epost, fornavn, etternavn) VALUES
('40000001', 'kunde1@example.com', 'Anna', 'Aasen'),
('40000002', 'kunde2@example.com', 'Bjørn', 'Berg'),
('40000003', 'kunde3@example.com', 'Cecilie', 'Christensen'),
('40000004', 'kunde4@example.com', 'Daniel', 'Dahl'),
('40000005', 'kunde5@example.com', 'Eirin', 'Engen');

INSERT INTO stasjon (navn, adresse, breddegrad, lengdegrad) VALUES
('Sentrum', 'Storgata 1', 59.912700, 10.746100),
('Grünerløkka', 'Marka 10', 59.923000, 10.759000),
('Majorstuen', 'Kirkeveien 2', 59.928500, 10.713200),
('Tøyen', 'Tøyengata 5', 59.915500, 10.780000),
('Bjørvika', 'Operagata 1', 59.907000, 10.753000);

INSERT INTO las (stasjon_id, lock_nr)
SELECT s.stasjon_id, n
FROM stasjon s
CROSS JOIN generate_series(1,20) AS n;

INSERT INTO sykkel (tatt_i_bruk, las_id)
SELECT
  (DATE '2023-01-01' + (g % 900))::date,
  CASE
    WHEN g <= 80 THEN (SELECT las_id FROM las ORDER BY las_id LIMIT 1 OFFSET (g-1))
    ELSE NULL
  END
FROM generate_series(1,100) AS g;

WITH base AS (
  SELECT
    gs AS i,
    ((gs - 1) % 5) + 1 AS kunde_id,
    gs AS sykkel_id,
    TIMESTAMPTZ '2025-01-01 08:00:00+00' + (gs || ' hours')::interval AS start_tid,
    TIMESTAMPTZ '2025-01-01 08:00:00+00' + (gs || ' hours')::interval + interval '45 minutes' AS slutt_tid,
    ((gs - 1) % 5) + 1 AS utlevert_stasjon_id,
    (SELECT las_id FROM las ORDER BY las_id LIMIT 1 OFFSET ((gs - 1) % 100)) AS innlevert_las_id,
    round((30 + (gs % 120))::numeric, 2) AS beloep
  FROM generate_series(1,45) gs
)
INSERT INTO utleie (kunde_id, sykkel_id, utlevert_tid, innlevert_tid, beloep, utlevert_stasjon_id, innlevert_las_id)
SELECT kunde_id, sykkel_id, start_tid, slutt_tid, beloep, utlevert_stasjon_id, innlevert_las_id
FROM base;

UPDATE sykkel s
SET las_id = u.innlevert_las_id
FROM utleie u
WHERE u.sykkel_id = s.sykkel_id
  AND u.innlevert_tid IS NOT NULL;

WITH base AS (
  SELECT
    gs AS i,
    ((gs - 1) % 5) + 1 AS kunde_id,
    (45 + gs) AS sykkel_id,
    TIMESTAMPTZ '2025-02-01 10:00:00+00' + (gs || ' hours')::interval AS start_tid,
    ((gs - 1) % 5) + 1 AS utlevert_stasjon_id,
    round((50 + (gs % 50))::numeric, 2) AS beloep
  FROM generate_series(1,5) gs
)
INSERT INTO utleie (kunde_id, sykkel_id, utlevert_tid, innlevert_tid, beloep, utlevert_stasjon_id, innlevert_las_id)
SELECT kunde_id, sykkel_id, start_tid, NULL, beloep, utlevert_stasjon_id, NULL
FROM base;

UPDATE sykkel s
SET las_id = NULL
WHERE s.sykkel_id IN (SELECT sykkel_id FROM utleie WHERE innlevert_tid IS NULL);

-- DBA setninger (rolle: kunde, bruker: kunde_1)

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kunde') THEN
    CREATE ROLE kunde NOINHERIT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kunde_1') THEN
    CREATE USER kunde_1 WITH PASSWORD 'kunde_1_pass';
    GRANT kunde TO kunde_1;
  END IF;
END$$;

GRANT CONNECT ON DATABASE postgres TO kunde;
GRANT USAGE ON SCHEMA public TO kunde;

GRANT SELECT ON stasjon, las, sykkel TO kunde;

CREATE TABLE kunde_login_map (
  db_user  TEXT PRIMARY KEY,
  kunde_id BIGINT NOT NULL REFERENCES kunde(kunde_id)
);

INSERT INTO kunde_login_map (db_user, kunde_id) VALUES ('kunde_1', 1)
ON CONFLICT (db_user) DO UPDATE SET kunde_id = EXCLUDED.kunde_id;

CREATE OR REPLACE VIEW v_mine_utleier AS
SELECT u.*
FROM utleie u
JOIN kunde_login_map m ON m.kunde_id = u.kunde_id
WHERE m.db_user = current_user;

GRANT SELECT ON v_mine_utleier TO kunde;
REVOKE ALL ON utleie FROM kunde;

-- Eventuelt: Opprett indekser for ytelse

CREATE INDEX ix_utleie_kunde ON utleie(kunde_id);
CREATE INDEX ix_utleie_sykkel ON utleie(sykkel_id);
CREATE INDEX ix_utleie_aktiv ON utleie(innlevert_tid) WHERE innlevert_tid IS NULL;

-- Vis at initialisering er fullført (kan se i loggen fra "docker-compose log"

COMMIT;
SELECT 'Database initialisert!' as status;
