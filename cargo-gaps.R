# HEV minus ICEV cargo volume with all seats in place: raw nameplate--year
# means and the within-trim path (trim fixed effects, matches weighted 1/m).
# Writes output/cargo_gaps_trim.pdf. Pickups have no cargo volume and drop out.
# Left panel is cubic feet; right panel is percent (100 x log ratio).

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
dir.create(file.path(project_root, "output"), showWarnings = FALSE)
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
source(file.path(project_root, "R", "trim_helpers.R"))

df <- load_analysis_sample(project_root) %>%
    filter(
        !is.na(cargo_seats_up_hyb), !is.na(cargo_seats_up_ice),
        cargo_seats_up_hyb > 0, cargo_seats_up_ice > 0
    ) %>%
    mutate(
        cargo_gap = cargo_seats_up_hyb - cargo_seats_up_ice,
        cargo_pct = 100 * log(cargo_seats_up_hyb / cargo_seats_up_ice)
    ) %>%
    add_trim_weights()

df %>% summarise(pairs = n(), nameplates = n_distinct(nameplate))

path <- bind_rows(
    build_trim_path(df, "cargo_gap") %>% mutate(metric = "Cubic feet"),
    build_trim_path(df, "cargo_pct") %>% mutate(metric = "Percent")
) %>%
    mutate(metric = factor(metric, levels = c("Cubic feet", "Percent")))

path %>%
    filter(year %in% c(2012, 2016, 2019, 2020, 2023, 2026)) %>%
    select(metric, series, year, estimate) %>%
    tidyr::pivot_wider(names_from = year, values_from = estimate) %>%
    mutate(across(where(is.numeric), ~ round(.x, 1))) %>%
    as.data.frame()

path <- path %>%
    mutate(series = forcats::fct_recode(series, "Unadjusted" = "Raw average", "Adjusted" = "Within trim"))

path_cols <- c(
    "Unadjusted" = "#E69F00",
    "Adjusted" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "cargo_gaps_trim.pdf"),
    ggplot(path, aes(year, estimate, color = series)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.4) +
        geom_line(linewidth = 0.7) +
        facet_wrap(vars(metric), ncol = 2, scales = "free_y") +
        scale_color_manual(values = path_cols) +
        scale_x_continuous(breaks = seq(2012, 2026, by = 2)) +
        labs(x = NULL, y = "HEV minus ICEV", color = NULL) +
        theme_minimal(base_size = 8) +
        theme(
            panel.grid.minor = element_blank(),
            strip.text = element_text(size = 8),
            axis.title.y = element_text(size = 7),
            legend.position = "top",
            legend.key.size = unit(0.3, "cm"),
            legend.spacing.x = unit(0.15, "cm"),
            legend.box.spacing = unit(0, "pt"),
            legend.margin = margin(0, 0, 0, 0)
        ),
    width = 6.35,
    height = 1.7
)
