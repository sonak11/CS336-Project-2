# Shared schema (everyone codes to this)

This is the contract between the tasks. It matches the Step 1 ER diagram
(`step1_fds_er/ER_Diagram_BCNF.pdf`) exactly. **The diagram must match the tables
we actually create, or Step 3 scores 0**, so don't rename, add or drop a table or
column without telling the group and updating Step 1 too.

- Types are the same as the Preliminary table from Project 1 (`project1/load.sql`).
- NOT NULL is taken from the data: a column is NOT NULL when it is never blank in the CSV
  (assignment Step 4 rule).
- Expected row counts come from `step1_fds_er/normalization_check_output.txt`. Use them to
  check your script.

## Main tables

### application (349,563 rows)
| column | type | null? | key |
|---|---|---|---|
| sequence_number | INTEGER | NOT NULL | **PK** |
| as_of_year | INTEGER | NOT NULL | |
| respondent_id | TEXT | NOT NULL | (the only TEXT column allowed here) |
| agency_code | INTEGER | NOT NULL | FK → agency |
| loan_type | INTEGER | NOT NULL | FK → loan_type |
| property_type | INTEGER | NOT NULL | FK → property_type |
| loan_purpose | INTEGER | NOT NULL | FK → loan_purpose |
| owner_occupancy | INTEGER | NOT NULL | FK → owner_occupancy |
| loan_amount_000s | INTEGER | NULL | |
| preapproval | INTEGER | NOT NULL | FK → preapproval |
| action_taken | INTEGER | NOT NULL | FK → action_taken |
| location_id | INTEGER | NOT NULL | FK → location |
| applicant_ethnicity | INTEGER | NOT NULL | FK → applicant_ethnicity |
| co_applicant_ethnicity | INTEGER | NOT NULL | FK → co_applicant_ethnicity |
| applicant_sex | INTEGER | NOT NULL | FK → applicant_sex |
| co_applicant_sex | INTEGER | NOT NULL | FK → co_applicant_sex |
| applicant_income_000s | INTEGER | NULL | |
| purchaser_type | INTEGER | NOT NULL | FK → purchaser_type |
| rate_spread | NUMERIC(4,2) | NULL | |
| hoepa_status | INTEGER | NOT NULL | FK → hoepa_status |
| lien_status | INTEGER | NOT NULL | FK → lien_status |

### location (2,135 rows)
| column | type | null? | key |
|---|---|---|---|
| location_id | INTEGER (serial) | NOT NULL | **PK** |
| state_code | INTEGER | NOT NULL | FK → state; (state_code, county_code) FK → county |
| county_code | INTEGER | NULL | |
| msamd | INTEGER | NULL | FK → msa_md |
| census_tract_number | TEXT | NULL | (keeps leading zeros, e.g. 0103.00) |
| population | INTEGER | NULL | |
| minority_population | NUMERIC | NULL | |
| hud_median_family_income | INTEGER | NULL | |
| tract_to_msamd_income | NUMERIC | NULL | |
| number_of_owner_occupied_units | INTEGER | NULL | |
| number_of_1_to_4_family_units | INTEGER | NULL | |

All ten columns after location_id are UNIQUE together. Many locations have NULLs, so use
`UNIQUE NULLS NOT DISTINCT (...)` (PostgreSQL 15+). Match locations with
`IS NOT DISTINCT FROM`, never `=`: `=` silently drops every row with a NULL location
column, and the rubric takes −2 for any location_id mismatch.

## First-normal-form join tables

### applicant_race (351,510 rows), co_applicant_race (350,201 rows)
| column | type | null? | key |
|---|---|---|---|
| sequence_number | INTEGER | NOT NULL | **PK**, FK → application |
| race_number | INTEGER | NOT NULL | **PK**; the original slot 1–5 |
| race | INTEGER | NOT NULL | FK → race |

One row per non-blank `applicant_race_k` (or `co_applicant_race_k`), with
race_number = k. **applicant_race must reject race = 8** ("No co-applicant") with a CHECK.

### application_denial (45,088 rows)
| column | type | null? | key |
|---|---|---|---|
| sequence_number | INTEGER | NOT NULL | **PK**, FK → application |
| denial_reason_number | INTEGER | NOT NULL | **PK**; the original slot 1–3 |
| denial_reason | INTEGER | NOT NULL | FK → denial_reason |

Keep the original slot. 26 rows have gaps (for example, only denial_reason_2 is filled),
and renumbering them breaks the export.

## Lookup tables (code → name)

Each table has the code as an INTEGER primary key and its name as TEXT NOT NULL, using
the **original column names**.

| table | columns | rows |
|---|---|---|
| agency | agency_code, agency_name, agency_abbr | 6 |
| loan_type | loan_type, loan_type_name | 4 |
| property_type | property_type, property_type_name | 3 |
| loan_purpose | loan_purpose, loan_purpose_name | 3 |
| owner_occupancy | owner_occupancy, owner_occupancy_name | 3 |
| preapproval | preapproval, preapproval_name | 3 |
| action_taken | action_taken, action_taken_name | 8 |
| purchaser_type | purchaser_type, purchaser_type_name | 10 |
| hoepa_status | hoepa_status, hoepa_status_name | 2 |
| lien_status | lien_status, lien_status_name | 4 |
| applicant_ethnicity | applicant_ethnicity, applicant_ethnicity_name | 4 |
| co_applicant_ethnicity | co_applicant_ethnicity, co_applicant_ethnicity_name | 5 |
| applicant_sex | applicant_sex, applicant_sex_name | 4 |
| co_applicant_sex | co_applicant_sex, co_applicant_sex_name | 5 |
| race | race, race_name | 8 |
| denial_reason | denial_reason, denial_reason_name | 9 |
| msa_md | msamd, **msamd_name (NULL allowed)** | 11 |
| state | state_code, state_name, state_abbr | 1 (NJ) |
| county | **PK (state_code, county_code)**, county_name; state_code FK → state | 21 |

- Fill lookups from the data, not the PDF: `SELECT DISTINCT code, name ... WHERE code IS NOT NULL`.
- msamd 35620 and 37980 have a blank name in every row, so they are stored with
  msamd_name NULL. This is why msamd_name allows NULL.
- Applicant and co-applicant ethnicity and sex stay **separate tables**. Merging them
  would rename original columns, which Step 1 forbids.

## null_columns (exactly 1 row)
| column | type |
|---|---|
| edit_status | INTEGER |
| edit_status_name | TEXT |
| application_date_indicator | INTEGER |

These three columns are blank in every row of the CSV. They live in a single row of
NULLs, as the assignment hint suggests. There is no primary key, because key columns
can't be NULL. The export cross-joins this row.
