# HEV minus ICEV performance gaps: raw nameplate-year means and the
# within-nameplate path. Writes output/perf_gaps.pdf.
# Left panel is horsepower; right panel is log horsepower per pound.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))

df <- load_analysis_sample(project_root)

hp <- df %>%
    filter(!is.na(hp_hyb), !is.na(hp_ice), hp_hyb > 0, hp_ice > 0) %>%
    mutate(hp_gap = hp_hyb - hp_ice)

logp <- df %>%
    filter(
        !is.na(hp_hyb), !is.na(hp_ice), hp_hyb > 0, hp_ice > 0,
        !is.na(curb_weight_hyb), !is.na(curb_weight_ice),
        curb_weight_hyb > 0, curb_weight_ice > 0
    ) %>%
    mutate(
        log_pwr_gap = log(hp_hyb / curb_weight_hyb) - log(hp_ice / curb_weight_ice)
    )

cells_hp <- hp %>%
    group_by(nameplate, body_type, year_fe, year) %>%
    summarise(hp_gap = mean(hp_gap), .groups = "drop")

cells_log <- logp %>%
    group_by(nameplate, body_type, year_fe, year) %>%
    summarise(log_pwr_gap = mean(log_pwr_gap), .groups = "drop")

path <- bind_rows(
    build_fe_path(cells_hp, "hp_gap") %>% mutate(metric = "Horsepower"),
    build_fe_path(cells_log, "log_pwr_gap") %>% mutate(metric = "Log hp per pound")
) %>%
    filter(series %in% c("Raw average", "2026 fleet held fixed")) %>%
    mutate(
        series = recode(
            as.character(series),
            "2026 fleet held fixed" = "Within nameplate"
        ),
        series = factor(series, levels = c("Raw average", "Within nameplate")),
        metric = factor(metric, levels = c("Horsepower", "Log hp per pound"))
    )

path_cols <- c(
    "Raw average" = "#E69F00",
    "Within nameplate" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "perf_gaps.pdf"),
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
        scale_y_continuous(breaks = breaks_pretty(n = 4)) +
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
