-- =====================================================================
-- NHS Hospital Directory Database | MySQL 8.0 | Third Normal Form (3NF)
-- Source: NHS ODS hospital directory (1,211 hospitals in England)
-- =====================================================================
DROP DATABASE IF EXISTS nhs_hospital_directory;
CREATE DATABASE nhs_hospital_directory CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nhs_hospital_directory;

-- ---------- geography hierarchy: region -> county -> city ----------
CREATE TABLE regions (
    region_id    INT AUTO_INCREMENT PRIMARY KEY,
    region_name  VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE counties (
    county_id    INT AUTO_INCREMENT PRIMARY KEY,
    county_name  VARCHAR(40) NOT NULL UNIQUE,
    region_id    INT NOT NULL,
    CONSTRAINT fk_county_region FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

CREATE TABLE cities (
    city_id      INT AUTO_INCREMENT PRIMARY KEY,
    city_name    VARCHAR(60) NOT NULL,
    county_id    INT NOT NULL,
    CONSTRAINT uq_city_county UNIQUE (city_name, county_id),
    CONSTRAINT fk_city_county FOREIGN KEY (county_id) REFERENCES counties(county_id)
);

-- ---------- classification lookups ----------
CREATE TABLE sectors (
    sector_id    INT AUTO_INCREMENT PRIMARY KEY,
    sector_name  VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE hospital_subtypes (
    subtype_id   INT AUTO_INCREMENT PRIMARY KEY,
    subtype_name VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE parent_organisations (
    parent_id       INT AUTO_INCREMENT PRIMARY KEY,
    parent_ods_code VARCHAR(10) NOT NULL UNIQUE,
    parent_name     VARCHAR(150) NOT NULL
);

-- ---------- main entity ----------
CREATE TABLE hospitals (
    hospital_id        INT PRIMARY KEY,                 -- OrganisationID from source
    organisation_code  VARCHAR(10)  NOT NULL UNIQUE,    -- ODS code
    hospital_name      VARCHAR(150) NOT NULL,
    sector_id          INT NOT NULL,
    subtype_id         INT NOT NULL,
    parent_id          INT NOT NULL,
    city_id            INT NOT NULL,
    address_line_1     VARCHAR(100) NULL,
    address_line_2     VARCHAR(100) NULL,
    address_line_3     VARCHAR(100) NULL,
    postcode           VARCHAR(8)   NULL,
    latitude           DECIMAL(9,6) NULL,
    longitude          DECIMAL(9,6) NULL,
    is_pims_managed    TINYINT(1)   NOT NULL,
    possible_duplicate TINYINT(1)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_h_sector  FOREIGN KEY (sector_id)  REFERENCES sectors(sector_id),
    CONSTRAINT fk_h_subtype FOREIGN KEY (subtype_id) REFERENCES hospital_subtypes(subtype_id),
    CONSTRAINT fk_h_parent  FOREIGN KEY (parent_id)  REFERENCES parent_organisations(parent_id),
    CONSTRAINT fk_h_city    FOREIGN KEY (city_id)    REFERENCES cities(city_id),
    CONSTRAINT chk_lat  CHECK (latitude  IS NULL OR latitude  BETWEEN 49 AND 61),
    CONSTRAINT chk_lon  CHECK (longitude IS NULL OR longitude BETWEEN -9 AND 2),
    CONSTRAINT chk_bool CHECK (is_pims_managed IN (0,1) AND possible_duplicate IN (0,1))
);

-- optional 1:1 contact details (only hospitals with at least one contact value have a row)
CREATE TABLE hospital_contacts (
    hospital_id INT PRIMARY KEY,
    phone       VARCHAR(30)  NULL,
    email       VARCHAR(150) NULL,
    website     VARCHAR(255) NULL,
    fax         VARCHAR(30)  NULL,
    CONSTRAINT fk_contact_hospital FOREIGN KEY (hospital_id) REFERENCES hospitals(hospital_id)
);

CREATE INDEX idx_h_sector ON hospitals(sector_id);
CREATE INDEX idx_h_parent ON hospitals(parent_id);
CREATE INDEX idx_h_city   ON hospitals(city_id);
CREATE INDEX idx_h_name   ON hospitals(hospital_name);
CREATE INDEX idx_h_pc     ON hospitals(postcode);
