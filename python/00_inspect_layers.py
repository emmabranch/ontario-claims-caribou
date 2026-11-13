"""
00_inspect_layers.py

Quick look inside the downloaded layers: feature count, geometry type,
coordinate reference system, column names, and two example rows.
Reads only the metadata and first rows, so it runs fast on big files.
"""

from pathlib import Path

import pyogrio

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"

layers = [
    *RAW.glob("ogsearth_claims/*/Operational_Cell_Claims.shp"),
    *RAW.glob("ogsearth_claims/*/Legacy_Boundary_Claims_*.shp"),
    *RAW.glob("ogsearth_claims/*/Cancelled_Claim_Polygons.shp"),
    *RAW.glob("caribou_ranges/*/CARIBOU_RANGE_BOUNDARY.shp"),
    *RAW.glob("ogsearth_admin/*/PROVINCE.shp"),
]

for path in layers:
    info = pyogrio.read_info(path)
    print("=" * 70)
    print(path.name)
    print(f"  Features: {info['features']:,}")
    print(f"  Geometry: {info['geometry_type']}")
    print(f"  CRS:      {info['crs']}")
    print(f"  Columns:  {list(info['fields'])}")
    sample = pyogrio.read_dataframe(path, max_features=2, read_geometry=False)
    print(sample.to_string())