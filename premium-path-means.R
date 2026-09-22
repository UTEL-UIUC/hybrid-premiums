# Yearly mean premiums behind the premium-path figures: matched pairs and
# nameplate--year cells.
# Writes output/tables/tab-premium-path-means.tex

suppressPackageStartupMessages({
    library(dplyr)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "analysis_window.R"))
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

year_stats <- function(d) {
    d %>%
        group_by(year) %>%
        summarise(
            mean = mean(premium),
            sd = sd(premium),
            n = n(),
            .groups = "drop"
        ) %>%
        arrange(year)
}

pairs <- year_stats(df)
cells <- year_stats(collapse_nameplate_year(df))

fmt_dollar <- function(x) formatC(round(x), format = "d", big.mark = ",")
row <- function(label, values) {
    paste0("        ", label, " & ", paste(values, collapse = " & "), " \\\\")
}
panel <- function(title, s) {
    c(
        sprintf("        \\multicolumn{%d}{l}{%s} \\\\", nrow(s) + 1L, title),
        row("Mean", fmt_dollar(s$mean)),
        row("SD", fmt_dollar(s$sd)),
        row("SD/mean", sprintf("%.2f", s$sd / s$mean)),
        row("$n$", s$n)
    )
}

years <- pairs$year
tab <- c(
    "\\begin{table}[ht]",
    "    \\caption{Yearly mean premiums from Figure~\\ref{fig:premium-path} (2026 dollars)}",
    "    \\label{tab:premium-path-means}",
    "    \\centering",
    "    \\scriptsize",
    "    \\resizebox{\\textwidth}{!}{%",
    sprintf("    \\begin{tabular}{l*{%d}{r}}", length(years)),
    "        \\toprule",
    row("", years),
    "        \\midrule",
    panel("Matched pairs", pairs),
    "        \\midrule",
    panel("Nameplate--year means", cells),
    "        \\bottomrule",
    "    \\end{tabular}%",
    "    }",
    "\\end{table}"
)
writeLines(tab, file.path(project_root, "output", "tables", "tab-premium-path-means.tex"))
