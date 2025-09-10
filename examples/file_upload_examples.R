#!/usr/bin/env Rscript

# Example File Upload Script for neuro2
# This script demonstrates different ways to upload files to the neuro2 system

# Load the neuro2 package
library(neuro2)

cat("🧠 neuro2 File Upload Examples\n")
cat("==============================\n\n")

# Example 1: Check if system is ready for file uploads
cat("📋 Checking upload requirements...\n")
check_upload_requirements()

cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

# Example 2: List available PDF templates
cat("📄 Available PDF extraction templates:\n")
available_templates <- list_pdf_templates()

cat("\n", paste(rep("=", 50), collapse = ""), "\n\n")

# Example 3: Interactive file upload demo
cat("💡 File Upload Examples\n")
cat("=====================\n\n")

cat("Example 1: Interactive upload\n")
cat('upload_files(method = "interactive")\n\n')

cat("Example 2: CSV upload\n")
cat('upload_files(\n')
cat('  method = "csv",\n')
cat('  file_path = "path/to/your/data.csv",\n')
cat('  patient_name = "John Doe"\n')
cat(')\n\n')

cat("Example 3: PDF extraction\n")
cat('upload_files(\n')
cat('  method = "pdf",\n')
cat('  test_type = "wisc5",\n')
cat('  patient_name = "Jane Smith"\n')
cat(')\n\n')

cat("Example 4: Quick upload (simplified)\n")
cat('quick_upload("Patient Name")\n\n')

cat("Example 5: Upload and run workflow automatically\n")
cat('upload_files(\n')
cat('  method = "csv",\n')
cat('  file_path = "data.csv",\n')
cat('  patient_name = "Patient Name",\n')
cat('  run_workflow = TRUE\n')
cat(')\n\n')

# Example 4: Show directory structure needed
cat("📁 Required Directory Structure\n")
cat("===============================\n")
cat("./\n")
cat("├── data-raw/\n")
cat("│   └── csv/          # Place your CSV files here\n")
cat("├── data/             # Processed data files (auto-created)\n")
cat("├── output/           # Generated reports (auto-created)\n")
cat("├── R/                # R6 class files\n")
cat("└── inst/\n")
cat("    └── rmarkdown/\n")
cat("        └── templates/\n")
cat("            └── pluck_pdfs/\n")
cat("                └── skeleton/   # PDF extraction templates\n\n")

# Example 5: Common workflow
cat("🚀 Common Workflow\n")
cat("==================\n")
cat("1. Check requirements: check_upload_requirements()\n")
cat("2. Upload files: upload_files(method = 'interactive')\n")
cat("3. Run workflow: ./unified_neuropsych_workflow.sh 'Patient Name'\n")
cat("4. Review report: template.pdf\n\n")

cat("📚 For more detailed information, see:\n")
cat("   - FILE_UPLOAD_GUIDE.md\n")
cat("   - README.md\n")
cat("   - UNIFIED_WORKFLOW_README.md\n\n")

cat("✨ Happy uploading! ✨\n")