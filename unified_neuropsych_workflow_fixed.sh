#!/bin/bash

# Unified Neuropsychology Workflow - FIXED VERSION
# Prevents multiple executions and adds debugging

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get patient name from command line
PATIENT_NAME="${1:-TEST_PATIENT}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Neuropsych Workflow${NC}"
echo -e "${GREEN}Patient: $PATIENT_NAME${NC}"
echo -e "${GREEN}Time: $(date)${NC}"
echo -e "${GREEN}========================================${NC}"

# Create a lock file to prevent multiple simultaneous runs
LOCKFILE="/tmp/neuropsych_workflow.lock"
if [ -f "$LOCKFILE" ]; then
    echo -e "${RED}ERROR: Workflow is already running!${NC}"
    echo -e "${RED}If this is a mistake, remove: $LOCKFILE${NC}"
    exit 1
fi
trap "rm -f $LOCKFILE" EXIT
touch "$LOCKFILE"

# Step 1: Clean previous outputs (optional)
echo -e "\n${YELLOW}Step 1: Cleaning previous outputs...${NC}"
if [ -d "figs" ]; then
    rm -f figs/*.png figs/*.pdf figs/*.svg 2>/dev/null || true
fi
if [ -d "output" ]; then
    rm -f output/*.pdf output/*.html 2>/dev/null || true
fi

# Step 2: Run the R workflow ONCE
echo -e "\n${YELLOW}Step 2: Running R domain processor...${NC}"
Rscript --vanilla -e "
  set.seed(123)

  # Source the workflow runner
  tryCatch({
    source('inst/scripts/main_workflow_runner.R')

    # Run workflow with patient name
    run_neuropsych_workflow(
      patient_name = '$PATIENT_NAME',
      generate_qmd = TRUE,
      render_report = FALSE  # Don't render here
    )

    cat('\nDomain processing complete!\n')
  }, error = function(e) {
    cat('\nERROR in R workflow:', conditionMessage(e), '\n')
    quit(status = 1)
  })
"

# Check if R script succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}R workflow failed!${NC}"
    exit 1
fi

# Step 3: Render the Quarto document ONCE
echo -e "\n${YELLOW}Step 3: Rendering Quarto document...${NC}"

# Check if template.qmd exists
if [ ! -f "template.qmd" ]; then
    echo -e "${RED}ERROR: template.qmd not found!${NC}"
    exit 1
fi

# Render with explicit parameters to prevent re-execution
quarto render template.qmd \
  --execute-params "patient:$PATIENT_NAME" \
  --cache-refresh \
  --quiet \
  --output-dir output

# Check if render succeeded
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Workflow completed successfully!${NC}"
    echo -e "${GREEN}Output: output/template.pdf${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}Quarto render failed!${NC}"
    exit 1
fi

# Optional: Open the PDF
if command -v open &> /dev/null; then
    open output/template.pdf
fi
