# tests/test-analysis.R
# Structural tests for the CMC analysis pipeline

source("analysis.R", local = TRUE)

stopifnot(
  "22 outputs produced"             = length(OUTPUTS) == 22L,
  "f2 is positive"                  = OUTPUTS$f2 > 0,
  "f2 CI lower < f2"                = OUTPUTS$f2_ci_lo < OUTPUTS$f2,
  "f2 CI upper > f2"                = OUTPUTS$f2_ci_hi > OUTPUTS$f2,
  "LTS slope is negative"           = OUTPUTS$lts_slope < 0,
  "INT slope is negative"           = OUTPUTS$int_slope < 0,
  "ACC slope is negative"           = OUTPUTS$acc_slope < 0,
  "ACC degrades faster than LTS"    = OUTPUTS$acc_slope < OUTPUTS$lts_slope,
  "Linearity R² is high"            = OUTPUTS$lin_r_squared > 0.99,
  "Repeatability CV is reasonable"  = OUTPUTS$repeat_cv > 0 & OUTPUTS$repeat_cv < 10,
  "IP CV is reasonable"             = OUTPUTS$ip_cv >= 0 & OUTPUTS$ip_cv < 10,
  "Recovery values are reasonable"  = all(c(OUTPUTS$acc_80pct,
                                             OUTPUTS$acc_100pct,
                                             OUTPUTS$acc_120pct) > 80 &
                                           c(OUTPUTS$acc_80pct,
                                             OUTPUTS$acc_100pct,
                                             OUTPUTS$acc_120pct) < 120)
)

cat("All tests passed.\n")