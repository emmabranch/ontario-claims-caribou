# =============================================================================
# 03_staking_trends.R
# How has mining claim staking changed over time, in caribou ranges and
# around the Ring of Fire?
#
# Method
# - Combine active and cancelled claims, so claims that have since lapsed are
#   still counted in the year they were staked (avoids survivorship bias).
# - Exclude claims dated 2018-04-10: that is the MLAS conversion date for
#   older claims, not when they were staked.
# - Locate each claim by a point guaranteed to fall inside it
#   (st_point_on_surface), then assign it to a caribou range and flag
#   whether it falls in the Ring of Fire area.
# - Ring of Fire area (illustrative, not an official boundary): 50 km radius
#   around McFaulds Lake (52.768295 N, 86.057131 W; Canadian Geographical
#   Names Database).
# - Area staked = sum of claim areas registered that year. Land that was
#   re-staked in a later year counts again, because this measures staking
#   activity, not the footprint at one point in time.
# - 2018 starts on 10 April (MLAS launch) and 2026 is a partial year.
#
# Outputs: outputs/tables/staking_by_year.csv
#          outputs/tables/staking_by_range_year.csv
#          ring_of_fire_area layer added to data/processed/claims_caribou.gpkg
# =============================================================================

library(sf)
library(dplyr)
library(readr)
library(units)
library(here)

gpkg <- here("data", "processed", "claims_caribou.gpkg")

active    <- st_read(gpkg, layer = "claims_active",    quiet = TRUE)
cancelled <- st_read(gpkg, layer = "claims_cancelled", quiet = TRUE)
ranges    <- st_read(gpkg, layer = "caribou_ranges",   quiet = TRUE) |> st_make_valid()

as_of <- read_csv(here("data", "raw", "download_log.csv"), show_col_types = FALSE) |>
  filter(dataset == "ogsearth_claims") |>
  slice_tail(n = 1) |>
  pull(downloaded_utc) |>
  as.Date()

# ---- 1. Combine active and cancelled, drop conversions -----------------------
claims <- rbind(active, cancelled) |>
  st_make_valid() |>
  filter(!converted_2018)

claims$area_km2 <- as.numeric(set_units(st_area(claims), km^2))
table(claims$record_type)

# ---- 2. Ring of Fire area ----------------------------------------------------
ring_of_fire <- st_sfc(st_point(c(-86.057131, 52.768295)), crs = 4326) |>
  st_transform(st_crs(claims)) |>
  st_buffer(dist = 50000) |>                 # metres
  st_sf(name = "Ring of Fire area (50 km around McFaulds Lake)", geometry = _)

# Save it so QGIS can use the same boundary for the map
st_write(ring_of_fire, gpkg, layer = "ring_of_fire_area",
         delete_layer = TRUE, quiet = TRUE)

# ---- 3. Where is each claim? -------------------------------------------------
pts <- st_point_on_surface(st_geometry(claims))

claims$in_ring_of_fire <- lengths(st_intersects(pts, ring_of_fire)) > 0

range_hits <- st_intersects(pts, ranges)
claims$range_name <- vapply(
  range_hits,
  function(i) if (length(i) > 0) ranges$range_name[i[1]] else NA_character_,
  character(1)
)
claims$in_caribou_range <- !is.na(claims$range_name)

# ---- 4. Staking by year ------------------------------------------------------
# Note: the yearly total is named area_staked_km2, NOT area_km2. Reusing the
# per-claim column name would overwrite it before the later lines use it.
claims_df <- st_drop_geometry(claims)

by_year <- claims_df |>
  group_by(issue_year) |>
  summarise(
    claims                 = n(),
    area_staked_km2        = sum(area_km2),
    claims_in_ranges       = sum(in_caribou_range),
    area_in_ranges_km2     = sum(area_km2[in_caribou_range]),
    claims_ring_of_fire    = sum(in_ring_of_fire),
    area_ring_of_fire_km2  = sum(area_km2[in_ring_of_fire]),
    still_active           = sum(record_type == "active"),
    .groups = "drop"
  ) |>
  mutate(
    pct_area_in_ranges = 100 * area_in_ranges_km2 / area_staked_km2,
    pct_still_active   = 100 * still_active / claims,
    partial_year       = issue_year %in% c(2018, as.integer(format(as_of, "%Y"))),
    across(where(is.double), \(x) round(x, 1)),
    claims_as_of       = as_of
  )

by_year |>
  select(issue_year, claims, area_staked_km2, pct_area_in_ranges,
         area_ring_of_fire_km2, pct_still_active, partial_year) |>
  print(n = Inf)

# ---- 5. Staking by caribou range and year ------------------------------------
by_range_year <- claims_df |>
  filter(in_caribou_range) |>
  group_by(range_name, issue_year) |>
  summarise(claims = n(), area_km2 = round(sum(area_km2), 1), .groups = "drop") |>
  mutate(claims_as_of = as_of)

# Which ranges saw the most staking overall?
by_range_year |>
  group_by(range_name) |>
  summarise(claims = sum(claims), area_km2 = sum(area_km2)) |>
  arrange(desc(area_km2)) |>
  print(n = Inf)

# ---- 6. Save -----------------------------------------------------------------
write_csv(by_year,       here("outputs", "tables", "staking_by_year.csv"))
write_csv(by_range_year, here("outputs", "tables", "staking_by_range_year.csv"))
