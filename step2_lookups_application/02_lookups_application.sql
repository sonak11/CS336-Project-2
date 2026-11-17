-- =====================================================================
-- CS336 Project 2, Step 2 -- 02_lookups_application.sql
-- Builds the code->name lookup tables, null_columns, location and the
-- main application table FROM the Preliminary table (load.sql).
-- Follows SCHEMA.md exactly (table names, column names, types, keys).
--
-- Run on ilab after load.sql has created and filled Preliminary:
--     postgres
--     \i load.sql                       (only needed once)
--     \i 02_lookups_application.sql
--
-- Design notes
--   * Every *_name column depends on its code column, so names live only in
--     lookup tables; application keeps codes only.
--   * Lookup contents come from the CSV data (SELECT DISTINCT ... WHERE code
--     IS NOT NULL), not from the PDF.
--   * msamd_name is NULLable: msamd 35620 and 37980 have a blank name.
--   * Applicant and co-applicant ethnicity and sex have separate lookup
--     tables (original column names are kept). race and denial_reason are
--     single tables used by all their numbered columns.
--   * application holds only integer / numeric columns plus respondent_id.
--     The race (1-5) and denial-reason (1-3) columns are not in application:
--     the first-normal-form join tables that hold them are built in Step 3.
--   * Types are the same as the final Preliminary table from Project 1
--     (INTEGER, NUMERIC(4,2) rate_spread, NUMERIC census percentages, TEXT
--     respondent_id and census_tract_number).
--   * NOT NULL only where the CSV is never blank.
--   * location_id is found by joining on all 10 location columns with
--     IS NOT DISTINCT FROM, so rows with NULL location values still match.
--   * Preliminary is only READ here (through the temp table prelim_typed).
-- =====================================================================
\set ON_ERROR_STOP on

-- Clean slate so the script can be re-run (also removes tables from older versions).
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
DROP TABLE IF EXISTS purchaser_type CASCADE;
DROP TABLE IF EXISTS hoepa_status CASCADE;
DROP TABLE IF EXISTS lien_status CASCADE;
DROP TABLE IF EXISTS applicant_ethnicity CASCADE;
DROP TABLE IF EXISTS co_applicant_ethnicity CASCADE;
DROP TABLE IF EXISTS applicant_sex CASCADE;
DROP TABLE IF EXISTS co_applicant_sex CASCADE;
DROP TABLE IF EXISTS ethnicity CASCADE;
DROP TABLE IF EXISTS sex CASCADE;
DROP TABLE IF EXISTS race CASCADE;
DROP TABLE IF EXISTS denial_reason CASCADE;
DROP TABLE IF EXISTS msa_md CASCADE;
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
FROM prelim_typed WHERE agency_code IS NOT NULL ORDER BY agency_code;

CREATE TABLE loan_type (
    loan_type       INTEGER PRIMARY KEY,
    loan_type_name  TEXT NOT NULL
);
INSERT INTO loan_type (loan_type, loan_type_name)
SELECT DISTINCT loan_type, loan_type_name
FROM prelim_typed WHERE loan_type IS NOT NULL ORDER BY loan_type;

CREATE TABLE property_type (
    property_type       INTEGER PRIMARY KEY,
    property_type_name  TEXT NOT NULL
);
INSERT INTO property_type (property_type, property_type_name)
SELECT DISTINCT property_type, property_type_name
FROM prelim_typed WHERE property_type IS NOT NULL ORDER BY property_type;

CREATE TABLE loan_purpose (
    loan_purpose       INTEGER PRIMARY KEY,
    loan_purpose_name  TEXT NOT NULL
);
INSERT INTO loan_purpose (loan_purpose, loan_purpose_name)
SELECT DISTINCT loan_purpose, loan_purpose_name
FROM prelim_typed WHERE loan_purpose IS NOT NULL ORDER BY loan_purpose;

CREATE TABLE owner_occupancy (
    owner_occupancy       INTEGER PRIMARY KEY,
    owner_occupancy_name  TEXT NOT NULL
);
INSERT INTO owner_occupancy (owner_occupancy, owner_occupancy_name)
SELECT DISTINCT owner_occupancy, owner_occupancy_name
FROM prelim_typed WHERE owner_occupancy IS NOT NULL ORDER BY owner_occupancy;

CREATE TABLE preapproval (
    preapproval       INTEGER PRIMARY KEY,
    preapproval_name  TEXT NOT NULL
);
INSERT INTO preapproval (preapproval, preapproval_name)
SELECT DISTINCT preapproval, preapproval_name
FROM prelim_typed WHERE preapproval IS NOT NULL ORDER BY preapproval;

CREATE TABLE action_taken (
    action_taken       INTEGER PRIMARY KEY,
    action_taken_name  TEXT NOT NULL
);
INSERT INTO action_taken (action_taken, action_taken_name)
SELECT DISTINCT action_taken, action_taken_name
FROM prelim_typed WHERE action_taken IS NOT NULL ORDER BY action_taken;

CREATE TABLE purchaser_type (
    purchaser_type       INTEGER PRIMARY KEY,
    purchaser_type_name  TEXT NOT NULL
);
INSERT INTO purchaser_type (purchaser_type, purchaser_type_name)
SELECT DISTINCT purchaser_type, purchaser_type_name
FROM prelim_typed WHERE purchaser_type IS NOT NULL ORDER BY purchaser_type;

CREATE TABLE hoepa_status (
    hoepa_status       INTEGER PRIMARY KEY,
    hoepa_status_name  TEXT NOT NULL
);
INSERT INTO hoepa_status (hoepa_status, hoepa_status_name)
SELECT DISTINCT hoepa_status, hoepa_status_name
FROM prelim_typed WHERE hoepa_status IS NOT NULL ORDER BY hoepa_status;

CREATE TABLE lien_status (
    lien_status       INTEGER PRIMARY KEY,
    lien_status_name  TEXT NOT NULL
);
INSERT INTO lien_status (lien_status, lien_status_name)
SELECT DISTINCT lien_status, lien_status_name
FROM prelim_typed WHERE lien_status IS NOT NULL ORDER BY lien_status;

CREATE TABLE applicant_ethnicity (
    applicant_ethnicity       INTEGER PRIMARY KEY,
    applicant_ethnicity_name  TEXT NOT NULL
);
INSERT INTO applicant_ethnicity (applicant_ethnicity, applicant_ethnicity_name)
SELECT DISTINCT applicant_ethnicity, applicant_ethnicity_name
FROM prelim_typed WHERE applicant_ethnicity IS NOT NULL ORDER BY applicant_ethnicity;

CREATE TABLE co_applicant_ethnicity (
    co_applicant_ethnicity       INTEGER PRIMARY KEY,
    co_applicant_ethnicity_name  TEXT NOT NULL
);
INSERT INTO co_applicant_ethnicity (co_applicant_ethnicity, co_applicant_ethnicity_name)
SELECT DISTINCT co_applicant_ethnicity, co_applicant_ethnicity_name
FROM prelim_typed WHERE co_applicant_ethnicity IS NOT NULL ORDER BY co_applicant_ethnicity;

CREATE TABLE applicant_sex (
    applicant_sex       INTEGER PRIMARY KEY,
    applicant_sex_name  TEXT NOT NULL
);
INSERT INTO applicant_sex (applicant_sex, applicant_sex_name)
SELECT DISTINCT applicant_sex, applicant_sex_name
FROM prelim_typed WHERE applicant_sex IS NOT NULL ORDER BY applicant_sex;

CREATE TABLE co_applicant_sex (
    co_applicant_sex       INTEGER PRIMARY KEY,
    co_applicant_sex_name  TEXT NOT NULL
);
INSERT INTO co_applicant_sex (co_applicant_sex, co_applicant_sex_name)
SELECT DISTINCT co_applicant_sex, co_applicant_sex_name
FROM prelim_typed WHERE co_applicant_sex IS NOT NULL ORDER BY co_applicant_sex;

-- one table for all 10 race columns (applicant 1-5, co-applicant 1-5)
CREATE TABLE race (
    race       INTEGER PRIMARY KEY,
    race_name  TEXT NOT NULL
);
INSERT INTO race (race, race_name)
SELECT c, n FROM (
    SELECT applicant_race_1 AS c, applicant_race_name_1 AS n FROM prelim_typed
    UNION SELECT applicant_race_2 AS c, applicant_race_name_2 AS n FROM prelim_typed
    UNION SELECT applicant_race_3 AS c, applicant_race_name_3 AS n FROM prelim_typed
    UNION SELECT applicant_race_4 AS c, applicant_race_name_4 AS n FROM prelim_typed
    UNION SELECT applicant_race_5 AS c, applicant_race_name_5 AS n FROM prelim_typed
    UNION SELECT co_applicant_race_1 AS c, co_applicant_race_name_1 AS n FROM prelim_typed
    UNION SELECT co_applicant_race_2 AS c, co_applicant_race_name_2 AS n FROM prelim_typed
    UNION SELECT co_applicant_race_3 AS c, co_applicant_race_name_3 AS n FROM prelim_typed
    UNION SELECT co_applicant_race_4 AS c, co_applicant_race_name_4 AS n FROM prelim_typed
    UNION SELECT co_applicant_race_5 AS c, co_applicant_race_name_5 AS n FROM prelim_typed
) u
WHERE c IS NOT NULL ORDER BY c;

-- one table for denial_reason_1..3
CREATE TABLE denial_reason (
    denial_reason       INTEGER PRIMARY KEY,
    denial_reason_name  TEXT NOT NULL
);
INSERT INTO denial_reason (denial_reason, denial_reason_name)
SELECT c, n FROM (
    SELECT denial_reason_1 AS c, denial_reason_name_1 AS n FROM prelim_typed
    UNION SELECT denial_reason_2 AS c, denial_reason_name_2 AS n FROM prelim_typed
    UNION SELECT denial_reason_3 AS c, denial_reason_name_3 AS n FROM prelim_typed
) u
WHERE c IS NOT NULL ORDER BY c;

-- msamd_name is blank in the CSV for some msamd codes, so it may be NULL.
CREATE TABLE msa_md (
    msamd       INTEGER PRIMARY KEY,
    msamd_name  TEXT
);
INSERT INTO msa_md (msamd, msamd_name)
SELECT DISTINCT msamd, msamd_name
FROM prelim_typed WHERE msamd IS NOT NULL ORDER BY msamd;

-- Only New Jersey for now; name and abbreviation kept for more states later.
CREATE TABLE state (
    state_code  INTEGER PRIMARY KEY,
    state_name  TEXT NOT NULL,
    state_abbr  TEXT NOT NULL
);
INSERT INTO state (state_code, state_name, state_abbr)
SELECT DISTINCT state_code, state_name, state_abbr
FROM prelim_typed WHERE state_code IS NOT NULL ORDER BY state_code;

-- County codes repeat across states, so the key is (state_code, county_code).
CREATE TABLE county (
    state_code   INTEGER NOT NULL REFERENCES state (state_code),
    county_code  INTEGER NOT NULL,
    county_name  TEXT NOT NULL,
    PRIMARY KEY (state_code, county_code)
);
INSERT INTO county (state_code, county_code, county_name)
SELECT DISTINCT state_code, county_code, county_name
FROM prelim_typed WHERE county_code IS NOT NULL ORDER BY state_code, county_code;

-- ---------------------------------------------------------------------
-- 2. null_columns: columns that are NULL in every row of the CSV.
--    One row, all NULL (aggregates over all-NULL columns return NULL).
--    No primary key: key columns cannot be NULL. sequence_number is also
--    blank in the CSV; it is replaced by application.sequence_number and the
--    export writes it back as blank.
-- ---------------------------------------------------------------------
CREATE TABLE null_columns (
    edit_status                INTEGER,
    edit_status_name           TEXT,
    application_date_indicator INTEGER
);
INSERT INTO null_columns (edit_status, edit_status_name, application_date_indicator)
SELECT MAX(edit_status), MAX(edit_status_name), MAX(application_date_indicator)
FROM prelim_typed;

-- ---------------------------------------------------------------------
-- 3. location: one row per distinct combination of the 10 location columns.
--    location_id is a serial number. All other columns except state_code are
--    nullable (the CSV has missing location values).
--    census_tract_number stays TEXT (leading zeros, e.g. 0103.00).
-- ---------------------------------------------------------------------
CREATE TABLE location (
    location_id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_code                     INTEGER NOT NULL REFERENCES state (state_code),
    county_code                    INTEGER,
    msamd                          INTEGER REFERENCES msa_md (msamd),
    census_tract_number            TEXT,
    population                     INTEGER,
    minority_population            NUMERIC,
    hud_median_family_income       INTEGER,
    tract_to_msamd_income          NUMERIC,
    number_of_owner_occupied_units INTEGER,
    number_of_1_to_4_family_units  INTEGER,
    FOREIGN KEY (state_code, county_code) REFERENCES county (state_code, county_code)
);

INSERT INTO location (state_code, county_code, msamd, census_tract_number,
                      population, minority_population, hud_median_family_income,
                      tract_to_msamd_income, number_of_owner_occupied_units,
                      number_of_1_to_4_family_units)
SELECT DISTINCT state_code, county_code, msamd, census_tract_number,
       population, minority_population, hud_median_family_income,
       tract_to_msamd_income, number_of_owner_occupied_units,
       number_of_1_to_4_family_units
FROM prelim_typed
ORDER BY state_code, county_code, census_tract_number, msamd, population,
         minority_population, hud_median_family_income, tract_to_msamd_income,
         number_of_owner_occupied_units, number_of_1_to_4_family_units;

-- All ten location columns are UNIQUE together, with NULLs counted as equal.
-- UNIQUE NULLS NOT DISTINCT needs PostgreSQL 15+; on an older server the
-- same rule is enforced with a unique index on COALESCE(...) expressions.
DO $$
BEGIN
    IF current_setting('server_version_num')::INT >= 150000 THEN
        ALTER TABLE location ADD CONSTRAINT location_unique
            UNIQUE NULLS NOT DISTINCT (state_code, county_code, msamd,
                census_tract_number, population, minority_population,
                hud_median_family_income, tract_to_msamd_income,
                number_of_owner_occupied_units, number_of_1_to_4_family_units);
    ELSE
        CREATE UNIQUE INDEX location_unique ON location (
            state_code, COALESCE(county_code, -1), COALESCE(msamd, -1),
            COALESCE(census_tract_number, ''), COALESCE(population, -1),
            COALESCE(minority_population, -1), COALESCE(hud_median_family_income, -1),
            COALESCE(tract_to_msamd_income, -1), COALESCE(number_of_owner_occupied_units, -1),
            COALESCE(number_of_1_to_4_family_units, -1));
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 4. application: integer / numeric columns plus respondent_id only.
--    Foreign keys are added in 4b, after loading (much faster).
-- ---------------------------------------------------------------------
CREATE TABLE application (
    sequence_number         INTEGER PRIMARY KEY,   -- 1..N in original file order
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
    location_id             INTEGER NOT NULL,
    applicant_ethnicity     INTEGER NOT NULL,
    co_applicant_ethnicity  INTEGER NOT NULL,
    applicant_sex           INTEGER NOT NULL,
    co_applicant_sex        INTEGER NOT NULL,
    applicant_income_000s   INTEGER,
    purchaser_type          INTEGER NOT NULL,
    rate_spread             NUMERIC(4,2),
    hoepa_status            INTEGER NOT NULL,
    lien_status             INTEGER NOT NULL
);

-- IS NOT DISTINCT FROM on all 10 location columns: a plain = would drop every
-- row where one of them is NULL (e.g. the 676 rows with no county/tract).
-- The two COALESCE equalities add nothing logically (the IS NOT DISTINCT FROM
-- tests already imply them); they only let the planner hash-join instead of a
-- very slow nested loop.
INSERT INTO application (
    sequence_number, as_of_year, respondent_id, agency_code, loan_type,
    property_type, loan_purpose, owner_occupancy, loan_amount_000s,
    preapproval, action_taken, location_id, applicant_ethnicity,
    co_applicant_ethnicity, applicant_sex, co_applicant_sex,
    applicant_income_000s, purchaser_type, rate_spread, hoepa_status, lien_status)
SELECT p.sequence_number, p.as_of_year, p.respondent_id, p.agency_code, p.loan_type,
       p.property_type, p.loan_purpose, p.owner_occupancy, p.loan_amount_000s,
       p.preapproval, p.action_taken, l.location_id, p.applicant_ethnicity,
       p.co_applicant_ethnicity, p.applicant_sex, p.co_applicant_sex,
       p.applicant_income_000s, p.purchaser_type, p.rate_spread, p.hoepa_status,
       p.lien_status
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
-- 4b. Foreign keys, added AFTER the rows are loaded: each is then checked
--     once in bulk instead of once per row (avoids ilab's statement timeout).
-- ---------------------------------------------------------------------
ALTER TABLE application ADD CONSTRAINT application_agency_code_fkey FOREIGN KEY (agency_code) REFERENCES agency (agency_code);
ALTER TABLE application ADD CONSTRAINT application_loan_type_fkey FOREIGN KEY (loan_type) REFERENCES loan_type (loan_type);
ALTER TABLE application ADD CONSTRAINT application_property_type_fkey FOREIGN KEY (property_type) REFERENCES property_type (property_type);
ALTER TABLE application ADD CONSTRAINT application_loan_purpose_fkey FOREIGN KEY (loan_purpose) REFERENCES loan_purpose (loan_purpose);
ALTER TABLE application ADD CONSTRAINT application_owner_occupancy_fkey FOREIGN KEY (owner_occupancy) REFERENCES owner_occupancy (owner_occupancy);
ALTER TABLE application ADD CONSTRAINT application_preapproval_fkey FOREIGN KEY (preapproval) REFERENCES preapproval (preapproval);
ALTER TABLE application ADD CONSTRAINT application_action_taken_fkey FOREIGN KEY (action_taken) REFERENCES action_taken (action_taken);
ALTER TABLE application ADD CONSTRAINT application_location_id_fkey FOREIGN KEY (location_id) REFERENCES location (location_id);
ALTER TABLE application ADD CONSTRAINT application_applicant_ethnicity_fkey FOREIGN KEY (applicant_ethnicity) REFERENCES applicant_ethnicity (applicant_ethnicity);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_ethnicity_fkey FOREIGN KEY (co_applicant_ethnicity) REFERENCES co_applicant_ethnicity (co_applicant_ethnicity);
ALTER TABLE application ADD CONSTRAINT application_applicant_sex_fkey FOREIGN KEY (applicant_sex) REFERENCES applicant_sex (applicant_sex);
ALTER TABLE application ADD CONSTRAINT application_co_applicant_sex_fkey FOREIGN KEY (co_applicant_sex) REFERENCES co_applicant_sex (co_applicant_sex);
ALTER TABLE application ADD CONSTRAINT application_purchaser_type_fkey FOREIGN KEY (purchaser_type) REFERENCES purchaser_type (purchaser_type);
ALTER TABLE application ADD CONSTRAINT application_hoepa_status_fkey FOREIGN KEY (hoepa_status) REFERENCES hoepa_status (hoepa_status);
ALTER TABLE application ADD CONSTRAINT application_lien_status_fkey FOREIGN KEY (lien_status) REFERENCES lien_status (lien_status);
