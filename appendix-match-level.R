# Match-level robustness: year effects and ICEV-price slopes on the 715
# matched pairs, beside the nameplate--year estimates.

suppressPackageStartupMessages({
    library(dplyr)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "analysis_window.R"))
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

stars <- function(p) {
    if (is.na(p)) {
        ""
    } else if (p < 0.01) {
        "$^{***}$"
    } else if (p < 0.05) {
        "$^{**}$"
    } else if (p < 0.10) {
        "$^{*}$"
    } else {
        ""
    }
}

fmt_coef <- function(b, se, p, digits = 3) {
    list(
        coef = paste0(formatC(b, format = "f", digits = digits), stars(p)),
        se = paste0("(", formatC(se, format = "f", digits = digits), ")")
    )
}

term_stats <- function(b, s, g) {
    t_stat <- b / s
    p <- 2 * pt(-abs(t_stat), df = max(g - 1, 1))
    c(b = unname(b), se = unname(s), p = p)
}

cluster_fit <- function(m, d) {
    V <- sandwich::vcovCL(m, cluster = d$nameplate)
    g <- nlevels(d$nameplate)
    se <- sqrt(diag(V))
    cf <- coef(m)
    y <- model.response(model.frame(m))
    sse <- sum(residuals(m)^2)
    sst <- sum((y - mean(y))^2)
    n <- nobs(m)
    p <- m$rank
    list(
        n = n,
        clusters = g,
        aic = AIC(m),
        adj_r2 = 1 - (sse / (n - p)) / (sst / (n - 1)),
        cf = cf,
        se = se
    )
}

era_dummies <- function(d) {
    d %>%
        mutate(
            nameplate = droplevels(.data$nameplate),
            year_fe = droplevels(.data$year_fe),
            pre = as.integer(.data$year < 2020),
            post = as.integer(.data$year >= 2020),
            p_ice_pre = .data$p_ice * .data$pre,
            p_ice_post = .data$p_ice * .data$post
        )
}

fmt_num <- function(x) {
    formatC(round(x), format = "d", big.mark = ",")
}

fmt_se <- function(x) {
    if (is.na(x)) {
        return("---")
    }
    sprintf("(%s)", fmt_num(x))
}

year_alphas <- function(d, years) {
    d <- d %>%
        mutate(
            year_fe = relevel(factor(.data$year), ref = "2026"),
            nameplate = droplevels(.data$nameplate)
        )
    m <- lm(premium ~ year_fe + nameplate, data = d)
    V <- sandwich::vcovCL(m, cluster = d$nameplate)
    cf <- coef(m)
    se <- sqrt(diag(V))
    alpha_hat <- setNames(rep(0, length(years)), as.character(years))
    alpha_se <- setNames(rep(NA_real_, length(years)), as.character(years))
    keep <- grepl("^year_fe", names(cf))
    yr_names <- sub("^year_fe", "", names(cf)[keep])
    alpha_hat[yr_names] <- unname(cf[keep])
    alpha_se[yr_names] <- unname(se[keep])
    list(alpha = alpha_hat, se = alpha_se, years = years)
}

cells <- collapse_nameplate_year(df)
years_all <- sort(unique(df$year))
alpha_cells <- year_alphas(cells, years_all)
alpha_matches <- year_alphas(df, years_all)

years <- alpha_cells$years
year_headers <- paste(years, collapse = " & ")
row_vals <- function(label, x, fmt) {
    cells_x <- vapply(as.character(years), function(y) fmt(x[[y]]), character(1))
    sprintf("        %s & %s \\\\", label, paste(cells_x, collapse = " & "))
}

tab_year <- c(
    "\\begin{table}[ht]",
    "    \\caption{Year fixed effects relative to 2026: nameplate--year cells and matched pairs (2026 dollars)}",
    "    \\label{tab:year-fe-matches}",
    "    \\centering",
    "    \\scriptsize",
    "    \\resizebox{\\textwidth}{!}{%",
    sprintf("    \\begin{tabular}{l*{%d}{r}}", length(years)),
    "        \\toprule",
    sprintf("        & %s \\\\", year_headers),
    "        \\midrule",
    row_vals("Nameplate--year", alpha_cells$alpha, fmt_num),
    row_vals("SE", alpha_cells$se, fmt_se),
    "        \\midrule",
    row_vals("Matches", alpha_matches$alpha, fmt_num),
    row_vals("SE", alpha_matches$se, fmt_se),
    "        \\bottomrule",
    "    \\end{tabular}%",
    "    }",
    "    \\par\\medskip",
    "    \\begin{minipage}{\\textwidth}",
    "        \\footnotesize \\emph{Notes:} Both rows omit 2026, so $\\alpha_{2026}=0$, and include nameplate fixed effects. The nameplate--year row is estimated on nameplate--year cells, as in Table~\\ref{tab:year-fe}. The matches row counts each matched pair once. Nameplate-clustered standard errors in parentheses.",
    "    \\end{minipage}",
    "\\end{table}"
)
writeLines(tab_year, file.path(project_root, "output", "tables", "tab-year-fe-matches.tex"))

gap <- unname(alpha_matches$alpha - alpha_cells$alpha)
gap_year <- years[which.max(abs(gap))]
cat(sprintf(
    "year-FE cor = %.3f; max |gap| = %s in %d; RMSE = %.0f\n",
    cor(alpha_cells$alpha, alpha_matches$alpha),
    fmt_num(max(abs(gap))),
    gap_year,
    sqrt(mean(gap^2))
))

matches <- era_dummies(df)
fit_pooled <- function(d) {
    m <- lm(premium ~ p_ice, data = d)
    out <- cluster_fit(m, d)
    out$slope <- term_stats(out$cf[["p_ice"]], out$se[["p_ice"]], out$clusters)
    out
}
fit_separate <- function(d) {
    m <- lm(premium ~ 0 + pre + post + p_ice_pre + p_ice_post, data = d)
    out <- cluster_fit(m, d)
    out$slope_pre <- term_stats(
        out$cf[["p_ice_pre"]], out$se[["p_ice_pre"]], out$clusters
    )
    out$slope_post <- term_stats(
        out$cf[["p_ice_post"]], out$se[["p_ice_post"]], out$clusters
    )
    out
}
fit_pooled_year_fe <- function(d) {
    m <- lm(premium ~ 0 + year_fe + p_ice, data = d)
    out <- cluster_fit(m, d)
    out$slope <- term_stats(out$cf[["p_ice"]], out$se[["p_ice"]], out$clusters)
    out
}
fit_separate_year_fe <- function(d) {
    m <- lm(premium ~ 0 + year_fe + p_ice_pre + p_ice_post, data = d)
    out <- cluster_fit(m, d)
    out$slope_pre <- term_stats(
        out$cf[["p_ice_pre"]], out$se[["p_ice_pre"]], out$clusters
    )
    out$slope_post <- term_stats(
        out$cf[["p_ice_post"]], out$se[["p_ice_post"]], out$clusters
    )
    out
}

hev_pooled <- fit_pooled(matches)
hev_sep <- fit_separate(matches)
hev_pooled_year_fe <- fit_pooled_year_fe(matches)
hev_sep_year_fe <- fit_separate_year_fe(matches)

fmt_term <- function(st) {
    fmt_coef(st[["b"]], st[["se"]], st[["p"]])
}
row4 <- function(label, a, b, c, d) {
    sprintf("        %s & %s & %s & %s & %s \\\\", label, a, b, c, d)
}
empty <- list(coef = "", se = "")
pool_slope <- fmt_term(hev_pooled$slope)
sep_pre <- fmt_term(hev_sep$slope_pre)
sep_post <- fmt_term(hev_sep$slope_post)
pool_slope_year_fe <- fmt_term(hev_pooled_year_fe$slope)
sep_pre_year_fe <- fmt_term(hev_sep_year_fe$slope_pre)
sep_post_year_fe <- fmt_term(hev_sep_year_fe$slope_post)

tab_ice <- c(
    "\\begin{table}[ht]",
    "    \\caption{Premium on matched ICEV price, counting each match}",
    "    \\label{tab:cr-ice-price-matches}",
    "    \\centering",
    "    \\footnotesize",
    "    \\begin{tabular}{lcccc}",
    "        \\toprule",
    "        & \\multicolumn{2}{c}{No year fixed effects} & \\multicolumn{2}{c}{Year fixed effects} \\\\",
    "        \\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
    "                                 & (1) & (2) & (3) & (4) \\\\",
    "        \\midrule",
    row4("ICEV price", pool_slope$coef, empty$coef, pool_slope_year_fe$coef, empty$coef),
    row4("", pool_slope$se, empty$se, pool_slope_year_fe$se, empty$se),
    row4("ICEV price (pre-2020)", empty$coef, sep_pre$coef, empty$coef, sep_pre_year_fe$coef),
    row4("", empty$se, sep_pre$se, empty$se, sep_pre_year_fe$se),
    row4("ICEV price (2020+)", empty$coef, sep_post$coef, empty$coef, sep_post_year_fe$coef),
    row4("", empty$se, sep_post$se, empty$se, sep_post_year_fe$se),
    "        \\midrule",
    "        Year fixed effects & No & No & Yes & Yes \\\\",
    sprintf(
        "        Observations & %d & %d & %d & %d \\\\",
        hev_pooled$n, hev_sep$n, hev_pooled_year_fe$n, hev_sep_year_fe$n
    ),
    sprintf(
        "        Nameplate clusters & %d & %d & %d & %d \\\\",
        hev_pooled$clusters, hev_sep$clusters,
        hev_pooled_year_fe$clusters, hev_sep_year_fe$clusters
    ),
    sprintf(
        "        AIC & %s & %s & %s & %s \\\\",
        formatC(hev_pooled$aic, format = "f", digits = 1),
        formatC(hev_sep$aic, format = "f", digits = 1),
        formatC(hev_pooled_year_fe$aic, format = "f", digits = 1),
        formatC(hev_sep_year_fe$aic, format = "f", digits = 1)
    ),
    sprintf(
        "        Adjusted $R^2$ & %s & %s & %s & %s \\\\",
        formatC(hev_pooled$adj_r2, format = "f", digits = 3),
        formatC(hev_sep$adj_r2, format = "f", digits = 3),
        formatC(hev_pooled_year_fe$adj_r2, format = "f", digits = 3),
        formatC(hev_sep_year_fe$adj_r2, format = "f", digits = 3)
    ),
    "        \\bottomrule",
    "    \\end{tabular}",
    "    \\par\\medskip",
    "    \\begin{minipage}{0.95\\textwidth}",
    "        \\footnotesize \\emph{Notes:} Unit of observation is a matched pair. Same specifications as Table~\\ref{tab:cr-ice-price}. Columns (1) and (3) estimate one slope across all years. Columns (2) and (4) estimate separate slopes before 2020 and since 2020. Columns (3) and (4) include model-year fixed effects. Intercepts and year coefficients omitted. Nameplate-clustered standard errors in parentheses. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "    \\end{minipage}",
    "\\end{table}"
)
writeLines(tab_ice, file.path(project_root, "output", "tables", "tab-cr-ice-price-matches.tex"))

report_slope <- function(label, st) {
    cat(sprintf(
        "%s  b=%.3f  se=%.3f  p=%.3f\n",
        label, st[["b"]], st[["se"]], st[["p"]]
    ))
}
report_slope("pooled", hev_pooled$slope)
report_slope("pre", hev_sep$slope_pre)
report_slope("post", hev_sep$slope_post)
report_slope("pooled year FE", hev_pooled_year_fe$slope)
report_slope("pre year FE", hev_sep_year_fe$slope_pre)
report_slope("post year FE", hev_sep_year_fe$slope_post)

sigma_era <- df %>%
    mutate(pre = .data$year < 2020) %>%
    group_by(.data$pre) %>%
    summarise(
        sigma = sigma(lm(premium ~ p_ice)),
        .groups = "drop"
    )
cat(sprintf(
    "residual SE pre = %.0f; post = %.0f\n",
    sigma_era$sigma[sigma_era$pre],
    sigma_era$sigma[!sigma_era$pre]
))

cat(sprintf("share of matches before 2020: %.3f\n", mean(df$year < 2020)))

for (cut in c(2019L, 2021L)) {
    d_cut <- df %>%
        mutate(
            nameplate = droplevels(.data$nameplate),
            pre = as.integer(.data$year < cut),
            post = as.integer(.data$year >= cut),
            p_ice_pre = .data$p_ice * .data$pre,
            p_ice_post = .data$p_ice * .data$post
        )
    m_cut <- lm(premium ~ 0 + pre + post + p_ice_pre + p_ice_post, data = d_cut)
    fit_cut <- cluster_fit(m_cut, d_cut)
    st <- term_stats(
        fit_cut$cf[["p_ice_post"]],
        fit_cut$se[["p_ice_post"]],
        fit_cut$clusters
    )
    report_slope(sprintf("post cutoff %d", cut), st)
}
