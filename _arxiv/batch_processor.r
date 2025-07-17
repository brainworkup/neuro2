# BATCH REPORT PROCESSOR
# Process multiple patient reports in sequence

# Function to process multiple patients
batch_process_reports <- function(patient_list, output_dir = "reports") {
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Track results
  results <- list()

  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║              BATCH REPORT PROCESSOR                          ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  cat("Processing", length(patient_list), "reports...\n\n")

  # Process each patient
  for (i in seq_along(patient_list)) {
    patient <- patient_list[[i]]

    cat(strrep("─", 60), "\n")
    cat("Patient", i, "of", length(patient_list), ":", patient$name, "\n")
    cat(strrep("─", 60), "\n")

    # Generate report
    tryCatch(
      {
        # Update config
        config <- list(
          patient = patient$name,
          first_name = patient$first_name %||%
            strsplit(patient$name, " ")[[1]][1],
          last_name = patient$last_name %||%
            tail(strsplit(patient$name, " ")[[1]], 1),
          age = patient$age,
          sex = patient$sex %||% "male",
          template_type = patient$template_type %||% "forensic",
          referral = patient$referral %||% "Referring Physician",
          extension_dir = "inst/extdata/_extensions",
          overwrite_templates = FALSE
        )

        # Save config
        assign("config", config, envir = .GlobalEnv)

        # Run workflow
        source("run_forensic_report.R")

        # Move output file
        if (file.exists("template.pdf")) {
          output_file <- file.path(
            output_dir,
            paste0(
              gsub(" ", "_", patient$name),
              "_report_",
              format(Sys.Date(), "%Y%m%d"),
              ".pdf"
            )
          )
          file.copy("template.pdf", output_file, overwrite = TRUE)

          results[[patient$name]] <- list(
            status = "Success",
            file = output_file
          )

          cat("✅ Report saved:", output_file, "\n\n")
        } else {
          results[[patient$name]] <- list(status = "Failed", file = NA)
          cat("❌ Report generation failed\n\n")
        }
      },
      error = function(e) {
        results[[patient$name]] <- list(
          status = "Error",
          file = NA,
          error = e$message
        )
        cat("❌ Error:", e$message, "\n\n")
      }
    )

    # Brief pause between reports
    Sys.sleep(2)
  }

  # Summary
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║                    BATCH COMPLETE                            ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")

  success_count <- sum(sapply(results, function(x) x$status == "Success"))
  cat(
    "Successfully generated:",
    success_count,
    "of",
    length(patient_list),
    "reports\n\n"
  )

  # Show results
  cat("Results:\n")
  for (name in names(results)) {
    status_icon <- ifelse(results[[name]]$status == "Success", "✅", "❌")
    cat(status_icon, name, "-", results[[name]]$status, "\n")
  }

  cat("\nReports saved to:", output_dir, "/\n")

  return(invisible(results))
}

# Helper function to create patient list from CSV
create_patient_list_from_csv <- function(csv_file) {
  # Read CSV with patient information
  patients_df <- read.csv(csv_file, stringsAsFactors = FALSE)

  # Convert to list format
  patient_list <- lapply(1:nrow(patients_df), function(i) {
    as.list(patients_df[i, ])
  })

  return(patient_list)
}

# EXAMPLE USAGE:

# Method 1: Manual patient list
example_patients <- list(
  list(
    name = "John Doe",
    age = 35,
    sex = "male",
    template_type = "forensic",
    referral = "Dr. Smith"
  ),
  list(
    name = "Jane Smith",
    age = 42,
    sex = "female",
    template_type = "adult",
    referral = "Dr. Johnson"
  ),
  list(
    name = "Bobby Wilson",
    age = 12,
    sex = "male",
    template_type = "pediatric",
    referral = "Dr. Brown"
  )
)

# Run batch processing
# batch_process_reports(example_patients)

# Method 2: From CSV file
# Create a CSV with columns: name, age, sex, template_type, referral
# patients <- create_patient_list_from_csv("patients.csv")
# batch_process_reports(patients)

cat(
  "
╔══════════════════════════════════════════════════════════════╗
║               BATCH REPORT PROCESSOR                         ║
╚══════════════════════════════════════════════════════════════╝

This script processes multiple patient reports automatically.

Usage:
  batch_process_reports(patient_list, output_dir = 'reports')

Example patient list:
  patients <- list(
    list(name = 'John Doe', age = 35, sex = 'male'),
    list(name = 'Jane Smith', age = 42, sex = 'female')
  )

  batch_process_reports(patients)

From CSV:
  patients <- create_patient_list_from_csv('patients.csv')
  batch_process_reports(patients)

CSV Format:
  name,age,sex,template_type,referral
  John Doe,35,male,forensic,Dr. Smith
  Jane Smith,42,female,adult,Dr. Johnson

Output:
  Reports will be saved to 'reports/' directory with format:
  patient_report_YYYYMMDD.pdf
"
)
