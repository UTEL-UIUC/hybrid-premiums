# Quarterly U.S. HEV share of light-duty sales, with the nameplate-mean
# premium on a second axis. Writes output/hev_quarterly_sales.pdf.
# 2026 Q3 is July--August only and is omitted.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))

share_top <- 0.20
premium_top <- 8000

quarterly <- read.csv(
    file.path(project_root, "data", "anl-ldv-monthly-sales.csv"),
    stringsAsFactors = FALSE
) %>%
    filter(year >= 2012) %>%
    mutate(quarter = ((month - 1) %/% 3) + 1L) %>%
    group_by(year, quarter) %>%
    summarise(
        hev_sold = sum(hev),
        ldv_sold = sum(ldv),
        months = n(),
        .groups = "drop"
    ) %>%
    filter(months == 3) %>%
    mutate(
        share = hev_sold / ldv_sold,
        date = as.Date(sprintf("%d-%02d-01", year, (quarter - 1) * 3 + 2))
    )

premium <- load_analysis_sample(project_root) %>%
    collapse_nameplate_year() %>%
    group_by(year) %>%
    summarise(premium = mean(premium), .groups = "drop") %>%
    mutate(
        date = as.Date(sprintf("%d-07-01", year)),
        y = premium / premium_top * share_top
    )

ggplot() +
    geom_line(
        data = quarterly,
        aes(date, share),
        color = "#009E73",
        linewidth = 0.5
    ) +
    geom_point(
        data = quarterly,
        aes(date, share),
        color = "#009E73",
        size = 0.6
    ) +
    geom_line(
        data = premium,
        aes(date, y),
        color = "#E69F00",
        linewidth = 0.55
    ) +
    geom_point(
        data = premium,
        aes(date, y),
        color = "#E69F00",
        size = 0.9
    ) +
    scale_x_date(
        breaks = as.Date(paste0(seq(2012, 2026, by = 2), "-01-01")),
        date_labels = "%Y",
        limits = as.Date(c("2011-11-01", "2026-09-01")),
        expand = c(0, 0)
    ) +
    scale_y_continuous(
        labels = label_percent(accuracy = 1),
        expand = c(0, 0),
        limits = c(0, share_top),
        sec.axis = sec_axis(
            ~ . / share_top * premium_top,
            labels = label_dollar(scale = 1e-3, suffix = "k", accuracy = 1),
            name = "HEV price premium"
        )
    ) +
    labs(x = NULL, y = "HEV share") +
    theme_minimal(base_size = 8) +
    theme(
        panel.grid.minor = element_blank(),
        axis.title.y.left = element_text(color = "#009E73"),
        axis.title.y.right = element_text(color = "#E69F00")
    )

ggsave(
    file.path(project_root, "output", "hev_quarterly_sales.pdf"),
    width = 4.6,
    height = 1.55
)
