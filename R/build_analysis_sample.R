# Shared HEV analysis sample: read matched pairs, keep the analysis year
# window, inflate to 2026 dollars, add common columns, and persist to
# output/analysis_sample.rds.

analysis_sample_path <- function(project_root = getwd()) {
    file.path(project_root, "output", "analysis_sample.rds")
}

matched_path <- function(project_root = getwd()) {
    file.path(project_root, "data", "matched.csv")
}

cpi_u <- data.frame(
    year = 2005:2027,
    cpi = c(
        195.300, 201.600, 207.342, 215.303, 214.537, 218.056, 224.939,
        229.594, 232.957, 236.736, 237.017, 240.007, 245.120, 251.107,
        255.657, 258.811, 270.970, 292.655, 304.702, 313.689, 321.943,
        333.952, 342.301
    )
)

inflate_to_2026 <- function(value, year) {
    round(
        value * cpi_u$cpi[cpi_u$year == 2026L] /
            cpi_u$cpi[match(year, cpi_u$year)]
    )
}

build_analysis_sample <- function(project_root = getwd()) {
    source(file.path(project_root, "R", "analysis_window.R"), local = FALSE)

    df <- read.csv(matched_path(project_root), stringsAsFactors = FALSE) %>%
        dplyr::filter(
            year >= ANALYSIS_YEAR_MIN,
            year <= ANALYSIS_YEAR_MAX
        )

    missing_cpi_years <- setdiff(unique(df$year), cpi_u$year)
    if (length(missing_cpi_years) > 0L) {
        stop(
            "Missing CPI values for model year(s): ",
            paste(sort(missing_cpi_years), collapse = ", ")
        )
    }

    df <- df %>%
        dplyr::mutate(
            msrp_2026_hyb = inflate_to_2026(msrp_hyb, year),
            msrp_2026_ice = inflate_to_2026(msrp_ice, year),
            raw_premium_2026 = msrp_2026_hyb - msrp_2026_ice,
            make = factor(make, levels = sort(unique(make))),
            year_fe = factor(year),
            nameplate = factor(paste(make, model)),
            body_type = factor(body_type_hyb),
            hpdiff = hp_hyb - hp_ice,
            p_ice = msrp_2026_ice,
            p_hyb = msrp_2026_hyb,
            premium = raw_premium_2026
        )

    out_path <- analysis_sample_path(project_root)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(df, out_path)
    df
}

load_analysis_sample <- function(project_root = getwd(), rebuild = FALSE) {
    source(file.path(project_root, "R", "analysis_window.R"), local = FALSE)
    out_path <- analysis_sample_path(project_root)
    if (rebuild || !file.exists(out_path)) {
        return(build_analysis_sample(project_root))
    }
    readRDS(out_path) %>%
        dplyr::filter(
            year >= ANALYSIS_YEAR_MIN,
            year <= ANALYSIS_YEAR_MAX
        )
}
