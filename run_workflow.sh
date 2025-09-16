#!/bin/bash
# Wrapper script for neuropsych workflow - works with Fish shell

# Set patient name (default to Ethan from config)
PATIENT="${1:-Ethan}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NEUROPSYCH WORKFLOW RUNNER${NC}"
echo -e "${GREEN}Patient: $PATIENT${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for R
if ! command_exists Rscript; then
    if [ -f "/usr/local/bin/Rscript" ]; then
        echo -e "${YELLOW}Using R from /usr/local/bin${NC}"
        RSCRIPT="/usr/local/bin/Rscript"
    else
        echo -e "${RED}ERROR: Rscript not found in PATH${NC}"
        echo "Please install R or add it to your PATH"
        exit 1
    fi
else
    RSCRIPT="Rscript"
fi

# Check for Quarto
if ! command_exists quarto; then
    echo -e "${RED}WARNING: Quarto not found in PATH${NC}"
    echo "The workflow may fail at the rendering step"
    echo "Install from: https://quarto.org/docs/get-started/"
fi

# Check which workflow script to use
if [ -f "complete_neuropsych_workflow_fixed_v3.R" ]; then
    WORKFLOW_SCRIPT="complete_neuropsych_workflow_fixed_v3.R"
    echo -e "${GREEN}Using fixed workflow v3${NC}"
elif [ -f "complete_neuropsych_workflow.R" ]; then
    WORKFLOW_SCRIPT="complete_neuropsych_workflow.R"
    echo -e "${YELLOW}Using original workflow${NC}"
else
    echo -e "${RED}ERROR: No workflow script found${NC}"
    exit 1
fi

# Create necessary directories
echo -e "\n${YELLOW}Creating directories...${NC}"
mkdir -p data data-raw/csv figs output logs

# Run diagnostics first (if available)
if [ -f "diagnose_quarto_issue.R" ]; then
    echo -e "\n${YELLOW}Running diagnostics...${NC}"
    $RSCRIPT diagnose_quarto_issue.R > logs/diagnostics.log 2>&1
    
    # Check if diagnostics found issues
    if grep -q "ISSUES FOUND" logs/diagnostics.log; then
        echo -e "${YELLOW}Diagnostics found issues - see logs/diagnostics.log${NC}"
        echo "Continue anyway? (y/n)"
        read -r response
        if [ "$response" != "y" ]; then
            exit 1
        fi
    fi
fi

# Run the workflow
echo -e "\n${GREEN}Running workflow...${NC}"
$RSCRIPT "$WORKFLOW_SCRIPT" "$PATIENT"

# Check if successful
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Workflow completed successfully!${NC}"
    
    # Try to find and open the output
    if [ -f "output/template.pdf" ]; then
        echo -e "${GREEN}Output: output/template.pdf${NC}"
        if command_exists open; then
            open output/template.pdf
        fi
    elif [ -f "output/template.html" ]; then
        echo -e "${GREEN}Output: output/template.html${NC}"
        if command_exists open; then
            open output/template.html
        fi
    fi
else
    echo -e "\n${RED}❌ Workflow failed${NC}"
    echo -e "${YELLOW}Check the latest log file in logs/${NC}"
    
    # Show last few lines of most recent log
    LATEST_LOG=$(ls -t logs/workflow_*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo -e "\n${YELLOW}Last 10 lines of $LATEST_LOG:${NC}"
        tail -10 "$LATEST_LOG"
    fi
    
    echo -e "\n${YELLOW}Try running the diagnostic script:${NC}"
    echo "  Rscript diagnose_quarto_issue.R"
    
    exit 1
fi
