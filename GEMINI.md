# Gemini Instructions for `jglance`

A jamovi module rendering an interactive **Data Overview** analysis. R6 analysis (R) on the backend, Vue 3 + Vite (TypeScript) on the frontend, integrated via jamovi's `Html` results element.

## Tech Stack
- **Backend:** R (R6, jmvcore, jsonlite)
- **Frontend:** Vue 3, Vite, TypeScript, Vanilla CSS
- **Integration:** UMD bundle (`inst/jglance.umd.js`) injected into jamovi `Html` elements

## Key Commands

### Development & Build
- `cd client && npm run dev`: Local UI development with fixture data (Vite dev server).
- `./scripts/format.sh`: Formats R code (air) and client code (prettier).
- `./scripts/build-and-install.sh`: Full build (client + R) and installation into jamovi.
- `./scripts/install-module.sh`: R-only installation (yaml + R code changes).
- `Rscript scripts/generate-demo-data.R`: Regenerate demo datasets in `demo/`.

### Validation
- `cd client && npm run build`: Runs `vue-tsc` (type check) and `vite build`. **Always run before shipping.**
- Full integration check: Run `./scripts/build-and-install.sh` and verify in jamovi.

## Architecture & Bridge
The module uses the "besoplots" technique:
1. R6 class (`R/overview.b.R`) computes data and serializes to JSON using `jsonlite::toJSON`.
2. It returns an `Html` results item with `scripts` set to `jglance.umd.js`.
3. The R code injects a bootstrap `<script>` that calls `window.Jglance.createOverview()`.
4. It also injects a `<link>` tag for `jglance.css`.
5. Vue mounts inside a placeholder `<div>`.

## Conventions

### CSS & Styling
- **Root Class:** Every analysis root must have `class="jglance jglance--<analysisName>"`.
- **Tokens:** Design tokens are in `client/src/tokens.css` under the `.jglance` scope.
- **Responsive:** Design for ~500px width (jamovi's results column limit).
- **Themes:** Use `[data-theme='dark']` for theming; ignore `prefers-color-scheme`.

### Naming & Types
- **Files:** `kebab-case.vue` for components, `snake_case.R` for R files.
- **Interfaces:** Prefix with `I` (e.g., `IVariableSummary`).
- **Variable Types:** Use the taxonomy in `client/src/common.ts` (`continuous`, `nominal`, `ordinal`, `id`).

## Critical Gotchas

1. **YAML Compiler Mode:** Set `compilerMode: tame` in `.u.yaml` once hand-customized to prevent overwriting.
2. **JSON Unboxing:** Use `I()` in R for arrays that might have length 1 (e.g., `counts = I(as.integer(h$counts))`) to prevent `jsonlite` from unboxing them into scalars.
3. **JSON Nulls:** Pass `null = "null"` to `jsonlite::toJSON` to ensure R `NULL` becomes JS `null`, not `{}`.
4. **R6 Nested Assignment:** Use local variables when assigning to nested results items (e.g., `item <- self$results$item; item$scripts <- ...`).
5. **Factor Order:** Always respect `levels(v)` order for nominal/ordinal variables; do NOT sort by count.
6. **ID Columns:** Ensure `permitted: [numeric, factor, id]` is set in both `.a.yaml` and `.u.yaml` (on both `VariableSupplier` and `VariablesListBox`).

## Workflow Mandates

1. **Research First:** Always check both R and JS sides when modifying data flow.
2. **Reproduce:** Use `npm run dev` for UI issues or the demo dataset in jamovi for R/integration issues.
3. **Surgical Edits:** Maintain existing BEM-ish CSS patterns and TypeScript interfaces.
## Committing

- **Small logical commits** — break changes into small, focused commits with a single purpose.
- **Commit title** — a single sentence in imperative mood, max 50 characters, no trailing dot, no type prefixes (e.g. no "feat:", "fix:").
- **Optional description** — only to clarify functional choices (the "what" and "why"). Do not explain the "how" or anything already evident from the diff. Max line length 72 characters.
- **No AI mentions** — never mention AI assistants or tools in commit messages.
- **Propose first** — always propose a draft commit message for the user to approve before committing.
