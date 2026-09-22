# HEV minus ICEV fuel gaps: raw nameplate-year means and the
# within-nameplate path. Writes output/fuel_gaps.pdf.
# Left panel is combined MPG; right panel is gallons per 1,000 miles.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))

df <- load_analysis_sample(project_root) %>%
    filter(
        !is.na(mpg_combined_hyb), !is.na(mpg_combined_ice),
        mpg_combined_hyb > 0, mpg_combined_ice > 0
    ) %>%
    mutate(
        g1000_gap = 1000 / mpg_combined_hyb - 1000 / mpg_combined_ice,
        mpg_gap = mpg_combined_hyb - mpg_combined_ice
    )

cells <- df %>%
    group_by(nameplate, body_type, year_fe, year) %>%
    summarise(
        g1000_gap = mean(g1000_gap),
        mpg_gap = mean(mpg_gap),
        .groups = "drop"
    )

path <- bind_rows(
    build_fe_path(cells, "mpg_gap") %>% mutate(metric = "Combined MPG"),
    build_fe_path(cells, "g1000_gap") %>% mutate(metric = "Gallons per 1,000 miles")
) %>%
    filter(series %in% c("Raw average", "2026 fleet held fixed")) %>%
    mutate(
        series = recode(
            as.character(series),
            "2026 fleet held fixed" = "Within nameplate"
        ),
        series = factor(series, levels = c("Raw average", "Within nameplate")),
        metric = factor(metric, levels = c("Combined MPG", "Gallons per 1,000 miles"))
    )

path_cols <- c(
    "Raw average" = "#E69F00",
    "Within nameplate" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "fuel_gaps.pdf"),
    ggplot(path, aes(year, estimate, color = series)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.4) +
        geom_ribbon(
            data = path %>% filter(series == "Within nameplate"),
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
