# Demo dataset — Clinical Trial Snapshot

Synthetic data designed to exercise every signal the Data Overview analysis surfaces. 80 hypothetical participants in a Phase II trial.

## Files

- `clinical-trial.csv` — the data (no variable descriptions).
- `clinical-trial.omv` — same data with descriptions + measure types preserved. Only generated if `jmvReadWrite` is installed when you run the generator script.

## Regenerate

From the repo root:

```bash
Rscript scripts/generate-demo-data.R
```

To also produce the `.omv`:

```r
install.packages("jmvReadWrite")
```

then re-run the generator.

## What's in it (and why)

| Variable | Type | Reason it's here |
|---|---|---|
| `patient_id` | Nominal | **Triggers "looks like identifier"** — every row unique. |
| `age` | Continuous | Roughly normal distribution. |
| `sex` | Nominal | Balanced two-level. |
| `treatment` | Nominal | Three balanced levels (Drug A / Drug B / Placebo). |
| `severity` | Ordinal | Three ordered levels. |
| `weight_kg` | Continuous | Normal-ish, decimal values. |
| `anxiety_pre` | Continuous | **Triggers Likert-like** — integer values, range 1–7. |
| `anxiety_post` | Continuous | Likert-like, lower for Drug A. |
| `improvement` | Continuous | **Triggers bimodal-suggesting** — Drug A clumps high, others near zero. |
| `country` | Nominal | Five levels, imbalanced (US dominates). |
| `notes` | Nominal | **Triggers >20% missing** — ~80% blank. |
| `study_phase` | Nominal | **Triggers single-level** — all "Phase II". |
| `total_visits` | Continuous | **Triggers constant continuous** — always 4. |

Open the file in jamovi → Analyses → Exploration → jglance → Data Overview to see the dashboard in action.
