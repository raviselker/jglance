# jglance

> *Glance at jamovi data — a scannable overview of every variable, with auto-detected data-quality notes and one-click drill-down.*

A jamovi module that adds a **Data Overview** analysis: load a dataset, open the analysis, and see in one screen what's in there — how many variables of each type, how complete the data is, what's worth looking at, and a per-variable summary with sparkline, distribution shape, and quartile ticks.

## What it shows

- **Summary strip** — total rows, variable count broken down by measure type, overall completeness.
- **Worth a Look** — auto-detected callouts for high-missing columns, single-level categoricals, constant continuous columns, and identifier-like columns. Variable names are clickable; click to expand that row.
- **Variable list** — one row per variable: type indicator, name, type label, sparkline, missing %. Hover a sparkline for a larger preview. Click a row to expand the detail panel inline.
- **Detail panel** — type-dispatched:
  - **Continuous** → italic headline ("right-skewed, range 10.4–33.9, no missing"), histogram with Q1/median/Q3 ticks, 6-stat grid (mean / SD / median / min / max / missing).
  - **Categorical (nominal / ordinal)** → horizontal level-count bars in *factor-defined order* (critical for ordinal), levels / mode / missing.
  - **ID** → sample-tag grid + unique/observed/missing.
- **Search** — fuzzy name + description filter.
- **Sort** — original / name / type / missing %; when sorted by type, mini section headers split the list.
- **Expand all / Collapse all** — toggle every visible variable at once.

## Install

```bash
git clone <repo>
cd jglance
./scripts/build-and-install.sh
```

That builds the Vite client bundle into `inst/`, then runs `jmvtools::install()` to install the module into your local jamovi library. **Restart jamovi** to pick up changes.

Prereqs:
- R with `jmvtools`, `jmvcore`, `R6`, `jsonlite` installed
- Node.js + npm
- jamovi 2.7.14 or newer

The first time, also run `cd client && npm install` to fetch the JS dependencies.

## Try it

A demo dataset is in `demo/`:
- `clinical-trial.omv` — open in jamovi to see all 80 rows × 13 variables with descriptions preserved (requires the demo was generated with `jmvReadWrite`).
- `clinical-trial.csv` — plain CSV fallback.

Open the file, navigate to **Analyses → Exploration → jglance → Data Overview**. The dataset is deliberately constructed to trip every signal — Worth-a-Look should highlight ~3 issues; `improvement` should be flagged as bimodal-suggesting; `anxiety_pre`/`anxiety_post` as Likert-like; `severity` shows in ordinal level order.

To regenerate the demo:
```bash
Rscript scripts/generate-demo-data.R
```

## Develop

Iterate on the UI without round-tripping through jamovi:
```bash
cd client
npm run dev    # http://localhost:5173 — Vite dev server with fixture data
```

Full integration test (after R or yaml changes):
```bash
./scripts/build-and-install.sh
# restart jamovi
```

See [`CLAUDE.md`](./CLAUDE.md) for the project layout, conventions, and gotchas accumulated while building this thing.

## Architecture in one paragraph

A jamovi `Html` results element loads a UMD bundle (`inst/jglance.umd.js`) built from a Vue 3 + TypeScript project under `client/`. The R6 analysis class computes per-variable summaries, serializes them to JSON, and injects a small bootstrap script that mounts the Vue app inside a placeholder div. Shared state (selection, filter, sort) lives in a `sessionStorage`-backed store so it survives jamovi's re-renders. The technique was pulled from [`jamovi/besoplots@laiton`](https://github.com/jamovi/besoplots/tree/laiton).

## License

AGPL-3
