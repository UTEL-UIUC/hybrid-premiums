# HEV models in the trim catalog by model year and body type.
# Reads data/hev-models-by-body.csv (counts of distinct HEV make--model
# nameplates per year and body type, aggregated from the licensed catalog).
# Writes output/hev_models_by_body.pdf

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
})

project_root <- getwd()
dir.create(file.path(project_root, "output"), showWarnings = FALSE)

body_levels <- c(
    "SUV", "Sedan", "Truck", "Minivan", "Hatchback",
    "Coupe", "Wagon", "Convertible"
)
pal <- c(
    "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00",
    "#A65628", "#F781BF", "#999999"
)

counts <- read.csv(
    file.path(project_root, "data", "hev-models-by-body.csv"),
    stringsAsFactors = FALSE
) %>%
    mutate(body = factor(.data$body, levels = body_levels))
totals <- counts %>%
    group_by(.data$year) %>%
    summarise(n = sum(.data$n_models), .groups = "drop")

ggplot(counts, aes(.data$year, .data$n_models, fill = .data$body)) +
    geom_col(width = 0.7, color = "white", linewidth = 0.3) +
    geom_text(
        aes(label = ifelse(.data$body %in% c("SUV", "Sedan"), .data$n_models, "")),
        position = position_stack(vjust = 0.5),
        color = "white",
        size = 2.2
    ) +
    geom_text(
        data = totals,
        aes(.data$year, .data$n, label = .data$n),
        inherit.aes = FALSE,
        vjust = -0.35,
        size = 2.4
    ) +
    scale_fill_manual(values = pal, name = NULL, drop = FALSE) +
    scale_x_continuous(breaks = totals$year) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
    labs(x = NULL, y = NULL) +
    guides(fill = guide_legend(nrow = 1)) +
    theme_minimal(base_size = 9) +
    theme(
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        legend.position = "bottom",
        legend.key.size = unit(0.28, "cm"),
        legend.key.height = unit(0.22, "cm"),
        legend.spacing.x = unit(0.12, "cm"),
        legend.text = element_text(size = 7),
        legend.margin = margin(0, 0, 0, 0),
        legend.box.margin = margin(-6, 0, 0, 0),
        axis.text.x = element_text(size = 7),
        plot.margin = margin(2, 4, 0, 2)
    )

ggsave(
    file.path(project_root, "output", "hev_models_by_body.pdf"),
    width = 6.5,
    height = 2.15
)
