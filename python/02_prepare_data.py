"""
02_prepare_data.py

Clean and standardise the raw layers, and save them to one GeoPackage
(data/processed/claims_caribou.gpkg) ready for analysis in R.

Decisions (based on python/00_check_claims.py):
- Active claims come from Operational_Cell_Claims only. The legacy boundary
  claims file is NOT used, because almost all of its tenure numbers already
  appear in the cell claims file (as Boundary Cell Mining Claims).
- Leased tenures are dropped (a lease is a different kind of tenure).
- Test records (holder names containing "test" or "do not use") are dropped.
- Cancelled claims: keep the latest revision of each tenure, keep only those
  whose status is "Cancelled", and drop any tenure that is active today.
  Amalgamated and merged records are administrative changes, not lapses,
  so they are excluded.
- Claims with an issue date of 2018-04-10 are flagged: that is the date
  older claims were converted into the new online system (MLAS), not the
  date they were actually staked.
- Holder names are dropped to protect individual prospectors' privacy.
- Caribou "Discontinuous Distribution" is kept as a separate layer, not a range.
- Everything is reprojected to Canada Albers Equal Area (ESRI:102001),
  so areas in R are measured in a projection that preserves area.

Run from the project root:
    conda activate claims-caribou
    python python/02_prepare_data.py
"""

from datetime import datetime
from pathlib import Path

import geopandas as gpd
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "processed" / "claims_caribou.gpkg"
LOG_PATH = ROOT / "docs" / "data_prep_log.md"

ANALYSIS_CRS = "ESRI:102001"  # Canada Albers Equal Area Conic
CONVERSION_DATE = pd.Timestamp("2018-04-10")
TEST_PATTERN = r"\btest\b|do not use"

log_lines: list[str] = []


def log(message: str) -> None:
    """Print a message and keep it for the prep log."""
    print(message)
    log_lines.append(message)


def find(pattern: str) -> Path:
    """Find one raw file by pattern (file names can include dates)."""
    matches = sorted(RAW.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"No file matching {pattern} in data/raw")
    return matches[-1]


def is_test(holder: pd.Series) -> pd.Series:
    return holder.str.contains(TEST_PATTERN, case=False, na=False, regex=True)


def prep_active() -> gpd.GeoDataFrame:
    gdf = gpd.read_file(find("ogsearth_claims/*/Operational_Cell_Claims.shp"))
    log(f"- Active cell claims read: {len(gdf):,}")

    leased = gdf["TENURE_S_1"] == "Leased"
    log(f"  - dropped leased: {leased.sum():,}")
    gdf = gdf[~leased]

    test = is_test(gdf["HOLDER"])
    log(f"  - dropped test records: {test.sum():,}")
    gdf = gdf[~test]

    out = gdf.rename(columns={
        "TENURE_NUM": "tenure_num",
        "TITLE_TY_1": "title_type",
        "TENURE_S_1": "status",
        "ISSUE_DATE": "issue_date",
    })[["tenure_num", "title_type", "status", "issue_date", "geometry"]]
    out["end_date"] = pd.NaT
    out["record_type"] = "active"
    log(f"  - kept: {len(out):,}")
    return out


def prep_cancelled(active_ids: set[str]) -> gpd.GeoDataFrame:
    gdf = gpd.read_file(find("ogsearth_claims/*/Cancelled_Claim_Polygons.shp"))
    gdf["TENURE_NUM"] = gdf["TENURE_NUM"].astype(str)
    log(f"- Cancelled file rows read: {len(gdf):,}")

    gdf = (gdf.sort_values(["TENURE_NUM", "REVISION_N"])
              .drop_duplicates("TENURE_NUM", keep="last"))
    log(f"  - after keeping latest revision per tenure: {len(gdf):,}")

    gdf = gdf[gdf["STATUS"] == "Cancelled"]
    log(f"  - with status 'Cancelled': {len(gdf):,}")

    test = is_test(gdf["HOLDER"])
    log(f"  - dropped test records: {test.sum():,}")
    gdf = gdf[~test]

    now_active = gdf["TENURE_NUM"].isin(active_ids)
    log(f"  - dropped tenures that are active today: {now_active.sum():,}")
    gdf = gdf[~now_active]

    out = gdf.rename(columns={
        "TENURE_NUM": "tenure_num",
        "TITLE_TY_1": "title_type",
        "STATUS": "status",
        "ISSUE_DATE": "issue_date",
        "TERMINATIO": "end_date",
    })[["tenure_num", "title_type", "status", "issue_date", "end_date", "geometry"]]
    out["record_type"] = "cancelled"
    log(f"  - kept: {len(out):,}")
    return out


def finish_claims(gdf: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    """Shared tidying for active and cancelled claims."""
    gdf["tenure_num"] = gdf["tenure_num"].astype(str)
    gdf["issue_date"] = pd.to_datetime(gdf["issue_date"], errors="coerce")
    gdf["end_date"] = pd.to_datetime(gdf["end_date"], errors="coerce")
    gdf["issue_year"] = gdf["issue_date"].dt.year.astype("Int64")
    gdf["converted_2018"] = gdf["issue_date"] == CONVERSION_DATE
    cols = ["tenure_num", "record_type", "title_type", "status",
            "issue_date", "issue_year", "end_date", "converted_2018", "geometry"]
    return gdf[cols].to_crs(ANALYSIS_CRS)


def prep_caribou() -> tuple[gpd.GeoDataFrame, gpd.GeoDataFrame]:
    gdf = gpd.read_file(find("caribou_ranges/*/CARIBOU_RANGE_BOUNDARY.shp"))
    gdf = gdf.rename(columns={
        "RANGE_ID": "range_id", "RANGE_NAME": "range_name", "RANGE_TYPE": "range_type"
    })[["range_id", "range_name", "range_type", "geometry"]].to_crs(ANALYSIS_CRS)
    discontinuous = gdf["range_type"] == "Discontinuous"
    log(f"- Caribou features: {len(gdf)} "
        f"({(~discontinuous).sum()} ranges, {discontinuous.sum()} discontinuous zone)")
    return gdf[~discontinuous], gdf[discontinuous]


def prep_province() -> gpd.GeoDataFrame:
    gdf = gpd.read_file(find("ogsearth_admin/*/PROVINCE.shp"))
    return gdf[["OFF_NAME", "geometry"]].rename(
        columns={"OFF_NAME": "name"}).to_crs(ANALYSIS_CRS)


def main() -> None:
    log(f"# Data preparation log\n\nRun: {datetime.now():%Y-%m-%d %H:%M}\n")

    active = prep_active()
    cancelled = prep_cancelled(set(active["tenure_num"].astype(str)))
    active = finish_claims(active)
    cancelled = finish_claims(cancelled)
    log(f"- Active claims with conversion date (2018-04-10): "
        f"{active['converted_2018'].sum():,}")

    ranges, discontinuous = prep_caribou()
    province = prep_province()

    # Start fresh each run, so no stale layers are left behind
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()

    layers = {
        "claims_active": active,
        "claims_cancelled": cancelled,
        "caribou_ranges": ranges,
        "caribou_discontinuous": discontinuous,
        "province": province,
    }
    log(f"\nWriting {OUT.relative_to(ROOT)} (CRS {ANALYSIS_CRS}):")
    for name, layer in layers.items():
        print(f"  writing {name} ...")
        layer.to_file(OUT, layer=name, driver="GPKG")
        log(f"- {name}: {len(layer):,} features")

    LOG_PATH.parent.mkdir(exist_ok=True)
    LOG_PATH.write_text("\n".join(log_lines) + "\n")
    print(f"\nDone. Log written to {LOG_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()