#!/bin/bash

# 
# 

set -e  # Exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}"
echo "🧠 NEUROPSYCHOLOGICAL REPORT GENERATION WORKFLOW"
echo "================================================="
echo -e "${NC}"

if [ -n "$1" ]; then
    PATIENT_NAME="$1"
else
    read -p "Enter patient name: " PATIENT_NAME
fi

echo "Patient: $PATIENT_NAME"
echo

print_step "Step 1: PDF Data Extraction"
echo "Available extraction templates:"
echo "  - pluck_wisc5.Rmd (WISC-V Intelligence)"
echo "  - pluck_wais5.Rmd (WAIS-V Adult Intelligence)" 
echo "  - pluck_rbans.Rmd (RBANS Memory)"
echo "  - pluck_wiat4.Rmd (WIAT-4 Achievement)"
echo "  - pluck_ktea3.Rmd (KTEA-3 Achievement)"
echo "  - pluck_caars2.Rmd (CAARS-2 ADHD)"
echo "  - And more in inst/rmarkdown/templates/pluck_pdfs/skeleton/"
echo

read -p "Do you want to run PDF extraction templates? (y/n): " run_extraction

if [[ $run_extraction =~ ^[Yy]$ ]]; then
    print_warning "Manual step required:"
    echo "1. Open appropriate .Rmd template in inst/rmarkdown/templates/pluck_pdfs/skeleton/"
    echo "2. Update patient name in params section"
    echo "3. Run file.choose() to select PDF"
    echo "4. Knit the document to generate CSV files"
    echo "5. Move generated CSV files to data-raw/csv/"
    echo
    read -p "Press Enter when PDF extraction is complete..."
else
    print_warning "Skipping PDF extraction - ensure CSV files are in data-raw/csv/"
fi

print_step "Step 2: Checking CSV Files"

mkdir -p data-raw/csv

csv_count=$(find data-raw/csv -name "*.csv" | wc -l)

if [ $csv_count -eq 0 ]; then
    print_error "No CSV files found in data-raw/csv/"
    echo "Please add your test data CSV files to data-raw/csv/ directory"
    exit 1
else
    print_success "Found $csv_count CSV files in data-raw/csv/"
    find data-raw/csv -name "*.csv" -exec basename {} \; | sed 's/^/   - /'
fi

print_step "Step 3: Processing Data (CSV → Parquet conversion)"

mkdir -p data

if [ -f "R/duckdb_neuropsych_loader.R" ]; then
    print_step "Running DuckDB data processing..."
    Rscript -e "
    source('R/duckdb_neuropsych_loader.R')
    
    load_data_duckdb(
      file_path = 'data-raw/csv',
      output_dir = 'data',
      return_data = FALSE,
      use_duckdb = TRUE,
      output_format = 'all'  # Generate CSV, Parquet, and Arrow formats
    )
    cat('✓ Data processing complete\n')
    "
    
    print_step "Adding score ranges to processed data..."
    Rscript -e "
    if (file.exists('R/pdf.R')) source('R/pdf.R')
    
    data_files <- list.files('data', pattern = '\\.csv$', full.names = TRUE)
    
    for (file in data_files) {
      cat('Adding ranges to', basename(file), '...\n')
      data <- read.csv(file, stringsAsFactors = FALSE)
      
      if ('percentile' %in% colnames(data)) {
        if (exists('gpluck_make_score_ranges')) {
          data <- gpluck_make_score_ranges(data, test_type = 'npsych_test')
        } else {
          library(dplyr)
          data <- data %>% mutate(
            range = case_when(
              percentile >= 98 ~ 'Exceptionally High',
              percentile >= 91 & percentile <= 97 ~ 'Above Average',
              percentile >= 75 & percentile <= 90 ~ 'High Average', 
              percentile >= 25 & percentile <= 74 ~ 'Average',
              percentile >= 9 & percentile <= 24 ~ 'Low Average',
              percentile >= 2 & percentile <= 8 ~ 'Below Average',
              percentile < 2 ~ 'Exceptionally Low',
              TRUE ~ NA_character_
            )
          )
        }
        write.csv(data, file, row.names = FALSE)
      }
    }
    cat('Score ranges added successfully\n')
    "
    
    print_success "Data processing complete"
    
    echo "Generated datasets:"
    find data -name "*.csv" -exec basename {} \; | sed 's/^/   📊 /'
    find data -name "*.parquet" -exec basename {} \; | sed 's/^/   📊 /'
    
else
    print_warning "DuckDB loader not found, using new_patient_workflow.R fallback..."
    
    if [ -f "new_patient_workflow.R" ]; then
        print_step "Running new patient workflow..."
        Rscript new_patient_workflow.R
        print_success "New patient workflow complete"
    else
        print_error "Neither DuckDB loader nor new_patient_workflow.R found"
        exit 1
    fi
fi

print_step "Step 4: Checking Patient Information"

if [ ! -f "_variables.yml" ]; then
    print_error "_variables.yml not found"
    echo "Please create _variables.yml with patient information"
    exit 1
else
    print_success "Patient information found in _variables.yml"
    Rscript -e "
    library(yaml)
    patient_info <- read_yaml('_variables.yml')
    cat('Patient:', patient_info\$patient, '\n')
    if (!is.null(patient_info\$age)) cat('Age:', patient_info\$age, '\n')
    if (!is.null(patient_info\$doe)) cat('DOE:', patient_info\$doe, '\n')
    "
fi

print_step "Step 5: Generating Domain Files with R6 Classes"

if [ -f "neuro2_r6_update_workflow.R" ]; then
    print_step "Running R6 workflow (recommended)..."
    Rscript neuro2_r6_update_workflow.R
    print_success "R6 workflow complete"
elif [ -f "test_domain_workflow_parquet.R" ]; then
    print_step "Running parquet domain workflow (comprehensive test)..."
    Rscript test_domain_workflow_parquet.R
    print_success "Parquet domain workflow complete"
elif [ -f "neuro2_duckdb_workflow.R" ]; then
    print_step "Running DuckDB workflow..."
    Rscript neuro2_duckdb_workflow.R
    print_success "DuckDB workflow complete"
else
    print_warning "No workflow script found"
    print_step "Running basic domain processing..."
    
    Rscript -e "
    if (file.exists('R/NeuropsychReportSystemR6.R')) {
      source('R/NeuropsychReportSystemR6.R')
      
      report_system <- NeuropsychReportSystemR6\$new(
        config = list(
          patient = '$PATIENT_NAME',
          data_files = list(neurocog = 'data/neurocog.csv')
        )
      )
      
      report_system\$run_workflow()
      cat('Basic domain processing complete\n')
    } else {
      cat('R6 classes not found, skipping domain generation\n')
    }
    "
fi

domain_files=$(find . -name "_02-*_*.qmd" | wc -l)
if [ $domain_files -gt 0 ]; then
    print_success "Generated $domain_files domain files:"
    find . -name "_02-*_*.qmd" -exec basename {} \; | sed 's/^/   📝 /'
else
    print_warning "No domain files generated"
fi

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

print_step "Step 7: Rendering Final PDF Report"

if [ ! -f "template.qmd" ]; then
    print_error "template.qmd not found"
    exit 1
fi

if ! command -v quarto &> /dev/null; then
    print_error "Quarto not found. Please install Quarto to render the final report."
    echo "Visit: https://quarto.org/docs/get-started/"
    exit 1
fi

print_step "Rendering PDF with Typst..."

if quarto render template.qmd --to typst-pdf; then
    print_success "PDF report generated successfully!"
    
    if [ -f "template.pdf" ]; then
        echo "📄 Final report: template.pdf"
    fi
else
    print_warning "PDF rendering failed, trying HTML format..."
    
    if quarto render template.qmd --to html; then
        print_success "HTML report generated successfully!"
        
        if [ -f "template.html" ]; then
            echo "🌐 Final report: template.html"
        fi
    else
        print_error "Report rendering failed"
        echo "Please check template.qmd for errors"
    fi
fi

echo
echo "================================================="
print_success "WORKFLOW COMPLETE! 🎉"
echo

echo "Generated files:"
if [ -d "data" ]; then
    find data -type f -exec basename {} \; | sed 's/^/   📊 /'
fi

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
echo "4. Customize as needed and re-run: quarto render template.qmd"

echo
print_success "Happy reporting! ✨"
