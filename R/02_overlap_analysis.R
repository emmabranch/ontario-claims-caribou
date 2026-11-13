# =============================================================================
# 02_overlap_analysis.R
# How much of each woodland caribou range is covered by active mining claims?
#
# Method
# - Repair the few invalid claim geometries with st_make_valid().
# - For each range, find the claims that touch it (one spatial-index lookup),
#   dissolve them into a single footprint with st_union() so that overlapping
#   claims are not double counted, then clip that footprint to the range.
# - Areas in km^2, measured in Canada Albers Equal Area (ESRI:102001).
#
# Output: outputs/tables/range_overlap.csv
# =============================================================================

library(sf)
library(dplyr)
library(readr)
library(units)
library(here)

gpkg <- here("data", "processed", "claims_caribou.gpkg")

active <- st_read(gpkg, layer = "claims_active", quiet = TRUE) |> st_make_valid()
ranges <- st_read(gpkg, layer = "caribou_ranges", quiet = TRUE) |> st_make_valid()

# Date the claims snapshot was downloaded, so results are labelled "as of"
as_of <- read_csv(here("data", "raw", "download_log.csv"), show_col_types = FALSE) |>
  filter(dataset == "ogsearth_claims") |>
  slice_tail(n = 1) |>
  pull(downloaded_utc) |>
  as.Date()

km2 <- function(x) as.numeric(set_units(sum(st_area(x)), km^2))

# ---- 1. Check the ranges do not overlap each other ---------------------------
# If they did, adding up the per-range results would double count.
range_overlap_km2 <- km2(ranges) - km2(st_union(ranges))
range_overlap_km2   # expect roughly 0

# ---- 2. Which claims touch which range? --------------------------------------
# A list with, for each range, the row numbers of the claims intersecting it.
hits <- st_intersects(ranges, active)
setNames(lengths(hits), ranges$range_name)

# ---- 3. Claim footprint within each range ------------------------------------
overlap_one <- function(i) {
  message("Range ", i, " of ", nrow(ranges), ": ", ranges$range_name[i])
  range_i  <- st_geometry(ranges)[i]
  claims_i <- st_geometry(active)[hits[[i]]]

  if (length(claims_i) == 0) {
    sum_km2 <- 0; footprint_km2 <- 0; within_km2 <- 0
  } else {
    footprint     <- st_union(claims_i)                # dissolve overlaps
    clipped       <- st_intersection(footprint, range_i) # part inside range
    sum_km2       <- km2(claims_i)
    footprint_km2 <- km2(footprint)
    within_km2    <- km2(clipped)
  }

  tibble(
    range_name          = ranges$range_name[i],
    range_km2           = km2(range_i),
    claims_touching     = length(claims_i),
    claims_area_sum_km2 = sum_km2,        # simple sum, before dissolving
    claims_overlap_km2  = sum_km2 - footprint_km2,  # double counting removed
    claimed_km2         = within_km2      # dissolved and clipped to range
  )
}

overlap <- bind_rows(lapply(seq_len(nrow(ranges)), overlap_one)) |>
  mutate(pct_claimed = 100 * claimed_km2 / range_km2) |>
  arrange(desc(pct_claimed))

# ---- 4. Total across all ranges ----------------------------------------------
# Claims touching two ranges appear in both counts, so the total claim count
# is left blank; the areas add up correctly because ranges do not overlap.
total <- overlap |>
  summarise(
    range_name         = "All ranges",
    range_km2          = sum(range_km2),
    claims_overlap_km2 = sum(claims_overlap_km2),
    claimed_km2        = sum(claimed_km2)
  ) |>
  mutate(pct_claimed = 100 * claimed_km2 / range_km2)

overlap_out <- bind_rows(overlap, total) |>
  mutate(
    across(where(is.double), \(x) round(x, 2)),
    claims_as_of = as_of
  )

overlap_out |>
  select(range_name, claims_touching, claimed_km2, range_km2, pct_claimed) |>
  print(n = Inf)

write_csv(overlap_out, here("outputs", "tables", "range_overlap.csv"))
