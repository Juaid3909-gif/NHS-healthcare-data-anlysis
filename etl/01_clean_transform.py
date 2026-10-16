"""
ETL for the NHS ODS hospital directory (data/raw/Hospital.csv).
EXTRACT raw CSV -> TRANSFORM (clean, standardise, impute) -> one CSV per 3NF table + cleaning log.
Run from the project root:  python3 etl/01_clean_transform.py
"""
import re, numpy as np, pandas as pd
from urllib.parse import urlparse

RAW, OUT = "data/raw/Hospital.csv", "data/clean/"
log = []
def note(step, n, detail=""): log.append({"step": step, "rows_affected": int(n), "detail": detail})

# ---------------- EXTRACT ----------------
# The file has an unnamed leading index column (rows have 23 fields, header 22) and a malformed
# last header "Fax,,," -> read with index_col=0 and strip the stray commas from header names.
df = pd.read_csv(RAW, dtype=str, index_col=0, keep_default_na=False)
df.columns = [c.strip(",").strip() for c in df.columns]
note("Extract: raw rows loaded", len(df), "unnamed leading index column dropped; header 'Fax,,,' repaired to 'Fax'")

# ---------------- TRANSFORM ----------------
# 1. whitespace + empty strings -> NULL
changed = 0
for c in df.columns:
    cleaned = df[c].str.strip().str.replace(r"\s+", " ", regex=True)
    changed += (cleaned != df[c]).sum(); df[c] = cleaned.replace("", np.nan)
note("Trimmed / collapsed whitespace in text fields", changed)
note("Blank strings converted to NULL", df.isna().sum().sum(), "all columns combined")

# 2. data types
df["Latitude"]  = pd.to_numeric(df["Latitude"],  errors="coerce")
df["Longitude"] = pd.to_numeric(df["Longitude"], errors="coerce")
bad_geo = df["Latitude"].notna() & ~(df["Latitude"].between(49.8, 60.9) & df["Longitude"].between(-8.7, 1.9))
df.loc[bad_geo, ["Latitude", "Longitude"]] = np.nan
note("Coordinates outside UK bounding box set to NULL", bad_geo.sum())
note("Missing coordinates left NULL", df["Latitude"].isna().sum())
df["IsPimsManaged"] = df["IsPimsManaged"].map({"True": 1, "False": 0}).astype("Int64")
df["OrganisationID"] = df["OrganisationID"].astype(int)

# 3. standardise formats
df["Postcode"] = df["Postcode"].str.upper().str.replace(r"^(.*?)\s*(\d[A-Z]{2})$", r"\1 \2", regex=True)
bad_pc = df["Postcode"].notna() & ~df["Postcode"].str.match(r"^[A-Z]{1,2}\d[A-Z\d]? \d[A-Z]{2}$")
df.loc[bad_pc, "Postcode"] = np.nan
note("Invalid postcodes set to NULL", bad_pc.sum()); note("Missing postcode", df["Postcode"].isna().sum())

for c in ["Phone", "Fax"]:
    before = df[c].copy()
    df[c] = df[c].str.replace(r"[,\s]+$", "", regex=True).str.replace(r"^[,\s]+", "", regex=True).replace("", np.nan)
    note(f"Cleaned trailing ',,,' artefacts in {c}", (before.fillna("") != df[c].fillna("")).sum())
df["Email"] = df["Email"].str.lower()
def norm_url(u):
    if pd.isna(u): return np.nan
    if not re.match(r"^https?://", u, re.I): u = "https://" + u
    p = urlparse(u); return f"{p.scheme.lower()}://{p.netloc.lower()}{p.path}".rstrip("/") + (f"?{p.query}" if p.query else "")
raw_web = df["Website"].copy(); df["Website"] = df["Website"].apply(norm_url)
note("Websites standardised (scheme added, host lower-cased, trailing '/' removed)", (raw_web.fillna("") != df["Website"].fillna("")).sum())

df["SubType"] = df["SubType"].replace({"UNKNOWN": "Not Specified"})
note("SubType 'UNKNOWN' relabelled 'Not Specified'", (raw_web.index.size and (df["SubType"] == "Not Specified").sum()))

# 4. county standardisation (historic / duplicate labels) + region lookup
county_fix = {"Durham": "County Durham", "Yorkshire(East Riding)": "East Riding of Yorkshire"}
n = df["County"].isin(county_fix).sum(); df["County"] = df["County"].replace(county_fix)
note("County labels standardised (Durham, Yorkshire(East Riding))", n)
REGION = {"Avon":"South West","Bedfordshire":"East of England","Berkshire":"South East","Buckinghamshire":"South East",
 "Cambridgeshire":"East of England","Cheshire":"North West","Cleveland":"North East","Cornwall":"South West","County Durham":"North East",
 "Cumbria":"North West","Derbyshire":"East Midlands","Devon":"South West","Dorset":"South West","East Riding of Yorkshire":"Yorkshire and The Humber",
 "East Sussex":"South East","Essex":"East of England","Gloucestershire":"South West","Greater London":"London","Greater Manchester":"North West",
 "Hampshire":"South East","Herefordshire":"West Midlands","Hertfordshire":"East of England","Isle of Wight":"South East","Kent":"South East",
 "Lancashire":"North West","Leicestershire":"East Midlands","Lincolnshire":"East Midlands","Merseyside":"North West","Middlesex":"London",
 "Norfolk":"East of England","North Humberside":"Yorkshire and The Humber","North Yorkshire":"Yorkshire and The Humber","Northamptonshire":"East Midlands",
 "Northumberland":"North East","Nottinghamshire":"East Midlands","Oxfordshire":"South East","Rutland":"East Midlands","Shropshire":"West Midlands",
 "Somerset":"South West","South Humberside":"Yorkshire and The Humber","South Yorkshire":"Yorkshire and The Humber","Staffordshire":"West Midlands",
 "Suffolk":"East of England","Surrey":"South East","Sussex":"South East","Tyne and Wear":"North East","Warwickshire":"West Midlands",
 "West Midlands":"West Midlands","West Sussex":"South East","West Yorkshire":"Yorkshire and The Humber","Wiltshire":"South West",
 "Worcestershire":"West Midlands","Yorkshire":"Yorkshire and The Humber"}
unmapped = set(df["County"].dropna()) - set(REGION); assert not unmapped, unmapped

# 5. missing county: (a) same city -> modal county, (b) nearest hospital with a county within 10 km, (c) 'Unknown County'
miss0 = df["County"].isna().sum(); note("Missing county before imputation", miss0)
city_mode = df.dropna(subset=["City", "County"]).groupby("City")["County"].agg(lambda s: s.mode().iloc[0])
m = df["County"].isna() & df["City"].isin(city_mode.index)
df.loc[m, "County"] = df.loc[m, "City"].map(city_mode); note("County imputed from same city's most common county", m.sum())
known = df[df["County"].notna() & df["Latitude"].notna()]
def hav(la1, lo1, la2, lo2):
    la1, lo1, la2, lo2 = map(np.radians, (la1, lo1, la2, lo2))
    a = np.sin((la2-la1)/2)**2 + np.cos(la1)*np.cos(la2)*np.sin((lo2-lo1)/2)**2
    return 6371 * 2 * np.arcsin(np.sqrt(a))
k = 0
for i in df[df["County"].isna() & df["Latitude"].notna()].index:
    d = hav(df.at[i,"Latitude"], df.at[i,"Longitude"], known["Latitude"].values, known["Longitude"].values)
    j = d.argmin()
    if d[j] <= 10: df.at[i, "County"] = known["County"].iloc[j]; k += 1
note("County imputed from nearest hospital with known county (<=10 km)", k)
note("County still unknown -> 'Unknown County'", df["County"].isna().sum())
df["County"] = df["County"].fillna("Unknown County"); REGION["Unknown County"] = "Unknown"
note("Missing city -> 'Unknown City'", df["City"].isna().sum()); df["City"] = df["City"].fillna("Unknown City")

# 6. duplicates
note("Exact duplicate rows", df.duplicated().sum(), "none found")
note("Duplicate ODS codes / IDs", df["OrganisationCode"].duplicated().sum() + df["OrganisationID"].duplicated().sum(), "none found")
pd_mask = df["Postcode"].notna() & df.duplicated(["OrganisationName", "Postcode"], keep="first")
df["PossibleDuplicate"] = pd_mask.astype(int)
note("Possible duplicate sites flagged (same name + postcode, different ODS code); kept, not deleted", pd_mask.sum())

# ---------------- build 3NF tables ----------------
def lookup(series, idcol, namecol):
    t = pd.DataFrame({namecol: sorted(series.dropna().unique())}); t.insert(0, idcol, range(1, len(t)+1)); return t
regions = lookup(pd.Series(sorted(set(REGION.values()))), "region_id", "region_name")
cm = pd.DataFrame({"county_name": sorted(df["County"].unique())})
cm["region_name"] = cm["county_name"].map(REGION)
counties = cm.merge(regions, on="region_name")[["county_name", "region_id"]].sort_values("county_name").reset_index(drop=True)
counties.insert(0, "county_id", range(1, len(counties)+1))
cc = df[["City", "County"]].drop_duplicates().rename(columns={"City":"city_name","County":"county_name"}).merge(counties[["county_id","county_name"]], on="county_name")
cities = cc[["city_name","county_id"]].sort_values(["city_name","county_id"]).reset_index(drop=True); cities.insert(0, "city_id", range(1, len(cities)+1))
sectors  = lookup(df["Sector"], "sector_id", "sector_name")
subtypes = lookup(df["SubType"], "subtype_id", "subtype_name")
parents = df[["ParentODSCode","ParentName"]].drop_duplicates().rename(columns={"ParentODSCode":"parent_ods_code","ParentName":"parent_name"}).sort_values("parent_name").reset_index(drop=True)
parents.insert(0, "parent_id", range(1, len(parents)+1))

h = (df.merge(sectors, left_on="Sector", right_on="sector_name").merge(subtypes, left_on="SubType", right_on="subtype_name")
       .merge(parents, left_on="ParentODSCode", right_on="parent_ods_code")
       .merge(counties[["county_id","county_name"]], left_on="County", right_on="county_name")
       .merge(cities.merge(counties[["county_id","county_name"]], on="county_id")[["city_id","city_name","county_name"]], left_on=["City","County"], right_on=["city_name","county_name"]))
assert len(h) == len(df), "join changed row count"
hospitals = h.rename(columns={"OrganisationID":"hospital_id","OrganisationCode":"organisation_code","OrganisationName":"hospital_name",
    "Address1":"address_line_1","Address2":"address_line_2","Address3":"address_line_3","Postcode":"postcode","Latitude":"latitude",
    "Longitude":"longitude","IsPimsManaged":"is_pims_managed","PossibleDuplicate":"possible_duplicate"})[
    ["hospital_id","organisation_code","hospital_name","sector_id","subtype_id","parent_id","city_id","address_line_1","address_line_2","address_line_3",
     "postcode","latitude","longitude","is_pims_managed","possible_duplicate"]].sort_values("hospital_id").reset_index(drop=True)
contacts = h.rename(columns={"OrganisationID":"hospital_id","Phone":"phone","Email":"email","Website":"website","Fax":"fax"})[
    ["hospital_id","phone","email","website","fax"]].sort_values("hospital_id").reset_index(drop=True)
contacts = contacts.dropna(subset=["phone","email","website","fax"], how="all")
note("Hospitals with at least one contact detail (rows in hospital_contacts)", len(contacts))
note("Load-ready hospitals rows", len(hospitals))

for name, t in [("regions",regions),("counties",counties),("cities",cities),("sectors",sectors),("hospital_subtypes",subtypes),
                ("parent_organisations",parents),("hospitals",hospitals),("hospital_contacts",contacts)]:
    t.to_csv(OUT + f"{name}.csv", index=False); print(f"{name:22s}{len(t):>6} rows")
pd.DataFrame(log).to_csv(OUT + "cleaning_log.csv", index=False)
print(); print(pd.DataFrame(log)[["step","rows_affected"]].to_string(index=False))
