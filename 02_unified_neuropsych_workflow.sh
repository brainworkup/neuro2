#!/bin/bash

# UNIFIED NEUROPSYCHOLOGICAL WORKFLOW SHELL SCRIPT
# Shell script entry point for the neuropsychological report generation workflow
# This script provides an interactive command-line interface and calls the unified_workflow_runner.R

set -e  # Exit on any error

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions for colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Print header
echo -e "${BLUE}"
echo "🧠 NEUROPSYCHOLOGICAL REPORT GENERATION WORKFLOW"
echo "================================================="
echo -e "${NC}"

# Check if config file exists
CONFIG_FILE="config.yml"
if [ -f "$CONFIG_FILE" ]; then
    echo "Using existing configuration file: $CONFIG_FILE"
else
    echo "Configuration file not found. It will be created with default settings."
fi

# Get patient name
if [ -n "$1" ]; then
    PATIENT_NAME="$1"
else
    read -p "Enter patient name: " PATIENT_NAME
fi

echo "Patient: $PATIENT_NAME"
echo

# Check if R is installed
if ! command -v Rscript &> /dev/null; then
    print_error "R is not installed or not in PATH"
    echo "Please install R to run this workflow"
    exit 1
fi

# Check if unified_workflow_runner.R exists
if [ ! -f "unified_workflow_runner.R" ]; then
    print_error "unified_workflow_runner.R not found"
    echo "Please ensure the unified workflow runner script is in the current directory"
    exit 1
fi

# Make the R script executable
chmod +x unified_workflow_runner.R

# Check for data directories
print_step "Step 1: Checking for data directories..."

mkdir -p data-raw/csv
mkdir -p data
mkdir -p output

print_success "Data directories created/verified"

# Check for CSV files
print_step "Step 2: Checking for CSV files..."

csv_count=$(find data-raw/csv -name "*.csv" | wc -l)

if [ $csv_count -eq 0 ]; then
    print_warning "No CSV files found in data-raw/csv/"
    echo "Please add your test data CSV files to data-raw/csv/ directory"

    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Found $csv_count CSV files in data-raw/csv/"
    find data-raw/csv -name "*.csv" -exec basename {} \; | sed 's/^/   - /'
fi

# Update config file with patient name
print_step "Step 3: Updating configuration..."

# Create a temporary file with patient information
TMP_CONFIG=$(mktemp)
cat > $TMP_CONFIG << EOF
patient:
  name: "$PATIENT_NAME"
  age: 35
  doe: "$(date +%Y-%m-%d)"
EOF

# If config file exists, update it; otherwise the R script will create it
if [ -f "$CONFIG_FILE" ]; then
    # Use awk to update just the patient section
    awk -v patient_name="$PATIENT_NAME" '
    BEGIN { in_patient = 0; patient_updated = 0; }
    /^patient:/ { in_patient = 1; print "patient:"; patient_updated = 1; next; }
    /^  name:/ && in_patient { print "  name: \"" patient_name "\""; next; }
    /^[a-z]/ && in_patient { in_patient = 0; }
    { print; }
    END { if (!patient_updated) print "patient:\n  name: \"" patient_name "\"\n  age: 35\n  doe: \"" strftime("%Y-%m-%d") "\""; }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    print_success "Updated patient name in $CONFIG_FILE"
else
    # R script will create the config file
    print_warning "$CONFIG_FILE will be created by the R script"
fi

# Ask about PDF extraction
# print_step "Step 4: PDF Data Extraction"
# echo "Available extraction templates:"
# echo "  - pluck_wisc5.Rmd (WISC-V Child Intelligence)"
# echo "  - pluck_wais5.Rmd (WAIS-5 Adult Intelligence)"
# echo "  - pluck_rbans.Rmd (RBANS)"
# echo "  - pluck_wiat4.Rmd (WIAT-4 Achievement)"
# echo "  - pluck_ktea3.Rmd (KTEA-3 Achievement)"
# echo "  - pluck_caars2.Rmd (CAARS-2 ADHD)"
# echo "  - And more in inst/rmarkdown/templates/pluck_pdfs/skeleton/"
# echo

# read -p "Do you want to run PDF extraction templates? (y/n): " run_extraction

# if [[ $run_extraction =~ ^[Yy]$ ]]; then
#     print_warning "Manual step required:"
#     echo "1. Open appropriate .Rmd template in inst/rmarkdown/templates/pluck_pdfs/skeleton/"
#     echo "2. Update patient name in params section"
#     echo "3. Run file.choose() to select PDF"
#     echo "4. Knit the document to generate CSV files"
#     echo "5. Move generated CSV files to data-raw/csv/"
#     echo
#     read -p "Press Enter when PDF extraction is complete..."
# else
#     print_warning "Skipping PDF extraction - ensure CSV files are in data-raw/csv/"
# fi

# Run the unified workflow
print_step "Step 5: Running unified workflow..."

# Execute the R script
./unified_workflow_runner.R "$CONFIG_FILE"

# Check if the workflow was successful
if [ $? -eq 0 ]; then
    print_success "Workflow completed successfully!"
else
    print_error "Workflow failed"
    echo "Check workflow.log for details"
    exit 1
fi

# Check for template.qmd
if [ ! -f "template.qmd" ]; then
    print_warning "template.qmd not found"
    echo "You may need to create or update the template file"
else
    print_success "template.qmd found"
fi

# Manual summary and recommendations
print_step "Step 6: Manual Summary and Recommendations"
print_warning "MANUAL STEP REQUIRED:"
echo "Please add your clinical summary and recommendations to template.qmd"
echo "Sections to complete:"
echo "  - Clinical summary and interpretation"
echo "  - Diagnostic impressions"
echo "  - Recommendations for treatment/intervention"
echo "  - Follow-up suggestions"
echo

read -p "Press Enter when manual summary is complete..."

# Final report rendering
print_step "Step 7: Rendering Final PDF Report"

if ! command -v quarto &> /dev/null; then
    print_error "Quarto not found. Please install Quarto to render the final report."
    echo "Visit: https://quarto.org/docs/get-started/"
    exit 1
fi

# Get format from config.yml if it exists, otherwise use default
if [ -f "$CONFIG_FILE" ]; then
    REPORT_FORMAT=$(grep -A 5 "^report:" "$CONFIG_FILE" | grep "format:" | awk '{print $2}' | tr -d '"')
    if [ -n "$REPORT_FORMAT" ]; then
        print_step "Rendering with format: $REPORT_FORMAT"
    fi
fi

# If no format found in config, let Quarto use the default from _quarto.yml
if [ -n "$REPORT_FORMAT" ]; then
    if quarto render template.qmd --to "$REPORT_FORMAT"; then
        print_success "Report generated successfully!"
    else
        print_error "Report rendering failed with format: $REPORT_FORMAT"
        echo "Please check template.qmd for errors"
    fi
else
    # Use default format from _quarto.yml
    print_step "Rendering with default format from _quarto.yml..."

    if quarto render template.qmd; then
        print_success "Report generated successfully!"
    else
        print_error "Report rendering failed"
        echo "Please check template.qmd for errors"
    fi
fi

# Check for generated output files
if [ -f "template.pdf" ]; then
    echo "📄 Final report: template.pdf"
elif [ -f "template.html" ]; then
    echo "🌐 Final report: template.html"
elif [ -f "template.typ" ]; then
    echo "📝 Typst file generated: template.typ"
    echo "Note: You may need to compile the .typ file separately if PDF generation didn't complete"
fi

echo
echo "================================================="
print_success "WORKFLOW COMPLETE! 🎉"
echo

echo "Generated files:"
if [ -d "data" ]; then
    find data -type f -exec basename {} \; | sed 's/^/   📊 /'
fi

domain_files=$(find . -name "_02-*_*.qmd" | wc -l)
if [ $domain_files -gt 0 ]; then
    echo
    echo "Generated domain sections:"
    find . -name "_02-*_*.qmd" -exec basename {} \; | sed 's/^/   📝 /'
fi

echo
if [ -f "template.pdf" ]; then
    echo "🎯 Final report: template.pdf"
elif [ -f "template.html" ]; then
    echo "🎯 Final report: template.html"
fi

echo
echo "Next steps:"
echo "1. Review generated domain files (_02-XX_*.qmd)"
echo "2. Check data files in data/ directory"
echo "3. Open final report for review"
echo "4. Customize as needed and re-run: ./unified_neuropsych_workflow.sh"

echo
print_success "Happy reporting! ✨"
