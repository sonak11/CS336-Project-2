# Step 4: Constraints, export, error video, spreadsheet screenshot (Maanya)

**Deliverables:** `03_constraints.sql`, `04_export.sql`, the error video, and a screenshot
of the exported CSV in a spreadsheet.

**Needs first:** every table from Steps 2 and 3.

`03_constraints.sql`:
- Every foreign key in `../SCHEMA.md`, and NOT NULL on every column marked NOT NULL there.
- `UNIQUE NULLS NOT DISTINCT` on location's ten columns.
- `CHECK (race <> 8)` on applicant_race, and race_number between 1 and 5 / denial_reason_number between 1 and 3.

`04_export.sql`:
- Rebuild all 78 columns from the normalized tables only. **Using Preliminary anywhere = 0 points.**
- Pivot race/denial back into the `_1`–`_5` columns by slot number.
- Cross-join `null_columns`.
- Reuse Project 1's formatting fixes from `../project1/export.sql`: FORCE_QUOTE, blank sequence_number, `to_char(rate_spread, 'FM00.00')`, unquoted header.
- Check with `diff` against the original CSV.

**Error video (≤ 1 minute):** three inserts rejected for different reasons, for example
`property_type = 4` (foreign key), a NULL in a NOT NULL column, and a duplicate primary key.
The graders may also try their own bad insert.
