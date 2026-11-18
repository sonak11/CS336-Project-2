# Step 3: Location table + first-normal-form join tables (James)

**Deliverables:** `01_location_1nf.sql` and the Step 3 table video.

**Creates:** `location` (serial location_id over the distinct ten-column combinations),
`applicant_race`, `co_applicant_race`, `application_denial`. See `../SCHEMA.md`.

**Needs first:** only Preliminary. This script runs first.

Rules that cost points:
- Every location gets a simple integer key, and it's the only location column in `application`.
- Insert only non-blank race/denial values, and keep the **original slot number** (1–5 or 1–3). 26 rows have gaps in their denial reasons.
- No `applicant_race_2`-style columns anywhere (0 points if the result isn't in first normal form).

**Video (≤ 1 minute):** after 01, 02 and 03 have all run, start recording, then run
`\i show_tables.sql`. It runs `SELECT * FROM <table>;` for all 25 tables and shows only
the first rows of each (no `q` needed). It takes a few seconds, so scroll back up
slowly while recording so every table is visible.

Check before pushing: location = 2,135, applicant_race = 351,510,
co_applicant_race = 350,201, application_denial = 45,088 rows.
