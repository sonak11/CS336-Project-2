-- =====================================================================
-- CS336 Project 2: HMDA 2017 New Jersey -- show_tables.sql   (Step 3 video)
-- Runs SELECT * FROM <table>; for every normalized table. Each result goes
-- through a pager that keeps only its first 12 lines ("the first part of
-- each table"), so no q is needed and all 25 tables fit well inside the
-- 1-minute limit.
-- Run on ilab after the normalized database is built:
--     postgres
--     \i show_tables.sql
-- =====================================================================
\set ECHO queries
\pset pager always
\setenv PAGER 'head -n 12'

SELECT * FROM application;
SELECT * FROM location;
SELECT * FROM applicant_race;
SELECT * FROM co_applicant_race;
SELECT * FROM application_denial;
SELECT * FROM agency;
SELECT * FROM loan_type;
SELECT * FROM property_type;
SELECT * FROM loan_purpose;
SELECT * FROM owner_occupancy;
SELECT * FROM preapproval;
SELECT * FROM action_taken;
SELECT * FROM purchaser_type;
SELECT * FROM hoepa_status;
SELECT * FROM lien_status;
SELECT * FROM applicant_ethnicity;
SELECT * FROM co_applicant_ethnicity;
SELECT * FROM applicant_sex;
SELECT * FROM co_applicant_sex;
SELECT * FROM race;
SELECT * FROM denial_reason;
SELECT * FROM msa_md;
SELECT * FROM state;
SELECT * FROM county;
SELECT * FROM null_columns;

\pset pager on
\unset ECHO
