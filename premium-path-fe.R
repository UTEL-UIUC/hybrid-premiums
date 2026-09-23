# HEV premium path with trim fixed effects: matched trims weighted 1/m so
# each nameplate--year counts once, model-year and trim-line fixed effects.
# Writes output/tables/tab-year-fe-trim.tex and output/premium_path_trim_fe.pdf.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "analysis_window.R"))
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
source(file.path(project_root, "R", "trim_helpers.R"))
df <- add_trim_weights(load_analysis_sample(project_root))

fit <- fit_trim_fe(df)
alphas <- year_effects(fit)
joint <- joint_year_test(fit, 2020:2025)
joint

years <- ANALYSIS_YEAR_MIN:ANALYSIS_YEAR_MAX
alpha_hat <- setNames(rep(0, length(years)), as.character(years))
alpha_se <- setNames(rep(NA_real_, length(years)), as.character(years))
alpha_hat[as.character(alphas$year)] <- alphas$alpha
alpha_se[as.character(alphas$year)] <- alphas$se

fmt_num <- function(x) {
    formatC(round(x), format = "d", big.mark = ",")
}
fmt_se <- function(x) {
    if (is.na(x)) {
        return("---")
    }
    sprintf("(%s)", fmt_num(x))
}

tab <- c(
    "\\begin{table}[ht]",
    "    \\caption{Year fixed effects from \\eqref{eq:path-trim} (2026 dollars, relative to 2026)}",
    "    \\label{tab:year-fe}",
    "    \\centering",
    "    \\scriptsize",
    "    \\resizebox{\\textwidth}{!}{%",
    sprintf("    \\begin{tabular}{l*{%d}{r}}", length(years)),
    "        \\toprule",
    sprintf("        & %s \\\\", paste(years, collapse = " & ")),
    "        \\midrule",
    sprintf("        $\\hat\\alpha_t$ & %s \\\\", paste(vapply(alpha_hat, fmt_num, ""), collapse = " & ")),
    sprintf("        SE & %s \\\\", paste(vapply(alpha_se, fmt_se, ""), collapse = " & ")),
    "        \\bottomrule",
    "    \\end{tabular}%",
    "    }",
    "    \\par\\medskip",
    "    \\begin{minipage}{\\textwidth}",
    sprintf(
        "        \\footnotesize \\emph{Notes:} Weighted least squares on the %d matched pairs, each weighted by one over the number of matches in its nameplate--year, with model-year and trim-line fixed effects. 2026 is omitted, so $\\alpha_{2026}=0$. Nameplate-clustered standard errors in parentheses. The 2020--2025 effects are jointly insignificant ($p=%.2f$).",
        nrow(df), joint[["p_F"]]
    ),
    "    \\end{minipage}",
    "\\end{table}"
)
writeLines(tab, file.path(project_root, "output", "tables", "tab-year-fe-trim.tex"))

path_series <- build_trim_path(df)
path_series %>%
    select(series, year, estimate) %>%
    tidyr::pivot_wider(names_from = series, values_from = estimate) %>%
    mutate(across(-year, round)) %>%
    as.data.frame()

# Nameplate fixed effects on nameplate--year cells, for the footnote.
build_fe_path(collapse_nameplate_year(df)) %>%
    filter(series == "2026 fleet held fixed", year %in% c(2012, 2016, 2019, 2020, 2023)) %>%
    transmute(year, nameplate_fe = round(estimate)) %>%
    as.data.frame()

# Robustness: trim lines keyed on the raw ICEV trim name, and on the HEV
# trim name with "Hybrid" stripped.
for (key in c("trim_id_ice", "trim_id_hyb")) {
    f <- fit_trim_fe(df, key = key)
    a <- year_effects(f)
    cat(
        key, ": lines =", nlevels(df[[key]]),
        " alpha_2012 =", round(a$alpha[a$year == 2012]),
        " alpha_2020 =", round(a$alpha[a$year == 2020]),
        " joint p =", round(joint_year_test(f, 2020:2025)[["p_F"]], 3), "\n"
    )
}

# Trim-line counts.
lines <- df %>% distinct(trim_id, year) %>% count(trim_id, name = "n_years")
c(
    trim_lines = nrow(lines),
    single_year = sum(lines$n_years == 1),
    lines_2026 = n_distinct(df$trim_id[df$year == 2026]),
    lines_2026_with_history = n_distinct(df$trim_id[
        df$year == 2026 & df$trim_id %in% df$trim_id[df$year < 2026]
    ])
)

path_cols <- c(
    "Raw average" = "#E69F00",
    "Within trim" = "#0072B2"
)

ggsave(
    file.path(project_root, "output", "premium_path_trim_fe.pdf"),
    ggplot(path_series, aes(year, estimate, color = series)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.6) +
        geom_ribbon(
            data = path_series %>% filter(series == "Within trim"),
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
