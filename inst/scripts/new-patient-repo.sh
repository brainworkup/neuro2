#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is required. Install from https://cli.github.com/."
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATIENT_ALIAS> [owner]"
  echo "Example: $0 Isabella            # creates neuro2-Isabella under your account"
  echo "         $0 Isabella brainworkup # creates brainworkup/neuro2-Isabella"
  exit 1
fi

PATIENT_ALIAS="$1"
OWNER="${2:-}"

# Basic slug: allow letters, numbers, hyphen/underscore; strip spaces
SLUG="$(echo "$PATIENT_ALIAS" | tr '[:space:]' '-' | tr -cd '[:alnum:]-_')"
REPO_NAME="neuro2-${SLUG}"

if [[ -n "$OWNER" ]]; then
  FULL_NAME="${OWNER}/${REPO_NAME}"
else
  FULL_NAME="${REPO_NAME}"
fi

echo "Creating private repository from template: ${FULL_NAME}"
gh repo create "${FULL_NAME}" \
  --template "brainworkup/neuro2" \
  --private \
  --disable-wiki \
  --description "Private neuropsych report workspace for ${PATIENT_ALIAS} (from neuro2 template)."

echo "Cloning ${FULL_NAME}..."
gh repo clone "${FULL_NAME}"

REPO_DIR="$(basename "${FULL_NAME}")"
cd "${REPO_DIR}"

# Optional: create a working branch to keep main clean
git checkout -b work

cat <<'EOF'

Next steps:
- You are on branch 'work'. Make edits and commit as you go.
- Do NOT add PHI to commit messages.
- Ensure your .gitignore is appropriate for patient data. You can copy .gitignore.patient from the template if needed.

EOF