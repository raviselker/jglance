#!/usr/bin/env Rscript
#
# Generates a demo dataset for the jglance Data Overview analysis.
# The dataset is designed to exercise every signal the overview surfaces:
#
#   - Continuous variables (normal-ish, right-skewed, bimodal)
#   - Likert-scale variables (integer, narrow range)
#   - Nominal + ordinal categoricals
#   - An ID-like variable (every row unique → "looks like identifier")
#   - A single-level nominal (→ "only one level")
#   - A constant continuous (→ "constant")
#   - A high-missing variable (→ ">20% missing")
#   - All variables carry descriptions (visible in the detail panel)
#
# Output:
#   demo/clinical-trial.csv  — always (data only, no descriptions)
#   demo/clinical-trial.omv  — if jmvReadWrite is installed (descriptions + measure types preserved)

set.seed(42)
N <- 80

# ---------- variables ----------

patient_id  <- sprintf("P%04d", 1001:(1000 + N))                 # id-like
age         <- pmax(18, pmin(80, round(rnorm(N, 50, 12))))       # roughly normal
sex         <- factor(sample(c("F", "M"), N, replace = TRUE, prob = c(0.55, 0.45)))
treatment   <- factor(sample(c("Drug A", "Drug B", "Placebo"), N, replace = TRUE))
severity    <- factor(
    sample(c("Mild", "Moderate", "Severe"), N, replace = TRUE,
           prob = c(0.25, 0.5, 0.25)),
    levels = c("Mild", "Moderate", "Severe"),
    ordered = TRUE
)
weight_kg   <- round(pmax(45, pmin(130, rnorm(N, 75, 15))), 1)

# anxiety scored 1–7 (Likert-detect target)
anxiety_pre  <- pmax(1, pmin(7, round(rgamma(N, shape = 3, rate = 0.7))))
delta        <- ifelse(treatment == "Drug A",
                       round(rnorm(N, 2.2, 0.8)),
                       round(rnorm(N, 0.3, 0.9)))
anxiety_post <- pmax(1, pmin(7, anxiety_pre - delta))

# bimodal-detect target: Drug A clumps high, others near 0
improvement  <- anxiety_pre - anxiety_post

country     <- factor(sample(c("US", "UK", "Germany", "France", "Italy"), N, replace = TRUE,
                              prob = c(0.4, 0.2, 0.15, 0.15, 0.1)))

# ~85% NA → triggers high-missing issue
notes_pool  <- c(rep(NA_character_, 18),
                 "completed all sessions", "missed follow-up",
                 "reported mild headache", "no comments", "extra session requested")
notes       <- factor(sample(notes_pool, N, replace = TRUE))

# single-level → triggers issue
study_phase <- factor(rep("Phase II", N))

# constant continuous → triggers issue
total_visits <- rep(4L, N)

df <- data.frame(
    patient_id   = patient_id,
    age          = age,
    sex          = sex,
    treatment    = treatment,
    severity     = severity,
    weight_kg    = weight_kg,
    anxiety_pre  = anxiety_pre,
    anxiety_post = anxiety_post,
    improvement  = improvement,
    country      = country,
    notes        = notes,
    study_phase  = study_phase,
    total_visits = total_visits,
    stringsAsFactors = FALSE
)

# ---------- descriptions (jamovi reads these via attr 'jmv-desc') ----------

descriptions <- list(
    patient_id   = "Unique anonymised participant identifier.",
    age          = "Participant age in years at enrollment.",
    sex          = "Participant self-reported sex.",
    treatment    = "Randomised treatment arm assignment.",
    severity     = "Baseline symptom severity (clinician-rated).",
    weight_kg    = "Body weight in kilograms at baseline.",
    anxiety_pre  = "Pre-treatment anxiety score (1 = none, 7 = severe).",
    anxiety_post = "Post-treatment anxiety score (1 = none, 7 = severe).",
    improvement  = "Reduction in anxiety score (pre minus post). Positive = improvement.",
    country      = "Study site country.",
    notes        = "Free-text clinician notes; mostly blank.",
    study_phase  = "Clinical trial phase (constant for this study).",
    total_visits = "Number of scheduled clinic visits (fixed protocol)."
)

for (name in names(descriptions))
    attr(df[[name]], "jmv-desc") <- descriptions[[name]]

# ---------- write outputs ----------
# Run from the repo root: `Rscript scripts/generate-demo-data.R`

out_dir <- "demo"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

csv_path <- file.path(out_dir, "clinical-trial.csv")
write.csv(df, csv_path, row.names = FALSE, na = "")
cat("Wrote", csv_path, "\n")

if (requireNamespace("jmvReadWrite", quietly = TRUE)) {
    omv_path <- file.path(out_dir, "clinical-trial.omv")
    jmvReadWrite::write_omv(dtaFrm = df, fleOut = omv_path)
    cat("Wrote", omv_path, "(with descriptions preserved)\n")
} else {
    cat("\n", strrep("-", 60), "\n", sep = "")
    cat("Note: install the 'jmvReadWrite' package to also produce an .omv\n")
    cat("      file with variable descriptions baked in:\n")
    cat("        install.packages('jmvReadWrite')\n")
    cat(strrep("-", 60), "\n", sep = "")
}
