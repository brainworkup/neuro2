#!/bin/bash
# Wrapper script for neuropsych workflow that handles Fish shell PATH issues

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

# Find R installation
find_r_installation() {
    # Try multiple methods to find R
    local r_paths=(
        "/usr/local/bin/Rscript"
        "/usr/bin/Rscript"
        "/opt/homebrew/bin/Rscript"  # Apple Silicon Macs
        "$(which Rscript 2>/dev/null)"
        "$(command -v Rscript 2>/dev/null)"
    )
    
    for path in "${r_paths[@]}"; do
        if [ -n "$path" ] && [ -f "$path" ] && [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try R.home method
    local r_home=$(R --slave -e 'cat(R.home("bin"))' 2>/dev/null)
    if [ -n "$r_home" ] && [ -f "$r_home/Rscript" ]; then
        echo "$r_home/Rscript"
        return 0
    fi
    
    return 1
}

# Find Rscript
RSCRIPT=$(find_r_installation)

if [ -z "$RSCRIPT" ]; then
    echo -e "${RED}ERROR: Could not find Rscript executable!${NC}"
    echo -e "${YELLOW}Please ensure R is installed and in your PATH${NC}"
    echo -e "${YELLOW}You can install R from: https://cran.r-project.org/${NC}"
    exit 1
fi

echo -e "${GREEN}Found Rscript at: $RSCRIPT${NC}"

# Check if workflow script exists
WORKFLOW_SCRIPT="complete_neuropsych_workflow_fixed_v2.R"

if [ ! -f "$WORKFLOW_SCRIPT" ]; then
    # Try the original name
    WORKFLOW_SCRIPT="complete_neuropsych_workflow_fixed.R"
fi

if [ ! -f "$WORKFLOW_SCRIPT" ]; then
    echo -e "${RED}ERROR: Workflow script not found!${NC}"
    echo -e "${YELLOW}Looking for: $WORKFLOW_SCRIPT${NC}"
    echo -e "${YELLOW}Current directory: $(pwd)${NC}"
    exit 1
fi

echo -e "${GREEN}Using workflow script: $WORKFLOW_SCRIPT${NC}"

# Create a lock file to prevent multiple simultaneous runs
LOCKFILE="/tmp/neuropsych_workflow.lock"
if [ -f "$LOCKFILE" ]; then
    echo -e "${YELLOW}WARNING: Workflow may already be running!${NC}"
    echo -e "${YELLOW}Lock file exists: $LOCKFILE${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    rm -f "$LOCKFILE"
fi

# Set up trap to remove lock file on exit
trap "rm -f $LOCKFILE" EXIT
touch "$LOCKFILE"

# Run the workflow with explicit PATH
echo -e "\n${YELLOW}Running R workflow...${NC}"

# Export PATH to include common R locations
export PATH="/usr/local/bin:/usr/bin:/opt/homebrew/bin:$PATH"

# Run the workflow
"$RSCRIPT" --vanilla "$WORKFLOW_SCRIPT" "$PATIENT_NAME"

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Workflow completed successfully!${NC}"
    
    # Check if PDF was created
    if [ -f "output/template.pdf" ]; then
        echo -e "${GREEN}Report: output/template.pdf${NC}"
        
        # Try to open the PDF (macOS)
        if command -v open &> /dev/null; then
            echo -e "${YELLOW}Opening PDF...${NC}"
            open "output/template.pdf"
        fi
    fi
    
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}Workflow failed!${NC}"
    echo -e "${RED}Check the output above for errors${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
