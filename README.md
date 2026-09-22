# The hybrid electric vehicle price premium in the United States: 2012–2026

Data and code for Shih and Lehe, "The hybrid electric vehicle price premium in the United States: 2012–2026."

The paper compares the base MSRP of conventional hybrid-electric vehicles (HEVs) with gasoline (ICE) trims of the same make, model, model year, body, drive, and equipment level. This repository contains the 715 matched HEV–ICE pairs and the R code that produces every figure and table in the paper from them.

## What is and is not included

The pairs were built from the Teoalida Year-Make-Model-Trim Basic Specs database, a licensed trim-level catalog of US vehicles. Its license does not allow redistribution, so the catalog and the code that reads it are not in this repository. Instead:

- `data/matched.csv` holds the matched pairs, limited to the fields the analysis uses.
- `methodology.md` documents every matching rule, including all manual model and trim renamings, exclusions, and the sources behind each brand-level decision.
- `data/curb-weight-corrections.csv` records the curb weights we sourced by hand where the catalog was missing them.
- `data/hev-models-by-body.csv` holds aggregate counts of HEV nameplates by year and body type from the catalog, used for one appendix-style figure.

Anyone with a copy of the catalog can rebuild the pairs by following `methodology.md`.

## Data

### `data/matched.csv`

One row per HEV–ICE pair (715 rows). Prices are nominal model-year dollars.

| Column | Description |
| --- | --- |
| `pair_id` | Sequential row identifier |
| `year` | Model year |
| `make`, `model` | Nameplate, after the renamings in `methodology.md` |
| `trim_hyb`, `trim_ice` | Source trim names of the HEV and its ICE match |
| `body_type_hyb` | Body type (identical for both sides by construction) |
| `msrp_hyb`, `msrp_ice` | Base MSRP |
| `hp_hyb`, `hp_ice` | Rated horsepower |
| `mpg_combined_hyb`, `mpg_combined_ice` | EPA combined MPG |
| `curb_weight_hyb`, `curb_weight_ice` | Curb weight (lb); blank where it could not be sourced |

Some pairs share both trim names and differ only in drive (e.g. FWD and AWD) or truck bed length, which is why a year–model–trim combination can appear more than once.

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

| Paper output | Script | File |
| --- | --- | --- |
| Nameplate timeline | `nameplate-timeline.R` | `output/nameplate_timeline.pdf` |
| Premium vs. horsepower difference | `premium-hpdiff.R` | `output/premium_hpdiff.pdf` |
| Premium path, matched pairs and nameplate means | `premium-path.R` | `output/premium_path_observations.pdf`, `output/premium_path_nameplates.pdf` |
| Yearly mean premiums table | `premium-path-means.R` | `output/tables/tab-premium-path-means.tex` |
| Selected nameplate paths | `nameplate-path.R` | `output/premium_nameplate_paths.pdf` |
| Year fixed effects table and adjusted path | `premium-path-fe.R` | `output/tables/tab-year-fe.tex`, `output/premium_path_nameplates_fe.pdf` |
| Premium vs. ICE price table and figure | `premium-by-ice-price-cr.R` | `output/tables/tab-cr-ice-price.tex`, `output/premium_by_ice_price.pdf` |
| HEV sales share and premium | `hev-quarterly-sales.R` | `output/hev_quarterly_sales.pdf` |
| Fuel economy gaps | `fuel-gaps.R` | `output/fuel_gaps.pdf` |
| Performance gaps | `perf-gaps.R` | `output/perf_gaps.pdf` |
| HEV models by body type | `hev-models-by-body.R` | `output/hev_models_by_body.pdf` |
| Appendix: match-level tables | `appendix-match-level.R` | `output/tables/tab-year-fe-matches.tex`, `output/tables/tab-cr-ice-price-matches.tex` |

Shared code lives in `R/`: `analysis_window.R` (model-year range), `build_analysis_sample.R` (CPI inflation and analysis columns), and `path_helpers.R` (nameplate–year collapsing, fixed-effect paths, plot theme).

## License

Code is released under the MIT License (see `LICENSE`). The data files we created (`matched.csv` as a compilation, `curb-weight-corrections.csv`, `hev-models-by-body.csv`, and `methodology.md`) are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The Argonne files are public data from Argonne National Laboratory.
