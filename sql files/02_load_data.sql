-- Run after 01_schema.sql, from the project root.
-- Requires: SET GLOBAL local_infile = 1;  and start the client with  mysql --local-infile=1
USE nhs_hospital_directory;
SET FOREIGN_KEY_CHECKS = 0;
LOAD DATA LOCAL INFILE 'data/clean/regions.csv' INTO TABLE regions FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'data/clean/counties.csv' INTO TABLE counties FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'data/clean/cities.csv' INTO TABLE cities FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'data/clean/sectors.csv' INTO TABLE sectors FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'data/clean/hospital_subtypes.csv' INTO TABLE hospital_subtypes FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'data/clean/parent_organisations.csv' INTO TABLE parent_organisations FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- hospitals: empty CSV fields must become NULL (not '' or 0)
LOAD DATA LOCAL INFILE 'data/clean/hospitals.csv' INTO TABLE hospitals FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
  (hospital_id, organisation_code, hospital_name, sector_id, subtype_id, parent_id, city_id,
   @a1, @a2, @a3, @pc, @lat, @lon, is_pims_managed, possible_duplicate)
  SET address_line_1 = NULLIF(@a1,''), address_line_2 = NULLIF(@a2,''), address_line_3 = NULLIF(@a3,''),
      postcode = NULLIF(@pc,''), latitude = NULLIF(@lat,''), longitude = NULLIF(@lon,'');

LOAD DATA LOCAL INFILE 'data/clean/hospital_contacts.csv' INTO TABLE hospital_contacts FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
  (hospital_id, @ph, @em, @web, @fax)
  SET phone = NULLIF(@ph,''), email = NULLIF(@em,''), website = NULLIF(@web,''), fax = NULLIF(@fax,'');
SET FOREIGN_KEY_CHECKS = 1;

-- sanity checks (expect 1211 hospitals, 961 contact rows)
SELECT 'hospitals' AS tbl, COUNT(*) AS n FROM hospitals UNION ALL SELECT 'hospital_contacts', COUNT(*) FROM hospital_contacts;
