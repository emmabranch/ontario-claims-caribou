# =============================================================================
# 04_figures.R
# Publication figures from the summary tables (no spatial data needed):
#   1. Share of each caribou range under active mining claims
#   2. Area staked per year, inside and outside caribou ranges
#
# Colours match the QGIS map: burnt orange = claims inside caribou range,
# warm grey = everything else (de-emphasised on purpose).
# Outputs: outputs/figures/fig1_range_overlap.png
#          outputs/figures/fig2_staking_by_year.png
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(here)

claim_orange <- "#D95F02"
other_grey   <- "#C9C4BC"
ink          <- "#222222"
ink_muted    <- "#666666"
grid_grey    <- "#E6E6E6"

theme_claims <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title         = element_text(face = "bold", colour = ink, size = 14),
      plot.subtitle      = element_text(colour = ink_muted, margin = margin(b = 12)),
      plot.caption       = element_text(colour = ink_muted, size = 8, hjust = 0,
                                        margin = margin(t = 12)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      axis.text          = element_text(colour = ink_muted),
      axis.title         = element_text(colour = ink_muted, size = 10),
      panel.grid.minor   = element_blank(),
      panel.grid.major   = element_line(colour = grid_grey, linewidth = 0.3),
      legend.position    = "top",
      legend.justification = "left",
      legend.title       = element_blank(),
      legend.text        = element_text(colour = ink),
      plot.margin        = margin(15, 20, 10, 15)
    )
}

source_note <- paste(
  "Data: Ontario Ministry of Energy and Mines, OGSEarth (MLAS operational data, unofficial version);",
  "Ontario MECP, Caribou Range Boundary.\nA mining claim is not a mine, and overlap is not impact."
)

# ---- Figure 1: share of each range under claim -------------------------------
overlap <- read_csv(here("outputs", "tables", "range_overlap.csv"), show_col_types = FALSE)
as_of   <- format(as.Date(overlap$claims_as_of[1]), "%d %B %Y")
all_pct <- overlap |> filter(range_name == "All ranges") |> pull(pct_claimed)

by_range <- overlap |>
  filter(range_name != "All ranges") |>
  mutate(range_name = reorder(range_name, pct_claimed))

fig1 <- ggplot(by_range, aes(x = pct_claimed, y = range_name)) +
  geom_col(fill = claim_orange, width = 0.7) +
  geom_vline(xintercept = all_pct, linetype = "dashed",
             colour = ink_muted, linewidth = 0.4) +
  # White-backed labels, drawn after the reference line so it never cuts through a number
  geom_label(aes(label = sprintf("%.1f%%", pct_claimed)),
             hjust = -0.1, size = 3.2, colour = ink, fill = "white",
             label.size = 0, label.padding = unit(0.1, "lines")) +
  annotate("text", x = all_pct + 0.5, y = 0.6, hjust = 0, vjust = 0, size = 3,
           colour = ink_muted, label = sprintf("All ranges: %.1f%%", all_pct)) +
  scale_x_continuous(labels = \(x) paste0(x, "%"),
                     limits = c(0, max(by_range$pct_claimed) * 1.15),
                     expand = c(0, 0)) +
  labs(
    title    = "Share of each woodland caribou range under active mining claims",
    subtitle = paste0("Active claims as of ", as_of,
                      ". Overlapping claims dissolved before measuring area."),
    x = "Range area under active claim", y = NULL,
    caption = source_note
  ) +
  theme_claims() +
  theme(panel.grid.major.y = element_blank())

ggsave(here("outputs", "figures", "fig1_range_overlap.png"), fig1,
       width = 8, height = 5.5, dpi = 300, bg = "white")

# ---- Figure 2: area staked per year, inside vs outside ranges ----------------
by_year <- read_csv(here("outputs", "tables", "staking_by_year.csv"), show_col_types = FALSE)

staked_long <- by_year |>
  mutate(
    outside_km2 = area_staked_km2 - area_in_ranges_km2,
    year_label  = ifelse(partial_year, paste0(issue_year, "*"), as.character(issue_year))
  ) |>
  select(year_label, inside = area_in_ranges_km2, outside = outside_km2) |>
  pivot_longer(c(inside, outside), names_to = "where", values_to = "km2") |>
  mutate(where = factor(where, levels = c("outside", "inside"),
                        labels = c("Outside caribou ranges", "Inside caribou ranges")))

# Label only the year that tells the story: the 2025 jump in share
lab_2025 <- by_year |>
  filter(issue_year == 2025) |>
  transmute(year_label = "2025", y = area_staked_km2,
            label = sprintf("%.0f%% inside\ncaribou ranges", pct_area_in_ranges))

fig2 <- ggplot(staked_long, aes(x = year_label, y = km2, fill = where)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.4) +
  geom_text(data = lab_2025, aes(x = year_label, y = y, label = label),
            inherit.aes = FALSE, vjust = -0.3, size = 3, colour = ink, lineheight = 0.9) +
  scale_fill_manual(values = c("Outside caribou ranges" = other_grey,
                               "Inside caribou ranges"  = claim_orange),
                    breaks = c("Inside caribou ranges", "Outside caribou ranges")) +
  scale_y_continuous(labels = scales::label_comma(),
                     expand = expansion(mult = c(0, 0.12))) +
  labs(
    title    = "Mining claim area staked each year in Ontario",
    subtitle = paste0("Includes claims that have since lapsed. In most years 40 to 46% of staked area\n",
                      "fell inside caribou ranges; it was 53% in 2021 and 60% in 2025."),
    x = NULL, y = expression("Area staked (km"^2*")"),
    caption = paste0(source_note,
                     "\n* Partial years: 2018 from MLAS launch (10 April); 2026 to ", as_of,
                     ". Claims converted into MLAS on 10 April 2018 are excluded.")
  ) +
  theme_claims() +
  theme(panel.grid.major.x = element_blank())

ggsave(here("outputs", "figures", "fig2_staking_by_year.png"), fig2,
       width = 8, height = 5.5, dpi = 300, bg = "white")
