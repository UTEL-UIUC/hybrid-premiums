# Premium versus HEV-minus-ICEV horsepower, with circle area = count
# of matched pairs at that exact (hpdiff, premium) point.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

plot_data <- df %>%
    count(.data$hpdiff, .data$premium) %>%
    mutate(
        sign = factor(
            case_when(
                .data$premium < 0 ~ "Negative",
                .data$premium == 0 ~ "Zero",
                TRUE ~ "Positive"
            ),
            levels = c("Positive", "Zero", "Negative")
        )
    ) %>%
    arrange(.data$sign)

p <- ggplot(
    plot_data,
    aes(.data$hpdiff, .data$premium, size = .data$n, color = .data$sign)
) +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
    geom_vline(xintercept = 0, color = "grey80", linewidth = 0.5) +
    geom_point(alpha = 0.45, stroke = 0.25) +
    scale_size_area(max_size = 5.5, guide = "none") +
    scale_color_manual(
        values = c(
            Positive = "grey55",
            Zero = "#0072B2",
            Negative = "#D55E00"
        )
    ) +
    scale_x_continuous(expand = expansion(mult = 0.07)) +
    scale_y_continuous(
        labels = label_dollar(scale = 1e-3, suffix = "k"),
        expand = expansion(mult = c(0.10, 0.06))
    ) +
    labs(
        x = "HEV minus ICEV horsepower",
        y = "Premium (2026 $)",
        color = NULL
    ) +
    path_plot_theme() +
    theme(
        legend.position = "right",
        legend.box = "vertical",
        legend.spacing.x = grid::unit(6, "pt"),
        legend.box.spacing = grid::unit(0, "pt"),
        legend.margin = margin(0, 0, 0, 0),
        text = element_text(size = 8),
        axis.text = element_text(size = 8),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 8, face = "plain"),
        axis.title = element_text(size = 7)
    )

ggsave(
    file.path(project_root, "output", "premium_hpdiff.pdf"),
    p,
    width = 6.0,
    height = 1.95
)
