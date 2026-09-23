# Trim-level helpers: 1/m weights (one vote per nameplate--year), trim-line
# identifiers followed across model years, and trim fixed-effect paths.

# nolint start: object_usage_linter

add_trim_weights <- function(d) {
    d %>%
        dplyr::group_by(nameplate, body_type, year) %>%
        dplyr::mutate(m = dplyr::n(), w = 1 / m) %>%
        dplyr::ungroup() %>%
        dplyr::mutate(
            nameplate = droplevels(nameplate),
            trim_id = trim_line_id(., "trim_key"),
            trim_id_ice = trim_line_id(., "trim_ice"),
            trim_id_hyb = trim_line_id(., "trim_key_hyb")
        )
}

trim_line_id <- function(d, trim_col) {
    factor(paste(
        d$nameplate, d$body_type, d[[trim_col]], d$drive_type_ice,
        dplyr::coalesce(as.character(d$truck_bed), ""),
        dplyr::coalesce(d$package_ice, ""),
        sep = " | "
    ))
}

# Weighted mean prediction over newdata rows, with a cluster-robust SE.
weighted_pred_band <- function(model, V, newdata, wts, z = 1.96) {
    tt <- delete.response(terms(model))
    mf <- model.frame(tt, newdata, xlev = model$xlevels, na.action = na.pass)
    X <- model.matrix(tt, mf, contrasts.arg = model$contrasts)
    b <- coef(model)
    common <- intersect(names(b)[!is.na(b)], colnames(X))
    common <- intersect(common, colnames(V))
    X <- X[, common, drop = FALSE]
    g <- as.vector(crossprod(X, wts / sum(wts)))
    estimate <- sum(g * b[common])
    se <- sqrt(drop(crossprod(g, V[common, common, drop = FALSE] %*% g)))
    tibble::tibble(
        estimate = estimate,
        std.error = se,
        conf.low = estimate - z * se,
        conf.high = estimate + z * se
    )
}

fit_trim_fe <- function(d, outcome = "premium", key = "trim_id") {
    d2 <- d %>%
        dplyr::filter(!is.na(.data[[outcome]])) %>%
        dplyr::mutate(
            y = .data[[outcome]],
            unit = droplevels(.data[[key]]),
            year_fe = relevel(factor(year), ref = "2026")
        )
    m <- lm(y ~ year_fe + unit, data = d2, weights = w)
    list(model = m, V = sandwich::vcovCL(m, cluster = d2$nameplate), data = d2)
}

year_effects <- function(fit) {
    cf <- coef(fit$model)
    se <- sqrt(diag(fit$V))
    keep <- grepl("^year_fe", names(cf))
    tibble::tibble(
        year = as.integer(sub("^year_fe", "", names(cf)[keep])),
        alpha = unname(cf[keep]),
        se = unname(se[keep])
    )
}

# Wald test that the year effects in `years` are jointly zero (2026 = 0).
joint_year_test <- function(fit, years = 2020:2025) {
    terms <- paste0("year_fe", years)
    b <- coef(fit$model)[terms]
    V <- fit$V[terms, terms]
    W <- drop(t(b) %*% solve(V) %*% b)
    g <- nlevels(droplevels(factor(fit$data$nameplate)))
    q <- length(terms)
    F_stat <- W / q
    c(
        W = W,
        p_chisq = pchisq(W, q, lower.tail = FALSE),
        F = F_stat,
        p_F = pf(F_stat, q, g - 1, lower.tail = FALSE)
    )
}

# Raw path (1/m-weighted year means = nameplate--year means) and the
# 2026 trim lineup priced in each year with trim fixed effects.
build_trim_path <- function(d, outcome = "premium", key = "trim_id",
                            fleet_year = 2026L, z = 1.96) {
    fit <- fit_trim_fe(d, outcome, key)
    d2 <- fit$data
    years <- sort(unique(d2$year))
    raw <- d2 %>%
        dplyr::group_by(year) %>%
        dplyr::summarise(estimate = weighted.mean(y, w), .groups = "drop") %>%
        dplyr::mutate(series = "Raw average")
    fleet <- d2 %>% dplyr::filter(year == fleet_year)
    adj <- dplyr::bind_rows(lapply(years, function(yr) {
        nd <- fleet %>%
            dplyr::mutate(year_fe = factor(yr, levels = levels(d2$year_fe)))
        weighted_pred_band(fit$model, fit$V, nd, nd$w, z = z) %>%
            dplyr::mutate(year = yr, series = "Within trim")
    }))
    dplyr::bind_rows(raw, adj) %>%
        dplyr::mutate(series = factor(series, levels = c("Raw average", "Within trim")))
}

# nolint end
