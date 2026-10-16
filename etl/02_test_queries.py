"""Validation harness: loads clean CSVs into SQLite (MySQL SQL transpiled with sqlglot) and runs every query.
Needs: pip install sqlglot pandas"""
import re, logging, sqlite3, pandas as pd, sqlglot
logging.getLogger("sqlglot").setLevel(logging.ERROR)
con = sqlite3.connect(":memory:")
ddl = re.sub(r"(?im)^(DROP DATABASE|CREATE DATABASE|USE) .*?;\s*$", "", open("sql/01_schema.sql").read())
for stmt in sqlglot.parse(ddl, read="mysql"):
    if stmt is not None: con.execute(stmt.sql(dialect="sqlite"))
for t in ["regions","counties","cities","sectors","hospital_subtypes","parent_organisations","hospitals","hospital_contacts"]:
    pd.read_csv(f"data/clean/{t}.csv").to_sql(t, con, if_exists="append", index=False)
print("integrity:", con.execute("PRAGMA foreign_key_check").fetchall() or "FK OK")
blocks = re.split(r"(?m)^-- (Q\d+): ", open("sql/03_analysis_queries.sql").read())[1:]
ok = 0
for i in range(0, len(blocks), 2):
    qid, body = blocks[i], blocks[i+1]; title, _, code = body.partition("\n")
    code = "\n".join(l for l in code.splitlines() if not l.strip().startswith("-- ====")).strip()
    try:
        for s in [x for x in sqlglot.parse(code, read="mysql") if x]:
            out = s.sql(dialect="sqlite").replace("CREATE OR REPLACE VIEW", "CREATE VIEW")
            cur = con.execute(out); rows = cur.fetchall() if cur.description else []
        print(f"{qid:4s} OK  rows={len(rows):<4d} {title[:75]}")
        if qid in globals().get("SHOW", ()): print("     ", rows[:6])
        ok += 1
    except Exception as e:
        print(f"{qid:4s} FAIL {e}\n{code[:160]}")
print(f"\n{ok}/{len(blocks)//2} queries passed")
