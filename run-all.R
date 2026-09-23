# Rebuild the analysis sample and every figure and table in the paper.
# Run from the repository root: Rscript run-all.R

scripts <- c(
    "nameplate-timeline.R",
    "premium-hpdiff.R",
    "premium-path.R",
    "premium-path-means.R",
    "trim-paths.R",
    "premium-path-fe.R",
    "premium-by-ice-price.R",
    "hev-quarterly-sales.R",
    "fuel-gaps.R",
    "perf-gaps.R",
    "hev-models-by-body.R"
)

suppressPackageStartupMessages(library(dplyr))
source(file.path("R", "build_analysis_sample.R"))
invisible(build_analysis_sample())

for (s in scripts) {
    cat("Running", s, "\n")
    source(s, local = new.env())
}
