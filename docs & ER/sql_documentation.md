# SQL Documentation

27 queries in `sql/03_analysis_queries.sql`, tested against the cleaned data. Run order: `01_schema.sql` -> `02_load_data.sql` -> `03_analysis_queries.sql`.

| # | Question answered | Techniques |
|---|---|---|
| Q1 | Headline KPIs for the directory | JOINs, conditional SUM, COUNT DISTINCT |
| Q2 | Hospitals by sector with percentage share | GROUP BY, scalar subquery |
| Q3 | Hospitals by subtype with percentage share | GROUP BY, scalar subquery |
| Q4 | Sector x subtype matrix (conditional aggregation) | Conditional aggregation |
| Q5 | Regional provision: hospitals, sector split and independent share | 4-table JOIN, boolean AVG |
| Q6 | Top 10 counties by number of hospitals | 4-table JOIN, filter, LIMIT |
| Q7 | Top 10 cities by number of hospitals | JOIN, filter, LIMIT |
| Q8 | Regions where independent hospitals exceed the national independent share (HAVING + subquery) | HAVING + subquery |
| Q9 | Regions with no Mental Health Hospital recorded (NOT EXISTS) | NOT EXISTS (correlated) |
| Q10 | Geographic bands by latitude (CASE) and sector | CASE bands, conditional SUM |
| Q11 | Northernmost and southernmost hospitals (subqueries on MAX / MIN) | Subquery MAX/MIN, UNION ALL |
| Q12 | Top 10 parent organisations by hospitals operated | JOINs, COUNT DISTINCT |
| Q13 | Parent organisations operating in 3 or more regions (HAVING on DISTINCT count) | HAVING on DISTINCT count |
| Q14 | Parent organisations with more hospitals than the average parent (nested subqueries) | Derived table, nested subquery |
| Q15 | Concentration: share of all hospitals run by parents with 10+ hospitals (derived table) | Derived table, HAVING |
| Q16 | Contact-detail completeness by sector (LEFT JOIN + boolean averages) | LEFT JOIN, boolean AVG |
| Q17 | Hospitals with no contact details at all, by sector (anti-join) | Anti-join (LEFT JOIN ... IS NULL) |
| Q18 | Completeness score (0-5 fields present) distribution (derived table + CASE) | Derived table, arithmetic on booleans |
| Q19 | PIMS-managed share by sector | Aggregates |
| Q20 | Rank counties within each region by hospital count (RANK) | RANK window, derived table |
| Q21 | Top 3 parent organisations in each region (ROW_NUMBER) | ROW_NUMBER, top-N per group |
| Q22 | Each region's share of the national total (SUM OVER window) | SUM() OVER () window |
| Q23 | Pareto: cumulative share of hospitals as counties are added, largest first (running SUM) | Running SUM window (Pareto) |
| Q24 | Sites sharing the same postcode (self-join), a duplicate / co-location check | Self-join |
| Q25 | Keyword search of hospital names (LIKE + UNION ALL) | LIKE, UNION ALL |
| Q26 | Data-quality audit of imputed or missing values (UNION ALL) | UNION ALL audit |
| Q27 | Reporting view: flattened hospital directory for BI / Excel export | CREATE VIEW, 7-table JOIN |
