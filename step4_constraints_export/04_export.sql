-- =====================================================================
-- CS336 Project 2: HMDA 2017 New Jersey -- 04_export.sql   (Task 4)
--
-- Rebuilds the original CSV, hmda_2017_nj_all-records_labels.csv, using
-- ONLY the normalized tables, and writes it to exported.csv. Check with:
--     diff hmda_2017_nj_all-records_labels.csv exported.csv
-- (no output means the files are identical)
--
-- How the original rows are put back together:
--   * application is the base table, one output row per application.
--   * Each *_name column comes back by joining the code to its lookup table.
--   * The 10 location columns come back through location_id; county_name,
--     msamd_name, state_name and state_abbr through location's codes.
--     LEFT JOINs keep the applications whose county or msamd is blank.
--   * Race and denial reasons are pivoted from the join tables back into
--     the _1.._5 (_1.._3) columns: one row per application, picking the
--     value at each position number. LEFT JOINs keep applications with no
--     race or denial rows; their columns come out blank.
--   * edit_status, edit_status_name and application_date_indicator come
--     from the one-row null_columns table (CROSS JOIN).
--   * sequence_number is blank in the original file, so it is written as ''.
--     It is still used to put the rows back in their original order.
--   * Formatting, as in Project 1's export: NULLs become '' through COALESCE
--     and FORCE_QUOTE * quotes every value, so blanks print as ""; the header
--     row is unquoted; rate_spread uses to_char(..., 'FM00.00') to restore
--     its leading zero (e.g. 01.50).
--
-- Run on ilab after scripts 01, 02 and 03:
--     \i 04_export.sql
--
-- References:
--   PostgreSQL docs, COPY (FORCE_QUOTE):
--     https://www.postgresql.org/docs/current/sql-copy.html
--   psql \copy: https://www.postgresql.org/docs/current/app-psql.html
--   Aggregate FILTER clause:
--     https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
--   to_char: https://www.postgresql.org/docs/current/functions-formatting.html
-- AI assistance is described in README.txt, section 2.
-- =====================================================================
\set ON_ERROR_STOP on

-- A temporary view keeps the query readable: \copy must fit on one line,
-- so the one-line \copy at the bottom just selects from this view.
-- The view disappears when the session ends.
CREATE OR REPLACE TEMP VIEW export_rows AS
WITH
-- applicant_race: positions 1..5 back into columns (codes and names)
ar AS (
    SELECT j.sequence_number,
           MAX(r.race_name) FILTER (WHERE j.race_number = 1) AS name_1,
           MAX(j.race)      FILTER (WHERE j.race_number = 1) AS code_1,
           MAX(r.race_name) FILTER (WHERE j.race_number = 2) AS name_2,
           MAX(j.race)      FILTER (WHERE j.race_number = 2) AS code_2,
           MAX(r.race_name) FILTER (WHERE j.race_number = 3) AS name_3,
           MAX(j.race)      FILTER (WHERE j.race_number = 3) AS code_3,
           MAX(r.race_name) FILTER (WHERE j.race_number = 4) AS name_4,
           MAX(j.race)      FILTER (WHERE j.race_number = 4) AS code_4,
           MAX(r.race_name) FILTER (WHERE j.race_number = 5) AS name_5,
           MAX(j.race)      FILTER (WHERE j.race_number = 5) AS code_5
    FROM applicant_race j
    JOIN race r ON r.race = j.race
    GROUP BY j.sequence_number
),
-- co_applicant_race: same, for the co-applicant
car AS (
    SELECT j.sequence_number,
           MAX(r.race_name) FILTER (WHERE j.race_number = 1) AS name_1,
           MAX(j.race)      FILTER (WHERE j.race_number = 1) AS code_1,
           MAX(r.race_name) FILTER (WHERE j.race_number = 2) AS name_2,
           MAX(j.race)      FILTER (WHERE j.race_number = 2) AS code_2,
           MAX(r.race_name) FILTER (WHERE j.race_number = 3) AS name_3,
           MAX(j.race)      FILTER (WHERE j.race_number = 3) AS code_3,
           MAX(r.race_name) FILTER (WHERE j.race_number = 4) AS name_4,
           MAX(j.race)      FILTER (WHERE j.race_number = 4) AS code_4,
           MAX(r.race_name) FILTER (WHERE j.race_number = 5) AS name_5,
           MAX(j.race)      FILTER (WHERE j.race_number = 5) AS code_5
    FROM co_applicant_race j
    JOIN race r ON r.race = j.race
    GROUP BY j.sequence_number
),
-- application_denial: positions 1..3 back into columns
den AS (
    SELECT j.sequence_number,
           MAX(d.denial_reason_name) FILTER (WHERE j.denial_reason_number = 1) AS name_1,
           MAX(j.denial_reason)      FILTER (WHERE j.denial_reason_number = 1) AS code_1,
           MAX(d.denial_reason_name) FILTER (WHERE j.denial_reason_number = 2) AS name_2,
           MAX(j.denial_reason)      FILTER (WHERE j.denial_reason_number = 2) AS code_2,
           MAX(d.denial_reason_name) FILTER (WHERE j.denial_reason_number = 3) AS name_3,
           MAX(j.denial_reason)      FILTER (WHERE j.denial_reason_number = 3) AS code_3
    FROM application_denial j
    JOIN denial_reason d ON d.denial_reason = j.denial_reason
    GROUP BY j.sequence_number
)
SELECT
    a.sequence_number AS sort_key,
    -- columns below are in the original CSV order
    COALESCE(a.as_of_year::text, '')                    AS as_of_year,
    COALESCE(a.respondent_id, '')                       AS respondent_id,
    COALESCE(ag.agency_name, '')                        AS agency_name,
    COALESCE(ag.agency_abbr, '')                        AS agency_abbr,
    COALESCE(a.agency_code::text, '')                   AS agency_code,
    COALESCE(lt.loan_type_name, '')                     AS loan_type_name,
    COALESCE(a.loan_type::text, '')                     AS loan_type,
    COALESCE(pt.property_type_name, '')                 AS property_type_name,
    COALESCE(a.property_type::text, '')                 AS property_type,
    COALESCE(lp.loan_purpose_name, '')                  AS loan_purpose_name,
    COALESCE(a.loan_purpose::text, '')                  AS loan_purpose,
    COALESCE(oo.owner_occupancy_name, '')               AS owner_occupancy_name,
    COALESCE(a.owner_occupancy::text, '')               AS owner_occupancy,
    COALESCE(a.loan_amount_000s::text, '')              AS loan_amount_000s,
    COALESCE(pa.preapproval_name, '')                   AS preapproval_name,
    COALESCE(a.preapproval::text, '')                   AS preapproval,
    COALESCE(at.action_taken_name, '')                  AS action_taken_name,
    COALESCE(a.action_taken::text, '')                  AS action_taken,
    COALESCE(m.msamd_name, '')                          AS msamd_name,
    COALESCE(l.msamd::text, '')                         AS msamd,
    COALESCE(s.state_name, '')                          AS state_name,
    COALESCE(s.state_abbr, '')                          AS state_abbr,
    COALESCE(l.state_code::text, '')                    AS state_code,
    COALESCE(c.county_name, '')                         AS county_name,
    COALESCE(l.county_code::text, '')                   AS county_code,
    COALESCE(l.census_tract_number, '')                 AS census_tract_number,
    COALESCE(ae.applicant_ethnicity_name, '')           AS applicant_ethnicity_name,
    COALESCE(a.applicant_ethnicity::text, '')           AS applicant_ethnicity,
    COALESCE(ce.co_applicant_ethnicity_name, '')        AS co_applicant_ethnicity_name,
    COALESCE(a.co_applicant_ethnicity::text, '')        AS co_applicant_ethnicity,
    COALESCE(ar.name_1, '')       AS applicant_race_name_1,
    COALESCE(ar.code_1::text, '') AS applicant_race_1,
    COALESCE(ar.name_2, '')       AS applicant_race_name_2,
    COALESCE(ar.code_2::text, '') AS applicant_race_2,
    COALESCE(ar.name_3, '')       AS applicant_race_name_3,
    COALESCE(ar.code_3::text, '') AS applicant_race_3,
    COALESCE(ar.name_4, '')       AS applicant_race_name_4,
    COALESCE(ar.code_4::text, '') AS applicant_race_4,
    COALESCE(ar.name_5, '')       AS applicant_race_name_5,
    COALESCE(ar.code_5::text, '') AS applicant_race_5,
    COALESCE(car.name_1, '')       AS co_applicant_race_name_1,
    COALESCE(car.code_1::text, '') AS co_applicant_race_1,
    COALESCE(car.name_2, '')       AS co_applicant_race_name_2,
    COALESCE(car.code_2::text, '') AS co_applicant_race_2,
    COALESCE(car.name_3, '')       AS co_applicant_race_name_3,
    COALESCE(car.code_3::text, '') AS co_applicant_race_3,
    COALESCE(car.name_4, '')       AS co_applicant_race_name_4,
    COALESCE(car.code_4::text, '') AS co_applicant_race_4,
    COALESCE(car.name_5, '')       AS co_applicant_race_name_5,
    COALESCE(car.code_5::text, '') AS co_applicant_race_5,
    COALESCE(asx.applicant_sex_name, '')                AS applicant_sex_name,
    COALESCE(a.applicant_sex::text, '')                 AS applicant_sex,
    COALESCE(csx.co_applicant_sex_name, '')             AS co_applicant_sex_name,
    COALESCE(a.co_applicant_sex::text, '')              AS co_applicant_sex,
    COALESCE(a.applicant_income_000s::text, '')         AS applicant_income_000s,
    COALESCE(pu.purchaser_type_name, '')                AS purchaser_type_name,
    COALESCE(a.purchaser_type::text, '')                AS purchaser_type,
    COALESCE(den.name_1, '')       AS denial_reason_name_1,
    COALESCE(den.code_1::text, '') AS denial_reason_1,
    COALESCE(den.name_2, '')       AS denial_reason_name_2,
    COALESCE(den.code_2::text, '') AS denial_reason_2,
    COALESCE(den.name_3, '')       AS denial_reason_name_3,
    COALESCE(den.code_3::text, '') AS denial_reason_3,
    COALESCE(to_char(a.rate_spread, 'FM00.00'), '')     AS rate_spread,
    COALESCE(hs.hoepa_status_name, '')                  AS hoepa_status_name,
    COALESCE(a.hoepa_status::text, '')                  AS hoepa_status,
    COALESCE(ls.lien_status_name, '')                   AS lien_status_name,
    COALESCE(a.lien_status::text, '')                   AS lien_status,
    COALESCE(nc.edit_status_name, '')                   AS edit_status_name,
    COALESCE(nc.edit_status::text, '')                  AS edit_status,
    ''                                                  AS sequence_number,
    COALESCE(l.population::text, '')                    AS population,
    COALESCE(l.minority_population::text, '')           AS minority_population,
    COALESCE(l.hud_median_family_income::text, '')      AS hud_median_family_income,
    COALESCE(l.tract_to_msamd_income::text, '')         AS tract_to_msamd_income,
    COALESCE(l.number_of_owner_occupied_units::text, '') AS number_of_owner_occupied_units,
    COALESCE(l.number_of_1_to_4_family_units::text, '')  AS number_of_1_to_4_family_units,
    COALESCE(nc.application_date_indicator::text, '')   AS application_date_indicator
FROM application a
JOIN location               l   ON l.location_id = a.location_id
JOIN state                  s   ON s.state_code = l.state_code
LEFT JOIN county            c   ON c.state_code = l.state_code AND c.county_code = l.county_code
LEFT JOIN msa_md            m   ON m.msamd = l.msamd
JOIN agency                 ag  ON ag.agency_code = a.agency_code
JOIN loan_type              lt  ON lt.loan_type = a.loan_type
JOIN property_type          pt  ON pt.property_type = a.property_type
JOIN loan_purpose           lp  ON lp.loan_purpose = a.loan_purpose
JOIN owner_occupancy        oo  ON oo.owner_occupancy = a.owner_occupancy
JOIN preapproval            pa  ON pa.preapproval = a.preapproval
JOIN action_taken           at  ON at.action_taken = a.action_taken
JOIN applicant_ethnicity    ae  ON ae.applicant_ethnicity = a.applicant_ethnicity
JOIN co_applicant_ethnicity ce  ON ce.co_applicant_ethnicity = a.co_applicant_ethnicity
JOIN applicant_sex          asx ON asx.applicant_sex = a.applicant_sex
JOIN co_applicant_sex       csx ON csx.co_applicant_sex = a.co_applicant_sex
JOIN purchaser_type         pu  ON pu.purchaser_type = a.purchaser_type
JOIN hoepa_status           hs  ON hs.hoepa_status = a.hoepa_status
JOIN lien_status            ls  ON ls.lien_status = a.lien_status
LEFT JOIN ar                    ON ar.sequence_number  = a.sequence_number
LEFT JOIN car                   ON car.sequence_number = a.sequence_number
LEFT JOIN den                   ON den.sequence_number = a.sequence_number
CROSS JOIN null_columns     nc;

-- Check before writing: one exported row per application. Expect 349563 | 349563.
SELECT (SELECT count(*) FROM application) AS applications,
       (SELECT count(*) FROM export_rows) AS export_rows;

-- (\copy must be written on a single line)
\copy (SELECT as_of_year, respondent_id, agency_name, agency_abbr, agency_code, loan_type_name, loan_type, property_type_name, property_type, loan_purpose_name, loan_purpose, owner_occupancy_name, owner_occupancy, loan_amount_000s, preapproval_name, preapproval, action_taken_name, action_taken, msamd_name, msamd, state_name, state_abbr, state_code, county_name, county_code, census_tract_number, applicant_ethnicity_name, applicant_ethnicity, co_applicant_ethnicity_name, co_applicant_ethnicity, applicant_race_name_1, applicant_race_1, applicant_race_name_2, applicant_race_2, applicant_race_name_3, applicant_race_3, applicant_race_name_4, applicant_race_4, applicant_race_name_5, applicant_race_5, co_applicant_race_name_1, co_applicant_race_1, co_applicant_race_name_2, co_applicant_race_2, co_applicant_race_name_3, co_applicant_race_3, co_applicant_race_name_4, co_applicant_race_4, co_applicant_race_name_5, co_applicant_race_5, applicant_sex_name, applicant_sex, co_applicant_sex_name, co_applicant_sex, applicant_income_000s, purchaser_type_name, purchaser_type, denial_reason_name_1, denial_reason_1, denial_reason_name_2, denial_reason_2, denial_reason_name_3, denial_reason_3, rate_spread, hoepa_status_name, hoepa_status, lien_status_name, lien_status, edit_status_name, edit_status, sequence_number, population, minority_population, hud_median_family_income, tract_to_msamd_income, number_of_owner_occupied_units, number_of_1_to_4_family_units, application_date_indicator FROM export_rows ORDER BY sort_key) TO 'exported.csv' WITH (FORMAT csv, HEADER true, FORCE_QUOTE *)
