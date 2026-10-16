# NHS Hospital Directory Analysis (MySQL | SQL | Excel | ETL)

University Database Module, individual project. Raw NHS hospital directory -> ETL cleaning -> normalised MySQL database -> 27 SQL queries -> Excel KPI dashboard.

## The data
`data/raw/Hospital.csv` is a directory of **1,211 hospitals in England** (NHS and independent sector) with ODS code, sub-type, sector, parent organisation, address, coordinates and contact details. It is a **directory**, not patient or activity data, so the KPIs measure **provision** (NHS vs independent, regional spread, provider concentration) and **data completeness** (phone, email, website, postcode, coordinates).

## What's included
- **3NF MySQL database:** 8 tables (`regions`, `counties`, `cities`, `sectors`, `hospital_subtypes`, `parent_organisations`, `hospitals`, `hospital_contacts`) with PK, FK, UNIQUE and CHECK constraints.
- **27 SQL queries:** JOINs (up to 7 tables), subqueries, aggregations, HAVING, NOT EXISTS, self-join, CTE-style derived tables and window functions.
- **ETL (Python / pandas):** fixes a malformed header and unnamed index column, trims whitespace, cleans a junk `,,,` fax column, validates postcodes and coordinates, standardises URLs and county names, imputes missing counties, flags possible duplicates. Every step is logged in `data/clean/cleaning_log.csv`.
- **Excel report:** KPI dashboard with editable targets, 5 charts, conditional formatting and summary tables.
- **Documentation:** ER diagram, data dictionary, SQL documentation.

![ER diagram](docs/er_diagram.png)

## Structure
```
data/raw/     Hospital.csv                  source file, unchanged
data/clean/   8 table CSVs + cleaning_log   ETL output, ready to load
etl/          01_clean_transform.py         cleaning + 3NF split
              02_test_queries.py            runs all 27 queries as a check (pip install sqlglot)
sql/          01_schema.sql  02_load_data.sql  03_analysis_queries.sql
excel/        NHS_Hospital_Directory_KPI_Report.xlsx
docs/         er_diagram.png  data_dictionary.md  sql_documentation.md
```

## How to run
1. `pip install pandas numpy` then `python3 etl/01_clean_transform.py`
2. In MySQL 8 (client started with `--local-infile=1`), from the project root:
   `SOURCE sql/01_schema.sql;` `SOURCE sql/02_load_data.sql;` `SOURCE sql/03_analysis_queries.sql;`

## Key findings (from the queries)
- 743 hospitals are NHS sector (61.4%) and 468 independent (38.6%).
- The South East has the most hospitals (230) and the highest independent share (51.3%); the North East has the fewest (69) and one of the lowest (27.5%).
- Greater London is the top county (100 hospitals); BMI Healthcare is the largest single operator (43 hospitals).
- NHS-sector records are better populated for phone (87%) and website (79%) than independent ones (67% and 57%); email is the weakest field in both.

## Data quality notes and limitations
- **Region is derived**, not in the source: counties were mapped to NHS England regions with a lookup written for this project. Historic counties (Middlesex, Avon, the Humbersides) are mapped to the closest present-day region, so a few assignments are approximate.
- **Missing counties (238)** were filled from the same city's most common county (181), then from the nearest hospital within 10 km (38). 19 remain `Unknown County`.
- **Sub-type is weak:** 244 hospitals are `Not Specified` and only 6 are tagged Mental Health, so mental-health provision is under-recorded in this field.
- **Possible duplicates:** 4 records share a name and postcode with another record but have different ODS codes. They are flagged (`possible_duplicate = 1`), not deleted.
- The SQL was written for MySQL 8 and verified by transpiling to SQLite; run it once in MySQL Workbench before submitting.
- Excel summaries are formula-driven (`COUNTIFS`) rather than native PivotTables. Dashboard targets are illustrative assumptions, not NHS standards.
