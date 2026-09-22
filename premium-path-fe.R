# HEV premium path: raw year means and the 2026 fleet held fixed using
# model-year and nameplate fixed effects.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "analysis_window.R"))
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

cells <- collapse_nameplate_year(df)
path_series <- build_fe_path(cells)

cells_fe <- cells %>%
    mutate(
        year_fe = relevel(factor(.data$year), ref = "2026"),
        nameplate = droplevels(.data$nameplate)
    )
m_fe <- lm(premium ~ year_fe + nameplate, data = cells_fe)
V_fe <- sandwich::vcovCL(m_fe, cluster = cells_fe$nameplate)

years <- ANALYSIS_YEAR_MIN:ANALYSIS_YEAR_MAX
cf <- coef(m_fe)
se <- sqrt(diag(V_fe))
alpha_hat <- setNames(rep(0, length(years)), as.character(years))
alpha_se <- setNames(rep(NA_real_, length(years)), as.character(years))
keep <- grepl("^year_fe", names(cf))
yr_names <- sub("^year_fe", "", names(cf)[keep])
alpha_hat[yr_names] <- unname(cf[keep])
alpha_se[yr_names] <- unname(se[keep])

fmt_num <- function(x) {
    formatC(round(x), format = "d", big.mark = ",")
}
fmt_se <- function(x) {
    if (is.na(x)) {
        return("---")
    }
    sprintf("(%s)", fmt_num(x))
}

year_headers <- paste(years, collapse = " & ")
coef_cells <- vapply(as.character(years), function(y) {
    fmt_num(alpha_hat[[y]])
}, character(1))
se_cells <- vapply(as.character(years), function(y) {
    fmt_se(alpha_se[[y]])
}, character(1))

tab <- c(
    "\\begin{table}[ht]",
    "    \\caption{Year fixed effects from \\eqref{eq:path-nameplate} (2026 dollars, relative to 2026)}",
    "    \\label{tab:year-fe}",
    "    \\centering",
    "    \\scriptsize",
    "    \\resizebox{\\textwidth}{!}{%",
    sprintf("    \\begin{tabular}{l*{%d}{r}}", length(years)),
    "        \\toprule",
    sprintf("        & %s \\\\", year_headers),
    "        \\midrule",
    sprintf("        $\\hat\\alpha_t$ & %s \\\\", paste(coef_cells, collapse = " & ")),
    sprintf("        SE & %s \\\\", paste(se_cells, collapse = " & ")),
    "        \\bottomrule",
    "    \\end{tabular}%",
    "    }",
    "    \\par\\medskip",
    "    \\begin{minipage}{\\textwidth}",
    "        \\footnotesize \\emph{Notes:} Estimated on nameplate--year cells. 2026 is omitted, so $\\alpha_{2026}=0$. Nameplate-clustered standard errors in parentheses.",
    "    \\end{minipage}",
    "\\end{table}"
)
writeLines(tab, file.path(project_root, "output", "tables", "tab-year-fe.tex"))

shown <- path_series %>%
    filter(series %in% c("Raw average", "2026 fleet held fixed")) %>%
    mutate(
        series = recode(
            as.character(series),
            "2026 fleet held fixed" = "Adjusted premium"
        ),
        series = factor(series, levels = c("Raw average", "Adjusted premium"))
    )

path_cols <- c(
    "Raw average" = "#E69F00",
    "Adjusted premium" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "premium_path_nameplates_fe.pdf"),
    ggplot(shown, aes(year, estimate, color = series)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.6) +
        geom_ribbon(
            data = shown %>% filter(series == "Adjusted premium"),
            aes(ymin = conf.low, ymax = conf.high, fill = series),
            alpha = 0.20,
            color = NA,
            show.legend = FALSE
        ) +
        geom_line(linewidth = 0.85) +
        scale_color_manual(values = path_cols) +
        scale_fill_manual(values = path_cols) +
        scale_x_continuous(breaks = seq(ANALYSIS_YEAR_MIN, ANALYSIS_YEAR_MAX, by = 2)) +
        scale_y_continuous(labels = scales::label_dollar(scale = 1e-3, suffix = "k")) +
        labs(x = NULL, y = NULL, color = NULL) +
        path_plot_theme() +
        theme(
            legend.position = "right",
            legend.key.size = unit(0.35, "cm"),
            legend.spacing.y = unit(0, "cm"),
            legend.box.spacing = unit(2, "pt"),
            legend.margin = margin(0, 0, 0, 0)
        ),
    width = 5.1,
    height = 2.05
)
