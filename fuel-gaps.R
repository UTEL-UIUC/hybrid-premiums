# HEV minus ICEV fuel gaps: raw nameplate--year means and the within-trim
# path (trim fixed effects, matches weighted 1/m). Writes output/fuel_gaps_trim.pdf.
# Left panel is combined MPG; right panel is gallons per 1,000 miles.

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
        !is.na(mpg_combined_hyb), !is.na(mpg_combined_ice),
        mpg_combined_hyb > 0, mpg_combined_ice > 0
    ) %>%
    mutate(
        g1000_gap = 1000 / mpg_combined_hyb - 1000 / mpg_combined_ice,
        mpg_gap = mpg_combined_hyb - mpg_combined_ice
    ) %>%
    add_trim_weights()

path <- bind_rows(
    build_trim_path(df, "mpg_gap") %>% mutate(metric = "Combined MPG"),
    build_trim_path(df, "g1000_gap") %>% mutate(metric = "Gallons per 1,000 miles")
) %>%
    mutate(metric = factor(metric, levels = c("Combined MPG", "Gallons per 1,000 miles")))

path %>%
    filter(year %in% c(2012, 2016, 2019, 2020, 2023, 2026)) %>%
    select(metric, series, year, estimate) %>%
    tidyr::pivot_wider(names_from = year, values_from = estimate) %>%
    mutate(across(where(is.numeric), ~ round(.x, 1))) %>%
    as.data.frame()

path_cols <- c(
    "Raw average" = "#E69F00",
    "Within trim" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "fuel_gaps_trim.pdf"),
    ggplot(path, aes(year, estimate, color = series)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.4) +
        geom_ribbon(
            data = path %>% filter(series == "Within trim"),
            aes(ymin = conf.low, ymax = conf.high, fill = series),
            alpha = 0.20,
            color = NA,
            show.legend = FALSE
        ) +
        geom_line(linewidth = 0.7) +
        facet_wrap(vars(metric), ncol = 2, scales = "free_y") +
        scale_color_manual(values = path_cols) +
        scale_fill_manual(values = path_cols) +
        scale_x_continuous(breaks = seq(2012, 2026, by = 2)) +
        scale_y_continuous(breaks = breaks_width(2)) +
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
