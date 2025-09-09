# neuro2 Template Workflow

## Daily flow
1. `git checkout main && git pull`
2. `git checkout -b feature/<short-name>`
3. Make small, focused changes; commit early/often.
4. Open a PR to `main`; use squash merge when ready.

## Branch protection (recommended)
- Require PR to merge into `main`.
- Prefer squash merges to keep history clean.
- Avoid committing generated files (see `.gitignore`).

## Creating a new patient repo
- Use the template:
  ```
  gh repo create <PATIENT> --template brainworkup/neuro2 --private --clone
  ```
- Optionally copy `.gitignore.patient` into the new repo if you want aggressive ignoring of data and exports.

## Sharing improvements back
- If you find a generalizable improvement while working in a patient repo, redo
  it in a `feature/` branch in the template repo and open a PR there.
