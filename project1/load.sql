-- =====================================================================
-- CS336 Project: HMDA 2017 New Jersey -- load.sql
-- Creates the Preliminary table, loads the CSV, numbers sequence_number
-- 1..N in file order, casts every column to its final type, and makes
-- sequence_number the primary key.
--
-- Run on ilab from the folder that holds this script and the CSV
-- hmda_2017_nj_all-records_labels.csv:
--     postgres
--     \i load.sql
--
-- References (cited per the assignment's academic-honesty rules):
--   PostgreSQL docs, COPY (CSV format, HEADER, FORCE_NULL):
--     https://www.postgresql.org/docs/current/sql-copy.html
--   PostgreSQL docs, psql \copy and \i:
--     https://www.postgresql.org/docs/current/app-psql.html
--   PostgreSQL docs, ALTER TABLE ... ALTER COLUMN ... TYPE ... USING:
--     https://www.postgresql.org/docs/current/sql-altertable.html
--   AI assistance is described in README.txt, section 2.
-- =====================================================================
\set ON_ERROR_STOP on

-- Step 1: staging table. Every column starts as TEXT so the raw CSV loads
-- without errors; the columns are cast to their real types in Step 4.
DROP TABLE IF EXISTS Preliminary;
CREATE TABLE Preliminary (
    "as_of_year" TEXT,
    "respondent_id" TEXT,
    "agency_name" TEXT,
    "agency_abbr" TEXT,
    "agency_code" TEXT,
    "loan_type_name" TEXT,
    "loan_type" TEXT,
    "property_type_name" TEXT,
    "property_type" TEXT,
    "loan_purpose_name" TEXT,
    "loan_purpose" TEXT,
    "owner_occupancy_name" TEXT,
    "owner_occupancy" TEXT,
    "loan_amount_000s" TEXT,
    "preapproval_name" TEXT,
    "preapproval" TEXT,
    "action_taken_name" TEXT,
    "action_taken" TEXT,
    "msamd_name" TEXT,
    "msamd" TEXT,
    "state_name" TEXT,
    "state_abbr" TEXT,
    "state_code" TEXT,
    "county_name" TEXT,
    "county_code" TEXT,
    "census_tract_number" TEXT,
    "applicant_ethnicity_name" TEXT,
    "applicant_ethnicity" TEXT,
    "co_applicant_ethnicity_name" TEXT,
    "co_applicant_ethnicity" TEXT,
    "applicant_race_name_1" TEXT,
    "applicant_race_1" TEXT,
    "applicant_race_name_2" TEXT,
    "applicant_race_2" TEXT,
    "applicant_race_name_3" TEXT,
    "applicant_race_3" TEXT,
    "applicant_race_name_4" TEXT,
    "applicant_race_4" TEXT,
    "applicant_race_name_5" TEXT,
    "applicant_race_5" TEXT,
    "co_applicant_race_name_1" TEXT,
    "co_applicant_race_1" TEXT,
    "co_applicant_race_name_2" TEXT,
    "co_applicant_race_2" TEXT,
    "co_applicant_race_name_3" TEXT,
    "co_applicant_race_3" TEXT,
    "co_applicant_race_name_4" TEXT,
    "co_applicant_race_4" TEXT,
    "co_applicant_race_name_5" TEXT,
    "co_applicant_race_5" TEXT,
    "applicant_sex_name" TEXT,
    "applicant_sex" TEXT,
    "co_applicant_sex_name" TEXT,
    "co_applicant_sex" TEXT,
    "applicant_income_000s" TEXT,
    "purchaser_type_name" TEXT,
    "purchaser_type" TEXT,
    "denial_reason_name_1" TEXT,
    "denial_reason_1" TEXT,
    "denial_reason_name_2" TEXT,
    "denial_reason_2" TEXT,
    "denial_reason_name_3" TEXT,
    "denial_reason_3" TEXT,
    "rate_spread" TEXT,
    "hoepa_status_name" TEXT,
    "hoepa_status" TEXT,
    "lien_status_name" TEXT,
    "lien_status" TEXT,
    "edit_status_name" TEXT,
    "edit_status" TEXT,
    "sequence_number" TEXT,
    "population" TEXT,
    "minority_population" TEXT,
    "hud_median_family_income" TEXT,
    "tract_to_msamd_income" TEXT,
    "number_of_owner_occupied_units" TEXT,
    "number_of_1_to_4_family_units" TEXT,
    "application_date_indicator" TEXT
);

-- Step 2: helper row counter. COPY fills it from a sequence as each row is
-- read, so its values 1..N follow the original file order exactly.
ALTER TABLE Preliminary ADD COLUMN _rowid BIGSERIAL;

-- Step 3: load the CSV. FORCE_NULL turns quoted blank fields ("") into NULL while loading, so missing
-- values are real NULLs. export.sql's COALESCE writes them back as "".
\copy Preliminary (as_of_year, respondent_id, agency_name, agency_abbr, agency_code, loan_type_name, loan_type, property_type_name, property_type, loan_purpose_name, loan_purpose, owner_occupancy_name, owner_occupancy, loan_amount_000s, preapproval_name, preapproval, action_taken_name, action_taken, msamd_name, msamd, state_name, state_abbr, state_code, county_name, county_code, census_tract_number, applicant_ethnicity_name, applicant_ethnicity, co_applicant_ethnicity_name, co_applicant_ethnicity, applicant_race_name_1, applicant_race_1, applicant_race_name_2, applicant_race_2, applicant_race_name_3, applicant_race_3, applicant_race_name_4, applicant_race_4, applicant_race_name_5, applicant_race_5, co_applicant_race_name_1, co_applicant_race_1, co_applicant_race_name_2, co_applicant_race_2, co_applicant_race_name_3, co_applicant_race_3, co_applicant_race_name_4, co_applicant_race_4, co_applicant_race_name_5, co_applicant_race_5, applicant_sex_name, applicant_sex, co_applicant_sex_name, co_applicant_sex, applicant_income_000s, purchaser_type_name, purchaser_type, denial_reason_name_1, denial_reason_1, denial_reason_name_2, denial_reason_2, denial_reason_name_3, denial_reason_3, rate_spread, hoepa_status_name, hoepa_status, lien_status_name, lien_status, edit_status_name, edit_status, sequence_number, population, minority_population, hud_median_family_income, tract_to_msamd_income, number_of_owner_occupied_units, number_of_1_to_4_family_units, application_date_indicator) FROM 'hmda_2017_nj_all-records_labels.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL (as_of_year, respondent_id, agency_name, agency_abbr, agency_code, loan_type_name, loan_type, property_type_name, property_type, loan_purpose_name, loan_purpose, owner_occupancy_name, owner_occupancy, loan_amount_000s, preapproval_name, preapproval, action_taken_name, action_taken, msamd_name, msamd, state_name, state_abbr, state_code, county_name, county_code, census_tract_number, applicant_ethnicity_name, applicant_ethnicity, co_applicant_ethnicity_name, co_applicant_ethnicity, applicant_race_name_1, applicant_race_1, applicant_race_name_2, applicant_race_2, applicant_race_name_3, applicant_race_3, applicant_race_name_4, applicant_race_4, applicant_race_name_5, applicant_race_5, co_applicant_race_name_1, co_applicant_race_1, co_applicant_race_name_2, co_applicant_race_2, co_applicant_race_name_3, co_applicant_race_3, co_applicant_race_name_4, co_applicant_race_4, co_applicant_race_name_5, co_applicant_race_5, applicant_sex_name, applicant_sex, co_applicant_sex_name, co_applicant_sex, applicant_income_000s, purchaser_type_name, purchaser_type, denial_reason_name_1, denial_reason_1, denial_reason_name_2, denial_reason_2, denial_reason_name_3, denial_reason_3, rate_spread, hoepa_status_name, hoepa_status, lien_status_name, lien_status, edit_status_name, edit_status, sequence_number, population, minority_population, hud_median_family_income, tract_to_msamd_income, number_of_owner_occupied_units, number_of_1_to_4_family_units, application_date_indicator));

-- Step 4: sequence number logic. sequence_number is blank in every row of the
-- source file, so it is filled with 1..N in the original file order.
UPDATE Preliminary SET sequence_number = _rowid::TEXT;
ALTER TABLE Preliminary DROP COLUMN _rowid;

-- Step 5: cast each column to its correct type.
-- Codes, counts, years and amounts -> INTEGER (blank -> NULL).
-- respondent_id and census_tract_number stay TEXT: lar_record_format.pdf lists
-- them as Alphanumeric, respondent_id contains hyphens, and both keep leading
-- zeros that must survive the round trip (e.g. 0103.00). Label columns (*_name,
-- state_abbr, agency_abbr) are English text and stay TEXT.
ALTER TABLE Preliminary
    ALTER COLUMN as_of_year                     TYPE INTEGER USING NULLIF(as_of_year, '')::INTEGER,
    ALTER COLUMN agency_code                    TYPE INTEGER USING NULLIF(agency_code, '')::INTEGER,
    ALTER COLUMN msamd                          TYPE INTEGER USING NULLIF(msamd, '')::INTEGER,
    ALTER COLUMN state_code                     TYPE INTEGER USING NULLIF(state_code, '')::INTEGER,
    ALTER COLUMN county_code                    TYPE INTEGER USING NULLIF(county_code, '')::INTEGER,
    ALTER COLUMN loan_type                      TYPE INTEGER USING NULLIF(loan_type, '')::INTEGER,
    ALTER COLUMN property_type                  TYPE INTEGER USING NULLIF(property_type, '')::INTEGER,
    ALTER COLUMN loan_purpose                   TYPE INTEGER USING NULLIF(loan_purpose, '')::INTEGER,
    ALTER COLUMN owner_occupancy                TYPE INTEGER USING NULLIF(owner_occupancy, '')::INTEGER,
    ALTER COLUMN loan_amount_000s               TYPE INTEGER USING NULLIF(loan_amount_000s, '')::INTEGER,
    ALTER COLUMN preapproval                    TYPE INTEGER USING NULLIF(preapproval, '')::INTEGER,
    ALTER COLUMN action_taken                   TYPE INTEGER USING NULLIF(action_taken, '')::INTEGER,
    ALTER COLUMN applicant_ethnicity            TYPE INTEGER USING NULLIF(applicant_ethnicity, '')::INTEGER,
    ALTER COLUMN co_applicant_ethnicity         TYPE INTEGER USING NULLIF(co_applicant_ethnicity, '')::INTEGER,
    ALTER COLUMN applicant_race_1               TYPE INTEGER USING NULLIF(applicant_race_1, '')::INTEGER,
    ALTER COLUMN applicant_race_2               TYPE INTEGER USING NULLIF(applicant_race_2, '')::INTEGER,
    ALTER COLUMN applicant_race_3               TYPE INTEGER USING NULLIF(applicant_race_3, '')::INTEGER,
    ALTER COLUMN applicant_race_4               TYPE INTEGER USING NULLIF(applicant_race_4, '')::INTEGER,
    ALTER COLUMN applicant_race_5               TYPE INTEGER USING NULLIF(applicant_race_5, '')::INTEGER,
    ALTER COLUMN co_applicant_race_1            TYPE INTEGER USING NULLIF(co_applicant_race_1, '')::INTEGER,
    ALTER COLUMN co_applicant_race_2            TYPE INTEGER USING NULLIF(co_applicant_race_2, '')::INTEGER,
    ALTER COLUMN co_applicant_race_3            TYPE INTEGER USING NULLIF(co_applicant_race_3, '')::INTEGER,
    ALTER COLUMN co_applicant_race_4            TYPE INTEGER USING NULLIF(co_applicant_race_4, '')::INTEGER,
    ALTER COLUMN co_applicant_race_5            TYPE INTEGER USING NULLIF(co_applicant_race_5, '')::INTEGER,
    ALTER COLUMN applicant_sex                  TYPE INTEGER USING NULLIF(applicant_sex, '')::INTEGER,
    ALTER COLUMN co_applicant_sex               TYPE INTEGER USING NULLIF(co_applicant_sex, '')::INTEGER,
    ALTER COLUMN applicant_income_000s          TYPE INTEGER USING NULLIF(applicant_income_000s, '')::INTEGER,
    ALTER COLUMN purchaser_type                 TYPE INTEGER USING NULLIF(purchaser_type, '')::INTEGER,
    ALTER COLUMN denial_reason_1                TYPE INTEGER USING NULLIF(denial_reason_1, '')::INTEGER,
    ALTER COLUMN denial_reason_2                TYPE INTEGER USING NULLIF(denial_reason_2, '')::INTEGER,
    ALTER COLUMN denial_reason_3                TYPE INTEGER USING NULLIF(denial_reason_3, '')::INTEGER,
    ALTER COLUMN hoepa_status                   TYPE INTEGER USING NULLIF(hoepa_status, '')::INTEGER,
    ALTER COLUMN lien_status                    TYPE INTEGER USING NULLIF(lien_status, '')::INTEGER,
    ALTER COLUMN edit_status                    TYPE INTEGER USING NULLIF(edit_status, '')::INTEGER,
    ALTER COLUMN sequence_number                TYPE INTEGER USING NULLIF(sequence_number, '')::INTEGER,
    ALTER COLUMN population                     TYPE INTEGER USING NULLIF(population, '')::INTEGER,
    ALTER COLUMN hud_median_family_income       TYPE INTEGER USING NULLIF(hud_median_family_income, '')::INTEGER,
    ALTER COLUMN number_of_owner_occupied_units TYPE INTEGER USING NULLIF(number_of_owner_occupied_units, '')::INTEGER,
    ALTER COLUMN number_of_1_to_4_family_units  TYPE INTEGER USING NULLIF(number_of_1_to_4_family_units, '')::INTEGER,
    ALTER COLUMN application_date_indicator     TYPE INTEGER USING NULLIF(application_date_indicator, '')::INTEGER;

-- Decimals -> NUMERIC, so no precision is lost (REAL/DOUBLE PRECISION would
-- round or reformat values). rate_spread always has the form NN.NN, so
-- NUMERIC(4,2) is exact; the two census percentages have up to 17 decimal
-- places, so they use unconstrained NUMERIC.
ALTER TABLE Preliminary
    ALTER COLUMN rate_spread            TYPE NUMERIC(4,2) USING NULLIF(rate_spread, '')::NUMERIC,
    ALTER COLUMN minority_population    TYPE NUMERIC USING NULLIF(minority_population, '')::NUMERIC,
    ALTER COLUMN tract_to_msamd_income  TYPE NUMERIC USING NULLIF(tract_to_msamd_income, '')::NUMERIC;

-- Step 6: sequence_number becomes the primary key (same column name).
ALTER TABLE Preliminary
    ADD CONSTRAINT preliminary_pkey PRIMARY KEY (sequence_number);
