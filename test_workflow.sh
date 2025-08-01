#!/bin/bash

# Non-interactive test version of the workflow
# This script runs the workflow without prompting for user input

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
echo "🧠 NEUROPSYCHOLOGICAL REPORT GENERATION WORKFLOW (TEST MODE)"
echo "==========================================================="
echo -e "${NC}"

# Set patient name
PATIENT_NAME="Ethan"
echo "Patient: $PATIENT_NAME"
echo

# Check for data directories
print_step "Step 1: Checking for data directories..."
mkdir -p data-raw/csv
mkdir -p data
mkdir -p output
print_success "Data directories created/verified"

# Check for CSV files
print_step "Step 2: Checking for CSV files..."
csv_count=$(find data-raw/csv -name "*.csv" | wc -l)
print_success "Found $csv_count CSV files in data-raw/csv/"
find data-raw/csv -name "*.csv" -exec basename {} \; | sed 's/^/   - /'

# Update config file with patient name
print_step "Step 3: Updating configuration..."
CONFIG_FILE="config.yml"
if [ -f "$CONFIG_FILE" ]; then
    awk -v patient_name="$PATIENT_NAME" '
    BEGIN { in_patient = 0; patient_updated = 0; }
    /^patient:/ { in_patient = 1; print "patient:"; patient_updated = 1; next; }
    /^  name:/ && in_patient { print "  name: \"" patient_name "\""; next; }
    /^[a-z]/ && in_patient { in_patient = 0; }
    { print; }
    END { if (!patient_updated) print "patient:\n  name: \"" patient_name "\"\n  age: 35\n  doe: \"" strftime("%Y-%m-%d") "\""; }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    print_success "Updated patient name in $CONFIG_FILE"
fi

# Skip PDF extraction
print_step "Step 4: PDF Data Extraction"
print_warning "Skipping PDF extraction (test mode)"

# Run the unified workflow
print_step "Step 5: Running unified workflow..."
./unified_workflow_runner.R "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    print_success "Workflow completed successfully!"
else
    print_error "Workflow failed"
    exit 1
fi

# Skip manual summary
print_step "Step 6: Manual Summary and Recommendations"
print_warning "Skipping manual summary (test mode)"

# Final report rendering
print_step "Step 7: Rendering Final PDF Report"

if ! command -v quarto &> /dev/null; then
    print_error "Quarto not found."
    exit 1
fi

# Try to render the report
if quarto render template.qmd; then
    print_success "Report generated successfully!"
else
    print_error "Report rendering failed"
    echo "Checking for generated files anyway..."
fi

# Check for generated output files
echo
echo "Checking generated files:"
echo "========================"

if [ -f "template.pdf" ]; then
    print_success "PDF report generated: template.pdf"
elif [ -f "template.typ" ]; then
    print_warning "Typst file generated: template.typ (PDF compilation may be pending)"
fi

# Check for table and figure files
echo
echo "Domain assets:"
for domain in iq academics verbal spatial memory executive motor; do
    if [ -f "table_${domain}.png" ]; then
        print_success "table_${domain}.png"
    else
        print_error "table_${domain}.png missing"
    fi
    if [ -f "fig_${domain}_subdomain.svg" ]; then
        print_success "fig_${domain}_subdomain.svg"
    else
        print_error "fig_${domain}_subdomain.svg missing"
    fi
done

echo
print_success "TEST WORKFLOW COMPLETE!"