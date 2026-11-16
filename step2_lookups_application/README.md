# Step 2: Lookup tables + application table (Kenneth)

**Deliverable:** `02_lookups_application.sql`, run successfully on ilab.

**Creates:** every lookup table in `../SCHEMA.md` (agency, loan_type, property_type,
loan_purpose, owner_occupancy, preapproval, action_taken, purchaser_type,
hoepa_status, lien_status, applicant_ethnicity, co_applicant_ethnicity, applicant_sex,
co_applicant_sex, race, denial_reason, msa_md, state, county), `null_columns`, and
`application`.

**Needs first:** Preliminary (Project 1), plus the `location` table from Step 3's
`01_location_1nf.sql`, to look up `location_id`.

Rules that cost points:
- **No name/label column in `application`** (0 points on Step 2). Only `respondent_id` may be TEXT.
- Keep Project 1's types and NULL rules (−1).
- Find `location_id` by joining on all ten location columns with `IS NOT DISTINCT FROM` (−2 if any row mismatches).
- No two identical tables (the "minor step skipped" rubric line).

Check before pushing: `application` = 349,563 rows, and each lookup's row count matches `SCHEMA.md`.
