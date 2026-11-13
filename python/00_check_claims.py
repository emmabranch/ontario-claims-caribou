"""
00_check_claims.py

Data quality checks that guide the preparation script:
- claim types and statuses
- whether legacy boundary claims duplicate the cell claims
- issue year distribution (looking for the 2018 conversion spike)
- duplicates and test records in cancelled claims
- caribou range names and types
Reads attributes only (no geometry), so it runs quickly.
"""

from pathlib import Path

import pandas as pd
import pyogrio

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"


def read_attrs(pattern: str) -> pd.DataFrame:
    path = next(RAW.glob(pattern))
    return pyogrio.read_dataframe(path, read_geometry=False)


cells = read_attrs("ogsearth_claims/*/Operational_Cell_Claims.shp")
legacy = read_attrs("ogsearth_claims/*/Legacy_Boundary_Claims_*.shp")
cancel = read_attrs("ogsearth_claims/*/Cancelled_Claim_Polygons.shp")
caribou = read_attrs("caribou_ranges/*/CARIBOU_RANGE_BOUNDARY.shp")

for df in (cells, legacy, cancel):
    df["TENURE_NUM"] = df["TENURE_NUM"].astype(str)
    df["ISSUE_DATE"] = pd.to_datetime(df["ISSUE_DATE"], errors="coerce")

print("\n=== ACTIVE CELL CLAIMS ===")
print(cells["TITLE_TY_1"].value_counts(dropna=False).to_string())
print(cells["TENURE_S_1"].value_counts(dropna=False).to_string())
print("Duplicate tenure numbers:", cells["TENURE_NUM"].duplicated().sum())

print("\n=== LEGACY BOUNDARY CLAIMS ===")
in_cells = legacy["TENURE_NUM"].isin(cells["TENURE_NUM"]).sum()
print(f"Rows: {len(legacy):,}  Unique tenure numbers: {legacy['TENURE_NUM'].nunique():,}")
print(f"Tenure numbers also in cell claims: {in_cells:,}")
print(legacy["TENURE_S_1"].value_counts(dropna=False).to_string())

print("\n=== ISSUE YEAR: ACTIVE CELL CLAIMS ===")
print(cells["ISSUE_DATE"].dt.year.value_counts(dropna=False).sort_index().to_string())
print("Claims issued on 2018-04-10:", (cells["ISSUE_DATE"] == "2018-04-10").sum())

print("\n=== CANCELLED CLAIMS ===")
print(f"Rows: {len(cancel):,}  Unique tenure numbers: {cancel['TENURE_NUM'].nunique():,}")
print(cancel["STATUS"].value_counts(dropna=False).to_string())
test_like = cancel["HOLDER"].str.contains("test|do not use", case=False, na=False)
print("Test-like holder records:", test_like.sum())
print("Issue year (unique tenures):")
first = cancel.sort_values("REVISION_N").drop_duplicates("TENURE_NUM")
print(first["ISSUE_DATE"].dt.year.value_counts(dropna=False).sort_index().to_string())

print("\n=== CARIBOU RANGES ===")
print(caribou[["RANGE_ID", "RANGE_NAME", "RANGE_TYPE"]].to_string())