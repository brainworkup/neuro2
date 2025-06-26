# Script to run the test workflow for neuropsychological report generation
# This script demonstrates the workflow for processing neuropsychological data
# and generating a forensic report for a test patient named Biggie

# Load required libraries
library(here)

# Load R6 class definitions
source("R/ReportTemplateR6.R")
source("R/NeuropsychResultsR6.R")
source("R/NeuropsychReportSystemR6.R")
source("R/IQReportGeneratorR6.R")
source("R/DomainProcessorR6.R")

# Source the test workflow script
source("test_workflow.R")

# The test_workflow.R script performs the following steps:
# 1. Imports and processes individual CSV files from data-raw to generate neurocog and neurobehav datasets
# 2. Sets up patient information (Biggie, 44-year-old male)
# 3. Creates a neuropsych report system with forensic template
# 4. Processes each cognitive domain (IQ, verbal, spatial, memory, executive, ADHD, emotion)
# 5. Generates domain-specific QMD files
# 6. Creates the template report
# 7. Renders the complete report

# To run this demonstration:
# 1. Ensure all CSV files are present in the data-raw directory
# 2. Ensure the template files are present in inst/extdata/_extensions/neurotyp-forensic
# 3. Run this script: source("run_test_workflow.R")

# Expected output:
# - Processed data files in data directory
# - Domain-specific QMD files
# - Complete report in output/Biggie_Neuropsych_Report.pdf

# Note: This is a demonstration workflow. In practice, you would need to:
# - Ensure proper data cleaning and preprocessing
# - Customize domain processors for specific test batteries
# - Adjust template content for the specific case
# - Review and edit the generated text files before final rendering

message("Starting neuropsychological report generation workflow...")
message("This demonstration will process test data for patient: Biggie")
message("Using template: forensic")
message("See test_workflow.R for detailed implementation")

# The workflow execution is handled by sourcing test_workflow.R above
# To monitor progress, check the console for messages during execution

message("Workflow execution complete.")
message(
  "Check the output directory for the generated report: output/Biggie_Neuropsych_Report.pdf"
)
