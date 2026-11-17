-- =====================================================================
-- CS336 Project 2: HMDA 2017 New Jersey -- 01_location_1nf.sql   (Task 3)
--
-- Builds, from the Preliminary table:
--   location            one row per distinct location, with a simple integer key
--   applicant_race      applicant_race_1..5     -> (sequence_number, race_number, race)
--   co_applicant_race   co_applicant_race_1..5  -> (sequence_number, race_number, race)
--   application_denial  denial_reason_1..3      -> (sequence_number, denial_reason_number, denial_reason)
-- Table and column names follow SCHEMA.md and the Step 1 ER diagram.
-- Primary keys are created here. Foreign keys, NOT NULL, the UNIQUE
-- constraint on location's ten columns and the CHECKs are added by
-- 03_constraints.sql (Step 4).
--
-- Run on ilab, after load.sql has created Preliminary:
--     postgres
--     \i 01_location_1nf.sql
-- It can be re-run: it drops and rebuilds its own tables.
-- Run order for the full project: 01 (this), 02_lookups_application.sql,
-- 03_constraints.sql, 04_export.sql.
--
-- References:
--   PostgreSQL docs, CREATE TABLE (identity columns):
--     https://www.postgresql.org/docs/current/sql-createtable.html
--   PostgreSQL docs, INSERT ... SELECT:
--     https://www.postgresql.org/docs/current/sql-insert.html
--   AI assistance is described in README.txt, section 2.
-- =====================================================================
\set ON_ERROR_STOP on

-- CASCADE also removes foreign keys that 03_constraints.sql may have added
-- on an earlier run; run 02 and 03 again after re-running this script.
DROP TABLE IF EXISTS application_denial, co_applicant_race, applicant_race, location CASCADE;


-- ---------------------------------------------------------------------
-- 1. location
-- The assignment says the 10 location columns together are the key of a
-- location, and no single column determines the rest. location_id is the
-- simple integer key that replaces them in the application table.
-- Column types are the same as in Preliminary.
-- ---------------------------------------------------------------------
CREATE TABLE location (
    location_id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_code                     INTEGER,
    county_code                    INTEGER,
    msamd                          INTEGER,
    census_tract_number            TEXT,
    population                     INTEGER,
    minority_population            NUMERIC,
    hud_median_family_income       INTEGER,
    tract_to_msamd_income          NUMERIC,
    number_of_owner_occupied_units INTEGER,
    number_of_1_to_4_family_units  INTEGER
);

-- One row per distinct combination. DISTINCT treats NULLs as equal, so the
-- 676 applications with no location information share a single row.
-- ORDER BY makes the location_id numbering the same on every run.
INSERT INTO location (
    state_code, county_code, msamd, census_tract_number, population,
    minority_population, hud_median_family_income, tract_to_msamd_income,
    number_of_owner_occupied_units, number_of_1_to_4_family_units)
SELECT DISTINCT
    state_code, county_code, msamd, census_tract_number, population,
    minority_population, hud_median_family_income, tract_to_msamd_income,
    number_of_owner_occupied_units, number_of_1_to_4_family_units
FROM Preliminary
ORDER BY state_code, county_code, census_tract_number, msamd, population,
         minority_population, hud_median_family_income, tract_to_msamd_income,
         number_of_owner_occupied_units, number_of_1_to_4_family_units;


-- ---------------------------------------------------------------------
-- 2. First normal form: repeating groups become join tables.
-- One row per non-blank value. The number column keeps the value's original
-- position (applicant_race_2 -> race_number 2). Positions are kept as-is,
-- not renumbered, because some rows skip a position (for example,
-- denial_reason_1 blank but denial_reason_2 filled in).
-- Codes and slot numbers are INTEGER, as in SCHEMA.md. The *_name columns are not stored
-- here: they belong to the race and denial_reason lookup tables (script 02).
-- ---------------------------------------------------------------------
CREATE TABLE applicant_race (
    sequence_number INTEGER,
    race_number     INTEGER,
    race            INTEGER,
    PRIMARY KEY (sequence_number, race_number)
);

INSERT INTO applicant_race (sequence_number, race_number, race)
SELECT p.sequence_number, r.race_number, r.race
FROM Preliminary p
CROSS JOIN LATERAL (VALUES
    (1, p.applicant_race_1),
    (2, p.applicant_race_2),
    (3, p.applicant_race_3),
    (4, p.applicant_race_4),
    (5, p.applicant_race_5)) AS r(race_number, race)
WHERE r.race IS NOT NULL;


CREATE TABLE co_applicant_race (
    sequence_number INTEGER,
    race_number     INTEGER,
    race            INTEGER,
    PRIMARY KEY (sequence_number, race_number)
);

INSERT INTO co_applicant_race (sequence_number, race_number, race)
SELECT p.sequence_number, r.race_number, r.race
FROM Preliminary p
CROSS JOIN LATERAL (VALUES
    (1, p.co_applicant_race_1),
    (2, p.co_applicant_race_2),
    (3, p.co_applicant_race_3),
    (4, p.co_applicant_race_4),
    (5, p.co_applicant_race_5)) AS r(race_number, race)
WHERE r.race IS NOT NULL;


CREATE TABLE application_denial (
    sequence_number    INTEGER,
    denial_reason_number INTEGER,
    denial_reason        INTEGER,
    PRIMARY KEY (sequence_number, denial_reason_number)
);

INSERT INTO application_denial (sequence_number, denial_reason_number, denial_reason)
SELECT p.sequence_number, d.denial_reason_number, d.denial_reason
FROM Preliminary p
CROSS JOIN LATERAL (VALUES
    (1, p.denial_reason_1),
    (2, p.denial_reason_2),
    (3, p.denial_reason_3)) AS d(denial_reason_number, denial_reason)
WHERE d.denial_reason IS NOT NULL;


-- ---------------------------------------------------------------------
-- 3. Checks. Each count should match the comment next to it.
-- ---------------------------------------------------------------------
-- Expected: location 2,135 | applicant_race 351,510 |
--           co_applicant_race 350,201 | application_denial 45,088
SELECT table_name, rows FROM (
    SELECT 1 AS ord, 'location' AS table_name, count(*) AS rows FROM location
    UNION ALL SELECT 2, 'applicant_race',     count(*) FROM applicant_race
    UNION ALL SELECT 3, 'co_applicant_race',  count(*) FROM co_applicant_race
    UNION ALL SELECT 4, 'application_denial', count(*) FROM application_denial
) c ORDER BY ord;

-- Every application must match exactly one location (lossless). Expect 0 | 0.
-- Each side's 10 location columns are turned into one text value with
-- ROW(...)::text, so blanks match blanks: a NULL prints as an empty slot.
-- This gives the same matches as comparing the 10 columns one by one with
-- IS NOT DISTINCT FROM, but PostgreSQL can hash it: about 0.4 s instead of
-- about 12 s, which keeps it well inside ilab's statement time limit.
SELECT count(*) FILTER (WHERE n = 0) AS apps_with_no_location,
       count(*) FILTER (WHERE n > 1) AS apps_with_many_locations
FROM (
    SELECT p.sequence_number, count(l.location_id) AS n
    FROM Preliminary p
    LEFT JOIN location l
      ON ROW(l.county_code, l.msamd, l.state_code, l.census_tract_number,
             l.population, l.minority_population, l.hud_median_family_income,
             l.tract_to_msamd_income, l.number_of_owner_occupied_units,
             l.number_of_1_to_4_family_units)::text
       = ROW(p.county_code, p.msamd, p.state_code, p.census_tract_number,
             p.population, p.minority_population, p.hud_median_family_income,
             p.tract_to_msamd_income, p.number_of_owner_occupied_units,
             p.number_of_1_to_4_family_units)::text
    GROUP BY p.sequence_number
) t;
