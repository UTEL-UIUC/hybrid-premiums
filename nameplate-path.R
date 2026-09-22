# Selected long-lived nameplate premium paths (mean of observations each year).

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
df <- load_analysis_sample(project_root)

# Long-span nameplates with a clear long-run decline; one color per series.
np_paths <- c(
    "Toyota Camry",
    "Toyota Highlander",
    "Toyota Avalon",
    "Toyota RAV4",
    "Toyota Corolla",
    "Ford Fusion",
    "Lexus ES",
    "Lexus NX",
    "Honda Accord"
)

np_colors <- c(
    "Toyota Camry" = "#E69F00",
    "Toyota Highlander" = "#D55E00",
    "Toyota Avalon" = "#0072B2",
    "Toyota RAV4" = "#009E73",
    "Toyota Corolla" = "#CC79A7",
    "Ford Fusion" = "#56B4E9",
    "Lexus ES" = "#882255",
    "Lexus NX" = "#44AA99",
    "Honda Accord" = "#332288"
)

series <- df %>%
    mutate(nameplate = as.character(nameplate)) %>%
    filter(nameplate %in% np_paths) %>%
    group_by(nameplate, year) %>%
    summarise(premium = mean(premium), .groups = "drop") %>%
    mutate(nameplate = factor(nameplate, levels = np_paths))

stopifnot(n_distinct(series$nameplate) == length(np_paths))

# Highlander nameplate means around the 2017 cut (for caption check).
series %>%
    filter(nameplate == "Toyota Highlander", year %in% 2016:2018) %>%
    as.data.frame()

series %>%
    ggplot(aes(year, premium, color = nameplate, group = nameplate)) +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
    geom_line(linewidth = 0.55, alpha = 0.95) +
    scale_color_manual(values = np_colors) +
    scale_x_continuous(breaks = pretty_breaks(n = 8)) +
    scale_y_continuous(labels = label_dollar(scale = 1e-3, suffix = "k")) +
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
    file.path(project_root, "output", "premium_nameplate_paths.pdf"),
    width = 4.5,
    height = 2.1
)
