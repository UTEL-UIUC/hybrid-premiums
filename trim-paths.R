# Premium paths for selected long-lived trim lines (the same trim lines the
# trim fixed effects compare). Writes output/premium_trim_line_paths.pdf.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
dir.create(file.path(project_root, "output"), showWarnings = FALSE)
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "trim_helpers.R"))
df <- add_trim_weights(load_analysis_sample(project_root))

drive_abbr <- c(
    "front wheel drive" = "FWD",
    "all wheel drive" = "AWD",
    "rear wheel drive" = "RWD",
    "four wheel drive" = "4WD"
)

lines <- tibble::tribble(
    ~trim_id, ~label, ~color,
    "Toyota Highlander | SUV | limited | all wheel drive |  | ", "Toyota Highlander Limited AWD", "#D55E00",
    "Lexus NX | SUV | base | all wheel drive |  | ", "Lexus NX (base) AWD", "#009E73",
    "Honda Accord | Sedan | ex l | front wheel drive |  | ", "Honda Accord EX-L FWD", "#0072B2",
    "Toyota Camry | Sedan | xle | front wheel drive |  | ", "Toyota Camry XLE FWD", "#E69F00",
    "Ford Fusion | Sedan | se | front wheel drive |  | ", "Ford Fusion SE FWD", "#56B4E9",
    "Lexus ES | Sedan | base | front wheel drive |  | ", "Lexus ES (base) FWD", "#CC79A7"
)

series <- df %>%
    mutate(trim_id = as.character(trim_id)) %>%
    inner_join(lines, by = "trim_id") %>%
    group_by(label, trim_id, year) %>%
    summarise(premium = mean(premium), .groups = "drop") %>%
    mutate(label = factor(label, levels = lines$label))

stopifnot(n_distinct(series$trim_id) == nrow(lines))

series %>%
    filter(grepl("Highlander", label), year %in% 2016:2018) %>%
    as.data.frame()

series %>%
    ggplot(aes(year, premium, color = label, group = label)) +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
    geom_line(linewidth = 0.6, alpha = 0.95) +
    geom_point(size = 0.7) +
    scale_color_manual(values = setNames(lines$color, lines$label)) +
    scale_x_continuous(breaks = seq(2012, 2026, by = 2)) +
    scale_y_continuous(
        breaks = breaks_width(2500),
        labels = label_dollar(scale = 1e-3, suffix = "k", accuracy = 0.1)
    ) +
    labs(x = NULL, y = NULL, color = NULL) +
    theme_minimal(base_size = 9) +
    theme(
        panel.grid.minor = element_blank(),
        legend.position = "right",
        legend.key.height = grid::unit(0.62, "lines"),
        legend.key.spacing.y = grid::unit(1, "pt"),
        legend.spacing.y = grid::unit(1, "pt"),
        legend.margin = margin(0, 0, 0, 0),
        legend.text = element_text(margin = margin(0, 0, 0, 0))
    )

ggsave(
    file.path(project_root, "output", "premium_trim_line_paths.pdf"),
    width = 5.2,
    height = 2.3
)
