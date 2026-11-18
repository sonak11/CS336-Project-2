-- =====================================================================
-- CS336 Project 2: HMDA 2017 New Jersey -- 03_constraints.sql   (Task 4)
--
-- Adds the integrity constraints to the normalized database:
--   1. Foreign keys (every code column -> its lookup table, every
--      first-normal-form join table -> application and its lookup table,
--      location -> state / county / msa_md, county -> state).
--   2. NOT NULL on every column that is never blank in the CSV.
--   3. UNIQUE on location's ten columns; null_columns limited to one row.
--   4. CHECK constraints on the 1NF join tables (slot ranges; no race 8
--      "No co-applicant" for an applicant).
--
-- Run on ilab after 01_location_1nf.sql and 02_lookups_application.sql:
--     \i 03_constraints.sql
--
-- It can be re-run, and it works whether or not 02 already created some of
-- these constraints: each constraint is dropped (IF EXISTS) and added again
-- under a fixed name, and SET NOT NULL does nothing on a column that is
-- already NOT NULL. Everything runs in one transaction, so a failure leaves
-- the database unchanged.
--
-- How the NOT NULL columns were chosen: section 0 counts the blanks in every
-- column that could be blank. A column gets NOT NULL only if its count is 0.
-- The columns left nullable, and their blank counts in the 349,563-row CSV:
--   application.loan_amount_000s        154 blank
--   application.applicant_income_000s   50,515 blank
--   application.rate_spread             340,747 blank
--   location: county_code, msamd, census_tract_number, population,
--     minority_population, hud_median_family_income, tract_to_msamd_income,
--     number_of_owner_occupied_units, number_of_1_to_4_family_units
--     (blank for applications with no tract information)
--   msa_md.msamd_name                    blank for msamd 35620 and 37980
--   null_columns (all three columns)     blank in every row
--
-- References: PostgreSQL docs, ALTER TABLE:
--   https://www.postgresql.org/docs/current/sql-altertable.html
-- AI assistance is described in README.txt, section 2.
-- =====================================================================
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------
-- 0. Data check behind the NOT NULL decisions (read-only).
--    Expected: 154 | 50515 | 340747 | 676 | 0 | 0 | 0
-- ---------------------------------------------------------------------
SELECT count(*) FILTER (WHERE a.loan_amount_000s IS NULL)      AS blank_loan_amount,
       count(*) FILTER (WHERE a.applicant_income_000s IS NULL) AS blank_income,
       count(*) FILTER (WHERE a.rate_spread IS NULL)           AS blank_rate_spread,
       count(*) FILTER (WHERE l.county_code IS NULL)           AS blank_county,
       (SELECT count(*) FROM applicant_race     WHERE race IS NULL)          AS blank_applicant_race,
       (SELECT count(*) FROM co_applicant_race  WHERE race IS NULL)          AS blank_co_applicant_race,
       (SELECT count(*) FROM application_denial WHERE denial_reason IS NULL) AS blank_denial_reason
FROM application a
JOIN location l USING (location_id);

BEGIN;

-- ---------------------------------------------------------------------
-- 1. NOT NULL
-- ---------------------------------------------------------------------
ALTER TABLE application
    ALTER COLUMN as_of_year             SET NOT NULL,
    ALTER COLUMN respondent_id          SET NOT NULL,
    ALTER COLUMN agency_code            SET NOT NULL,
    ALTER COLUMN loan_type              SET NOT NULL,
    ALTER COLUMN property_type          SET NOT NULL,
    ALTER COLUMN loan_purpose           SET NOT NULL,
    ALTER COLUMN owner_occupancy        SET NOT NULL,
    ALTER COLUMN preapproval            SET NOT NULL,
    ALTER COLUMN action_taken           SET NOT NULL,
    ALTER COLUMN location_id            SET NOT NULL,
    ALTER COLUMN applicant_ethnicity    SET NOT NULL,
    ALTER COLUMN co_applicant_ethnicity SET NOT NULL,
    ALTER COLUMN applicant_sex          SET NOT NULL,
    ALTER COLUMN co_applicant_sex       SET NOT NULL,
    ALTER COLUMN purchaser_type         SET NOT NULL,
    ALTER COLUMN hoepa_status           SET NOT NULL,
    ALTER COLUMN lien_status            SET NOT NULL;

-- The join tables only hold non-blank values, so the code is never NULL.
ALTER TABLE applicant_race     ALTER COLUMN race          SET NOT NULL;
ALTER TABLE co_applicant_race  ALTER COLUMN race          SET NOT NULL;
ALTER TABLE application_denial ALTER COLUMN denial_reason SET NOT NULL;

-- Every application has a state, so every location row does too.
ALTER TABLE location ALTER COLUMN state_code SET NOT NULL;

-- Lookup tables: every code has a name (msa_md.msamd_name excepted, see above).
ALTER TABLE agency          ALTER COLUMN agency_name SET NOT NULL,
                            ALTER COLUMN agency_abbr SET NOT NULL;
ALTER TABLE loan_type       ALTER COLUMN loan_type_name       SET NOT NULL;
ALTER TABLE property_type   ALTER COLUMN property_type_name   SET NOT NULL;
ALTER TABLE loan_purpose    ALTER COLUMN loan_purpose_name    SET NOT NULL;
ALTER TABLE owner_occupancy ALTER COLUMN owner_occupancy_name SET NOT NULL;
ALTER TABLE preapproval     ALTER COLUMN preapproval_name     SET NOT NULL;
ALTER TABLE action_taken    ALTER COLUMN action_taken_name    SET NOT NULL;
ALTER TABLE purchaser_type  ALTER COLUMN purchaser_type_name  SET NOT NULL;
ALTER TABLE hoepa_status    ALTER COLUMN hoepa_status_name    SET NOT NULL;
ALTER TABLE lien_status     ALTER COLUMN lien_status_name     SET NOT NULL;
ALTER TABLE applicant_ethnicity    ALTER COLUMN applicant_ethnicity_name    SET NOT NULL;
ALTER TABLE co_applicant_ethnicity ALTER COLUMN co_applicant_ethnicity_name SET NOT NULL;
ALTER TABLE applicant_sex          ALTER COLUMN applicant_sex_name          SET NOT NULL;
ALTER TABLE co_applicant_sex       ALTER COLUMN co_applicant_sex_name       SET NOT NULL;
ALTER TABLE race            ALTER COLUMN race_name            SET NOT NULL;
ALTER TABLE denial_reason   ALTER COLUMN denial_reason_name   SET NOT NULL;
ALTER TABLE state           ALTER COLUMN state_name SET NOT NULL,
                            ALTER COLUMN state_abbr SET NOT NULL;
ALTER TABLE county          ALTER COLUMN county_name SET NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Foreign keys
-- ---------------------------------------------------------------------
-- application -> lookup tables and location
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_agency_code_fkey,
    ADD CONSTRAINT application_agency_code_fkey FOREIGN KEY (agency_code) REFERENCES agency (agency_code);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_loan_type_fkey,
    ADD CONSTRAINT application_loan_type_fkey FOREIGN KEY (loan_type) REFERENCES loan_type (loan_type);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_property_type_fkey,
    ADD CONSTRAINT application_property_type_fkey FOREIGN KEY (property_type) REFERENCES property_type (property_type);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_loan_purpose_fkey,
    ADD CONSTRAINT application_loan_purpose_fkey FOREIGN KEY (loan_purpose) REFERENCES loan_purpose (loan_purpose);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_owner_occupancy_fkey,
    ADD CONSTRAINT application_owner_occupancy_fkey FOREIGN KEY (owner_occupancy) REFERENCES owner_occupancy (owner_occupancy);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_preapproval_fkey,
    ADD CONSTRAINT application_preapproval_fkey FOREIGN KEY (preapproval) REFERENCES preapproval (preapproval);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_action_taken_fkey,
    ADD CONSTRAINT application_action_taken_fkey FOREIGN KEY (action_taken) REFERENCES action_taken (action_taken);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_location_id_fkey,
    ADD CONSTRAINT application_location_id_fkey FOREIGN KEY (location_id) REFERENCES location (location_id);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_applicant_ethnicity_fkey,
    ADD CONSTRAINT application_applicant_ethnicity_fkey FOREIGN KEY (applicant_ethnicity) REFERENCES applicant_ethnicity (applicant_ethnicity);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_co_applicant_ethnicity_fkey,
    ADD CONSTRAINT application_co_applicant_ethnicity_fkey FOREIGN KEY (co_applicant_ethnicity) REFERENCES co_applicant_ethnicity (co_applicant_ethnicity);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_applicant_sex_fkey,
    ADD CONSTRAINT application_applicant_sex_fkey FOREIGN KEY (applicant_sex) REFERENCES applicant_sex (applicant_sex);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_co_applicant_sex_fkey,
    ADD CONSTRAINT application_co_applicant_sex_fkey FOREIGN KEY (co_applicant_sex) REFERENCES co_applicant_sex (co_applicant_sex);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_purchaser_type_fkey,
    ADD CONSTRAINT application_purchaser_type_fkey FOREIGN KEY (purchaser_type) REFERENCES purchaser_type (purchaser_type);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_hoepa_status_fkey,
    ADD CONSTRAINT application_hoepa_status_fkey FOREIGN KEY (hoepa_status) REFERENCES hoepa_status (hoepa_status);
ALTER TABLE application DROP CONSTRAINT IF EXISTS application_lien_status_fkey,
    ADD CONSTRAINT application_lien_status_fkey FOREIGN KEY (lien_status) REFERENCES lien_status (lien_status);

-- location -> state, county (composite key), msa_md; county -> state
ALTER TABLE location DROP CONSTRAINT IF EXISTS location_state_code_fkey,
    ADD CONSTRAINT location_state_code_fkey FOREIGN KEY (state_code) REFERENCES state (state_code);
ALTER TABLE location DROP CONSTRAINT IF EXISTS location_state_code_county_code_fkey,
    ADD CONSTRAINT location_state_code_county_code_fkey FOREIGN KEY (state_code, county_code) REFERENCES county (state_code, county_code);
ALTER TABLE location DROP CONSTRAINT IF EXISTS location_msamd_fkey,
    ADD CONSTRAINT location_msamd_fkey FOREIGN KEY (msamd) REFERENCES msa_md (msamd);
ALTER TABLE county DROP CONSTRAINT IF EXISTS county_state_code_fkey,
    ADD CONSTRAINT county_state_code_fkey FOREIGN KEY (state_code) REFERENCES state (state_code);

-- first-normal-form join tables -> application and their lookup table
ALTER TABLE applicant_race DROP CONSTRAINT IF EXISTS applicant_race_sequence_number_fkey,
    ADD CONSTRAINT applicant_race_sequence_number_fkey FOREIGN KEY (sequence_number) REFERENCES application (sequence_number);
ALTER TABLE applicant_race DROP CONSTRAINT IF EXISTS applicant_race_race_fkey,
    ADD CONSTRAINT applicant_race_race_fkey FOREIGN KEY (race) REFERENCES race (race);

ALTER TABLE co_applicant_race DROP CONSTRAINT IF EXISTS co_applicant_race_sequence_number_fkey,
    ADD CONSTRAINT co_applicant_race_sequence_number_fkey FOREIGN KEY (sequence_number) REFERENCES application (sequence_number);
ALTER TABLE co_applicant_race DROP CONSTRAINT IF EXISTS co_applicant_race_race_fkey,
    ADD CONSTRAINT co_applicant_race_race_fkey FOREIGN KEY (race) REFERENCES race (race);

ALTER TABLE application_denial DROP CONSTRAINT IF EXISTS application_denial_sequence_number_fkey,
    ADD CONSTRAINT application_denial_sequence_number_fkey FOREIGN KEY (sequence_number) REFERENCES application (sequence_number);
ALTER TABLE application_denial DROP CONSTRAINT IF EXISTS application_denial_denial_reason_fkey,
    ADD CONSTRAINT application_denial_denial_reason_fkey FOREIGN KEY (denial_reason) REFERENCES denial_reason (denial_reason);

-- ---------------------------------------------------------------------
-- 3. UNIQUE: the ten location columns together identify one location
--    (NULLs count as equal). UNIQUE NULLS NOT DISTINCT needs PostgreSQL 15+;
--    on an older server the same rule is a unique index on COALESCE(...).
-- ---------------------------------------------------------------------
ALTER TABLE location DROP CONSTRAINT IF EXISTS location_unique;
DROP INDEX IF EXISTS location_unique;
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

-- null_columns must hold exactly one row: the export cross-joins it, so a
-- second row would duplicate every exported row. A unique index on a
-- constant expression allows only one row.
DROP INDEX IF EXISTS null_columns_one_row;
CREATE UNIQUE INDEX null_columns_one_row ON null_columns ((true));

-- ---------------------------------------------------------------------
-- 4. CHECK: position numbers stay inside the original column ranges
--    (applicant_race_1..5, co_applicant_race_1..5, denial_reason_1..3).
-- ---------------------------------------------------------------------
ALTER TABLE applicant_race DROP CONSTRAINT IF EXISTS applicant_race_number_check,
    ADD CONSTRAINT applicant_race_number_check CHECK (race_number BETWEEN 1 AND 5);
ALTER TABLE co_applicant_race DROP CONSTRAINT IF EXISTS co_applicant_race_number_check,
    ADD CONSTRAINT co_applicant_race_number_check CHECK (race_number BETWEEN 1 AND 5);
ALTER TABLE application_denial DROP CONSTRAINT IF EXISTS application_denial_number_check,
    ADD CONSTRAINT application_denial_number_check CHECK (denial_reason_number BETWEEN 1 AND 3);

-- Race code 8 means "No co-applicant", so it is valid for a co-applicant only.
-- (applicant_race never contains 8 in the CSV.)
ALTER TABLE applicant_race DROP CONSTRAINT IF EXISTS applicant_race_not_no_coapplicant,
    ADD CONSTRAINT applicant_race_not_no_coapplicant CHECK (race <> 8);

COMMIT;

-- ---------------------------------------------------------------------
-- 5. Result: list every foreign key now in place (expect 25 rows).
-- ---------------------------------------------------------------------
SELECT conrelid::regclass AS table_name, conname AS constraint_name,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'public'::regnamespace
ORDER BY 1, 2;
