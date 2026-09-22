# Nameplate presence timeline for the HEV analysis sample.
# Writes output/nameplate_timeline.pdf

suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(tibble)
    library(ggplot2)
    library(scales)
})

project_root <- getwd()
source(file.path(project_root, "R", "build_analysis_sample.R"))
df <- load_analysis_sample(project_root)

# Contiguous year spells per nameplate.
spells_from_years <- function(years) {
    years <- sort(unique(years))
    if (!length(years)) {
        return(tibble(yr_start = integer(), yr_end = integer()))
    }
    brk <- c(TRUE, diff(years) != 1L)
    gid <- cumsum(brk)
    tibble(year = years, gid = gid) %>%
        group_by(gid) %>%
        summarise(
            yr_start = min(year),
            yr_end = max(year),
            .groups = "drop"
        ) %>%
        select(yr_start, yr_end)
}

np_meta <- df %>%
    mutate(
        make = as.character(make),
        nameplate = as.character(nameplate)
    ) %>%
    group_by(make, model, nameplate) %>%
    summarise(
        yr_first = min(year),
        years = list(sort(unique(year))),
        .groups = "drop"
    ) %>%
    arrange(yr_first, make, model) %>%
    mutate(
        y = row_number(),
        lab = dplyr::if_else(
            make == "Volkswagen",
            paste("VW", model),
            nameplate
        )
    )

spells <- np_meta %>%
    mutate(spell = lapply(years, spells_from_years)) %>%
    select(make, nameplate, y, lab, spell) %>%
    unnest(spell)

makes <- sort(unique(np_meta$make))
# Darker versions of the paper table row colors so adjacent makes
# (Honda / Hyundai / Kia / Lexus) stay distinct on thin bars.
make_cols <- c(
    Acura = "#1E88E5",
    Audi = "#6D4C41",
    BMW = "#00695C",
    Cadillac = "#1B5E20",
    Chevrolet = "#5C6BC0",
    Ford = "#FB8C00",
    GMC = "#B71C1C",
    Honda = "#D81B60",
    Hyundai = "#5E35B1",
    INFINITI = "#00BCD4",
    Kia = "#A15C38",
    Lexus = "#7CB342",
    Lincoln = "#311B92",
    Mazda = "#E6A817",
    `Mercedes-Benz` = "#1A237E",
    Nissan = "#F48FB1",
    Porsche = "#37474F",
    Subaru = "#90A4AE",
    Toyota = "#E64A19",
    Volkswagen = "#0D47A1"
)
missing <- setdiff(makes, names(make_cols))
if (length(missing)) {
    extra <- hue_pal(h = c(0, 360) + 15, c = 80, l = 45)(length(missing))
    names(extra) <- missing
    make_cols <- c(make_cols, extra)
}
make_cols <- make_cols[makes]

yr_min <- 2012L
# Model year t occupies [t, t+1), so the 2026 sample runs through 2027.
yr_max <- 2027L

# Label just to the left of each nameplate's first spell.
labels <- np_meta %>%
    left_join(
        spells %>%
            group_by(nameplate) %>%
            summarise(x = min(yr_start) - 0.2, .groups = "drop"),
        by = "nameplate"
    )

p <- ggplot() +
    geom_segment(
        data = spells,
        aes(
            x = yr_start,
            xend = yr_end + 1L,
            y = y,
            yend = y,
            color = make
        ),
        linewidth = 1.15,
        lineend = "butt"
    ) +
    geom_label(
        data = labels,
        aes(x = x, y = y, label = lab),
        inherit.aes = FALSE,
        fill = "white",
        text.colour = "black",
        border.colour = "white",
        linewidth = 1.0,
        label.padding = unit(0.2, "lines"),
        label.r = unit(0.08, "lines"),
        hjust = 1,
        size = 2.3,
        family = "Times",
        position = "identity"
    ) +
    scale_color_manual(values = make_cols, guide = "none") +
    scale_x_continuous(
        breaks = c(seq(2012L, 2026L, by = 2L), 2027L),
        minor_breaks = yr_min:yr_max,
        expand = expansion(mult = 0)
    ) +
    scale_y_reverse(
        breaks = NULL,
        expand = expansion(add = 0.6)
    ) +
    # Keep the panel on the data years; early labels hang into the left margin.
    coord_cartesian(xlim = c(yr_min, yr_max), clip = "off") +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 10, base_family = "Times") +
    theme(
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3),
        panel.grid.minor.x = element_line(color = "grey92", linewidth = 0.2),
        axis.text.y = element_blank(),
        plot.margin = margin(4, 18, 4, 62)
    )

ggsave(
    file.path(project_root, "output", "nameplate_timeline.pdf"),
    p,
    width = 5.5,
    height = 7
)

nrow(np_meta)
