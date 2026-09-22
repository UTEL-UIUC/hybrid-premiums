# Shared year-path helpers for the HEV analysis scripts.

# nolint start: object_usage_linter

PATH_SERIES_COLS <- c(
    "Raw average" = "#E69F00",
    "2026 fleet held fixed" = "#0072B2",
    "2026 fleet, equal horsepower" = "#009E73"
)

# Cluster-robust SE of the mean prediction over newdata rows.
mean_pred_band <- function(model, V, newdata, z = 1.96) {
    tt <- delete.response(terms(model))
    mf <- model.frame(tt, newdata, xlev = model$xlevels, na.action = na.pass)
    X <- model.matrix(tt, mf, contrasts.arg = model$contrasts)
    b <- coef(model)
    common <- intersect(names(b)[!is.na(b)], colnames(X))
    common <- intersect(common, colnames(V))
    X <- X[, common, drop = FALSE]
    b <- b[common]
    V2 <- V[common, common, drop = FALSE]
    w <- rep(1 / nrow(X), nrow(X))
    g <- as.vector(crossprod(X, w))
    estimate <- sum(w * as.vector(X %*% b))
    se <- sqrt(drop(crossprod(g, V2 %*% g)))
    tibble::tibble(
        estimate = estimate,
        std.error = se,
        conf.low = estimate - z * se,
        conf.high = estimate + z * se
    )
}

collapse_nameplate_year <- function(d, cols = "premium") {
    d %>%
        dplyr::group_by(nameplate, body_type, year_fe, year) %>%
        dplyr::summarise(
            dplyr::across(dplyr::all_of(cols), mean),
            .groups = "drop"
        )
}

collapse_truck_body <- function(body_type) {
    dplyr::if_else(
        grepl("^Truck", as.character(body_type)),
        "Truck",
        as.character(body_type)
    )
}

# Year FE raw path plus year FE + unit FE holding the fleet-year mix fixed.
# With hp_col, a third path adds that column as a control and then sets it to
# zero: the fleet-year units priced as if hybrid and gas had equal horsepower.
build_fe_path <- function(
    d,
    outcome = "premium",
    unit_col = "nameplate",
    cluster_col = "nameplate",
    fleet_year = 2026L,
    hp_col = NULL,
    z = 1.96
) {
    d2 <- d %>%
        dplyr::mutate(
            y = .data[[outcome]],
            unit = droplevels(.data[[unit_col]]),
            year_fe = droplevels(year_fe),
            cluster = droplevels(factor(.data[[cluster_col]]))
        )

    if (!is.null(hp_col)) {
        d2$hp <- d2[[hp_col]]
    }

    years <- sort(unique(as.integer(as.character(d2$year_fe))))

    m_raw <- lm(y ~ 0 + year_fe, data = d2)
    V_raw <- sandwich::vcovCL(m_raw, cluster = d2$cluster)
    raw <- dplyr::bind_rows(lapply(years, function(yr) {
        nd <- d2 %>%
            dplyr::filter(year == yr) %>%
            dplyr::select(year_fe) %>%
            dplyr::slice(1)
        mean_pred_band(m_raw, V_raw, nd, z = z) %>%
            dplyr::mutate(year = yr, series = "Raw average")
    }))

    fe <- lm(y ~ 0 + year_fe + unit, data = d2)
    V <- sandwich::vcovCL(fe, cluster = d2$cluster)
    fleet <- d2 %>%
        dplyr::filter(year == fleet_year) %>%
        dplyr::select(unit)

    adj <- dplyr::bind_rows(lapply(years, function(yr) {
        nd <- fleet %>%
            dplyr::mutate(year_fe = factor(yr, levels = levels(d2$year_fe)))
        mean_pred_band(fe, V, nd, z = z) %>%
            dplyr::mutate(year = yr, series = "2026 fleet held fixed")
    }))

    adj_hp <- NULL
    if (!is.null(hp_col)) {
        fe_hp <- lm(y ~ 0 + year_fe + unit + hp, data = d2)
        V_hp <- sandwich::vcovCL(fe_hp, cluster = d2$cluster)
        fleet_hp <- d2 %>%
            dplyr::filter(year == fleet_year) %>%
            dplyr::select(unit) %>%
            dplyr::mutate(hp = 0)

        adj_hp <- dplyr::bind_rows(lapply(years, function(yr) {
            nd <- fleet_hp %>%
                dplyr::mutate(
                    year_fe = factor(yr, levels = levels(d2$year_fe))
                )
            mean_pred_band(fe_hp, V_hp, nd, z = z) %>%
                dplyr::mutate(
                    year = yr,
                    series = "2026 fleet, equal horsepower"
                )
        }))
    }

    dplyr::bind_rows(raw, adj, adj_hp) %>%
        dplyr::mutate(
            series = factor(series, levels = names(PATH_SERIES_COLS))
        )
}

# Raw year means plus year FE + controls holding the fleet-year mix fixed.
build_gap_path <- function(d, outcome, controls, fleet_year = 2026L) {
    d2 <- d %>%
        dplyr::mutate(
            year_fe = droplevels(year_fe),
            y = .data[[outcome]]
        )

    for (nm in controls) {
        if (is.numeric(d2[[nm]])) {
            d2[[nm]] <- d2[[nm]] - mean(d2[[nm]])
        } else {
            d2[[nm]] <- droplevels(factor(d2[[nm]]))
        }
    }

    form <- stats::as.formula(paste(
        "y ~ 0 + year_fe +",
        paste(controls, collapse = " + ")
    ))
    fe <- lm(form, data = d2)

    raw <- d2 %>%
        dplyr::group_by(year) %>%
        dplyr::summarise(estimate = mean(y), .groups = "drop") %>%
        dplyr::mutate(series = "Raw average")

    fleet <- d2 %>%
        dplyr::filter(year == fleet_year) %>%
        dplyr::select(dplyr::all_of(controls))

    years <- sort(unique(as.integer(as.character(d2$year_fe))))
    adj <- dplyr::bind_rows(lapply(years, function(yr) {
        nd <- fleet %>%
            dplyr::mutate(year_fe = factor(yr, levels = levels(d2$year_fe)))
        tibble::tibble(
            year = yr,
            estimate = mean(predict(fe, newdata = nd)),
            series = "2026 fleet held fixed"
        )
    }))

    dplyr::bind_rows(raw, adj) %>%
        dplyr::mutate(
            series = factor(series, levels = names(PATH_SERIES_COLS))
        )
}

path_plot_theme <- function() {
    ggplot2::theme_minimal(base_size = 10) +
        ggplot2::theme(
            panel.grid.minor = ggplot2::element_blank(),
            legend.position = "top",
            legend.box.spacing = grid::unit(0, "pt"),
            legend.margin = ggplot2::margin(0, 0, 0, 0),
            axis.title = ggplot2::element_text(size = 9)
        )
}

plot_fe_path <- function(series) {
    ggplot2::ggplot(
        series,
        ggplot2::aes(x = year, y = estimate, color = series, fill = series)
    ) +
        ggplot2::geom_hline(yintercept = 0, color = "grey80", linewidth = 0.6) +
        ggplot2::geom_ribbon(
            ggplot2::aes(ymin = conf.low, ymax = conf.high),
            alpha = 0.20,
            color = NA
        ) +
        ggplot2::geom_line(linewidth = 0.85) +
        ggplot2::scale_color_manual(values = PATH_SERIES_COLS) +
        ggplot2::scale_fill_manual(values = PATH_SERIES_COLS) +
        ggplot2::scale_x_continuous(
            breaks = seq(ANALYSIS_YEAR_MIN, ANALYSIS_YEAR_MAX, by = 2)
        ) +
        ggplot2::scale_y_continuous(
            labels = scales::label_dollar(scale = 1e-3, suffix = "k")
        ) +
        ggplot2::labs(x = NULL, y = NULL, color = NULL, fill = NULL) +
        path_plot_theme()
}

# nolint end
