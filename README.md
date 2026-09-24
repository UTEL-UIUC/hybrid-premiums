# The hybrid electric vehicle price premium in the United States: 2012–2026

Data and code for Shih and Lehe, "The hybrid electric vehicle price premium in the United States: 2012–2026."

The paper compares the base MSRP of conventional hybrid-electric vehicles (HEVs) with gasoline (ICE) trims of the same make, model, model year, body, drive, and equipment level. This repository contains the 714 matched HEV–ICE pairs and the R code that produces every figure and table in the paper from them.

## What is and is not included

The pairs were built from the Teoalida Year-Make-Model-Trim Basic Specs database, a licensed trim-level catalog of US vehicles. Its license does not allow redistribution, so the catalog and the code that reads it are not in this repository. Instead:

- `data/matched.csv` holds the matched pairs, limited to the fields the analysis uses.
- `methodology.md` documents every matching rule, including all manual model and trim renamings, exclusions, and the sources behind each brand-level decision.
- `data/curb-weight-corrections.csv` records the curb weights we sourced by hand where the catalog was missing them.
- `data/hev-models-by-body.csv` holds aggregate counts of HEV nameplates by year and body type from the catalog, used for the HEV-models-by-body figure.

Anyone with a copy of the catalog can rebuild the pairs by following `methodology.md`.

## Data

### `data/matched.csv`

One row per HEV–ICE pair (714 rows). Prices are nominal model-year dollars.

| Column | Description |
| --- | --- |
| `pair_id` | Sequential row identifier |
| `year` | Model year |
| `make`, `model` | Nameplate, after the renamings in `methodology.md` |
| `trim_hyb`, `trim_ice` | Source trim names of the HEV and its ICE match |
| `trim_key` | Normalized trim name on which the pair was matched (lowercase, punctuation and powertrain words removed, Lexus badges stripped, HEV remaps applied); identical for both sides. Used to follow trims across years |
| `trim_key_hyb` | Normalized HEV trim name before any remap (`basic` for a blank or bare "Hybrid" trim). Used only in a robustness check |
| `body_type_hyb` | Body type (identical for both sides by construction) |
| `drive_type_hyb`, `drive_type_ice` | Drive type; all-wheel and four-wheel drive are pooled for matching, so a few pairs differ |
| `truck_bed` | Pickup bed length in feet (blank for non-pickups); identical for both sides by construction |
| `package_hyb`, `package_ice` | Option package in the catalog listing (e.g. `Technology Package`), blank if none |
| `msrp_hyb`, `msrp_ice` | Base MSRP |
| `hp_hyb`, `hp_ice` | Rated horsepower |
| `mpg_combined_hyb`, `mpg_combined_ice` | EPA combined MPG |
| `curb_weight_hyb`, `curb_weight_ice` | Curb weight (lb); blank where it could not be sourced |

A year–model–trim combination can appear more than once when the trim is sold in several drive types, truck bed lengths, or packages; those columns tell the rows apart. The one exception is the 2020–2022 Lexus RX Base, where the standard RX and long-wheelbase RX L share all listed fields; the RX L is the higher-priced row of each pair.

### `data/curb-weight-corrections.csv`

Curb weights researched by hand for matched vehicles whose catalog weight was missing (98 rows). Columns: `year`, `make`, `model`, `trim`, `side` (`hev` or `ice`), `curb_weight_lbs`, `status` (`exact`, `shared_configuration`, or `unresolved`), `source_url`, `source_tier`, `source_quote`, `notes`. These values are already applied in `matched.csv`.

### `data/hev-models-by-body.csv`

Number of distinct HEV make–model nameplates in the catalog by model year and body type (`year`, `body`, `n_models`), 2012–2026.

### Argonne sales data

US light-duty vehicle sales from Argonne National Laboratory's [Light Duty Electric Drive Vehicles Monthly Sales Updates](https://www.anl.gov/esia/light-duty-electric-drive-vehicles-monthly-sales-updates):

- `data/anl-ldv-monthly-sales.csv`: monthly BEV, PHEV, HEV, and total light-duty sales from December 2010.
- `data/anl-hev-quarterly-2018-2026.csv`, `data/anl-hev-halfyear-2018-2026.csv`, `data/anl-hev-annual-2018-2026.csv`: HEV sales and share of light-duty sales by quarter, half-year, and year.
- `data/anl-total-sales-july-2026.pdf`, `data/anl-total-sales-august-2026.pdf`: the source reports.

## Reproducing the results

Requires R (4.3 or later) with `dplyr`, `tibble`, `tidyr`, `ggplot2`, `scales`, `patchwork`, and `sandwich`:

```r
install.packages(c("dplyr", "tibble", "tidyr", "ggplot2", "scales", "patchwork", "sandwich"))
```

From the repository root:

```bash
Rscript run-all.R
```

This builds `output/analysis_sample.rds` (the matched pairs inflated to 2026 dollars with CPI-U, restricted to model years 2012–2026), then writes figures to `output/` and LaTeX tables to `output/tables/`. Each script can also be run on its own from the repository root.

### Estimation design

- **Weights.** Every average and regression uses all matched pairs, each weighted by one over the number of matches its nameplate has in that year (nameplate = make × model × body), so each nameplate–year counts once.
- **Trim lines.** A trim line is nameplate × body × ICE drive type × truck bed × ICE package × `trim_key`, followed across model years (205 lines).
- **Adjusted paths.** The adjusted premium, fuel-economy, and performance paths use model-year and trim-line fixed effects, and price the 2026 lineup in each earlier year.
- **Standard errors.** All standard errors are clustered by nameplate.
- **Robustness.** `premium-path-fe.R` also prints results with trim lines keyed on the raw ICE trim name (`trim_ice`) and on `trim_key_hyb`, and with nameplate instead of trim fixed effects.

| Paper output | Script | File |
| --- | --- | --- |
| Nameplate timeline | `nameplate-timeline.R` | `output/nameplate_timeline.pdf` |
| Premium vs. horsepower difference | `premium-hpdiff.R` | `output/premium_hpdiff.pdf` |
| Premium path, matched pairs and nameplates weighted equally | `premium-path.R` | `output/premium_path_observations.pdf`, `output/premium_path_nameplates.pdf` |
| Yearly mean premiums table | `premium-path-means.R` | `output/tables/tab-premium-path-means.tex` |
| Selected long-lived trims | `trim-paths.R` | `output/premium_trim_line_paths.pdf` |
| Year fixed effects table and adjusted premium | `premium-path-fe.R` | `output/tables/tab-year-fe-trim.tex`, `output/premium_path_trim_fe.pdf` |
| Premium vs. ICE price table and figure | `premium-by-ice-price.R` | `output/tables/tab-cr-ice-price-trim.tex`, `output/premium_by_ice_price_trim.pdf` |
| HEV sales share and premium | `hev-quarterly-sales.R` | `output/hev_quarterly_sales.pdf` |
| Fuel economy gaps | `fuel-gaps.R` | `output/fuel_gaps_trim.pdf` |
| Performance gaps | `perf-gaps.R` | `output/perf_gaps_trim.pdf` |
| HEV models by body type | `hev-models-by-body.R` | `output/hev_models_by_body.pdf` |

Shared code lives in `R/`:

- `analysis_window.R`: the model-year range.
- `build_analysis_sample.R`: CPI inflation and analysis columns.
- `path_helpers.R`: nameplate–year collapsing, nameplate fixed-effect paths, and the plot theme.
- `trim_helpers.R`: the 1/m weights, trim-line identifiers, trim fixed-effect paths with clustered confidence bands, and the joint test of the post-2019 year effects.

## License

Code is released under the MIT License (see `LICENSE`). The data files we created (`matched.csv` as a compilation, `curb-weight-corrections.csv`, `hev-models-by-body.csv`, and `methodology.md`) are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The Argonne files are public data from Argonne National Laboratory.
