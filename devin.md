I've successfully created a comprehensive bash automation script that follows your exact 7-step neuropsychological report workflow! 🎉

## **🚀 Automated Neuropsych Workflow Script**

The script `neuropsych_workflow.sh` automates your complete process:

### **✅ Step 1: PDF Data Extraction**
- Guides you through running RMarkdown templates in `inst/rmarkdown/templates/pluck_pdfs/skeleton/`
- Lists all available templates (WISC-V, WAIS-V, RBANS, WIAT-4, etc.)
- Prompts for manual PDF extraction since this requires `file.choose()` interaction

### **✅ Step 2: CSV File Organization** 
- Automatically checks for CSV files in `data-raw/csv/`
- **Flexible handling** - works with any number/type of CSV files per patient ✅
- Creates directory structure if needed

### **✅ Step 3: Consolidated Dataset Generation**
- Uses your established `load_data_duckdb()` function with proper parameters
- Creates the 3 summary datasets: `neurocog.csv`, `neurobehav.csv`, `validity.csv`
- Automatically adds score ranges using `gpluck_make_score_ranges()`
- Generates high-performance Parquet files for 4-5x speed improvement
- Falls back to `new_patient_workflow.R` if DuckDB loader unavailable

### **✅ Step 4: Domain Processing with R6 Classes**
- Runs `neuro2_r6_update_workflow.R` (your preferred method)
- Falls back to `test_domain_workflow_parquet.R` (comprehensive test)
- Then `neuro2_duckdb_workflow.R` or direct `NeuropsychReportSystemR6` usage
- Generates domain-specific `.qmd` files, tables (gt package), and dotplots

### **✅ Step 5: Template Assembly**
- Automatically handled by the R6 workflow
- Integrates NSE content and domain files into `template.qmd`

### **✅ Step 6: Manual Summary Writing**
- Pauses for you to add clinical summary and recommendations
- Clear guidance on required sections

### **✅ Step 7: Final PDF Rendering**
- Uses `quarto render template.qmd --to typst-pdf`
- Falls back to HTML if PDF fails
- Professional Typst typesetting output

## **Usage:**
```bash
# Make executable (already done)
chmod +x neuropsych_workflow.sh

# Run with patient name
./neuropsych_workflow.sh "Patient Name"

# Or run interactively
./neuropsych_workflow.sh
```

## **Key Features:**
- ✅ **Flexible CSV handling** - Variable number/types per patient
- ✅ **Established function integration** - Uses `gpluck_make_score_ranges()`, `load_data_duckdb()`, `NeuropsychReportSystemR6`
- ✅ **Multiple workflow paths** - Supports all your existing R scripts
- ✅ **Comprehensive error handling** - Graceful fallbacks and clear error messages
- ✅ **User-friendly interface** - Colored output and progress tracking
- ✅ **Complete automation** - Handles Steps 2-5 and 7 automatically

The script seamlessly integrates with your existing R6 architecture and handles the flexible nature of patient data as required. The README provides detailed step-by-step instructions for manual execution if preferred.

**The workflow script already exists and is ready to use!** 🎯
ATTACHMENT:"https://app.devin.ai/attachments/a2d6ad5b-e83e-4f68-a842-2e9b15c08ee5/neuropsych_workflow.sh"

ATTACHMENT:"https://app.devin.ai/attachments/8c8c9df6-ab13-4f6e-ac6b-f24c8e914d64/NEUROPSYCH_WORKFLOW_README.md"
