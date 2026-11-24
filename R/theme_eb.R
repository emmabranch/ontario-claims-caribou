# theme_eb.R
# Shared chart style for Emma Branch's portfolio sites (Flash sheet, portfolio edition).
# Master copy lives in _brand-kit/R/. Copy it into a project's R/ folder, never edit it there first.
#
# Needs: ggplot2, scales, ragg, systemfonts
# Use:
#   source(here::here("R", "theme_eb.R"))
#   eb_use("bc-wildfire-bigquery")          # fonts, text defaults, and the project accent
#   ggplot(df, aes(x, y)) + geom_col(fill = eb_accent()) + theme_eb()
#
# Save with ragg at 300 dpi so text stays sharp on Retina screens:
#   ggsave("fig.png", p, device = ragg::agg_png, dpi = 300, ...)
# In Quarto, add to the YAML:  knitr: { opts_chunk: { dev: "ragg_png", fig.retina: 3 } }
# so charts drawn in the page are sharp too. Don't use fig-dpi for this: it shrinks
# leaflet maps and plotly charts that have a set height.

# ---- Colours ---------------------------------------------------------------
eb_col <- list(
  ink = "#111111", paper = "#F3EEE3", white = "#FFFFFF", muted = "#5A544A",
  cobalt = "#2340FF", tomato = "#FF5A36", sunflower = "#FFD23F", kelp = "#00B386",
  hotpink = "#FF6FB0", lilac = "#B9A4FF",
  grid = "#DCD4C4",      # faint gridlines on paper
  context = "#C9C1B3"    # "everything else" when one series is highlighted
)

# Categorical FILLS (bars, areas, points): bright inks, always with an ink outline.
# Checked: distinct under deuteranomaly, protanomaly, and tritanomaly. Hot pink is sixth
# because it sits closest to kelp and tomato for colourblind readers; it is also the
# go-to highlight on top of a project accent (eb_col$hotpink).
eb_cat_fill <- c(eb_col$cobalt, eb_col$tomato, eb_col$sunflower, eb_col$kelp, eb_col$lilac, eb_col$hotpink)

# Categorical LINES: deeper inks that pass 3:1 against paper and white. Four at most;
# label lines directly where you can.
eb_cat_line <- c("#2340FF", "#E0431B", "#00664B", "#111111")

# Diverging (below / above a reference): brand-tinted red to blue, paper in the middle.
eb_div <- c("#A3241A", "#E08A6E", "#F3EEE3", "#8A9BEA", "#1F33B5")

# Project accents, from the kit README
eb_projects <- list(
  "redcap-starter-kit"         = c("#6b4c9a", "#a07cc5", "#c9b2ea"),
  "bc-housing-indicators"      = c("#3b3fc4", "#7b80f2", "#aab0ff"),
  "bc-fish-stock-status"       = c("#0f7f66", "#3fbf9a", "#7fe0c4"),
  "bc-lightstation-qc"         = c("#1f5f99", "#4aa3df", "#8ccaf2"),
  "bc-wildfire-bigquery"       = c("#b33a0e", "#f4a259", "#ffb347"),
  "vch-climate-equity-profile" = c("#3f7d2c", "#8cc152", "#b5e08a"),
  "ontario-claims-caribou"     = c("#94661a", "#d9a441", "#f0c674"),
  "bc-salmon-explorer"         = c("#c2415e", "#f08aa0", "#ffb0c0"),
  "salish-sea-whales"          = c("#8a4a72", "#cf86ae", "#f0bcd8"),
  "bike-recall-surveillance"   = c("#6b5f00", "#e3c600", "#ffe94d"),
  "gravel-geometry"            = c("#7a5c43", "#c19a6b", "#e2c9a6")
)

.eb <- new.env()
.eb$project <- NULL
.eb$sans <- "sans"; .eb$sans_heavy <- "sans"; .eb$mono <- "mono"

# accent(1) = main highlight, accent(2) = second tone, accent(3) = light tone
eb_accent <- function(n = 1, project = .eb$project) {
  if (is.null(project)) return(eb_col$cobalt)
  eb_projects[[project]][n]
}

# ---- Fonts -----------------------------------------------------------------
# Loads Bricolage Grotesque and Space Mono from the kit's fonts/ folder, so nothing
# needs installing. If that folder is missing, it uses installed copies, and if there
# are none, falls back to the default fonts with a message.
eb_font_dir <- "~/projects/_brand-kit/fonts"

eb_fonts <- function(font_dir = eb_font_dir) {
  have <- function(fam) fam %in% systemfonts::system_fonts()$family ||
    fam %in% systemfonts::registry_fonts()$family
  font_dir <- path.expand(font_dir)
  f <- function(x) file.path(font_dir, x)
  if (dir.exists(font_dir)) {
    if (!have("Bricolage Grotesque"))
      systemfonts::register_font("Bricolage Grotesque",
        plain = f("BricolageGrotesque-Regular.ttf"), bold = f("BricolageGrotesque-Bold.ttf"))
    if (!have("Bricolage Grotesque ExtraBold"))
      systemfonts::register_font("Bricolage Grotesque ExtraBold",
        plain = f("BricolageGrotesque-ExtraBold.ttf"))
    if (!have("Space Mono"))
      systemfonts::register_font("Space Mono",
        plain = f("SpaceMono-Regular.ttf"), bold = f("SpaceMono-Bold.ttf"))
  }
  .eb$sans <- if (have("Bricolage Grotesque")) "Bricolage Grotesque" else {
    message("theme_eb: Bricolage Grotesque not found, using the default sans font"); "sans" }
  .eb$sans_heavy <- if (have("Bricolage Grotesque ExtraBold")) "Bricolage Grotesque ExtraBold" else .eb$sans
  .eb$mono <- if (have("Space Mono")) "Space Mono" else {
    message("theme_eb: Space Mono not found, using the default mono font"); "mono" }
  invisible(c(sans = .eb$sans, heavy = .eb$sans_heavy, mono = .eb$mono))
}

# One call at the top of a script: fonts, project accent, and text defaults
eb_use <- function(project = NULL, font_dir = eb_font_dir) {
  if (!is.null(project) && !project %in% names(eb_projects))
    stop("theme_eb: unknown project '", project, "'")
  .eb$project <- project
  eb_fonts(font_dir)
  ggplot2::update_geom_defaults("text",  list(family = .eb$sans, colour = eb_col$ink))
  ggplot2::update_geom_defaults("label", list(family = .eb$sans, colour = eb_col$ink))
  invisible(project)
}

# ---- Theme -----------------------------------------------------------------
# bg:   "paper" for website pages, "white" for single-page reports and cards
# grid: which gridlines to keep ("y", "x", "xy", or "none")
theme_eb <- function(base_size = 12, bg = c("paper", "white"), grid = c("y", "x", "xy", "none")) {
  bg <- eb_col[[match.arg(bg)]]
  grid <- match.arg(grid)
  gl <- ggplot2::element_line(colour = eb_col$grid, linewidth = 0.35)
  no <- ggplot2::element_blank()
  ggplot2::theme_minimal(base_size = base_size, base_family = .eb$sans) +
    ggplot2::theme(
      text               = ggplot2::element_text(colour = eb_col$ink),
      plot.background    = ggplot2::element_rect(fill = bg, colour = NA),
      panel.background   = ggplot2::element_rect(fill = bg, colour = NA),
      plot.title         = ggplot2::element_text(family = .eb$sans_heavy, face = "plain",
                             size = base_size * 1.45, lineheight = 1.1, margin = ggplot2::margin(b = 4)),
      plot.subtitle      = ggplot2::element_text(size = base_size * 0.95, lineheight = 1.25,
                             margin = ggplot2::margin(b = 10)),
      plot.caption       = ggplot2::element_text(family = .eb$mono, colour = eb_col$muted,
                             size = base_size * 0.62, hjust = 0, lineheight = 1.3,
                             margin = ggplot2::margin(t = 10)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      axis.text          = ggplot2::element_text(family = .eb$mono, colour = eb_col$ink, size = base_size * 0.7),
      axis.title         = ggplot2::element_text(family = .eb$mono, colour = eb_col$muted, size = base_size * 0.7),
      axis.line.x        = ggplot2::element_line(colour = eb_col$ink, linewidth = 0.6),
      axis.ticks.x       = ggplot2::element_line(colour = eb_col$ink, linewidth = 0.6),
      axis.ticks.length.x = grid::unit(3, "pt"),
      panel.grid.minor   = no,
      panel.grid.major.x = if (grid %in% c("x", "xy")) gl else no,
      panel.grid.major.y = if (grid %in% c("y", "xy")) gl else no,
      strip.text         = ggplot2::element_text(family = .eb$sans, face = "bold",
                             size = base_size * 0.95, hjust = 0, colour = eb_col$ink),
      legend.position    = "top",
      legend.justification = "left",
      legend.title       = ggplot2::element_text(family = .eb$mono, size = base_size * 0.7, colour = eb_col$muted),
      legend.text        = ggplot2::element_text(size = base_size * 0.85),
      legend.key         = ggplot2::element_rect(fill = NA, colour = NA),
      plot.margin        = ggplot2::margin(14, 16, 10, 12)
    )
}

# ---- Scales ---
# Category colours, in order. Use the fills for bars, areas, and points (with an ink
# outline: colour = eb_col$ink), and the line colours for lines.-------------------------------------------------------------
scale_fill_eb_cat   <- function(...) ggplot2::scale_fill_manual(values = eb_cat_fill, ...)
scale_colour_eb_cat <- function(...) ggplot2::scale_colour_manual(values = eb_cat_line, ...)

# Diverging around a midpoint (for example log2 ratio to a limit, midpoint 0)
scale_fill_eb_div <- function(..., midpoint = 0) {
  ggplot2::scale_fill_gradientn(colours = eb_div, values = NULL, ...,
    rescaler = function(x, to = c(0, 1), from = range(x, na.rm = TRUE))
      scales::rescale_mid(x, to, from, midpoint))
}
scale_colour_eb_div <- function(..., midpoint = 0) {
  ggplot2::scale_colour_gradientn(colours = eb_div, ...,
    rescaler = function(x, to = c(0, 1), from = range(x, na.rm = TRUE))
      scales::rescale_mid(x, to, from, midpoint))
}

# Sequential: paper to the project accent to ink (single hue, reads in greyscale)
eb_seq <- function(n = 7, project = .eb$project) {
  grDevices::colorRampPalette(c("#F3EEE3", eb_accent(3, project), eb_accent(1, project), "#111111"))(n)
}
scale_fill_eb_seq   <- function(...) ggplot2::scale_fill_gradientn(colours = eb_seq(), ...)
scale_colour_eb_seq <- function(...) ggplot2::scale_colour_gradientn(colours = eb_seq(), ...)

# ---- plotly ----------------------------------------------------------------
# Gives a plotly chart (plot_ly or ggplotly) the shared look. Use as the last step:
#   plot_ly(...) |> layout(...) |> eb_plotly()
# bg: "paper" for website pages, "white" for reports. grid: which gridlines to keep, as in theme_eb(). Leaves the data, titles, and hover
# text alone (axis titles keep their words and use the main font).
eb_plotly <- function(p, bg = c("paper", "white"), grid = c("y", "x", "xy", "none")) {
  bg <- eb_col[[match.arg(bg)]]
  grid <- match.arg(grid)
  sans <- "Bricolage Grotesque, system-ui, sans-serif"
  mono <- "Space Mono, ui-monospace, monospace"
  ax <- list(
    tickfont = list(family = mono, size = 11, color = eb_col$ink),
    gridcolor = eb_col$grid, zerolinecolor = eb_col$ink, linecolor = eb_col$ink
  )
  # Style every axis, including the extra ones subplot() makes (xaxis2, yaxis2, ...)
  axes <- grep("^[xy]axis[0-9]*$", names(plotly::plotly_build(p)$x$layout), value = TRUE)
  axes <- union(c("xaxis", "yaxis"), axes)
  axis_args <- lapply(axes, function(a) {
    show <- if (startsWith(a, "x")) grid %in% c("x", "xy") else grid %in% c("y", "xy")
    c(ax, showgrid = show)
  })
  names(axis_args) <- axes
  do.call(plotly::layout, c(list(p,
    font = list(family = sans, size = 13, color = eb_col$ink),
    paper_bgcolor = bg, plot_bgcolor = bg,
    colorway = eb_cat_line,
    legend = list(font = list(family = sans, size = 12, color = eb_col$ink), bgcolor = "rgba(0,0,0,0)"),
    hoverlabel = list(bgcolor = eb_col$white, bordercolor = eb_col$ink,
                      font = list(family = sans, size = 12, color = eb_col$ink))),
    axis_args))
}
