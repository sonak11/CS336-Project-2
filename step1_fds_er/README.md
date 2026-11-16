# Step 1: Functional dependencies + BCNF ER diagram (Sonakshi) ✅

**Turn in:** `functional_dependencies.txt` and `ER_Diagram_BCNF.pdf`

| File | What it is |
|---|---|
| `functional_dependencies.txt` | First normal form, canonical cover (27 FDs), the 25 BCNF tables, and the reasoning behind each choice |
| `ER_Diagram_BCNF.pdf` | The diagram to submit (crow's foot, every PK marked) |
| `ER_Diagram_BCNF.drawio` | Editable draw.io source. If the schema changes, edit this and re-export the PDF |
| `normalization_check.py` | Normalization checker: canonical cover, BCNF, lossless join, dependency preservation, and an exact rebuild of the CSV |
| `normalization_check_output.txt` | Its output: all checks pass |

Run the checker yourself:
```
unzip ../data/hmda_2017_nj_all-records_labels.zip
python3 normalization_check.py functional_dependencies.txt hmda_2017_nj_all-records_labels.csv
```
