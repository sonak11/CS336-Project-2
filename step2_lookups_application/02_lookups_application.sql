-- =====================================================================
-- CS336 Project 2, Step 2 -- 02_lookups_application.sql
-- Builds the code->name lookup tables, null_columns, location and the
-- main application table FROM the Preliminary table (load.sql).
--
-- Run on ilab after load.sql has created and filled Preliminary:
--     postgres
--     \i load.sql                       (only needed once)
--     \i 02_lookups_application.sql
--
-- Design notes
--   * Every *_name column is functionally dependent on its code column, so
--     the names live only in lookup tables; application keeps codes only.
--   * Lookup contents are taken from the CSV data itself
--   * msamd_name is NULLable: msamd codes 35620 and 37980 appear in the CSV
--     with a blank name.
--   * application holds only integer / numeric columns plus respondent_id.
--  
--   * Column types are the same as the final Preliminary table from Project 1
--     (load.sql): INTEGER for codes/years/amounts, NUMERIC(4,2) for
--     rate_spread, NUMERIC for the census percentages, TEXT for respondent_id
--     and census_tract_number (leading zeros / hyphens must survive).
--   * NOT NULL is applied only to columns that are never NULL in the data.
--   * location_id is found by joining Preliminary to location on all 10
--     location columns with IS NOT DISTINCT FROM, so rows with NULL
--     location values are matched too.
--   * Preliminary is only READ here (through the temp table prelim_typed).
-- =====================================================================
\set ON_ERROR_STOP on

-- Clean slate so the script can be re-run.
DROP TABLE IF EXISTS application CASCADE;
DROP TABLE IF EXISTS location CASCADE;
DROP TABLE IF EXISTS null_columns CASCADE;
DROP TABLE IF EXISTS agency CASCADE;
DROP TABLE IF EXISTS loan_type CASCADE;
DROP TABLE IF EXISTS property_type CASCADE;
DROP TABLE IF EXISTS loan_purpose CASCADE;
DROP TABLE IF EXISTS owner_occupancy CASCADE;
DROP TABLE IF EXISTS preapproval CASCADE;
DROP TABLE IF EXISTS action_taken CASCADE;
DROP TABLE IF EXISTS ethnicity CASCADE;
DROP TABLE IF EXISTS race CASCADE;
DROP TABLE IF EXISTS sex CASCADE;
DROP TABLE IF EXISTS purchaser_type CASCADE;
DROP TABLE IF EXISTS denial_reason CASCADE;
DROP TABLE IF EXISTS hoepa_status CASCADE;
DROP TABLE IF EXISTS lien_status CASCADE;
DROP TABLE IF EXISTS msamd CASCADE;
DROP TABLE IF EXISTS county CASCADE;
DROP TABLE IF EXISTS state CASCADE;

-- ---------------------------------------------------------------------
-- 0. Typed, temporary copy of Preliminary (built once, so it is fast).
--    Works whether Preliminary's columns are already INTEGER/NUMERIC
--    (load.sql after its casts) or still TEXT: every value is converted
--    with NULLIF(...,'') so blanks become NULL. Preliminary is never changed.
--    (A temp table, not a view: a view would redo every cast on every use and
--    can hit ilab's statement timeout.)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS prelim_typed;
CREATE TEMP TABLE prelim_typed AS
SELECT
    NULLIF(BTRIM("as_of_year"::text), '')::INTEGER AS as_of_year,
    NULLIF(BTRIM("agency_code"::text), '')::INTEGER AS agency_code,
    NULLIF(BTRIM("msamd"::text), '')::INTEGER AS msamd,
    NULLIF(BTRIM("state_code"::text), '')::INTEGER AS state_code,
    NULLIF(BTRIM("county_code"::text), '')::INTEGER AS county_code,
    NULLIF(BTRIM("loan_type"::text), '')::INTEGER AS loan_type,
    NULLIF(BTRIM("property_type"::text), '')::INTEGER AS property_type,
    NULLIF(BTRIM("loan_purpose"::text), '')::INTEGER AS loan_purpose,
    NULLIF(BTRIM("owner_occupancy"::text), '')::INTEGER AS owner_occupancy,
    NULLIF(BTRIM("loan_amount_000s"::text), '')::INTEGER AS loan_amount_000s,
    NULLIF(BTRIM("preapproval"::text), '')::INTEGER AS preapproval,
    NULLIF(BTRIM("action_taken"::text), '')::INTEGER AS action_taken,
    NULLIF(BTRIM("applicant_ethnicity"::text), '')::INTEGER AS applicant_ethnicity,
    NULLIF(BTRIM("co_applicant_ethnicity"::text), '')::INTEGER AS co_applicant_ethnicity,
    NULLIF(BTRIM("applicant_race_1"::text), '')::INTEGER AS applicant_race_1,
    NULLIF(BTRIM("applicant_race_2"::text), '')::INTEGER AS applicant_race_2,
    NULLIF(BTRIM("applicant_race_3"::text), '')::INTEGER AS applicant_race_3,
    NULLIF(BTRIM("applicant_race_4"::text), '')::INTEGER AS applicant_race_4,
    NULLIF(BTRIM("applicant_race_5"::text), '')::INTEGER AS applicant_race_5,
    NULLIF(BTRIM("co_applicant_race_1"::text), '')::INTEGER AS co_applicant_race_1,
    NULLIF(BTRIM("co_applicant_race_2"::text), '')::INTEGER AS co_applicant_race_2,
    NULLIF(BTRIM("co_applicant_race_3"::text), '')::INTEGER AS co_applicant_race_3,
    NULLIF(BTRIM("co_applicant_race_4"::text), '')::INTEGER AS co_applicant_race_4,
    NULLIF(BTRIM("co_applicant_race_5"::text), '')::INTEGER AS co_applicant_race_5,
    NULLIF(BTRIM("applicant_sex"::text), '')::INTEGER AS applicant_sex,
    NULLIF(BTRIM("co_applicant_sex"::text), '')::INTEGER AS co_applicant_sex,
    NULLIF(BTRIM("applicant_income_000s"::text), '')::INTEGER AS applicant_income_000s,
    NULLIF(BTRIM("purchaser_type"::text), '')::INTEGER AS purchaser_type,
    NULLIF(BTRIM("denial_reason_1"::text), '')::INTEGER AS denial_reason_1,
    NULLIF(BTRIM("denial_reason_2"::text), '')::INTEGER AS denial_reason_2,
    NULLIF(BTRIM("denial_reason_3"::text), '')::INTEGER AS denial_reason_3,
    NULLIF(BTRIM("hoepa_status"::text), '')::INTEGER AS hoepa_status,
    NULLIF(BTRIM("lien_status"::text), '')::INTEGER AS lien_status,
    NULLIF(BTRIM("edit_status"::text), '')::INTEGER AS edit_status,
    NULLIF(BTRIM("sequence_number"::text), '')::INTEGER AS sequence_number,
    NULLIF(BTRIM("population"::text), '')::INTEGER AS population,
    NULLIF(BTRIM("hud_median_family_income"::text), '')::INTEGER AS hud_median_family_income,
    NULLIF(BTRIM("number_of_owner_occupied_units"::text), '')::INTEGER AS number_of_owner_occupied_units,
    NULLIF(BTRIM("number_of_1_to_4_family_units"::text), '')::INTEGER AS number_of_1_to_4_family_units,
    NULLIF(BTRIM("application_date_indicator"::text), '')::INTEGER AS application_date_indicator,
    NULLIF(BTRIM("rate_spread"::text), '')::NUMERIC(4,2) AS rate_spread,
    NULLIF(BTRIM("minority_population"::text), '')::NUMERIC AS minority_population,
    NULLIF(BTRIM("tract_to_msamd_income"::text), '')::NUMERIC AS tract_to_msamd_income,
    NULLIF("respondent_id"::text, '') AS respondent_id,
    NULLIF("agency_name"::text, '') AS agency_name,
    NULLIF("agency_abbr"::text, '') AS agency_abbr,
    NULLIF("loan_type_name"::text, '') AS loan_type_name,
    NULLIF("property_type_name"::text, '') AS property_type_name,
    NULLIF("loan_purpose_name"::text, '') AS loan_purpose_name,
    NULLIF("owner_occupancy_name"::text, '') AS owner_occupancy_name,
    NULLIF("preapproval_name"::text, '') AS preapproval_name,
    NULLIF("action_taken_name"::text, '') AS action_taken_name,
    NULLIF("msamd_name"::text, '') AS msamd_name,
    NULLIF("state_name"::text, '') AS state_name,
    NULLIF("state_abbr"::text, '') AS state_abbr,
    NULLIF("county_name"::text, '') AS county_name,
    NULLIF("census_tract_number"::text, '') AS census_tract_number,
    NULLIF("applicant_ethnicity_name"::text, '') AS applicant_ethnicity_name,
    NULLIF("co_applicant_ethnicity_name"::text, '') AS co_applicant_ethnicity_name,
    NULLIF("applicant_race_name_1"::text, '') AS applicant_race_name_1,
    NULLIF("applicant_race_name_2"::text, '') AS applicant_race_name_2,
    NULLIF("applicant_race_name_3"::text, '') AS applicant_race_name_3,
    NULLIF("applicant_race_name_4"::text, '') AS applicant_race_name_4,
    NULLIF("applicant_race_name_5"::text, '') AS applicant_race_name_5,
    NULLIF("co_applicant_race_name_1"::text, '') AS co_applicant_race_name_1,
    NULLIF("co_applicant_race_name_2"::text, '') AS co_applicant_race_name_2,
    NULLIF("co_applicant_race_name_3"::text, '') AS co_applicant_race_name_3,
    NULLIF("co_applicant_race_name_4"::text, '') AS co_applicant_race_name_4,
    NULLIF("co_applicant_race_name_5"::text, '') AS co_applicant_race_name_5,
    NULLIF("applicant_sex_name"::text, '') AS applicant_sex_name,
    NULLIF("co_applicant_sex_name"::text, '') AS co_applicant_sex_name,
    NULLIF("purchaser_type_name"::text, '') AS purchaser_type_name,
    NULLIF("denial_reason_name_1"::text, '') AS denial_reason_name_1,
    NULLIF("denial_reason_name_2"::text, '') AS denial_reason_name_2,
    NULLIF("denial_reason_name_3"::text, '') AS denial_reason_name_3,
    NULLIF("hoepa_status_name"::text, '') AS hoepa_status_name,
    NULLIF("lien_status_name"::text, '') AS lien_status_name,
    NULLIF("edit_status_name"::text, '') AS edit_status_name
FROM Preliminary;
ALTER TABLE prelim_typed ADD PRIMARY KEY (sequence_number);
ANALYZE prelim_typed;

DO $$
DECLARE n BIGINT; k BIGINT; d BIGINT;
BEGIN
    SELECT COUNT(*), COUNT(sequence_number), COUNT(DISTINCT sequence_number)
      INTO n, k, d FROM prelim_typed;
    IF n <> 349563 OR k <> n OR d <> n THEN
        RAISE EXCEPTION 'Preliminary is not ready (rows=%, numbered=%, distinct numbers=%). Run load.sql first, completely, with no errors.', n, k, d;
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 1. Lookup tables (code -> name)
-- ---------------------------------------------------------------------
CREATE TABLE agency (
    agency_code  INTEGER PRIMARY KEY,
    agency_name  TEXT NOT NULL,
    agency_abbr  TEXT NOT NULL
);
INSERT INTO agency (agency_code, agency_name, agency_abbr)
SELECT DISTINCT agency_code, agency_name, agency_abbr
FROM prelim_typed WHERE agency_code IS NOT NULL
ORDER BY agency_code;

CREATE TABLE loan_type (
    loan_type       INTEGER PRIMARY KEY,
    loan_type_name  TEXT NOT NULL
);
INSERT INTO loan_type
SELECT DISTINCT loan_type, loan_type_name
FROM prelim_typed WHERE loan_type IS NOT NULL ORDER BY loan_type;

CREATE TABLE property_type (
    property_type       INTEGER PRIMARY KEY,
    property_type_name  TEXT NOT NULL
);
INSERT INTO property_type
SELECT DISTINCT property_type, property_type_name
FROM prelim_typed WHERE property_type IS NOT NULL ORDER BY property_type;

CREATE TABLE loan_purpose (
    loan_purpose       INTEGER PRIMARY KEY,
    loan_purpose_name  TEXT NOT NULL
);
INSERT INTO loan_purpose
SELECT DISTINCT loan_purpose, loan_purpose_name
FROM prelim_typed WHERE loan_purpose IS NOT NULL ORDER BY loan_purpose;

CREATE TABLE owner_occupancy (
    owner_occupancy       INTEGER PRIMARY KEY,
    owner_occupancy_name  TEXT NOT NULL
);
INSERT INTO owner_occupancy
SELECT DISTINCT owner_occupancy, owner_occupancy_name
FROM prelim_typed WHERE owner_occupancy IS NOT NULL ORDER BY owner_occupancy;

CREATE TABLE preapproval (
    preapproval       INTEGER PRIMARY KEY,
    preapproval_name  TEXT NOT NULL
);
INSERT INTO preapproval
SELECT DISTINCT preapproval, preapproval_name
FROM prelim_typed WHERE preapproval IS NOT NULL ORDER BY preapproval;

CREATE TABLE action_taken (
    action_taken       INTEGER PRIMARY KEY,
    action_taken_name  TEXT NOT NULL
);
INSERT INTO action_taken
SELECT DISTINCT action_taken, action_taken_name
FROM prelim_typed WHERE action_taken IS NOT NULL ORDER BY action_taken;

-- applicant and co-applicant share one code list, so one table serves both.
CREATE TABLE ethnicity (
    ethnicity_code  INTEGER PRIMARY KEY,
    ethnicity_name  TEXT NOT NULL
);
INSERT INTO ethnicity (ethnicity_code, ethnicity_name)
SELECT c, n FROM (
    SELECT applicant_ethnicity AS c, applicant_ethnicity_name AS n FROM prelim_typed
    UNION
    SELECT co_applicant_ethnicity, co_applicant_ethnicity_name FROM prelim_typed
) u
WHERE c IS NOT NULL
ORDER BY c;

-- one table for all 10 race columns (applicant 1-5, co-applicant 1-5).
CREATE TABLE race (
    race_code  INTEGER PRIMARY KEY,
    race_name  TEXT NOT NULL
);
INSERT INTO race (race_code, race_name)
SELECT c, n FROM (
    SELECT applicant_race_1 AS c, applicant_race_name_1 AS n FROM prelim_typed
    UNION SELECT applicant_race_2, applicant_race_name_2 FROM prelim_typed
    UNION SELECT applicant_race_3, applicant_race_name_3 FROM prelim_typed
    UNION SELECT applicant_race_4, applicant_race_name_4 FROM prelim_typed
    UNION SELECT applicant_race_5, applicant_race_name_5 FROM prelim_typed
    UNION SELECT co_applicant_race_1, co_applicant_race_name_1 FROM prelim_typed
    UNION SELECT co_applicant_race_2, co_applicant_race_name_2 FROM prelim_typed
    UNION SELECT co_applicant_race_3, co_applicant_race_name_3 FROM prelim_typed
    UNION SELECT co_applicant_race_4, co_applicant_race_name_4 FROM prelim_typed
    UNION SELECT co_applicant_race_5, co_applicant_race_name_5 FROM prelim_typed
) u
WHERE c IS NOT NULL
ORDER BY c;

CREATE TABLE sex (
    sex_code  INTEGER PRIMARY KEY,
    sex_name  TEXT NOT NULL
);
INSERT INTO sex (sex_code, sex_name)
SELECT c, n FROM (
    SELECT applicant_sex AS c, applicant_sex_name AS n FROM prelim_typed
    UNION
    SELECT co_applicant_sex, co_applicant_sex_name FROM prelim_typed
) u
WHERE c IS NOT NULL
ORDER BY c;

CREATE TABLE purchaser_type (
    purchaser_type       INTEGER PRIMARY KEY,
    purchaser_type_name  TEXT NOT NULL
);
INSERT INTO purchaser_type
SELECT DISTINCT purchaser_type, purchaser_type_name
FROM prelim_typed WHERE purchaser_type IS NOT NULL ORDER BY purchaser_type;

-- one table for denial_reason_1..3
CREATE TABLE denial_reason (
    denial_reason_code  INTEGER PRIMARY KEY,
    denial_reason_name  TEXT NOT NULL
);
INSERT INTO denial_reason (denial_reason_code, denial_reason_name)
SELECT c, n FROM (
    SELECT denial_reason_1 AS c, denial_reason_name_1 AS n FROM prelim_typed
    UNION SELECT denial_reason_2, denial_reason_name_2 FROM prelim_typed
    UNION SELECT denial_reason_3, denial_reason_name_3 FROM prelim_typed
) u
WHERE c IS NOT NULL
ORDER BY c;

CREATE TABLE hoepa_status (
    hoepa_status       INTEGER PRIMARY KEY,
    hoepa_status_name  TEXT NOT NULL
);
INSERT INTO hoepa_status
SELECT DISTINCT hoepa_status, hoepa_status_name
FROM prelim_typed WHERE hoepa_status IS NOT NULL ORDER BY hoepa_status;

CREATE TABLE lien_status (
    lien_status       INTEGER PRIMARY KEY,
    lien_status_name  TEXT NOT NULL
);
INSERT INTO lien_status
SELECT DISTINCT lien_status, lien_status_name
FROM prelim_typed WHERE lien_status IS NOT NULL ORDER BY lien_status;

-- msamd_name is blank in the CSV for some msamd codes, so it may be NULL.
CREATE TABLE msamd (
    msamd       INTEGER PRIMARY KEY,
    msamd_name  TEXT
);
INSERT INTO msamd (msamd, msamd_name)
SELECT DISTINCT msamd, msamd_name
FROM prelim_typed WHERE msamd IS NOT NULL ORDER BY msamd;

CREATE TABLE county (
    county_code  INTEGER PRIMARY KEY,
    county_name  TEXT NOT NULL
);
INSERT INTO county (county_code, county_name)
SELECT DISTINCT county_code, county_name
FROM prelim_typed WHERE county_code IS NOT NULL ORDER BY county_code;

-- Only New Jersey for now, but name and abbreviation are kept so more
-- states can be added later.
CREATE TABLE state (
    state_code  INTEGER PRIMARY KEY,
    state_name  TEXT NOT NULL,
    state_abbr  TEXT NOT NULL
);
INSERT INTO state (state_code, state_name, state_abbr)
SELECT DISTINCT state_code, state_name, state_abbr
FROM prelim_typed WHERE state_code IS NOT NULL ORDER BY state_code;

-- ---------------------------------------------------------------------
-- 2. null_columns: columns that are NULL in every row of the CSV.
--    One row, all NULL (aggregates over all-NULL columns return NULL).
--    sequence_number is also blank in the CSV; it is replaced by
--    application.application_id, and export writes it back as blank.
-- ---------------------------------------------------------------------
CREATE TABLE null_columns (
    edit_status_name           TEXT,
    edit_status                INTEGER,
    application_date_indicator INTEGER
);
INSERT INTO null_columns (edit_status_name, edit_status, application_date_indicator)
SELECT MAX(edit_status_name), MAX(edit_status), MAX(application_date_indicator)
FROM prelim_typed;

-- ---------------------------------------------------------------------
-- 3. location: one row per distinct combination of the 10 location columns.
--    location_id is a plain serial number. Columns are nullable because the
--    CSV has missing location values (e.g. 676 rows without county/tract).
--    census_tract_number stays TEXT (leading zeros, e.g. 0103.00).
-- ---------------------------------------------------------------------
CREATE TABLE location (
    location_id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    county_code                    INTEGER REFERENCES county (county_code),
    msamd                          INTEGER  REFERENCES msamd (msamd),
    state_code                     INTEGER NOT NULL REFERENCES state (state_code),
    census_tract_number            TEXT,
    population                     INTEGER,
    minority_population            NUMERIC,
    hud_median_family_income       INTEGER,
    tract_to_msamd_income          NUMERIC,
    number_of_owner_occupied_units INTEGER,
    number_of_1_to_4_family_units  INTEGER
);

INSERT INTO location (county_code, msamd, state_code, census_tract_number,
                      population, minority_population, hud_median_family_income,
                      tract_to_msamd_income, number_of_owner_occupied_units,
                      number_of_1_to_4_family_units)
SELECT DISTINCT county_code, msamd, state_code, census_tract_number,
       population, minority_population, hud_median_family_income,
       tract_to_msamd_income, number_of_owner_occupied_units,
       number_of_1_to_4_family_units
FROM prelim_typed
ORDER BY state_code, county_code, census_tract_number, msamd, population,
         minority_population, hud_median_family_income, tract_to_msamd_income,
         number_of_owner_occupied_units, number_of_1_to_4_family_units;

-- A location may not be stored twice. NULLs are treated as equal here
-- (works on every PostgreSQL version, unlike UNIQUE NULLS NOT DISTINCT).
CREATE UNIQUE INDEX location_unique_idx ON location (
    COALESCE(county_code, -1), COALESCE(msamd, -1), state_code,
    COALESCE(census_tract_number, ''), COALESCE(population, -1),
    COALESCE(minority_population, -1), COALESCE(hud_median_family_income, -1),
    COALESCE(tract_to_msamd_income, -1), COALESCE(number_of_owner_occupied_units, -1),
    COALESCE(number_of_1_to_4_family_units, -1)
);

-- ---------------------------------------------------------------------
-- 4. application: integer / numeric columns plus respondent_id only.
--    NOT NULL only where the CSV never has a blank. Foreign keys: see 4b.
-- ---------------------------------------------------------------------
CREATE TABLE application (
    application_id          INTEGER PRIMARY KEY,   -- = sequence_number 1..N
    as_of_year              INTEGER NOT NULL,
    respondent_id           TEXT NOT NULL,
    agency_code             INTEGER NOT NULL,
    loan_type               INTEGER NOT NULL,
    property_type           INTEGER NOT NULL,
    loan_purpose            INTEGER NOT NULL,
    owner_occupancy         INTEGER NOT NULL,
    loan_amount_000s        INTEGER,
    preapproval             INTEGER NOT NULL,
    action_taken            INTEGER NOT NULL,
    location_id             INTEGER  NOT NULL,
    applicant_ethnicity     INTEGER NOT NULL,
    co_applicant_ethnicity  INTEGER NOT NULL,
    applicant_race_1        INTEGER NOT NULL,
    applicant_race_2        INTEGER,
    applicant_race_3        INTEGER,
    applicant_race_4        INTEGER,
    applicant_race_5        INTEGER,
    co_applicant_race_1     INTEGER NOT NULL,
    co_applicant_race_2     INTEGER,
    co_applicant_race_3     INTEGER,
    co_applicant_race_4     INTEGER,
    co_applicant_race_5     INTEGER,
    applicant_sex           INTEGER NOT NULL,
    co_applicant_sex        INTEGER NOT NULL,
    applicant_income_000s   INTEGER,
    purchaser_type          INTEGER NOT NULL,
    denial_reason_1         INTEGER,
    denial_reason_2         INTEGER,
    denial_reason_3         INTEGER,
    rate_spread             NUMERIC(4,2),
    hoepa_status            INTEGER NOT NULL,
    lien_status             INTEGER NOT NULL
);

-- IS NOT DISTINCT FROM on all 10 location columns: a plain = would drop every
-- row where one of them is NULL (e.g. the 676 rows with no county/tract).
-- The COALESCE equalities add nothing logically (they are implied by the
-- IS NOT DISTINCT FROM tests); they only give the planner something it can
-- hash on, because IS NOT DISTINCT FROM alone forces a slow nested loop.
INSERT INTO application (
    application_id, as_of_year, respondent_id, agency_code, loan_type,
    property_type, loan_purpose, owner_occupancy, loan_amount_000s,
    preapproval, action_taken, location_id, applicant_ethnicity,
    co_applicant_ethnicity, applicant_race_1, applicant_race_2,
    applicant_race_3, applicant_race_4, applicant_race_5, co_applicant_race_1,
    co_applicant_race_2, co_applicant_race_3, co_applicant_race_4,
    co_applicant_race_5, applicant_sex, co_applicant_sex, applicant_income_000s,
    purchaser_type, denial_reason_1, denial_reason_2, denial_reason_3,
    rate_spread, hoepa_status, lien_status)
SELECT p.sequence_number, p.as_of_year, p.respondent_id, p.agency_code, p.loan_type,
       p.property_type, p.loan_purpose, p.owner_occupancy, p.loan_amount_000s,
       p.preapproval, p.action_taken, l.location_id, p.applicant_ethnicity,
       p.co_applicant_ethnicity, p.applicant_race_1, p.applicant_race_2,
       p.applicant_race_3, p.applicant_race_4, p.applicant_race_5, p.co_applicant_race_1,
       p.co_applicant_race_2, p.co_applicant_race_3, p.co_applicant_race_4,
       p.co_applicant_race_5, p.applicant_sex, p.co_applicant_sex, p.applicant_income_000s,
       p.purchaser_type, p.denial_reason_1, p.denial_reason_2, p.denial_reason_3,
       p.rate_spread, p.hoepa_status, p.lien_status
FROM prelim_typed p
JOIN location l
  ON  COALESCE(p.census_tract_number, '') = COALESCE(l.census_tract_number, '')
  AND COALESCE(p.population, -1)          = COALESCE(l.population, -1)
  AND p.county_code                    IS NOT DISTINCT FROM l.county_code
  AND p.msamd                          IS NOT DISTINCT FROM l.msamd
  AND p.state_code                     IS NOT DISTINCT FROM l.state_code
  AND p.census_tract_number            IS NOT DISTINCT FROM l.census_tract_number
  AND p.population                     IS NOT DISTINCT FROM l.population
  AND p.minority_population            IS NOT DISTINCT FROM l.minority_population
  AND p.hud_median_family_income       IS NOT DISTINCT FROM l.hud_median_family_income
  AND p.tract_to_msamd_income          IS NOT DISTINCT FROM l.tract_to_msamd_income
  AND p.number_of_owner_occupied_units IS NOT DISTINCT FROM l.number_of_owner_occupied_units
  AND p.number_of_1_to_4_family_units  IS NOT DISTINCT FROM l.number_of_1_to_4_family_units
ORDER BY p.sequence_number;

-- ---------------------------------------------------------------------
-- 4b. Foreign keys, added AFTER the rows are loaded. Each one is then checked
--     once in bulk instead of once per inserted row, which is much faster
--     (checking ~20 keys per row during the INSERT hit ilab's statement
--     timeout). The finished table is constrained exactly the same.
-- ---------------------------------------------------------------------
ALTER TABLE application ADD CONSTRAINT application_agency_code_fkey FOREIGN KEY (agency_code) REFERENCES agency (agency_code);
ALTER TABLE application ADD CONSTRAINT application_loan_type_fkey FOREIGN KEY (loan_type) REFERENCES loan_type (loan_type);
ALTER TABLE application ADD CONSTRAINT application_property_type_fkey FOREIGN KEY (property_type) REFERENCES property_type (property_type);
ALTER TABLE application ADD CONSTRAINT application_loan_purpose_fkey FOREIGN KEY (loan_purpose) REFERENCES loan_purpose (loan_purpose);
ALTER TABLE application ADD CONSTRAINT application_owner_occupancy_fkey FOREIGN KEY (owner_occupancy) REFERENCES owner_occupancy (owner_occupancy);
ALTER TABLE application ADD CONSTRAINT application_preapproval_fkey FOREIGN KEY (preapproval) REFERENCES preapproval (preapproval);
ALTER TABLE application ADD CONSTRAINT application_action_taken_fkey FOREIGN KEY (action_taken) REFERENCES action_taken (action_taken);
ALTER TABLE application ADD CONSTRAINT application_location_id_fkey FOREIGN KEY (location_id) REFERENCES location (location_id);
ALTER TABLE application ADD CONSTRAINT application_applicant_ethnicity_fkey FOREIGN KEY (applicant_ethnicity) REFERENCES ethnicity (ethnicity_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_ethnicity_fkey FOREIGN KEY (co_applicant_ethnicity) REFERENCES ethnicity (ethnicity_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_race_1_fkey FOREIGN KEY (applicant_race_1) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_race_2_fkey FOREIGN KEY (applicant_race_2) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_race_3_fkey FOREIGN KEY (applicant_race_3) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_race_4_fkey FOREIGN KEY (applicant_race_4) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_race_5_fkey FOREIGN KEY (applicant_race_5) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_race_1_fkey FOREIGN KEY (co_applicant_race_1) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_race_2_fkey FOREIGN KEY (co_applicant_race_2) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_race_3_fkey FOREIGN KEY (co_applicant_race_3) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_race_4_fkey FOREIGN KEY (co_applicant_race_4) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_race_5_fkey FOREIGN KEY (co_applicant_race_5) REFERENCES race (race_code);
ALTER TABLE application ADD CONSTRAINT application_applicant_sex_fkey FOREIGN KEY (applicant_sex) REFERENCES sex (sex_code);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_sex_fkey FOREIGN KEY (co_applicant_sex) REFERENCES sex (sex_code);
ALTER TABLE application ADD CONSTRAINT application_purchaser_type_fkey FOREIGN KEY (purchaser_type) REFERENCES purchaser_type (purchaser_type);
ALTER TABLE application ADD CONSTRAINT application_denial_reason_1_fkey FOREIGN KEY (denial_reason_1) REFERENCES denial_reason (denial_reason_code);
ALTER TABLE application ADD CONSTRAINT application_denial_reason_2_fkey FOREIGN KEY (denial_reason_2) REFERENCES denial_reason (denial_reason_code);
ALTER TABLE application ADD CONSTRAINT application_denial_reason_3_fkey FOREIGN KEY (denial_reason_3) REFERENCES denial_reason (denial_reason_code);
ALTER TABLE application ADD CONSTRAINT application_hoepa_status_fkey FOREIGN KEY (hoepa_status) REFERENCES hoepa_status (hoepa_status);
ALTER TABLE application ADD CONSTRAINT application_lien_status_fkey FOREIGN KEY (lien_status) REFERENCES lien_status (lien_status);

-- ---------------------------------------------------------------------
-- 5. Checks: stop with an error if any row was skipped or duplicated.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    n_prelim  BIGINT;
    n_app     BIGINT;
    n_missing BIGINT;
    n_nullloc BIGINT;
    n_nulls   BIGINT;
BEGIN
    SELECT COUNT(*) INTO n_prelim FROM prelim_typed;
    SELECT COUNT(*) INTO n_app FROM application;
    IF n_app <> 349563 OR n_app <> n_prelim THEN
        RAISE EXCEPTION 'Row count mismatch: Preliminary=%, application=% (expected 349563)',
                        n_prelim, n_app;
    END IF;

    -- every Preliminary row must have exactly one application row
    SELECT COUNT(*) INTO n_missing
    FROM prelim_typed p LEFT JOIN application a ON a.application_id = p.sequence_number
    WHERE a.application_id IS NULL;
    IF n_missing <> 0 THEN
        RAISE EXCEPTION '% Preliminary rows were skipped', n_missing;
    END IF;

    -- rows whose location has a NULL value must still have been carried over
    SELECT COUNT(*) INTO n_nullloc
    FROM application a JOIN location l USING (location_id)
    WHERE l.county_code IS NULL OR l.msamd IS NULL OR l.census_tract_number IS NULL;
    IF n_nullloc <> (SELECT COUNT(*) FROM prelim_typed
                     WHERE county_code IS NULL OR msamd IS NULL OR census_tract_number IS NULL) THEN
        RAISE EXCEPTION 'Rows with NULL location values were not matched correctly';
    END IF;

    SELECT COUNT(*) INTO n_nulls FROM null_columns;
    IF n_nulls <> 1 THEN
        RAISE EXCEPTION 'null_columns must have exactly one row, has %', n_nulls;
    END IF;

    RAISE NOTICE 'OK: application has % rows, none skipped.', n_app;
END $$;

-- Quick report
SELECT 'Preliminary' AS tbl, COUNT(*) AS row_count FROM prelim_typed
UNION ALL SELECT 'application', COUNT(*) FROM application
UNION ALL SELECT 'location', COUNT(*) FROM location
UNION ALL SELECT 'null_columns', COUNT(*) FROM null_columns
UNION ALL SELECT 'agency', COUNT(*) FROM agency
UNION ALL SELECT 'loan_type', COUNT(*) FROM loan_type
UNION ALL SELECT 'property_type', COUNT(*) FROM property_type
UNION ALL SELECT 'loan_purpose', COUNT(*) FROM loan_purpose
UNION ALL SELECT 'owner_occupancy', COUNT(*) FROM owner_occupancy
UNION ALL SELECT 'preapproval', COUNT(*) FROM preapproval
UNION ALL SELECT 'action_taken', COUNT(*) FROM action_taken
UNION ALL SELECT 'ethnicity', COUNT(*) FROM ethnicity
UNION ALL SELECT 'race', COUNT(*) FROM race
UNION ALL SELECT 'sex', COUNT(*) FROM sex
UNION ALL SELECT 'purchaser_type', COUNT(*) FROM purchaser_type
UNION ALL SELECT 'denial_reason', COUNT(*) FROM denial_reason
UNION ALL SELECT 'hoepa_status', COUNT(*) FROM hoepa_status
UNION ALL SELECT 'lien_status', COUNT(*) FROM lien_status
UNION ALL SELECT 'msamd', COUNT(*) FROM msamd
UNION ALL SELECT 'county', COUNT(*) FROM county
UNION ALL SELECT 'state', COUNT(*) FROM state;
