# Data Dictionary

Database: `nhs_hospital_directory` (MySQL 8.0). Source: NHS ODS hospital directory (`Hospital.csv`, 1,211 rows). Design: Third Normal Form.


## regions

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| region_id | INT | PK | No | Surrogate key | Auto-increment |
| region_name | VARCHAR(40) |  | No | NHS England region (plus 'Unknown') | UNIQUE; derived from county by lookup |

## counties

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| county_id | INT | PK | No | Surrogate key | Auto-increment |
| county_name | VARCHAR(40) |  | No | County as recorded in ODS, standardised | UNIQUE; 'Unknown County' where it could not be imputed |
| region_id | INT | FK | No | -> regions.region_id | Referential integrity |

## cities

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| city_id | INT | PK | No | Surrogate key | Auto-increment |
| city_name | VARCHAR(60) |  | No | City / town | 'Unknown City' where missing in source |
| county_id | INT | FK | No | -> counties.county_id | UNIQUE with city_name (same name can exist in two counties) |

## sectors

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| sector_id | INT | PK | No | Surrogate key | Auto-increment |
| sector_name | VARCHAR(30) |  | No | NHS Sector / Independent Sector | UNIQUE |

## hospital_subtypes

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| subtype_id | INT | PK | No | Surrogate key | Auto-increment |
| subtype_name | VARCHAR(40) |  | No | Hospital / Mental Health Hospital / Not Specified | UNIQUE; source 'UNKNOWN' relabelled |

## parent_organisations

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| parent_id | INT | PK | No | Surrogate key | Auto-increment |
| parent_ods_code | VARCHAR(10) |  | No | ODS code of the parent organisation | UNIQUE |
| parent_name | VARCHAR(150) |  | No | Trust / company that operates the hospital |  |

## hospitals

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| hospital_id | INT | PK | No | OrganisationID from the source file | Not auto-generated |
| organisation_code | VARCHAR(10) |  | No | ODS organisation code | UNIQUE |
| hospital_name | VARCHAR(150) |  | No | Hospital / site name | Trimmed; names are not unique (22 repeated) |
| sector_id | INT | FK | No | -> sectors.sector_id | Referential integrity |
| subtype_id | INT | FK | No | -> hospital_subtypes.subtype_id | Referential integrity |
| parent_id | INT | FK | No | -> parent_organisations.parent_id | Referential integrity |
| city_id | INT | FK | No | -> cities.city_id (city -> county -> region) | Referential integrity |
| address_line_1 | VARCHAR(100) |  | Yes | Address line 1 | NULL if missing (27% missing in source) |
| address_line_2 | VARCHAR(100) |  | Yes | Address line 2 | NULL if missing |
| address_line_3 | VARCHAR(100) |  | Yes | Address line 3 | NULL if missing |
| postcode | VARCHAR(8) |  | Yes | UK postcode, upper-case, single space | Format validated by regex; 1 missing |
| latitude | DECIMAL(9,6) |  | Yes | WGS84 latitude | CHECK 49-61; 2 missing |
| longitude | DECIMAL(9,6) |  | Yes | WGS84 longitude | CHECK -9 to 2; 2 missing |
| is_pims_managed | TINYINT(1) |  | No | 1 if record is managed in PIMS | CHECK in (0,1) |
| possible_duplicate | TINYINT(1) |  | No | 1 if another record has the same name and postcode | Flag only; row kept |

## hospital_contacts

| Column | Type | Key | Null | Description | Rules |
|---|---|---|---|---|---|
| hospital_id | INT | PK/FK | No | -> hospitals.hospital_id (1:0..1) | Row exists only if the hospital has any contact detail |
| phone | VARCHAR(30) |  | Yes | Switchboard phone | Whitespace normalised |
| email | VARCHAR(150) |  | Yes | Contact email | Lower-cased |
| website | VARCHAR(255) |  | Yes | Website URL | https:// added if missing; host lower-cased; trailing / removed |
| fax | VARCHAR(30) |  | Yes | Fax number | Source column held ',,,' artefacts; cleaned |


## Normalisation notes (why this is 3NF)

- **1NF:** every column is atomic; every table has a primary key. The source file's three address lines stay as separate columns.
- **2NF:** every table uses a single-column key, so there are no partial dependencies.
- **3NF:** the source repeated city, county, sector, subtype and parent name on every row. Those facts now live once in their own tables: `city -> county -> region` is a transitive chain split into `cities`, `counties` and `regions`; `ParentName` depends on `ParentODSCode`, so it moved to `parent_organisations`. Contact details are optional and sit in `hospital_contacts`.
- **Derived data:** `regions` is not in the source. It comes from a county-to-region lookup written for this project (historic counties such as Middlesex and Avon are mapped to the closest present-day region, so a few assignments are approximate).
