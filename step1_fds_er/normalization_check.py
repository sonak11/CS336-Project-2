"""
CS336 Project 2, Step 1 -- normalization checker.

Reads the functional dependencies from functional_dependencies.txt and checks,
with the standard algorithms (attribute closure, canonical cover, BCNF test,
chase test for lossless join, dependency preservation):

  1. every dependency holds on the real data (NULL treated as a value)
  2. the set is a canonical cover (no redundant FD, no extraneous attribute)
  3. the candidate keys of each first-normal-form relation
  4. every table of the decomposition is in BCNF (all subsets tested)
  5. the decomposition is lossless (chase test)
  6. every dependency is preserved
  7. splitting the real data into the 25 tables and joining it back gives
     exactly the original CSV

Usage:  python3 normalization_check.py functional_dependencies.txt hmda.csv
"""
import csv, re, sys, itertools
from collections import OrderedDict

FD_FILE, CSV_FILE = sys.argv[1], sys.argv[2]
ok_all = True
def report(name, ok, detail=""):
    global ok_all
    ok_all &= ok
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"  -- {detail}" if detail else ""))

# ---------------------------------------------------------------- parse FDs
def parse_fds(path):
    rels, cur, buf = OrderedDict(), None, None
    def flush():
        if buf:
            m = re.search(r"\{([^}]*)\}\s*->\s*\{([^}]*)\}", " ".join(buf[1]), re.S)
            lhs = frozenset(a.strip() for a in m.group(1).split(",") if a.strip())
            rhs = frozenset(a.strip() for a in m.group(2).split(",") if a.strip())
            rels[cur].append((buf[0], lhs, rhs))
    in_cover = False
    for line in open(path):
        if line.startswith("2. Canonical cover"): in_cover = True; continue
        if line.startswith("3. "): break
        if not in_cover: continue
        m = re.match(r"Relation:\s*(\S+)", line)
        if m:
            flush(); buf = None; cur = m.group(1); rels[cur] = []; continue
        m = re.match(r"(FD\d+)\s+(.*)", line)
        if m:
            flush(); buf = (m.group(1), [m.group(2)]); continue
        if buf and line.strip() and not line.startswith("Why"):
            buf[1].append(line.strip())
        elif buf and (not line.strip() or line.startswith("Why")):
            flush(); buf = None
    flush()
    return rels

REL = parse_fds(FD_FILE)
print("Dependencies read from", FD_FILE)
for r, fds in REL.items():
    print(f"  {r}: {len(fds)} FDs ({', '.join(f[0] for f in fds)})")
print()

# ------------------------------------------------------------- 1NF schemas
LOC = ["state_code", "county_code", "msamd", "census_tract_number", "population",
       "minority_population", "hud_median_family_income", "tract_to_msamd_income",
       "number_of_owner_occupied_units", "number_of_1_to_4_family_units"]
REPEAT = [f"{p}_{i}" for p in ("applicant_race", "applicant_race_name",
          "co_applicant_race", "co_applicant_race_name") for i in range(1, 6)] + \
         [f"{p}_{i}" for p in ("denial_reason", "denial_reason_name") for i in range(1, 4)]

rows = list(csv.reader(open(CSV_FILE, newline="")))
HDR, DATA = rows[0], rows[1:]
N = len(DATA)
MAIN_COLS = [c for c in HDR if c not in REPEAT] + ["location_id"]
SCHEMA = {
    "APPLICATION_1NF": MAIN_COLS,
    "APPLICANT_RACE_1NF": ["sequence_number", "race_number", "race", "race_name"],
    "CO_APPLICANT_RACE_1NF": ["sequence_number", "race_number", "race", "race_name"],
    "DENIAL_1NF": ["sequence_number", "denial_reason_number", "denial_reason", "denial_reason_name"],
}
report("1NF column bookkeeping", len(HDR) == 78 and len(REPEAT) == 26 and len(MAIN_COLS) == 53,
       f"78 original columns, 26 repeating columns removed, 6 added, main relation has {len(MAIN_COLS)} columns")

# ---------------------------------------------------------- build 1NF data
H = {c: i for i, c in enumerate(HDR)}
def v(r, c): x = r[H[c]]; return None if x == "" else x
loc_ids, main, arace, crace, denial = {}, [], [], [], []
for i, r in enumerate(DATA, start=1):
    seq = str(i)                                   # Project 1: sequence_number = 1..N in file order
    key = tuple(v(r, c) for c in LOC)
    lid = loc_ids.setdefault(key, len(loc_ids) + 1)
    row = {c: v(r, c) for c in MAIN_COLS if c != "location_id"}
    row["sequence_number"] = seq; row["location_id"] = lid
    main.append(row)
    for k in range(1, 6):
        if v(r, f"applicant_race_{k}") is not None:
            arace.append({"sequence_number": seq, "race_number": k,
                          "race": v(r, f"applicant_race_{k}"), "race_name": v(r, f"applicant_race_name_{k}")})
        if v(r, f"co_applicant_race_{k}") is not None:
            crace.append({"sequence_number": seq, "race_number": k,
                          "race": v(r, f"co_applicant_race_{k}"), "race_name": v(r, f"co_applicant_race_name_{k}")})
    for k in range(1, 4):
        if v(r, f"denial_reason_{k}") is not None:
            denial.append({"sequence_number": seq, "denial_reason_number": k,
                           "denial_reason": v(r, f"denial_reason_{k}"),
                           "denial_reason_name": v(r, f"denial_reason_name_{k}")})
DATA1NF = {"APPLICATION_1NF": main, "APPLICANT_RACE_1NF": arace,
           "CO_APPLICANT_RACE_1NF": crace, "DENIAL_1NF": denial}
print(f"\n1NF data: {len(main)} applications, {len(loc_ids)} locations, {len(arace)} applicant race rows, "
      f"{len(crace)} co-applicant race rows, {len(denial)} denial rows\n")

# ------------------------------------------------- 1. FDs hold in the data
for rel, fds in REL.items():
    for name, lhs, rhs in fds:
        unknown = (lhs | rhs) - set(SCHEMA[rel])
        if unknown:
            report(f"{name} uses known columns", False, f"unknown: {sorted(unknown)}"); continue
        seen, bad = {}, 0
        L, R = sorted(lhs), sorted(rhs)
        for t in DATA1NF[rel]:
            k = tuple(t[a] for a in L); val = tuple(t[a] for a in R)
            if seen.setdefault(k, val) != val: bad += 1
        report(f"{name} holds in data ({rel})", bad == 0, f"{len(seen)} distinct left sides, {bad} violations")
print()

# --------------------------------------------------------- closure helpers
def closure(X, F):
    X = set(X); changed = True
    while changed:
        changed = False
        for _, l, r in F:
            if l <= X and not r <= X:
                X |= r; changed = True
    return X

# ------------------------------------------------- 2. canonical cover test
for rel, F in REL.items():
    lhs_seen = [f[1] for f in F]
    report(f"{rel}: each left side appears once", len(lhs_seen) == len(set(lhs_seen)))
    problems = []
    for idx, (name, l, r) in enumerate(F):
        for A in r:                                    # redundant right-side attribute
            Fp = [f for j, f in enumerate(F) if j != idx]
            if r - {A}: Fp.append((name, l, r - {A}))
            if A in closure(l, Fp): problems.append(f"{A} redundant in {name}")
        for B in l:                                    # extraneous left-side attribute
            if r <= closure(l - {B}, F): problems.append(f"{B} extraneous in {name}")
    report(f"{rel}: canonical cover (no redundant or extraneous attributes)", not problems, "; ".join(problems))
print()

# ----------------------------------------------------- 3. candidate keys
def candidate_keys(attrs, F):
    attrs = set(attrs)
    core = attrs - set().union(*[r for _, _, r in F])          # never on a right side: in every key
    if closure(core, F) >= attrs: return [core]
    keys, rest = [], sorted(attrs - core)
    for k in range(1, len(rest) + 1):
        for extra in itertools.combinations(rest, k):
            K = core | set(extra)
            if any(kk <= K for kk in keys): continue
            if closure(K, F) >= attrs: keys.append(K)
    return keys
for rel, F in REL.items():
    ks = candidate_keys(SCHEMA[rel], F)
    print(f"  candidate keys of {rel}: " + "; ".join("{" + ", ".join(sorted(k)) + "}" for k in ks))
print()

# --------------------------------------------------- the decomposition
# Each table as (name, columns). race appears in both race relations; test 7 checks
# that the two agree, so it is stored once.
APP = ["sequence_number", "as_of_year", "respondent_id", "agency_code", "loan_type", "property_type",
       "loan_purpose", "owner_occupancy", "loan_amount_000s", "preapproval", "action_taken", "location_id",
       "applicant_ethnicity", "co_applicant_ethnicity", "applicant_sex", "co_applicant_sex",
       "applicant_income_000s", "purchaser_type", "rate_spread", "hoepa_status", "lien_status"]
LOOK = ["loan_type", "property_type", "loan_purpose", "owner_occupancy", "preapproval", "action_taken",
        "purchaser_type", "hoepa_status", "lien_status"]
DECOMP = {"APPLICATION_1NF": [("application", APP), ("location", ["location_id"] + LOC),
          ("agency", ["agency_code", "agency_name", "agency_abbr"]),
          ("msa_md", ["msamd", "msamd_name"]), ("state", ["state_code", "state_name", "state_abbr"]),
          ("county", ["state_code", "county_code", "county_name"]),
          ("applicant_ethnicity", ["applicant_ethnicity", "applicant_ethnicity_name"]),
          ("co_applicant_ethnicity", ["co_applicant_ethnicity", "co_applicant_ethnicity_name"]),
          ("applicant_sex", ["applicant_sex", "applicant_sex_name"]),
          ("co_applicant_sex", ["co_applicant_sex", "co_applicant_sex_name"]),
          ("null_columns", ["edit_status", "edit_status_name", "application_date_indicator"])]
          + [(t, [t, t + "_name"]) for t in LOOK],
          "APPLICANT_RACE_1NF": [("applicant_race", ["sequence_number", "race_number", "race"]),
                                 ("race", ["race", "race_name"])],
          "CO_APPLICANT_RACE_1NF": [("co_applicant_race", ["sequence_number", "race_number", "race"]),
                                    ("race", ["race", "race_name"])],
          "DENIAL_1NF": [("application_denial", ["sequence_number", "denial_reason_number", "denial_reason"]),
                         ("denial_reason", ["denial_reason", "denial_reason_name"])]}

for rel, tables in DECOMP.items():
    cols = [c for _, t in tables for c in t]
    report(f"{rel}: decomposition covers every column", set(cols) == set(SCHEMA[rel]),
           f"missing {sorted(set(SCHEMA[rel]) - set(cols))}" if set(cols) != set(SCHEMA[rel]) else "")

# ------------------------------------------------------------ 4. BCNF
def bcnf_violations(Ri, F):
    Ri = list(Ri); full = set(Ri); out = []
    for k in range(0, len(Ri)):
        for X in itertools.combinations(Ri, k):
            X = set(X)
            c = closure(X, F)
            if c >= full: continue                   # superkey: fine
            gained = (c & full) - X
            if gained: out.append((sorted(X), sorted(gained)))
                                                     # X determines something but is not a superkey
            if len(out) > 3: return out
    return out
for rel, tables in DECOMP.items():
    F = REL[rel]
    for tname, cols in tables:
        # superkeys contain every column that is never on a right side; testing all
        # subsets of the remaining columns is exhaustive and fast
        viol = bcnf_violations(cols, F) if len(cols) <= 22 else [("too big", "")]
        report(f"BCNF: {tname} ({len(cols)} columns)", not viol, f"violations {viol}" if viol else "")
print()

# ------------------------------------------------------ 5. lossless (chase)
def chase_lossless(attrs, tables, F):
    attrs = list(attrs)
    T = [{a: ("a", a) if a in cols else ("b", i, a) for a in attrs} for i, (_, cols) in enumerate(tables)]
    changed = True
    while changed:
        changed = False
        for _, l, r in F:
            groups = {}
            for row in T: groups.setdefault(tuple(row[a] for a in sorted(l)), []).append(row)
            for g in groups.values():
                if len(g) < 2: continue
                for A in r:
                    syms = {row[A] for row in g}
                    if len(syms) > 1:
                        best = ("a", A) if ("a", A) in syms else min(syms)
                        for row in T:
                            if row[A] in syms and row[A] != best: row[A] = best; changed = True
    return any(all(row[a] == ("a", a) for a in attrs) for row in T)
for rel, tables in DECOMP.items():
    report(f"Lossless join (chase): {rel}", chase_lossless(SCHEMA[rel], tables, REL[rel]))

# --------------------------------------------- 6. dependency preservation
for rel, tables in DECOMP.items():
    F = REL[rel]; lost = []
    for name, l, r in F:
        Z = set(l); changed = True
        while changed:
            changed = False
            for _, cols in tables:
                add = closure(Z & set(cols), F) & set(cols)
                if not add <= Z: Z |= add; changed = True
        if not r <= Z: lost.append(name)
    report(f"Dependency preservation: {rel}", not lost, f"lost {lost}" if lost else "")
print()

# ------------------------------- 7. split the real data and join it back
def project(rel, cols, rename=None):
    out = set()
    for t in DATA1NF[rel]:
        out.add(tuple(t[c] for c in cols))
    return out
T = {}
for rel, tables in DECOMP.items():
    for tname, cols in tables:
        T[(rel, tname)] = project(rel, cols)

def merged(*parts):
    """Store several role tables as one code->name table; the mapping must agree."""
    m = {}
    for p in parts:
        for code, name in p:
            if code is None: continue                # a blank code is a NULL foreign key, not a row
            if m.setdefault(code, name) != name: return None
    return m
race = merged(T[("APPLICANT_RACE_1NF", "race")], T[("CO_APPLICANT_RACE_1NF", "race")])
report("Shared race table: applicant and co-applicant mappings agree", race is not None, f"{len(race)} codes")
denial_reason = merged(T[("DENIAL_1NF", "denial_reason")])
nullrow = T[("APPLICATION_1NF", "null_columns")]
report("null_columns has exactly one row, all NULL", nullrow == {(None, None, None)})

def lookup(rel, tname):
    m = {}
    for t in T[(rel, tname)]:
        if t[0] is None: continue
        if m.setdefault(t[0], t[1:]) != t[1:]: raise SystemExit(f"{tname}: duplicate key {t[0]}")
    return m
A = "APPLICATION_1NF"
agency = lookup(A, "agency"); msa = lookup(A, "msa_md"); state = lookup(A, "state")
county = {}
for sc, cc, nm in T[(A, "county")]:
    if cc is not None: county[(sc, cc)] = nm
loc = {}
for t in T[(A, "location")]:
    loc[t[0]] = dict(zip(["location_id"] + LOC, t))
lk = {t: lookup(A, t) for t in LOOK}
ROLE = ["applicant_ethnicity", "co_applicant_ethnicity", "applicant_sex", "co_applicant_sex"]
rl = {t: lookup(A, t) for t in ROLE}
application = {t[0]: dict(zip(APP, t)) for t in T[(A, "application")]}
report("location: ten columns are unique (FD3)", len({tuple(r[c] for c in LOC) for r in loc.values()}) == len(loc), f"{len(loc)} locations")
report("application: one row per sequence_number", len(application) == N, f"{len(application)} rows")
def slots(rel, tname, numcol):
    s = {}
    for seq, k, code in T[(rel, tname)]: s.setdefault(seq, {})[k] = code
    return s
ar = slots("APPLICANT_RACE_1NF", "applicant_race", "race_number")
cr = slots("CO_APPLICANT_RACE_1NF", "co_applicant_race", "race_number")
dn = slots("DENIAL_1NF", "application_denial", "denial_reason_number")

mismatch = 0; first = None
for i, orig in enumerate(DATA, start=1):
    a = application[str(i)]; L = loc[a["location_id"]]
    out = {}
    out.update({c: a[c] for c in APP if c not in ("location_id",)})
    out.update({c: L[c] for c in LOC})
    out["agency_name"], out["agency_abbr"] = agency[a["agency_code"]]
    for t in LOOK: out[t + "_name"] = lk[t][a[t]][0]
    out["msamd_name"] = msa[L["msamd"]][0] if L["msamd"] is not None else None
    out["state_name"], out["state_abbr"] = state[L["state_code"]]
    out["county_name"] = county[(L["state_code"], L["county_code"])] if L["county_code"] is not None else None
    for role in ("applicant", "co_applicant"):
        out[f"{role}_ethnicity_name"] = rl[f"{role}_ethnicity"][a[f"{role}_ethnicity"]][0]
        out[f"{role}_sex_name"] = rl[f"{role}_sex"][a[f"{role}_sex"]][0]
    for role, s in (("applicant", ar), ("co_applicant", cr)):
        for k in range(1, 6):
            code = s.get(str(i), {}).get(k)
            out[f"{role}_race_{k}"] = code; out[f"{role}_race_name_{k}"] = race[code] if code else None
    for k in range(1, 4):
        code = dn.get(str(i), {}).get(k)
        out[f"denial_reason_{k}"] = code; out[f"denial_reason_name_{k}"] = denial_reason[code] if code else None
    (out["edit_status"], out["edit_status_name"], out["application_date_indicator"]), = nullrow
    out["sequence_number"] = None                    # the original file has this column blank
    rebuilt = ["" if out[c] is None else str(out[c]) for c in HDR]
    if rebuilt != orig:
        mismatch += 1
        if first is None: first = (i, [(c, x, y) for c, x, y in zip(HDR, orig, rebuilt) if x != y][:5])
report("Split the data into the 25 tables and join it back: identical to the CSV", mismatch == 0,
       f"{N} rows x {len(HDR)} columns compared, {mismatch} differ" + (f", first: {first}" if first else ""))

print("\nTables and row counts:")
counts = OrderedDict([("application", len(application)), ("location", len(loc)), ("agency", len(agency))]
    + [(t, len(lk[t])) for t in LOOK] + [("msa_md", len(msa)), ("state", len(state)), ("county", len(county)),
    ] + [(t, len(rl[t])) for t in ROLE] + [("race", len(race)), ("denial_reason", len(denial_reason)),
    ("applicant_race", len(T[("APPLICANT_RACE_1NF", "applicant_race")])),
    ("co_applicant_race", len(T[("CO_APPLICANT_RACE_1NF", "co_applicant_race")])),
    ("application_denial", len(T[("DENIAL_1NF", "application_denial")])), ("null_columns", len(nullrow))])
for t, c in counts.items(): print(f"  {t:20} {c:>8}")
print(f"  {len(counts)} tables")
print("\nRESULT:", "ALL CHECKS PASSED" if ok_all else "SOME CHECKS FAILED")
sys.exit(0 if ok_all else 1)
