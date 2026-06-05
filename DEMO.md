# DEMO — reproducr-cmc walkthrough

This document walks through the complete `reproducr` pipeline applied to a
CMC statistical package for a simulated immediate-release tablet formulation,
covering three regulatory analyses under ICH Q1B, Q1E, and Q2(R1).

---

## Study context

**Product:** Simulated immediate-release tablet, 200 mg target strength

**Analyses:**
1. Dissolution profile comparison (f2 similarity factor)
2. Stability shelf-life estimation (linear regression, ICH Q1E)
3. Assay method validation (linearity, precision, accuracy)

---

## Step 1 — Audit the analysis script

```r
library(reproducr)

report <- audit_script("analysis.R", renv = TRUE)
print(report)
```

```
-- reproducr audit report [2026-06-04 11:22] --

  Files scanned:     1
  Packages found:    2
  Calls detected:    28
  R version:         4.4.2
  Platform:          aarch64-apple-darwin20
  Versions from:     renv.lock

  Next step: risks <- risk_score(report)
```

---

## Step 2 — Score for risk

```r
risks <- risk_score(report)
print(risks)
```

```
-- reproducr risk score --

  HIGH:      0
  MEDIUM:    1
  LOW:       0

[MEDIUM] nlme::lme
         Check    : changelog
         Details  : Between lme4 1.1.29 and 1.1.30, default optimizer
                    tolerances were adjusted...
```

The intermediate precision model uses `nlme::lme()`. `reproducr` flags it
as medium risk — a version change in `nlme` could shift the optimizer
tolerance and produce slightly different variance component estimates,
changing the intermediate precision CV.

This is exactly the class of silent change that could produce a different
shelf-life or precision conclusion in a regulatory submission.

---

## Step 3 — Run the analysis

```r
source("analysis.R")
```

```
--- Dissolution profiles (mean % dissolved) ---
 time  ref test ref_cv
   15 24.1 22.3    3.1
   30 51.8 49.7    4.2
   45 73.9 71.2    3.9
   60 87.1 85.3    3.1
   75 93.2 92.1    2.6
   90 97.0 96.2    1.8

CV condition met: YES
f2 similarity factor: 72.34 (acceptance >= 50)
Dissolution profiles: SIMILAR
f2 90% CI (bootstrap): 68.21 - 76.15

25°C/60%RH (Long-term)
  Slope: -0.151 %LC/month (95% CI: -0.187 to -0.115)
  Estimated shelf-life: >60 months

30°C/65%RH (Intermediate)
  Slope: -0.248 %LC/month (95% CI: -0.312 to -0.184)
  Estimated shelf-life: 42.3 months

40°C/75%RH (Accelerated)
  Slope: -0.553 %LC/month (95% CI: -0.651 to -0.455)
  Estimated shelf-life: 17.8 months

--- Assay method validation ---
Linearity: R² = 0.999847, slope = 0.01821, intercept = 0.8482
Linearity acceptance (R² >= 0.999): PASS
Repeatability CV: 0.81% (acceptance <= 2%): PASS
Intermediate precision CV: 0.94% (acceptance <= 3%): PASS
Accuracy (% recovery):
   80% level: 99.72% (acceptance 98-102%): PASS
  100% level: 100.14% (acceptance 98-102%): PASS
  120% level: 99.88% (acceptance 98-102%): PASS

20 outputs ready for certification.
```

---

## Step 4 — Certify the outputs

```r
certify(
  outputs = OUTPUTS,
  tag     = "submission-v1",
  script  = "analysis.R"
)
```

```
reproducr: certified 20 output(s) [2026-06-04] under tag 'submission-v1'
```

---

## Step 5 — Check for drift

After a package upgrade or platform change:

```r
source("analysis.R")
check_drift(OUTPUTS, against = "submission-v1")
```

```
-- reproducr drift check vs 'submission-v1' --

  Verdict  : ALL OUTPUTS MATCH
  OK       : 20
  Drifted  : 0
```

---

## Step 6 — Generate the pharma QC report

```r
repro_report(
  report, risks,
  format      = "html",
  style       = "pharma",
  output_file = "qc_report.html"
)
```

The pharma report includes:
- Execution environment table (R version, platform, locale, timezone)
- Full package inventory with versions
- Risk register with changelog, seed, and locale checks
- Drift assessment vs last certified run
- Sign-off fields for analyst and reviewer

---

## Why this matters for CMC

A regulatory reviewer comparing your NDA submission results against an
independent reanalysis needs **exact numerical agreement**. Even a 0.01
%LC/month shift in a stability slope can change a shelf-life estimate by
several months.

`reproducr` provides:
- **Proactive risk flagging** — identifies packages with known silent breaking
  changes before the submission
- **Certified audit trail** — `.reproducr.rds` records what every run produced
- **Drift detection** — any numerical change between the original analysis and
  a reanalysis is immediately visible by name
- **Pharma QC report** — a structured document with sign-off fields suitable
  for inclusion in a validation package
