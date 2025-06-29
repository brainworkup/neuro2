#!/usr/bin/env Rscript

# EFFICIENT NEUROPSYCHOLOGICAL REPORT WORKFLOW
# This streamlined script only does what's necessary:
# 1. Process data, 2. Update variables, 3. Generate text, 4. Render report

# Clear workspace and load packages
rm(list = ls())

packages <- c("tidyverse", "here", "glue", "yaml", "quarto", "NeurotypR")
invisible(lapply(packages, library, character.only = TRUE))

message("🚀 EFFICIENT NEUROPSYCH REPORT WORKFLOW")
message("=======================================\n")

# STEP 1: Process Data (using existing script)
message("📊 Step 1: Processing data...")
if (file.exists("01_import_process_data.R")) {
  source("01_import_process_data.R")
  message("✅ Data processed\n")
} else {
  stop("❌ 01_import_process_data.R not found!")
}

# STEP 2: Update Patient Variables (minimal update)
message("📝 Step 2: Updating patient variables...")
update_patient_variables <- function(
  patient_name = "Biggie",
  first_name = "Biggie",
  last_name = "Smalls",
  age = 44,
  sex = "male"
) {
  if (!file.exists("_variables.yml")) {
    stop("❌ _variables.yml not found!")
  }

  # Read existing variables
  variables <- yaml::read_yaml("_variables.yml")

  # Update only essential patient info
  variables$patient <- patient_name
  variables$first_name <- first_name
  variables$last_name <- last_name
  variables$age <- age
  variables$sex <- sex
  variables$sex_cap <- stringr::str_to_title(sex)
  variables$date_of_report <- format(Sys.Date(), "%Y-%m-%d")

  # Update pronouns
  if (tolower(sex) == "male") {
    variables$mr_mrs <- "Mr."
    variables$he_she <- "he"
    variables$he_she_cap <- "He"
    variables$his_her <- "his"
    variables$his_her_cap <- "His"
    variables$him_her <- "him"
    variables$him_her_cap <- "Him"
  } else {
    variables$mr_mrs <- "Ms."
    variables$he_she <- "she"
    variables$he_she_cap <- "She"
    variables$his_her <- "her"
    variables$his_her_cap <- "Her"
    variables$him_her <- "her"
    variables$him_her_cap <- "Her"
  }

  # Write back
  yaml::write_yaml(variables, "_variables.yml")
  message("✅ Variables updated")
}

update_patient_variables()

# STEP 3: Generate Text Summaries (for existing text files only)
message("\n📑 Step 3: Generating domain text summaries...")

generate_domain_texts <- function() {
  # Load processed data
  if (
    !file.exists("data/neurocog.csv") || !file.exists("data/neurobehav.csv")
  ) {
    stop("❌ Processed data files not found!")
  }

  neurocog <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
  neurobehav <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)

  # Define domain mappings to existing text files
  domain_mappings <- list(
    "General Cognitive Ability" = "_02-01_iq_text.qmd",
    "Academic Skills" = "_02-02_academics_text.qmd",
    "Verbal/Language" = "_02-03_verbal_text.qmd",
    "Visual Perception/Construction" = "_02-04_spatial_text.qmd",
    "Memory" = "_02-05_memory_text.qmd",
    "Attention/Executive" = "_02-06_executive_text.qmd",
    "Motor" = "_02-07_motor_text.qmd",
    "Social Cognition" = "_02-08_social_text.qmd",
    "ADHD" = "_02-09_adhd_adult_text_self.qmd",
    "ADHD" = "_02-09_adhd_adult_text_observer.qmd",
    "Psychiatric Disorders" = "_02-10_emotion_adult_text.qmd",
    "Personality Disorders" = "_02-10_emotion_adult_text.qmd",
    "Substance Use" = "_02-10_emotion_adult_text.qmd",
    "Psychosocial Problems" = "_02-10_emotion_adult_text.qmd",
    "Adaptive Functioning" = "_02-11_adaptive_text.qmd",
    "Daily Living" = "_02-12_daily_living_text.qmd"
  )

  # Generate summary for each domain
  for (domain_name in names(domain_mappings)) {
    text_file <- domain_mappings[[domain_name]]

    # Skip if text file doesn't exist
    if (!file.exists(text_file)) {
      message(paste("⚠️ Skipping", domain_name, "- text file not found"))
      next
    }

    # Filter data for this domain
    domain_data <- neurocog |>
      filter(domain == domain_name) |>
      filter(!is.na(percentile))

    # If no data, keep existing content
    if (nrow(domain_data) == 0) {
      message(paste("⚠️ No data for", domain_name))
      next
    }

    # Generate simple summary
    mean_percentile <- mean(domain_data$percentile, na.rm = TRUE)

    overall_range <- case_when(
      mean_percentile >= 91 ~ "above average",
      mean_percentile >= 75 ~ "high average",
      mean_percentile >= 25 ~ "average",
      mean_percentile >= 9 ~ "low average",
      TRUE ~ "below average"
    )

    # Create summary text
    summary_text <- glue::glue(
      "
<summary>

Testing of {tolower(domain_name)} revealed overall {overall_range} performance (mean percentile = {round(mean_percentile)}).

</summary>
"
    )

    # Write to existing text file
    writeLines(summary_text, text_file)
    message(paste("✅ Updated", text_file))
  }
}

generate_domain_texts()

# STEP 4: Render Report (using existing template)
message("\n📄 Step 4: Rendering report...")

if (!file.exists("template.qmd")) {
  stop("❌ template.qmd not found!")
}

if (!file.exists("_quarto.yml")) {
  stop("❌ _quarto.yml not found!")
}

# Render using Quarto
tryCatch(
  {
    quarto::quarto_render("template.qmd")
    message("✅ Report rendered successfully!")
  },
  error = function(e) {
    message("❌ Render failed:", e$message)
    message("🔧 Try running: quarto render template.qmd")
  }
)

# Summary
message("\n🎉 WORKFLOW COMPLETE!")
message("=======================================")
message("Generated files:")
message("- Updated _variables.yml")
message("- Updated domain text summaries")
message("- Rendered final report")
message("\n💡 Key efficiency gains:")
message("- No unnecessary file creation")
message("- Uses existing template structure")
message("- Minimal processing steps")
message("- Fast execution")
