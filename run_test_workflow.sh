#!/bin/bash

# Script to test the parquet/DuckDB workflow with patient data

echo "================================================"
echo "Testing Neuropsych Domain Generation Workflow"
echo "================================================"
echo ""

# Check if raw CSV files exist
echo "Checking for raw CSV files in data-raw/csv/..."
if [ -d "data-raw/csv" ] && [ "$(ls -A data-raw/csv/*.csv 2>/dev/null)" ]; then
    echo "✓ Found CSV files:"
    ls -la data-raw/csv/*.csv
else
    echo "✗ No CSV files found in data-raw/csv/"
    echo "Please add patient CSV files to data-raw/csv/ directory"
    exit 1
fi

echo ""
echo "Running the parquet workflow test..."
echo "================================================"

# Run the R script
Rscript test_domain_workflow_parquet.R

echo ""
echo "================================================"
echo "Test complete!"
echo ""
echo "Check the following outputs:"
echo "1. Processed data files in data/"
echo "   - neurocog.parquet (cognitive test data)"
echo "   - neurobehav.parquet (behavioral data)"
echo "   - validity.parquet (validity measures)"
echo ""
echo "2. Generated domain files:"
echo "   - _02-03_verbal.qmd (or similar based on your data)"
echo "   - _02-03_verbal_text.qmd"
echo ""
echo "3. Generated visualizations:"
echo "   - table_verbal_parquet.png/pdf"
echo "   - test_verbal_dotplot.svg"
echo ""
echo "To use the parquet workflow in production:"
echo "1. Update domain .qmd files to use the parquet loading method"
echo "2. See _02-03_verbal_parquet.qmd for an example"
echo "================================================"
