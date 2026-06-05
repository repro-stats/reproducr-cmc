# reproducr-cmc <a href="https://repro-stats.github.io/reproducr/"><img src="https://raw.githubusercontent.com/repro-stats/reproducr/main/man/figures/logo.svg" align="right" height="120" alt="reproducr website" /></a>

<!-- badges: start -->
[![reproducibility](https://img.shields.io/badge/reproducibility-caution-yellow)](https://repro-stats.github.io/reproducr/)
[![R-CMD-check](https://github.com/repro-stats/reproducr-cmc/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/repro-stats/reproducr-cmc/actions/workflows/R-CMD-check.yml)
<!-- badges: end -->

> End-to-end `reproducr` pipeline for a simulated CMC statistical package —
> dissolution f2, ICH Q1E stability shelf-life, and ICH Q2(R1) assay method
> validation. `renv` environment locking, pharma-style QC report.

| | |
|---|---|
| **Domain** | Chemistry, Manufacturing and Controls (CMC) |
| **Analyses** | Dissolution f2, stability, assay method validation |
| **Regulatory framework** | ICH Q1B, ICH Q1E, ICH Q2(R1) |
| **Environment** | renv — locked environment |
| **Report style** | pharma |
| **Outputs certified** | 20 |
| **Audience** | CMC statisticians, analytical chemists, regulatory affairs |

See the full walkthrough: [DEMO.md](DEMO.md)

---

## Study overview

A simulated CMC statistical package for an immediate-release tablet
formulation, covering three standard regulatory analyses:

**1. Dissolution profile comparison (ICH Q1B / Q4B Annex 7)**
- f2 similarity factor comparing reference and test dissolution profiles
- 6 time points (15–90 min), 12 vessels per arm
- Bootstrap 90% CI for f2
- Acceptance: f2 ≥ 50

**2. Stability analysis (ICH Q1E)**
- Linear regression of assay (% label claim) vs time
- Three storage conditions: LTS (25°C/60%RH), INT (30°C/65%RH), ACC (40°C/75%RH)
- Shelf-life estimated where 95% one-sided LCL crosses 90% LC acceptance limit

**3. Assay method validation (ICH Q2(R1))**
- Linearity: 5 concentration levels (50–150%), R² ≥ 0.999
- Repeatability: 6 replicates at 100%, CV ≤ 2%
- Intermediate precision: mixed model (nlme), CV ≤ 3%
- Accuracy: % recovery at 80%, 100%, 120% levels (98–102%)

---

## Key results (simulated data)

**Dissolution:**

| Metric | Value | Acceptance |
|---|---|---|
| f2 similarity factor | — | ≥ 50 |
| f2 90% CI (bootstrap) | — | — |

**Stability slopes (%LC/month):**

| Condition | Slope | 95% LCL |
|---|---|---|
| LTS (25°C/60%RH) | — | — |
| INT (30°C/65%RH) | — | — |
| ACC (40°C/75%RH) | — | — |

**Method validation:**

| Test | Result | Acceptance |
|---|---|---|
| Linearity R² | — | ≥ 0.999 |
| Repeatability CV | — | ≤ 2% |
| Intermediate precision CV | — | ≤ 3% |

*Results populated by CI on each run — see `.reproducr.rds` for certified values.*

---

## Why CMC analyses need reproducibility tooling

CMC analyses feed directly into regulatory submissions (CTD Module 3 / NDA /
ANDA). Silent breaking changes in statistical packages are especially
consequential here because:

1. **Regulatory precedent** — results in a submission are compared against
   reanalysis during review. Any numerical difference requires explanation.

2. **Long timelines** — a stability programme may span 5 years from IND to
   NDA. Package upgrades over that period are inevitable.

3. **Method transfers** — the same analysis may be run at multiple sites (lab,
   CRO, sponsor). Locale differences and package version differences can
   produce different shelf-life estimates.

4. **`nlme` sensitivity** — `lme()` optimizer tolerance and default REML
   settings have changed across versions. Intermediate precision estimates
   are sensitive to these changes.

`reproducr` flags these risks at the call level and certifies the outputs so
any numerical change between runs is immediately visible.

---

## Running locally

```r
# Clone the repo, then:
renv::restore()
source("analysis.R")

library(reproducr)
report <- audit_script("analysis.R", renv = TRUE)
risks  <- risk_score(report)
print(risks)
```

---

## CI/CD

| Workflow | Purpose |
|---|---|
| `R-CMD-check.yml` | Restore renv, run structural tests |
| `reproducr-audit.yml` | Audit, certify, detect drift, update badge |

---

## Part of the reproducr gallery

| Example | Domain | renv | Report style |
|---|---|---|---|
| [reproducr-ecology](https://github.com/repro-stats/reproducr-ecology) | Ecology / penguins | No | minimal |
| [reproducr-clinical](https://github.com/repro-stats/reproducr-clinical) | Clinical trials / oncology | Yes | pharma |
| [reproducr-rwe](https://github.com/repro-stats/reproducr-rwe) | Real world evidence | Yes | academic |
| **reproducr-cmc** (this repo) | CMC statistics | Yes | pharma |
