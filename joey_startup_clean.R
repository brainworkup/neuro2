# joey_startup_clean.R - Pure R code only
patient_name <- "Biggie"

# Function to run the workflow
run_workflow <- function(patient = patient_name) {
  source("inst/scripts/00_complete_neuropsych_workflow.R")
  run_neuropsych_workflow(
    patient = patient,
    generate_qmd = TRUE,
    render_report = TRUE
  )
}

cat("Neuropsych workflow ready. Use run_workflow() to start.\n")
