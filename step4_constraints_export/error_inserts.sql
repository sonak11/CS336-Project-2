-- =====================================================================
-- CS336 Project 2: HMDA 2017 New Jersey -- error_inserts.sql   (Task 4)
-- Used for the Step 4 error video. Three inserts, each rejected for a
-- different reason. Each one copies application 1 (a valid row) and
-- changes exactly one thing, so the only error is the one being shown.
-- Run on ilab after scripts 01-03:
--     \i error_inserts.sql
-- =====================================================================
\set ON_ERROR_STOP off
\set ECHO queries

\echo '--- 1. Bad code: property_type 4 does not exist in property_type (foreign key) ---'
INSERT INTO application (sequence_number, as_of_year, respondent_id, agency_code,
    loan_type, property_type, loan_purpose, owner_occupancy, loan_amount_000s,
    preapproval, action_taken, location_id, applicant_ethnicity,
    co_applicant_ethnicity, applicant_sex, co_applicant_sex,
    applicant_income_000s, purchaser_type, rate_spread, hoepa_status, lien_status)
VALUES (349564, 2017, '62-1532940', 7, 1, 4, 1, 1, 272, 3, 6, 412, 4, 4, 4, 4,
        NULL, 1, NULL, 2, 4);

\echo '--- 2. NULL in a NOT NULL column: loan_type is NULL ---'
INSERT INTO application (sequence_number, as_of_year, respondent_id, agency_code,
    loan_type, property_type, loan_purpose, owner_occupancy, loan_amount_000s,
    preapproval, action_taken, location_id, applicant_ethnicity,
    co_applicant_ethnicity, applicant_sex, co_applicant_sex,
    applicant_income_000s, purchaser_type, rate_spread, hoepa_status, lien_status)
VALUES (349564, 2017, '62-1532940', 7, NULL, 1, 1, 1, 272, 3, 6, 412, 4, 4, 4, 4,
        NULL, 1, NULL, 2, 4);

\echo '--- 3. Duplicate primary key: sequence_number 1 already exists ---'
INSERT INTO application (sequence_number, as_of_year, respondent_id, agency_code,
    loan_type, property_type, loan_purpose, owner_occupancy, loan_amount_000s,
    preapproval, action_taken, location_id, applicant_ethnicity,
    co_applicant_ethnicity, applicant_sex, co_applicant_sex,
    applicant_income_000s, purchaser_type, rate_spread, hoepa_status, lien_status)
VALUES (1, 2017, '62-1532940', 7, 1, 1, 1, 1, 272, 3, 6, 412, 4, 4, 4, 4,
        NULL, 1, NULL, 2, 4);

\echo '--- Nothing was added: still 349563 rows ---'
SELECT count(*) AS application_rows FROM application;
