# CS336 Project 2: Normalizing the 2017 New Jersey HMDA database

The Project 1 `Preliminary` table becomes a fully normalized (BCNF) PostgreSQL
database that can still reproduce the original CSV. The assignment is in
`docs/assignment_project2.txt` (15 points).

| Who | Task | Assignment step | Folder | Status |
|---|---|---|---|---|
| Sonakshi Sharma (ss4910) | Functional dependencies + BCNF ER diagram | Step 1 (5 pts) | `step1_fds_er/` | ✅ done |
| Kenneth Wang (ksw94) | Lookup tables + application table | Step 2 (3 pts) | `step2_lookups_application/` | ✅ done |
| James Kurian (jjk369) | Location table + 1NF join tables + table video | Step 3 (4 pts) | `step3_location_1nf/` | ✅ script · ⬜ video |
| Maanya | Constraints, export, error video, spreadsheet screenshot | Step 4 (3 pts) | `step4_constraints_export/` | ✅ done |

**Before you write any SQL, read [`SCHEMA.md`](SCHEMA.md).** It lists every table,
column, type, NULL rule and key. All four tasks code to it, which is how we can work in
parallel.

## What depends on what

```
            Step 1: FDs + ER diagram  (done)
              defines every table and column name
                         │
          ┌──────────────┴───────────────┐
          ▼                              ▼
  Step 3: 01_location_1nf.sql    Step 2: 02_lookups_application.sql
  (needs only Preliminary)       (needs the location table from 01
          │                       to fill location_id)
          └──────────────┬───────────────┘
                         ▼
        Step 4: 03_constraints.sql + 04_export.sql
        (needs every table from 01 and 02 to exist)
                         ▼
        Videos + spreadsheet screenshot (need everything above)
```

| Task | Depends on | Can start now? |
|---|---|---|
| Step 1 | The CSV only | Done |
| Step 3 | Step 1 names. Reads only Preliminary. | Yes, fully |
| Step 2 | Step 1 names, plus the `location` table from Step 3 to fill `location_id` | Write it now; test it after 01 runs |
| Step 4 | Step 1 names and NULL rules, plus all tables from Steps 2 and 3 | Write it now; test it after 01 and 02 run |
| Step 3 table video | Every table existing | Last |
| Step 4 error video | 03_constraints.sql | After 03 |

So **Steps 2 and 3 should be due a few days before Step 4.**

## Run order on ilab

Put the CSV and every script in one folder, run `postgres`, then:

```
\i project1/load.sql                                -- Preliminary (Project 1; skip if it already exists)
\i step3_location_1nf/01_location_1nf.sql           -- location, applicant_race, co_applicant_race, application_denial
\i step2_lookups_application/02_lookups_application.sql   -- lookups, null_columns, application
\i step4_constraints_export/03_constraints.sql      -- foreign keys, NOT NULL, CHECKs
\i step4_constraints_export/04_export.sql           -- writes the CSV from the normalized tables
```

Scripts 01–03 are combined into `submission/create_normalized_db.sql`, the single
"complete SQL script that creates the normalized database from the Preliminary table".
Running it instead of 01, 02 and 03 gives the same database.

## How to add your work

**Work only in your own folder.** If you think the schema needs to change, tell the group
first: the ER diagram has to change with it.

**Easiest way (no git needed):** open your folder on GitHub, click **Add file → Upload
files**, drag your files in, write a short message, and click **Commit changes**.

**With git:**
```
git clone https://github.com/sonak11/CS336-Project-2.git
cd CS336-Project-2
git pull                      # always pull before you start
# add or edit files in YOUR folder
git add step2_lookups_application/
git commit -m "Step 2: lookup tables script"
git push
```

To push, you must be a collaborator. Sonakshi adds each teammate under the repo's
**Settings → Collaborators** using their GitHub username.

Don't commit the CSV: it's 266 MB, over GitHub's limit. Use the zip in `data/` instead
(`.gitignore` already blocks `*.csv`).

## Repo layout

```
SCHEMA.md                      the shared table/column contract
data/                          the original CSV, zipped
docs/                          assignment text, CFPB code sheet, field format PDF
project1/                      final Project 1 scripts (Preliminary table)
step1_fds_er/                  Sonakshi: functional_dependencies.txt, ER diagram (PDF + .drawio), checker
step2_lookups_application/     Kenneth
step3_location_1nf/            James
step4_constraints_export/      Maanya
submission/                    create_normalized_db.sql = scripts 01 + 02 + 03 in one file
```

## Final submission checklist

| Step | Turn in | File | Status |
|---|---|---|---|
| 1 | Functional dependencies (txt) | `step1_fds_er/functional_dependencies.txt` | ✅ |
| 1 | ER diagram (PDF) | `step1_fds_er/ER_Diagram_BCNF.pdf` | ✅ |
| 3 | Preliminary script from Project 1 | `project1/load.sql` | ✅ |
| 3 | Complete script: Preliminary → normalized database | `submission/create_normalized_db.sql` | ✅ |
| 3 | Video: `SELECT * FROM` every new table (≤ 1 min) | run `step3_location_1nf/show_tables.sql` | ⬜ James |
| 4 | Export script | `step4_constraints_export/04_export.sql` | ✅ |
| 4 | Video: 3 rejected inserts (≤ 1 min) | `step4_constraints_export/Error_Inserts_Recording.mov` | ✅ |
| 4 | Screenshot of the exported CSV in a spreadsheet | `step4_constraints_export/Exported_CSV_SS.png` | ✅ |

Checked end to end on PostgreSQL 16 from an empty database: load.sql, then
create_normalized_db.sql (or 01, 02, 03), then 04_export.sql. The export is
identical to the original CSV (`diff` prints nothing), even with Preliminary
renamed away. The 25 tables match the ER diagram column for column, with the
same primary keys.

The normalized tables must be loaded, with the final 03_constraints.sql, in the
ilab database we name for grading.
