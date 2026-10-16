-- =====================================================================
-- NHS Hospital Directory | 26 analysis queries (MySQL 8.0)
-- Each query starts with a "-- Qn:" title line (used by the test runner).
-- =====================================================================
USE nhs_hospital_directory;

-- ============ SECTION A: headline KPIs and classification ============

-- Q1: Headline KPIs for the directory
SELECT COUNT(*) AS total_hospitals,
       SUM(s.sector_name = 'NHS Sector') AS nhs_sector,
       SUM(s.sector_name = 'Independent Sector') AS independent_sector,
       COUNT(DISTINCT h.parent_id) AS parent_organisations,
       COUNT(DISTINCT c.county_id) AS counties_covered
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
JOIN cities c ON c.city_id = h.city_id;

-- Q2: Hospitals by sector with percentage share
SELECT s.sector_name,
       COUNT(*) AS hospitals,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM hospitals), 1) AS pct_of_total
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
GROUP BY s.sector_name
ORDER BY hospitals DESC;

-- Q3: Hospitals by subtype with percentage share
SELECT st.subtype_name,
       COUNT(*) AS hospitals,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM hospitals), 1) AS pct_of_total
FROM hospitals h
JOIN hospital_subtypes st ON st.subtype_id = h.subtype_id
GROUP BY st.subtype_name
ORDER BY hospitals DESC;

-- Q4: Sector x subtype matrix (conditional aggregation)
SELECT s.sector_name,
       SUM(st.subtype_name = 'Hospital') AS general_hospital,
       SUM(st.subtype_name = 'Mental Health Hospital') AS mental_health,
       SUM(st.subtype_name = 'Not Specified') AS not_specified,
       COUNT(*) AS total
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
JOIN hospital_subtypes st ON st.subtype_id = h.subtype_id
GROUP BY s.sector_name
ORDER BY total DESC;

-- ============ SECTION B: geography (4-table joins) ============

-- Q5: Regional provision: hospitals, sector split and independent share
SELECT r.region_name,
       COUNT(*) AS hospitals,
       SUM(s.sector_name = 'NHS Sector') AS nhs,
       SUM(s.sector_name = 'Independent Sector') AS independent,
       ROUND(100 * AVG(s.sector_name = 'Independent Sector'), 1) AS pct_independent
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
JOIN regions r ON r.region_id = co.region_id
GROUP BY r.region_name
ORDER BY hospitals DESC;

-- Q6: Top 10 counties by number of hospitals
SELECT co.county_name, r.region_name, COUNT(*) AS hospitals
FROM hospitals h
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
JOIN regions r ON r.region_id = co.region_id
WHERE co.county_name <> 'Unknown County'
GROUP BY co.county_name, r.region_name
ORDER BY hospitals DESC, co.county_name
LIMIT 10;

-- Q7: Top 10 cities by number of hospitals
SELECT c.city_name, co.county_name, COUNT(*) AS hospitals
FROM hospitals h
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
WHERE c.city_name <> 'Unknown City'
GROUP BY c.city_name, co.county_name
ORDER BY hospitals DESC, c.city_name
LIMIT 10;

-- Q8: Regions where independent hospitals exceed the national independent share (HAVING + subquery)
SELECT r.region_name,
       ROUND(100 * AVG(s.sector_name = 'Independent Sector'), 1) AS pct_independent
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
JOIN regions r ON r.region_id = co.region_id
GROUP BY r.region_name
HAVING AVG(s.sector_name = 'Independent Sector') >
       (SELECT AVG(s2.sector_name = 'Independent Sector') FROM hospitals h2 JOIN sectors s2 ON s2.sector_id = h2.sector_id)
ORDER BY pct_independent DESC;

-- Q9: Regions with no Mental Health Hospital recorded (NOT EXISTS)
SELECT r.region_name
FROM regions r
WHERE r.region_name <> 'Unknown'
  AND NOT EXISTS (SELECT 1
                  FROM hospitals h
                  JOIN hospital_subtypes st ON st.subtype_id = h.subtype_id
                  JOIN cities c ON c.city_id = h.city_id
                  JOIN counties co ON co.county_id = c.county_id
                  WHERE co.region_id = r.region_id AND st.subtype_name = 'Mental Health Hospital')
ORDER BY r.region_name;

-- Q10: Geographic bands by latitude (CASE) and sector
SELECT CASE WHEN h.latitude >= 53.5 THEN 'North (53.5+)'
            WHEN h.latitude >= 52.0 THEN 'Midlands (52.0-53.5)'
            ELSE 'South (<52.0)' END AS lat_band,
       SUM(s.sector_name = 'NHS Sector') AS nhs,
       SUM(s.sector_name = 'Independent Sector') AS independent,
       COUNT(*) AS total
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
WHERE h.latitude IS NOT NULL
GROUP BY lat_band
ORDER BY MIN(h.latitude) DESC;

-- Q11: Northernmost and southernmost hospitals (subqueries on MAX / MIN)
SELECT 'Northernmost' AS extreme, hospital_name, latitude FROM hospitals WHERE latitude = (SELECT MAX(latitude) FROM hospitals)
UNION ALL
SELECT 'Southernmost', hospital_name, latitude FROM hospitals WHERE latitude = (SELECT MIN(latitude) FROM hospitals);

-- ============ SECTION C: parent organisations (provider concentration) ============

-- Q12: Top 10 parent organisations by hospitals operated
SELECT p.parent_name, COUNT(*) AS hospitals, COUNT(DISTINCT co.region_id) AS regions_served
FROM hospitals h
JOIN parent_organisations p ON p.parent_id = h.parent_id
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
GROUP BY p.parent_id, p.parent_name
ORDER BY hospitals DESC, p.parent_name
LIMIT 10;

-- Q13: Parent organisations operating in 3 or more regions (HAVING on DISTINCT count)
SELECT p.parent_name, COUNT(*) AS hospitals, COUNT(DISTINCT co.region_id) AS regions_served
FROM hospitals h
JOIN parent_organisations p ON p.parent_id = h.parent_id
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
GROUP BY p.parent_id, p.parent_name
HAVING COUNT(DISTINCT co.region_id) >= 3
ORDER BY regions_served DESC, hospitals DESC;

-- Q14: Parent organisations with more hospitals than the average parent (nested subqueries)
SELECT t.parent_name, t.hospitals
FROM (SELECT p.parent_name, COUNT(*) AS hospitals
      FROM hospitals h JOIN parent_organisations p ON p.parent_id = h.parent_id
      GROUP BY p.parent_id, p.parent_name) t
WHERE t.hospitals > (SELECT AVG(x.n) FROM (SELECT COUNT(*) AS n FROM hospitals GROUP BY parent_id) x)
ORDER BY t.hospitals DESC, t.parent_name
LIMIT 15;

-- Q15: Concentration: share of all hospitals run by parents with 10+ hospitals (derived table)
SELECT SUM(n) AS hospitals_in_large_groups,
       ROUND(100 * SUM(n) / (SELECT COUNT(*) FROM hospitals), 1) AS pct_of_all_hospitals
FROM (SELECT COUNT(*) AS n FROM hospitals GROUP BY parent_id HAVING COUNT(*) >= 10) g;

-- ============ SECTION D: data completeness KPIs ============

-- Q16: Contact-detail completeness by sector (LEFT JOIN + boolean averages)
SELECT s.sector_name,
       COUNT(*) AS hospitals,
       ROUND(100 * AVG(hc.phone   IS NOT NULL), 1) AS pct_with_phone,
       ROUND(100 * AVG(hc.email   IS NOT NULL), 1) AS pct_with_email,
       ROUND(100 * AVG(hc.website IS NOT NULL), 1) AS pct_with_website
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
LEFT JOIN hospital_contacts hc ON hc.hospital_id = h.hospital_id
GROUP BY s.sector_name
ORDER BY s.sector_name;

-- Q17: Hospitals with no contact details at all, by sector (anti-join)
SELECT s.sector_name, COUNT(*) AS hospitals_without_any_contact
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
LEFT JOIN hospital_contacts hc ON hc.hospital_id = h.hospital_id
WHERE hc.hospital_id IS NULL
GROUP BY s.sector_name;

-- Q18: Completeness score (0-5 fields present) distribution (derived table + CASE)
SELECT score, COUNT(*) AS hospitals
FROM (SELECT h.hospital_id,
             (h.postcode IS NOT NULL) + (h.latitude IS NOT NULL) + (hc.phone IS NOT NULL)
             + (hc.email IS NOT NULL) + (hc.website IS NOT NULL) AS score
      FROM hospitals h
      LEFT JOIN hospital_contacts hc ON hc.hospital_id = h.hospital_id) t
GROUP BY score
ORDER BY score DESC;

-- Q19: PIMS-managed share by sector
SELECT s.sector_name,
       SUM(h.is_pims_managed) AS pims_managed,
       COUNT(*) AS hospitals,
       ROUND(100 * AVG(h.is_pims_managed), 1) AS pct_pims_managed
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
GROUP BY s.sector_name;

-- ============ SECTION E: window functions ============

-- Q20: Rank counties within each region by hospital count (RANK)
SELECT region_name, county_name, hospitals,
       RANK() OVER (PARTITION BY region_name ORDER BY hospitals DESC) AS rank_in_region
FROM (SELECT r.region_name, co.county_name, COUNT(*) AS hospitals
      FROM hospitals h
      JOIN cities c ON c.city_id = h.city_id
      JOIN counties co ON co.county_id = c.county_id
      JOIN regions r ON r.region_id = co.region_id
      GROUP BY r.region_name, co.county_name) t
ORDER BY region_name, rank_in_region, county_name;

-- Q21: Top 3 parent organisations in each region (ROW_NUMBER)
SELECT region_name, parent_name, hospitals
FROM (SELECT r.region_name, p.parent_name, COUNT(*) AS hospitals,
             ROW_NUMBER() OVER (PARTITION BY r.region_name ORDER BY COUNT(*) DESC, p.parent_name) AS rn
      FROM hospitals h
      JOIN parent_organisations p ON p.parent_id = h.parent_id
      JOIN cities c ON c.city_id = h.city_id
      JOIN counties co ON co.county_id = c.county_id
      JOIN regions r ON r.region_id = co.region_id
      GROUP BY r.region_name, p.parent_name) t
WHERE rn <= 3
ORDER BY region_name, hospitals DESC, parent_name;

-- Q22: Each region's share of the national total (SUM OVER window)
SELECT r.region_name,
       COUNT(*) AS hospitals,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_national
FROM hospitals h
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
JOIN regions r ON r.region_id = co.region_id
GROUP BY r.region_name
ORDER BY hospitals DESC;

-- Q23: Pareto: cumulative share of hospitals as counties are added, largest first (running SUM)
SELECT county_name, hospitals,
       SUM(hospitals) OVER (ORDER BY hospitals DESC, county_name) AS cumulative_hospitals,
       ROUND(100 * SUM(hospitals) OVER (ORDER BY hospitals DESC, county_name) / SUM(hospitals) OVER (), 1) AS cumulative_pct
FROM (SELECT co.county_name, COUNT(*) AS hospitals
      FROM hospitals h
      JOIN cities c ON c.city_id = h.city_id
      JOIN counties co ON co.county_id = c.county_id
      GROUP BY co.county_name) t
ORDER BY hospitals DESC, county_name
LIMIT 15;

-- ============ SECTION F: data quality, text search, views ============

-- Q24: Sites sharing the same postcode (self-join), a duplicate / co-location check
SELECT h1.postcode, h1.hospital_name AS hospital_a, h2.hospital_name AS hospital_b,
       h1.possible_duplicate + h2.possible_duplicate AS flagged_as_duplicate
FROM hospitals h1
JOIN hospitals h2 ON h2.postcode = h1.postcode AND h2.hospital_id > h1.hospital_id
ORDER BY flagged_as_duplicate DESC, h1.postcode
LIMIT 15;

-- Q25: Keyword search of hospital names (LIKE + UNION ALL)
SELECT 'Community'  AS keyword, SUM(h.hospital_name LIKE '%Community%') AS matches FROM hospitals h
UNION ALL SELECT 'Day Surgery / Surgical', SUM(h.hospital_name LIKE '%Day Surg%' OR h.hospital_name LIKE '%Surgical%') FROM hospitals h
UNION ALL SELECT 'Children', SUM(h.hospital_name LIKE '%Children%') FROM hospitals h
UNION ALL SELECT 'Mental / Psychiatric', SUM(h.hospital_name LIKE '%Mental%' OR h.hospital_name LIKE '%Psychiatric%') FROM hospitals h
UNION ALL SELECT 'University', SUM(h.hospital_name LIKE '%University%') FROM hospitals h;

-- Q26: Data-quality audit of imputed or missing values (UNION ALL)
SELECT 'Unknown county' AS issue, COUNT(*) AS records FROM hospitals h JOIN cities c ON c.city_id = h.city_id JOIN counties co ON co.county_id = c.county_id WHERE co.county_name = 'Unknown County'
UNION ALL SELECT 'Unknown city', COUNT(*) FROM hospitals h JOIN cities c ON c.city_id = h.city_id WHERE c.city_name = 'Unknown City'
UNION ALL SELECT 'Missing postcode', COUNT(*) FROM hospitals WHERE postcode IS NULL
UNION ALL SELECT 'Missing coordinates', COUNT(*) FROM hospitals WHERE latitude IS NULL OR longitude IS NULL
UNION ALL SELECT 'Subtype not specified', COUNT(*) FROM hospitals h JOIN hospital_subtypes st ON st.subtype_id = h.subtype_id WHERE st.subtype_name = 'Not Specified'
UNION ALL SELECT 'Possible duplicate sites', COUNT(*) FROM hospitals WHERE possible_duplicate = 1;

-- Q27: Reporting view: flattened hospital directory for BI / Excel export
CREATE OR REPLACE VIEW vw_hospital_directory AS
SELECT h.hospital_id, h.organisation_code, h.hospital_name, s.sector_name, st.subtype_name,
       p.parent_name, c.city_name, co.county_name, r.region_name, h.postcode, h.latitude, h.longitude,
       h.is_pims_managed, hc.phone, hc.email, hc.website
FROM hospitals h
JOIN sectors s ON s.sector_id = h.sector_id
JOIN hospital_subtypes st ON st.subtype_id = h.subtype_id
JOIN parent_organisations p ON p.parent_id = h.parent_id
JOIN cities c ON c.city_id = h.city_id
JOIN counties co ON co.county_id = c.county_id
JOIN regions r ON r.region_id = co.region_id
LEFT JOIN hospital_contacts hc ON hc.hospital_id = h.hospital_id;
