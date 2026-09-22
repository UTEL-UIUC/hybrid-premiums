# Premium vs matched ICEV price (HEV): scatter and two-intercept table.
# Nameplate--year cells = mean of observations (premium and matched ICEV MSRP).

suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(scales)
    library(tidyr)
    library(tibble)
    library(patchwork)
})

project_root <- getwd()
dir.create(file.path(project_root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
source(file.path(project_root, "R", "build_analysis_sample.R"))
source(file.path(project_root, "R", "path_helpers.R"))
df <- load_analysis_sample(project_root)

df_cr <- collapse_nameplate_year(df, c("p_ice", "premium")) %>%
    mutate(
        era = factor(
            if_else(year < 2020, "Pre-2020", "2020+"),
            levels = c("Pre-2020", "2020+")
        ),
        post = year >= 2020,
        year_fe = droplevels(year_fe),
        nameplate = droplevels(nameplate)
    )

# Optional CR residual panel (year FE only).
df_cr %>%
    mutate(
        premium_cr = {
            m <- lm(premium ~ 0 + year_fe + p_ice + p_ice:post)
            cf <- coef(m)
            b_interact <- cf[grepl("p_ice", names(cf)) & grepl("post", names(cf))]
            b_p <- cf[["p_ice"]] + unname(b_interact) * as.numeric(post)
            comp <- b_p * p_ice
            residuals(m) + comp + mean(fitted(m) - comp)
        }
    ) %>%
    pivot_longer(
        cols = c(premium, premium_cr),
        names_to = "panel",
        values_to = "y"
    ) %>%
    mutate(
        panel = factor(
            panel,
            levels = c("premium", "premium_cr"),
            labels = c(
                "Unadjusted data",
                "Component + residual for p_ice"
            )
        )
    ) %>%
    ggplot(aes(p_ice, y, color = era)) +
    geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
    geom_point(alpha = 0.50, size = 1.0) +
    geom_smooth(
        method = "lm",
        formula = y ~ x,
        se = TRUE,
        linewidth = 0.6,
        alpha = 0.15,
        aes(fill = era)
    ) +
    facet_wrap(~panel, nrow = 1, scales = "free_y") +
    scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k")) +
    scale_y_continuous(labels = label_dollar(scale = 1e-3, suffix = "k")) +
    labs(
        x = "Matched ICEV MSRP (2026 $)",
        y = NULL,
        color = NULL,
        fill = NULL
    ) +
    theme_minimal(base_size = 9) +
    theme(
        panel.grid.minor = element_blank(),
        legend.position = "top",
        strip.text = element_text(face = "bold", hjust = 0)
    )

ggsave(
    file.path(project_root, "output", "premium_by_ice_price_cr.pdf"),
    width = 7,
    height = 3.5
)

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
    t <- b / s
    p <- 2 * pt(-abs(t), df = max(g - 1, 1))
    c(b = unname(b), se = unname(s), p = p)
}

era_dummies <- function(d) {
    d %>%
        dplyr::mutate(
            nameplate = droplevels(.data$nameplate),
            pre = as.integer(.data$year < 2020),
            post = as.integer(.data$year >= 2020),
            p_ice_pre = .data$p_ice * .data$pre,
            p_ice_post = .data$p_ice * .data$post
        )
}

cluster_fit <- function(m, d) {
    V <- sandwich::vcovCL(m, cluster = d$nameplate)
    g <- nlevels(d$nameplate)
    se <- sqrt(diag(V))
    cf <- coef(m)
    y <- model.response(model.frame(m))
    sse <- sum(residuals(m)^2)
    sst <- sum((y - mean(y))^2)
    n <- nrow(d)
    p <- m$rank
    list(
        m = m,
        n = n,
        clusters = g,
        aic = AIC(m),
        adj_r2 = 1 - (sse / (n - p)) / (sst / (n - 1)),
        cf = cf,
        se = se
    )
}

fit_pooled <- function(d) {
    d <- era_dummies(d)
    m <- lm(premium ~ p_ice, data = d)
    out <- cluster_fit(m, d)
    out$intercept <- term_stats(
        out$cf[["(Intercept)"]],
        out$se[["(Intercept)"]],
        out$clusters
    )
    out$slope <- term_stats(out$cf[["p_ice"]], out$se[["p_ice"]], out$clusters)
    out
}

fit_separate <- function(d) {
    d <- era_dummies(d)
    m <- lm(premium ~ 0 + pre + post + p_ice_pre + p_ice_post, data = d)
    out <- cluster_fit(m, d)
    out$int_pre <- term_stats(out$cf[["pre"]], out$se[["pre"]], out$clusters)
    out$int_post <- term_stats(out$cf[["post"]], out$se[["post"]], out$clusters)
    out$slope_pre <- term_stats(
        out$cf[["p_ice_pre"]],
        out$se[["p_ice_pre"]],
        out$clusters
    )
    out$slope_post <- term_stats(
        out$cf[["p_ice_post"]],
        out$se[["p_ice_post"]],
        out$clusters
    )
    out
}

fit_pooled_year_fe <- function(d) {
    d <- era_dummies(d)
    m <- lm(premium ~ 0 + year_fe + p_ice, data = d)
    out <- cluster_fit(m, d)
    out$slope <- term_stats(out$cf[["p_ice"]], out$se[["p_ice"]], out$clusters)
    out
}

fit_separate_year_fe <- function(d) {
    d <- era_dummies(d)
    m <- lm(premium ~ 0 + year_fe + p_ice_pre + p_ice_post, data = d)
    out <- cluster_fit(m, d)
    out$slope_pre <- term_stats(
        out$cf[["p_ice_pre"]],
        out$se[["p_ice_pre"]],
        out$clusters
    )
    out$slope_post <- term_stats(
        out$cf[["p_ice_post"]],
        out$se[["p_ice_post"]],
        out$clusters
    )
    out
}

hev_pooled <- fit_pooled(df_cr)
hev_sep <- fit_separate(df_cr)
hev_pooled_year_fe <- fit_pooled_year_fe(df_cr)
hev_sep_year_fe <- fit_separate_year_fe(df_cr)

fmt_term <- function(st, digits = 3) {
    fmt_coef(st[["b"]], st[["se"]], st[["p"]], digits = digits)
}

row4 <- function(label, a, b, c, d, shade = FALSE) {
    pref <- if (shade) "        \\rowcolor{gray!18} " else "        "
    sprintf("%s%s & %s & %s & %s & %s \\\\", pref, label, a, b, c, d)
}

empty <- list(coef = "", se = "")
pool_slope <- fmt_term(hev_pooled$slope)
sep_pre <- fmt_term(hev_sep$slope_pre)
sep_post <- fmt_term(hev_sep$slope_post)
pool_slope_year_fe <- fmt_term(hev_pooled_year_fe$slope)
sep_pre_year_fe <- fmt_term(hev_sep_year_fe$slope_pre)
sep_post_year_fe <- fmt_term(hev_sep_year_fe$slope_post)

tab <- c(
    "\\begin{table}[ht]",
    "    \\caption{Premium on matched ICEV price}",
    "    \\label{tab:cr-ice-price}",
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
    "        \\footnotesize \\emph{Notes:} Unit of observation is a nameplate--year cell (mean premium and matched ICEV MSRP). HEV sample only. Columns (1) and (3) estimate one slope across all years. Columns (2) and (4) estimate separate slopes before 2020 and since 2020. Columns (3) and (4) include model-year fixed effects. Intercepts and year coefficients omitted. Nameplate-clustered standard errors in parentheses. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "    \\end{minipage}",
    "\\end{table}"
)

tab_path <- file.path(project_root, "output", "tables", "tab-cr-ice-price.tex")
writeLines(tab, tab_path)

c(
    hev_pooled = hev_pooled$slope[["b"]],
    hev_pre = hev_sep$slope_pre[["b"]],
    hev_post = hev_sep$slope_post[["b"]],
    hev_pooled_year_fe = hev_pooled_year_fe$slope[["b"]],
    hev_pre_year_fe = hev_sep_year_fe$slope_pre[["b"]],
    hev_post_year_fe = hev_sep_year_fe$slope_post[["b"]]
)

plot_price_slopes <- function(d, x_label, y_label) {
    slope_labs <- d %>%
        group_by(.data$era) %>%
        summarise(
            fit = list(lm(y ~ x)),
            .groups = "drop"
        ) %>%
        mutate(
            slope = vapply(.data$fit, function(m) coef(m)[["x"]], numeric(1)),
            sigma = vapply(.data$fit, sigma, numeric(1)),
            lab = paste0(
                "slope = ",
                formatC(.data$slope, format = "f", digits = 3)
            ),
            se_lab = paste0(
                "Residual SE = ",
                label_dollar(accuracy = 1)(.data$sigma)
            ),
            x = -Inf,
            y = Inf,
            hj = -0.12
        )

    d %>%
        ggplot(
            aes(
                .data$x,
                .data$y,
                color = .data$era,
                fill = .data$era
            )
        ) +
        geom_hline(yintercept = 0, color = "grey80", linewidth = 0.5) +
        geom_vline(xintercept = 0, color = "grey80", linewidth = 0.5) +
        geom_point(alpha = 0.50, size = 1.0) +
        geom_smooth(
            method = "lm",
            formula = y ~ x,
            se = TRUE,
            linewidth = 0.6,
            alpha = 0.15
        ) +
        geom_text(
            data = slope_labs,
            aes(label = .data$lab, hjust = .data$hj),
            vjust = 1.5,
            size = 3,
            show.legend = FALSE
        ) +
        geom_label(
            data = slope_labs,
            aes(label = .data$se_lab),
            x = Inf,
            y = Inf,
            hjust = 1,
            vjust = 1.4,
            size = 2.5,
            fill = "white",
            linewidth = 0,
            label.padding = unit(1, "pt"),
            show.legend = FALSE
        ) +
        facet_grid(cols = vars(.data$era)) +
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

raw_plot_data <- df_cr %>%
    transmute(era, x = p_ice, y = premium)

year_fe_plot_data <- df_cr %>%
    group_by(year) %>%
    mutate(
        x = p_ice - mean(p_ice),
        y = premium - mean(premium)
    ) %>%
    ungroup() %>%
    select(era, x, y)

p_raw <- plot_price_slopes(
    raw_plot_data,
    x_label = "Matched ICEV MSRP (2026 $)",
    y_label = "Premium (2026 $)"
)

p_year_fe <- plot_price_slopes(
    year_fe_plot_data,
    x_label = "ICEV MSRP residual after year FE (2026 $)",
    y_label = "Premium residual after year FE (2026 $)"
)

p_raw / p_year_fe

ggsave(
    file.path(project_root, "output", "premium_by_ice_price.pdf"),
    width = 6.4,
    height = 5.2
)
