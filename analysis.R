# =============================================================================
# CMC Statistics Analysis — reproducr-cmc
#
# Study:   Chemistry, Manufacturing and Controls (CMC) statistical package
#          for a simulated immediate-release tablet formulation
#
# Analyses:
#   1. Dissolution profile comparison — f2 similarity factor (ICH Q1E)
#   2. Stability analysis — shelf-life estimation (ICH Q1E linear regression)
#   3. Assay method validation — linearity, precision, accuracy
#
# Author:  Ndoh Penn
# Repo:    https://github.com/repro-stats/reproducr-cmc
# =============================================================================

set.seed(2026L)

# ---- 0. Dependencies --------------------------------------------------------

library(nlme)
library(boot)

# ---- 1. Dissolution profile comparison (f2 similarity factor) ---------------
#
# ICH Q1B / Q4B Annex 7: f2 = 50 * log10( 100 / sqrt(1 + mean((R - T)^2)) )
# Acceptance: f2 >= 50 indicates similarity between reference and test profiles
# Conditions: only first time point > 85% dissolution is included;
#             one formulation must have <= 85% at all but last time point.

# Simulated dissolution profiles — 6 time points (15, 30, 45, 60, 75, 90 min)
time_points <- c(15, 30, 45, 60, 75, 90)
n_vessels   <- 12L   # per arm

# Reference product (innovator)
ref_mean <- c(24, 52, 74, 87, 93, 97)
ref_sd   <- c(3.2, 4.1, 3.8, 3.0, 2.5, 1.8)

# Test product (generic / new batch)
test_mean <- c(22, 50, 71, 85, 92, 96)
test_sd   <- c(3.5, 4.3, 4.0, 3.2, 2.7, 1.9)

ref_profiles  <- mapply(stats::rnorm, n = n_vessels,
                        mean = ref_mean, sd = ref_sd)
test_profiles <- mapply(stats::rnorm, n = n_vessels,
                        mean = test_mean, sd = test_sd)

ref_mean_obs  <- colMeans(ref_profiles)
test_mean_obs <- colMeans(test_profiles)
ref_cv        <- apply(ref_profiles, 2, stats::sd) / ref_mean_obs * 100

cat("--- Dissolution profiles (mean % dissolved) ---\n")
dissolution_tab <- data.frame(
  time    = time_points,
  ref     = round(ref_mean_obs, 1),
  test    = round(test_mean_obs, 1),
  ref_cv  = round(ref_cv, 1)
)
print(dissolution_tab, row.names = FALSE)

# ICH Q1B condition: CV at first time point <= 20%, others <= 10%
cv_ok <- all(ref_cv[-1] <= 10) && ref_cv[1] <= 20
cat(sprintf("\nCV condition met: %s\n", ifelse(cv_ok, "YES", "NO")))

# f2 calculation
.f2 <- function(R, T) {
  diffs <- (R - T)^2
  50 * log10(100 / sqrt(1 + mean(diffs)))
}

f2_obs <- .f2(ref_mean_obs, test_mean_obs)
cat(sprintf("f2 similarity factor: %.2f (acceptance >= 50)\n", f2_obs))
cat(sprintf("Dissolution profiles: %s\n",
            ifelse(f2_obs >= 50, "SIMILAR", "NOT SIMILAR")))

# Bootstrap 90% CI for f2 — resample vessels within each arm
set.seed(2026L)
f2_boot_vals <- replicate(1000L, {
  ref_b  <- ref_profiles[sample(n_vessels, replace = TRUE), ]
  test_b <- test_profiles[sample(n_vessels, replace = TRUE), ]
  .f2(colMeans(ref_b), colMeans(test_b))
})
f2_ci <- stats::quantile(f2_boot_vals, c(0.05, 0.95))

cat(sprintf("f2 90%% CI (bootstrap): %.2f - %.2f\n",
            f2_ci[1], f2_ci[2]))

# ---- 2. Stability analysis — shelf-life estimation (ICH Q1E) ----------------
#
# ICH Q1E: linear regression of assay (% label claim) vs time
# Shelf-life = time when 95% one-sided LCL crosses acceptance limit (90% LC)
# Three storage conditions: 25°C/60% RH (LTS), 30°C/65% RH, 40°C/75% RH (AS)

conditions <- list(
  LTS = list(label = "25°C/60%RH (Long-term)",   slope_true = -0.15, n_tp = 5L),
  INT = list(label = "30°C/65%RH (Intermediate)", slope_true = -0.25, n_tp = 4L),
  ACC = list(label = "40°C/75%RH (Accelerated)",  slope_true = -0.55, n_tp = 3L)
)

time_months <- list(
  LTS = c(0, 3, 6, 12, 24),
  INT = c(0, 3, 6, 12),
  ACC = c(0, 1, 3, 6)
)

initial_assay <- 100.2   # % label claim at T=0

stability_results <- lapply(names(conditions), function(cond) {
  cond_info <- conditions[[cond]]
  tp        <- time_months[[cond]]
  n_reps    <- 3L

  # Simulate assay values
  assay_vals <- sapply(tp, function(t) {
    stats::rnorm(n_reps,
                 mean = initial_assay + cond_info$slope_true * t,
                 sd   = 1.2)
  })

  # ICH Q1E: use mean of replicates per time point
  assay_mean <- colMeans(assay_vals)

  stability_df <- data.frame(
    time  = tp,
    assay = assay_mean
  )

  # Linear regression
  fit   <- stats::lm(assay ~ time, data = stability_df)
  slope <- stats::coef(fit)["time"]
  intercept <- stats::coef(fit)["(Intercept)"]

  # 95% one-sided lower confidence limit at each time
  pred   <- stats::predict(fit, newdata = data.frame(time = tp),
                            interval = "confidence", level = 0.95)
  lcl    <- pred[, "lwr"]

  # Shelf-life: time when LCL crosses 90% LC
  # Solve: intercept + slope * t - t_se * qt(0.05, df) = 90
  # Numerically: find crossing point
  t_seq  <- seq(0, 60, by = 0.1)
  pred_t <- stats::predict(fit, newdata = data.frame(time = t_seq),
                            interval = "confidence", level = 0.95)
  lcl_t  <- pred_t[, "lwr"]

  # Shelf-life = last time LCL >= 90
  cross_idx <- which(lcl_t < 90)
  shelf_life <- if (length(cross_idx) == 0) {
    ">60 months"
  } else {
    sprintf("%.1f months", t_seq[cross_idx[1] - 1L])
  }

  cat(sprintf("\n%s (%s)\n", cond, cond_info$label))
  cat(sprintf("  Slope: %.3f %%LC/month (95%% CI: %.3f to %.3f)\n",
              slope,
              stats::confint(fit)["time", 1],
              stats::confint(fit)["time", 2]))
  cat(sprintf("  Estimated shelf-life: %s\n", shelf_life))

  list(
    condition  = cond,
    slope      = round(slope, 4),
    intercept  = round(intercept, 3),
    slope_lcl  = round(stats::confint(fit)["time", 1], 4),
    slope_ucl  = round(stats::confint(fit)["time", 2], 4),
    shelf_life = shelf_life,
    r_squared  = round(summary(fit)$r.squared, 4)
  )
})

names(stability_results) <- names(conditions)

# ---- 3. Assay method validation ---------------------------------------------
#
# ICH Q2(R1): linearity, precision (repeatability + intermediate),
#             accuracy (recovery)

# Linearity — 5 concentration levels, 3 replicates each (50–150% of target)
conc_levels <- c(50, 75, 100, 125, 150)   # % of target concentration (200 µg/mL)
n_reps_val  <- 3L
true_slope  <- 0.0182   # mAU per µg/mL
true_inter  <- 0.85     # mAU

lin_data <- do.call(rbind, lapply(conc_levels, function(c) {
  conc_actual <- c * 2    # µg/mL
  response    <- stats::rnorm(n_reps_val,
                              mean = true_inter + true_slope * conc_actual,
                              sd   = 0.018)
  data.frame(conc_pct = c, conc_ugml = conc_actual, response = response)
}))

lin_fit    <- stats::lm(response ~ conc_ugml, data = lin_data)
lin_r2     <- summary(lin_fit)$r.squared
lin_slope  <- stats::coef(lin_fit)["conc_ugml"]
lin_inter  <- stats::coef(lin_fit)["(Intercept)"]

cat(sprintf("\n--- Assay method validation ---\n"))
cat(sprintf("Linearity: R² = %.6f, slope = %.5f, intercept = %.4f\n",
            lin_r2, lin_slope, lin_inter))
cat(sprintf("Linearity acceptance (R² >= 0.999): %s\n",
            ifelse(lin_r2 >= 0.999, "PASS", "FAIL")))

# Precision — repeatability (6 replicates at 100%)
repeat_vals <- stats::rnorm(6L,
                            mean = true_inter + true_slope * 200,
                            sd   = 0.015)
repeat_cv   <- stats::sd(repeat_vals) / mean(repeat_vals) * 100
cat(sprintf("Repeatability CV: %.2f%% (acceptance <= 2%%): %s\n",
            repeat_cv, ifelse(repeat_cv <= 2, "PASS", "FAIL")))

# Intermediate precision — 3 days, 2 analysts, 3 reps each
ip_data <- data.frame(
  day     = rep(1:3, each = 6L),
  analyst = rep(rep(1:2, each = 3L), 3L),
  value   = stats::rnorm(18L,
                         mean = true_inter + true_slope * 200,
                         sd   = 0.020)
)

ip_model <- nlme::lme(value ~ 1,
                      random = ~ 1 | day,
                      data   = ip_data,
                      method = "REML")

# Extract variance components — between-day and residual
ip_vc       <- nlme::VarCorr(ip_model)
ip_sd       <- as.numeric(ip_vc[1, "StdDev"])    # between-day SD
resid_sd    <- as.numeric(ip_vc[2, "StdDev"])    # residual SD
ip_total_sd <- sqrt(ip_sd^2 + resid_sd^2)        # total SD
ip_cv       <- ip_total_sd / mean(ip_data$value) * 100
cat(sprintf("Intermediate precision CV: %.2f%% (acceptance <= 3%%): %s\n",
            ip_cv, ifelse(ip_cv <= 3, "PASS", "FAIL")))

# Accuracy — recovery at 3 levels (80%, 100%, 120%)
acc_levels   <- c(80, 100, 120)
acc_recovery <- sapply(acc_levels, function(pct) {
  conc   <- pct * 2   # µg/mL
  meas   <- stats::rnorm(3L,
                         mean = true_inter + true_slope * conc,
                         sd   = 0.015)
  # Back-calculate concentration and express as % recovery
  conc_back <- (mean(meas) - lin_inter) / lin_slope
  conc_back / conc * 100
})

cat("Accuracy (% recovery):\n")
for (i in seq_along(acc_levels)) {
  cat(sprintf("  %d%% level: %.2f%% (acceptance 98-102%%): %s\n",
              acc_levels[i], acc_recovery[i],
              ifelse(acc_recovery[i] >= 98 & acc_recovery[i] <= 102,
                     "PASS", "FAIL")))
}

# ---- 4. Collect outputs for certification -----------------------------------

OUTPUTS <- list(
  # Dissolution
  f2                  = round(f2_obs, 4),
  f2_ci_lo            = round(f2_ci[[1]], 4),
  f2_ci_hi            = round(f2_ci[[2]], 4),
  dissolution_similar = f2_obs >= 50,
  f2_boot_sd          = round(stats::sd(f2_boot_vals), 4),

  # Stability — LTS
  lts_slope           = stability_results$LTS$slope,
  lts_slope_lcl       = stability_results$LTS$slope_lcl,
  lts_r_squared       = stability_results$LTS$r_squared,

  # Stability — INT
  int_slope           = stability_results$INT$slope,
  int_slope_lcl       = stability_results$INT$slope_lcl,
  int_r_squared       = stability_results$INT$r_squared,

  # Stability — ACC
  acc_slope           = stability_results$ACC$slope,
  acc_slope_lcl       = stability_results$ACC$slope_lcl,
  acc_r_squared       = stability_results$ACC$r_squared,

  # Method validation
  lin_r_squared       = round(lin_r2, 6),
  lin_slope           = round(lin_slope, 6),
  lin_intercept       = round(lin_inter, 4),
  repeat_cv           = round(repeat_cv, 4),
  ip_cv               = round(ip_cv, 4),
  acc_80pct           = round(acc_recovery[1], 4),
  acc_100pct          = round(acc_recovery[2], 4),
  acc_120pct          = round(acc_recovery[3], 4)
)

cat(sprintf("\n%d outputs ready for certification.\n", length(OUTPUTS)))