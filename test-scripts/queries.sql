-- ============================================================================
-- TEST-SKRIPT FOR OBLIG 1
-- ============================================================================

SELECT * FROM sykkel ORDER BY sykkel_id;

SELECT etternavn, fornavn, mobil
FROM kunde
ORDER BY etternavn, fornavn;

SELECT *
FROM sykkel
WHERE tatt_i_bruk > DATE '2023-04-01'
ORDER BY tatt_i_bruk;

SELECT COUNT(*) AS antall_kunder
FROM kunde;

SELECT
  k.kunde_id,
  k.etternavn,
  k.fornavn,
  COUNT(u.utleie_id) AS antall_utleier
FROM kunde k
LEFT JOIN utleie u ON u.kunde_id = k.kunde_id
GROUP BY k.kunde_id, k.etternavn, k.fornavn
ORDER BY k.etternavn, k.fornavn;

SELECT
  k.kunde_id,
  k.etternavn,
  k.fornavn,
  k.mobil
FROM kunde k
LEFT JOIN utleie u ON u.kunde_id = k.kunde_id
WHERE u.utleie_id IS NULL
ORDER BY k.etternavn, k.fornavn;

SELECT s.*
FROM sykkel s
LEFT JOIN utleie u ON u.sykkel_id = s.sykkel_id
WHERE u.utleie_id IS NULL
ORDER BY s.sykkel_id;

SELECT
  u.utleie_id,
  u.sykkel_id,
  k.fornavn,
  k.etternavn,
  k.mobil,
  u.utlevert_tid
FROM utleie u
JOIN kunde k ON k.kunde_id = u.kunde_id
WHERE u.innlevert_tid IS NULL
  AND u.utlevert_tid < NOW() - INTERVAL '1 day'
ORDER BY u.utlevert_tid;

-- Kjør med: docker-compose exec postgres psql -h -U admin -d data1500_db -f test-scripts/queries.sql

-- En test med en SQL-spørring mot metadata i PostgreSQL (kan slettes fra din script)
