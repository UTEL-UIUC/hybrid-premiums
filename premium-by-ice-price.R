# Premium vs matched ICEV price on matched trims weighted 1/m (one vote per
# nameplate--year). Columns (5)-(6) add nameplate--year fixed effects, so
# their slopes compare trims of the same car in the same year.
# Writes output/tables/tab-cr-ice-price-trim.tex and output/premium_by_ice_price_trim.pdf.

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
    library(patchwork)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
source(file.path(project_root, "R", "trim_helpers.R"))

df <- add_trim_weights(load_analysis_sample(project_root)) %>%
    mutate(
        era = factor(if_else(year < 2020, "Pre-2020", "2020+"), levels = c("Pre-2020", "2020+")),
        pre = as.integer(year < 2020),
        post = 1L - pre,
        p_ice_pre = p_ice * pre,
        p_ice_post = p_ice * post,
        year_fe = droplevels(year_fe),
        cell = factor(paste(nameplate, body_type, year))
    ) %>%
    group_by(cell) %>%
    mutate(xbar = mean(p_ice)) %>%
    ungroup() %>%
    mutate(
        xdev = p_ice - xbar,
        xdev_pre = xdev * pre, xdev_post = xdev * post,
        xbar_pre = xbar * pre, xbar_post = xbar * post
    )

stars <- function(p) {
    if (p < 0.01) "$^{***}$" else if (p < 0.05) "$^{**}$" else if (p < 0.10) "$^{*}$" else ""
}

n_clusters <- nlevels(df$nameplate)

slope <- function(fit, term) {
    b <- coef(fit$m)[[term]]
    s <- sqrt(fit$V[term, term])
    p <- 2 * pt(-abs(b / s), df = n_clusters - 1)
    c(b = b, se = s, p = p)
}

weighted_adj_r2 <- function(m, d) {
    y <- d$premium
    ybar <- weighted.mean(y, d$w)
    sse <- sum(d$w * residuals(m)^2)
    sst <- sum(d$w * (y - ybar)^2)
    n <- nrow(d)
    1 - (sse / (n - m$rank)) / (sst / (n - 1))
}

fit_w <- function(formula, d = df) {
    m <- lm(formula, data = d, weights = w)
    list(m = m, V = sandwich::vcovCL(m, cluster = d$nameplate), r2 = weighted_adj_r2(m, d))
}

fits <- list(
    fit_w(premium ~ p_ice),
    fit_w(premium ~ 0 + pre + post + p_ice_pre + p_ice_post),
    fit_w(premium ~ 0 + year_fe + p_ice),
    fit_w(premium ~ 0 + year_fe + p_ice_pre + p_ice_post),
    fit_w(premium ~ 0 + cell + p_ice),
    fit_w(premium ~ 0 + cell + p_ice_pre + p_ice_post)
)
# Between slopes for columns (5)-(6): ICEV price split into its
# nameplate--year mean and the deviation from it, with year fixed effects.
# The within slopes and SEs in (5)-(6) come from the nameplate--year FE fits.
between_fits <- list(
    `5` = fit_w(premium ~ 0 + year_fe + xdev + xbar),
    `6` = fit_w(premium ~ 0 + year_fe + xdev_pre + xdev_post + xbar_pre + xbar_post)
)

fmt_slope <- function(fit, term, part) {
    if (is.null(fit) || !term %in% names(coef(fit$m))) {
        return("")
    }
    s <- slope(fit, term)
    if (part == "coef") {
        paste0(sub("^-", "$-$", formatC(s[["b"]], format = "f", digits = 3)), stars(s[["p"]]))
    } else {
        sprintf("(%s)", formatC(s[["se"]], format = "f", digits = 3))
    }
}

# Each row names, per column, the fit and term to report ("" = blank).
row_spec <- function(label, terms, part, source = "main") {
    vals <- vapply(seq_along(terms), function(i) {
        if (terms[[i]] == "") return("")
        fit <- if (source == "between") between_fits[[as.character(i)]] else fits[[i]]
        fmt_slope(fit, terms[[i]], part)
    }, "")
    sprintf("        %s & %s \\\\", label, paste(vals, collapse = " & "))
}
rows2 <- function(label, terms, source = "main") {
    c(row_spec(label, terms, "coef", source), row_spec("", terms, "se", source))
}

tab <- c(
    "\\begin{table}[ht]",
    "    \\caption{Premium on matched ICEV price}",
    "    \\label{tab:cr-ice-price}",
    "    \\centering",
    "    \\footnotesize",
    "    \\begin{tabular}{lcccccc}",
    "        \\toprule",
    "        & \\multicolumn{2}{c}{No fixed effects} & \\multicolumn{2}{c}{Year fixed effects} & \\multicolumn{2}{c}{Within and between} \\\\",
    "        \\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}",
    "        & (1) & (2) & (3) & (4) & (5) & (6) \\\\",
    "        \\midrule",
    rows2("ICEV price", c("p_ice", "", "p_ice", "", "", "")),
    rows2("ICEV price (pre-2020)", c("", "p_ice_pre", "", "p_ice_pre", "", "")),
    rows2("ICEV price (2020+)", c("", "p_ice_post", "", "p_ice_post", "", "")),
    "        \\midrule",
    rows2("Within nameplate--year", c("", "", "", "", "p_ice", "")),
    rows2("\\quad pre-2020", c("", "", "", "", "", "p_ice_pre")),
    rows2("\\quad 2020+", c("", "", "", "", "", "p_ice_post")),
    rows2("Between nameplate--years", c("", "", "", "", "xbar", ""), "between"),
    rows2("\\quad pre-2020", c("", "", "", "", "", "xbar_pre"), "between"),
    rows2("\\quad 2020+", c("", "", "", "", "", "xbar_post"), "between"),
    "        \\midrule",
    sprintf("        Matched pairs & %s \\\\", paste(rep(nrow(df), 6), collapse = " & ")),
    sprintf("        Nameplate--years & %s \\\\", paste(rep(nlevels(df$cell), 6), collapse = " & ")),
    sprintf("        Nameplate clusters & %s \\\\", paste(rep(n_clusters, 6), collapse = " & ")),
    sprintf(
        "        Adjusted $R^2$ & %s & & \\\\",
        paste(vapply(fits[1:4], function(f) formatC(f$r2, format = "f", digits = 3), ""), collapse = " & ")
    ),
    "        \\bottomrule",
    "    \\end{tabular}",
    "    \\par\\medskip",
    "    \\begin{minipage}{0.95\\textwidth}",
    "        \\footnotesize \\emph{Notes:} Weighted least squares on matched pairs, each weighted by one over the number of matches in its nameplate--year, so that each nameplate--year carries equal weight. Columns (1), (3), and (5) estimate one slope across all years; columns (2), (4), and (6) estimate separate slopes before 2020 and since 2020. Columns (3) and (4) include model-year fixed effects. Columns (5) and (6) split the ICEV price into its nameplate--year mean and each trim's deviation from that mean. The within slope compares trims of the same nameplate in the same year and is estimated with nameplate--year fixed effects. The between slope compares nameplate--year means and is estimated with model-year fixed effects, controlling for the within deviation. Intercepts and fixed effects omitted. Nameplate-clustered standard errors in parentheses. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "    \\end{minipage}",
    "\\end{table}"
)
writeLines(tab, file.path(project_root, "output", "tables", "tab-cr-ice-price-trim.tex"))

# Slopes for the text.
lapply(seq_along(fits), function(i) {
    terms <- intersect(c("p_ice", "p_ice_pre", "p_ice_post"), names(coef(fits[[i]]$m)))
    sapply(terms, function(t) round(slope(fits[[i]], t), 3))
})

# Residual SE by era, weighted, around era-specific lines (as in the figure).
wrse <- function(d) {
    m <- lm(premium ~ p_ice, data = d, weights = w)
    sqrt(sum(d$w * residuals(m)^2) / (sum(d$w) - 2))
}
c(pre = wrse(filter(df, pre == 1)), post = wrse(filter(df, post == 1)))

# Share of weight (nameplate--years) before 2020.
sum(df$w[df$pre == 1]) / sum(df$w)

# Cutoff sensitivity, no year fixed effects.
sapply(c(2019, 2020, 2021), function(cut) {
    d <- df %>%
        mutate(
            pre = as.integer(year < cut), post = 1L - pre,
            p_ice_pre = p_ice * pre, p_ice_post = p_ice * post
        )
    f <- fit_w(premium ~ 0 + pre + post + p_ice_pre + p_ice_post, d)
    round(slope(f, "p_ice_post"), 3)
})

# Multi-trim cells with a single premium across all trims.
df %>%
    group_by(cell) %>%
    filter(n() > 1) %>%
    summarise(same = n_distinct(msrp_hyb - msrp_ice) == 1) %>%
    summarise(cells = n(), single_premium = sum(same))

plot_w <- function(d, x_label, y_label) {
    labs_d <- d %>%
        group_by(era) %>%
        summarise(fit = list(lm(y ~ x, weights = w)), sw = sum(w), .groups = "drop") %>%
        mutate(
            slope = vapply(fit, function(m) coef(m)[["x"]], numeric(1)),
            rse = mapply(function(m, s) sqrt(sum(weights(m) * residuals(m)^2) / (s - 2)), fit, sw),
            lab = paste0("slope = ", formatC(slope, format = "f", digits = 3)),
            se_lab = paste0("Residual SE = ", label_dollar(accuracy = 1)(rse))
        )
    ggplot(d, aes(x, y, color = era, fill = era)) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
        geom_vline(xintercept = 0, color = "grey80", linewidth = 0.5) +
        geom_point(aes(size = w), alpha = 0.45, stroke = 0) +
        geom_smooth(aes(weight = w), method = "lm", formula = y ~ x, se = TRUE, linewidth = 0.6, alpha = 0.15) +
        geom_text(
            data = labs_d, aes(label = lab), x = -Inf, y = Inf,
            hjust = -0.12, vjust = 1.5, size = 3, show.legend = FALSE
        ) +
        geom_label(
            data = labs_d, aes(label = se_lab), x = Inf, y = Inf,
            hjust = 1, vjust = 1.4, size = 2.5, fill = "white",
            linewidth = 0, label.padding = unit(1, "pt"), show.legend = FALSE
        ) +
        facet_grid(cols = vars(era)) +
        scale_size_area(max_size = 2.2, guide = "none") +
        scale_x_continuous(
            labels = label_dollar(scale = 1e-3, suffix = "k"),
            expand = expansion(mult = c(0.04, 0.06))
        ) +
        scale_y_continuous(
            breaks = breaks_width(2500),
            labels = label_dollar(scale = 1e-3, suffix = "k"),
            expand = expansion(mult = 0.06)
        ) +
        labs(x = x_label, y = y_label, color = NULL, fill = NULL) +
        theme_minimal(base_size = 9) +
        theme(
            panel.grid.minor = element_blank(),
            legend.position = "none",
            strip.text = element_text(face = "bold")
        )
}

raw_plot_data <- df %>% transmute(era, w, x = p_ice, y = premium)
year_fe_plot_data <- df %>%
    group_by(year) %>%
    mutate(x = p_ice - weighted.mean(p_ice, w), y = premium - weighted.mean(premium, w)) %>%
    ungroup() %>%
    select(era, w, x, y)

plot_w(raw_plot_data, "Matched ICEV MSRP (2026 $)", "Premium (2026 $)") /
    plot_w(
        year_fe_plot_data,
        "ICEV MSRP residual after year FE (2026 $)",
        "Premium residual after year FE (2026 $)"
    )

ggsave(
    file.path(project_root, "output", "premium_by_ice_price_trim.pdf"),
    width = 6.4,
    height = 5.2
)
