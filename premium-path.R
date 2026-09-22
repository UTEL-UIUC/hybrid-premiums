# HEV premium paths: nameplate--year means, observation-level raw year
# means, plus within nameplate-year observation dispersion.

suppressPackageStartupMessages({
    library(dplyr)
    library(tibble)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "analysis_window.R"))
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

cells <- collapse_nameplate_year(df)
path_series <- build_fe_path(cells)
raw <- path_series %>% filter(series == "Raw average")

p_raw <- ggplot() +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.6) +
    geom_point(
        data = cells,
        aes(x = year, y = premium, color = nameplate),
        size = 1.15,
        alpha = 0.38,
        stroke = 0,
        position = position_jitter(width = 0.28, height = 0, seed = 1)
    ) +
    geom_line(
        data = raw,
        aes(x = year, y = estimate),
        color = PATH_SERIES_COLS[["Raw average"]],
        linewidth = 0.85
    ) +
    scale_color_discrete(guide = "none") +
    scale_x_continuous(
        breaks = seq(ANALYSIS_YEAR_MIN, ANALYSIS_YEAR_MAX, by = 2)
    ) +
    scale_y_continuous(
        breaks = seq(-4000, 14000, by = 2000),
        labels = label_dollar(scale = 1e-3, suffix = "k")
    ) +
    labs(x = NULL, y = NULL) +
    path_plot_theme() +
    theme(
        legend.position = "none",
        plot.margin = margin(2, 4, 2, 2)
    )

ggsave(
    file.path(project_root, "output", "premium_path_nameplates.pdf"),
    p_raw,
    width = 3.2,
    height = 2.55
)

# Same path without collapsing to nameplate--year cells: each match is a
# point, and the line is the unweighted mean of observations.
path_obs <- build_fe_path(df)
raw_obs <- path_obs %>% filter(series == "Raw average")

p_obs <- ggplot() +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.6) +
    geom_point(
        data = df,
        aes(x = year, y = premium, color = nameplate),
        size = 1.0,
        alpha = 0.30,
        stroke = 0,
        position = position_jitter(width = 0.28, height = 0, seed = 1)
    ) +
    geom_line(
        data = raw_obs,
        aes(x = year, y = estimate),
        color = PATH_SERIES_COLS[["Raw average"]],
        linewidth = 0.85
    ) +
    scale_color_discrete(guide = "none") +
    scale_x_continuous(
        breaks = seq(ANALYSIS_YEAR_MIN, ANALYSIS_YEAR_MAX, by = 2)
    ) +
    scale_y_continuous(
        breaks = seq(-4000, 14000, by = 2000),
        labels = label_dollar(scale = 1e-3, suffix = "k")
    ) +
    labs(x = NULL, y = NULL) +
    path_plot_theme() +
    theme(
        legend.position = "none",
        plot.margin = margin(2, 2, 2, 4)
    )

ggsave(
    file.path(project_root, "output", "premium_path_observations.pdf"),
    p_obs,
    width = 3.2,
    height = 2.55
)

# Within nameplate-year observation dispersion (multi-observation cells only).
dev_within <- df %>%
    group_by(nameplate, year) %>%
    filter(n() > 1) %>%
    mutate(dev = premium - mean(premium)) %>%
    ungroup()

dev_within %>%
    summarise(
        n = n(),
        med_abs = median(abs(dev)),
        within_500 = mean(abs(dev) <= 500)
    )

df %>%
    group_by(nameplate, year) %>%
    mutate(m = mean(premium)) %>%
    ungroup() %>%
    summarise(
        within_share = mean((premium - m)^2) / mean((premium - mean(premium))^2)
    )

ggplot(dev_within, aes(dev)) +
    geom_histogram(
        binwidth = 250,
        center = 0,
        fill = "#E69F00",
        color = "white",
        linewidth = 0.2
    ) +
    geom_vline(xintercept = 0, color = "grey50", linewidth = 0.4) +
    scale_x_continuous(
        labels = label_dollar(scale = 1e-3, suffix = "k"),
        limits = c(-4000, 4000),
        oob = scales::squish
    ) +
    labs(
        x = "Observation premium minus nameplate-year mean (2026 $)",
        y = NULL
    ) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank())

ggsave(
    file.path(project_root, "output", "premium_within_year_hist.pdf"),
    width = 4.5,
    height = 2.0
)
