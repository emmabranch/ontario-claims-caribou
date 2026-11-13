# =============================================================================
# 01_load_and_check.R
# Load the prepared GeoPackage (from python/02_prepare_data.py) and run data
# quality checks before analysis: projections, geometry validity, claim
# sizes, dates, and caribou range areas. Saves QA tables to outputs/tables/.
# =============================================================================

library(sf)
library(dplyr)
library(readr)
library(units)
library(here)

gpkg <- here("data", "processed", "claims_caribou.gpkg")

# ---- 1. Layers in the GeoPackage --------------------------------------------
st_layers(gpkg)

active    <- st_read(gpkg, layer = "claims_active",    quiet = TRUE)
cancelled <- st_read(gpkg, layer = "claims_cancelled", quiet = TRUE)
ranges    <- st_read(gpkg, layer = "caribou_ranges",   quiet = TRUE)
province  <- st_read(gpkg, layer = "province",         quiet = TRUE)

# ---- 2. Projections ----------------------------------------------------------
# Every layer must share one projected, equal-area CRS measured in metres.
layers <- list(active = active, cancelled = cancelled,
               ranges = ranges, province = province)
same_crs <- vapply(layers, function(x) st_crs(x) == st_crs(active), logical(1))
stopifnot(all(same_crs))
st_crs(active)$Name      # expect "Canada_Albers_Equal_Area_Conic"
st_is_longlat(active)    # expect FALSE (projected, not latitude/longitude)
st_crs(active)$units     # expect "m"

# ---- 3. Geometry validity ----------------------------------------------------
# Invalid shapes (for example, self-intersecting outlines) can break overlays.
geom_check <- function(x, name) {
  tibble(
    layer   = name,
    n       = nrow(x),
    empty   = sum(st_is_empty(x)),
    invalid = sum(!st_is_valid(x), na.rm = TRUE)
  )
}
qa_geoms <- bind_rows(Map(geom_check, layers, names(layers)))
qa_geoms

# ---- 4. Claim sizes ----------------------------------------------------------
# Single cells should be similar in size; multi-cell claims larger.
# Very small or very large values would suggest data problems.
active$area_ha <- as.numeric(set_units(st_area(active), ha))

claim_sizes <- active |>
  st_drop_geometry() |>
  group_by(title_type) |>
  summarise(
    n         = n(),
    min_ha    = min(area_ha),
    median_ha = median(area_ha),
    max_ha    = max(area_ha),
    total_km2 = sum(area_ha) / 100,
    .groups   = "drop"
  )
claim_sizes

# ---- 5. Dates ----------------------------------------------------------------
date_check <- bind_rows(st_drop_geometry(active), st_drop_geometry(cancelled)) |>
  group_by(record_type) |>
  summarise(
    n                  = n(),
    missing_issue_date = sum(is.na(issue_date)),
    earliest           = min(issue_date, na.rm = TRUE),
    latest             = max(issue_date, na.rm = TRUE),
    converted_2018     = sum(converted_2018, na.rm = TRUE),
    .groups            = "drop"
  )
date_check

# ---- 6. Caribou ranges -------------------------------------------------------
ranges$area_km2 <- as.numeric(set_units(st_area(ranges), km^2))
range_areas <- ranges |>
  st_drop_geometry() |>
  arrange(desc(area_km2))
range_areas

# ---- 7. Quick look -----------------------------------------------------------
plot(st_geometry(province), col = "grey95", border = "grey60",
     main = "Ontario caribou ranges")
plot(st_geometry(ranges), col = adjustcolor("darkgreen", 0.3), add = TRUE)

# ---- 8. Save QA tables -------------------------------------------------------
write_csv(qa_geoms,    here("outputs", "tables", "qa_geometry.csv"))
write_csv(claim_sizes, here("outputs", "tables", "qa_claim_sizes.csv"))
write_csv(date_check,  here("outputs", "tables", "qa_dates.csv"))
write_csv(range_areas, here("outputs", "tables", "caribou_range_areas.csv"))
