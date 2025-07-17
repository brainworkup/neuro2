# Test Workflow for Neuropsychological Report Generation
# Patient: Biggie
# Neurotyp template: "forensic"
# Age: 44
# Sex: Male

library(here)
library(dplyr)
library(readr)
library(purrr)
library(stringr)
library(tidyr)

# Load the R6 class definitions from the current package
source("R/ReportTemplateR6.R")
source("R/NeuropsychResultsR6.R")
source("R/NeuropsychReportSystemR6.R")
source("R/IQReportGeneratorR6.R")
source("R/DomainProcessorR6.R")

# Load utility functions (replacements for NeurotypR functions)
source("R/utility_functions.R")

# Step 1: Import and process individual CSV files to generate neurocog and neurobehav datasets

# Function to import and standardize CSV files
import_csv <- function(file_path) {
  message(paste0("Importing ", file_path))

  # Extract test name from file name
  test_name <- tools::file_path_sans_ext(basename(file_path))

  # Read the CSV file
  data <- readr::read_csv(file_path, show_col_types = FALSE)

  # Add test identifier column
  data$test <- test_name

  return(data)
}

# Get list of all CSV files in data-raw
csv_files <- list.files(
  path = "data-raw",
  pattern = "\\.csv$",
  full.names = TRUE
)

# Import all CSV files
raw_data_list <- lapply(csv_files, import_csv)

# Combine all imported data
raw_data <- bind_rows(raw_data_list)

# Categorize tests into neurocog and neurobehav
neurocog_tests <- c(
  "wais5",
  "wiat4",
  "topf",
  "cvlt3_brief",
  "rocft",
  "dkefs",
  "examiner",
  "nabs"
)

neurobehav_tests <- c(
  "caars2_self",
  "caars2_observer",
  "cefi_self",
  "cefi_observer",
  "pai_clinical",
  "pai_inatt",
  "pai_validity"
)

# Create neurocog and neurobehav datasets with z-score calculations
# First, convert percentiles to z-scores
raw_data <- raw_data |>
  mutate(
    z = ifelse(!is.na(percentile), qnorm(percentile / 100), NA_real_),
    domain = as.character(domain),
    subdomain = as.character(subdomain),
    narrow = as.character(narrow),
    pass = as.character(pass),
    verbal = as.factor(verbal),
    timed = as.factor(timed)
  )

# Create neurocog dataset with aggregated z-scores
neurocog_data <- raw_data |>
  filter(test %in% neurocog_tests) |>
  # Add test_type for consistency with user's workflow
  mutate(test_type = "npsych_test") |>
  # domain
  group_by(domain) |>
  mutate(
    z_mean_domain = mean(z, na.rm = TRUE),
    z_sd_domain = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # subdomain
  group_by(subdomain) |>
  mutate(
    z_mean_subdomain = mean(z, na.rm = TRUE),
    z_sd_subdomain = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # narrow
  group_by(narrow) |>
  mutate(
    z_mean_narrow = mean(z, na.rm = TRUE),
    z_sd_narrow = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # pass
  group_by(pass) |>
  mutate(
    z_mean_pass = mean(z, na.rm = TRUE),
    z_sd_pass = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # verbal
  group_by(verbal) |>
  mutate(
    z_mean_verbal = mean(z, na.rm = TRUE),
    z_sd_verbal = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # timed
  group_by(timed) |>
  mutate(
    z_mean_timed = mean(z, na.rm = TRUE),
    z_sd_timed = sd(z, na.rm = TRUE)
  ) |>
  ungroup()

# Create neurobehav dataset with aggregated z-scores
neurobehav_data <- raw_data |>
  filter(test %in% neurobehav_tests) |>
  # Add test_type for consistency with user's workflow
  mutate(test_type = "rating_scale") |>
  # domain
  group_by(domain) |>
  mutate(
    z_mean_domain = mean(z, na.rm = TRUE),
    z_sd_domain = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # subdomain
  group_by(subdomain) |>
  mutate(
    z_mean_subdomain = mean(z, na.rm = TRUE),
    z_sd_subdomain = sd(z, na.rm = TRUE)
  ) |>
  ungroup() |>
  # narrow
  group_by(narrow) |>
  mutate(
    z_mean_narrow = mean(z, na.rm = TRUE),
    z_sd_narrow = sd(z, na.rm = TRUE)
  ) |>
  ungroup()

# Save the processed datasets
write_csv(neurocog_data, "data-raw/neurocog.csv")
write_csv(neurobehav_data, "data-raw/neurobehav.csv")

message(
  "Datasets created: neurocog.csv and neurobehav.csv with z-score calculations"
)

# Step 2: Set up patient info and create the report system

# Create directories if they don't exist
if (!dir.exists("data")) {
  dir.create("data")
}

if (!dir.exists("output")) {
  dir.create("output")
}

# Patient information
patient_info <- list(
  patient = "Biggie",
  first_name = "Biggie",
  last_name = "Smalls", # Add a last name to prevent YAML formatting issues
  age = 44,
  sex = "Male",
  dob = format(Sys.Date() - 365 * 44, "%Y-%m-%d"),
  doe = format(Sys.Date(), "%Y-%m-%d"),
  doe2 = format(Sys.Date() - 1, "%Y-%m-%d"),
  doe3 = format(Sys.Date() - 2, "%Y-%m-%d"),
  date_of_report = format(Sys.Date(), "%Y-%m-%d")
)

# Define domains to include in the report
domains <- c(
  "General Cognitive Ability",
  "Verbal",
  "Spatial",
  "Memory",
  "Attention/Executive",
  "ADHD",
  "Psychiatric Disorders"
)

# Create the neuropsych report system
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = patient_info$patient,
    domains = domains,
    data_files = list(
      neurocog = "data-raw/neurocog.csv",
      neurobehav = "data-raw/neurobehav.csv"
    ),
    template_file = "forensic_report.qmd",
    output_file = "Biggie_Neuropsych_Report.pdf"
  ),
  template_dir = "inst/extdata/_extensions/neurotyp-forensic",
  output_dir = "output"
)

# Step 3: Generate domain-specific files

# Process each domain
domain_processors <- list()

# General Cognitive Ability (IQ)
iq_processor <- IQReportGeneratorR6$new(
  patient = patient_info$patient,
  input_file = "data-raw/neurocog.csv",
  output_dir = "data",
  domains = "General Cognitive Ability",
  pheno = "iq"
)
iq_processor$generate_report()
iq_processor$render_document(output_file = "_02-01_iq.qmd")
domain_processors[["iq"]] <- iq_processor

# Process other domains using DomainProcessorR6
domain_configs <- list(
  verbal = list(domain = "Verbal", pheno = "verbal"),
  spatial = list(domain = "Spatial", pheno = "spatial"),
  memory = list(domain = "Memory", pheno = "memory"),
  executive = list(domain = "Attention/Executive", pheno = "executive"),
  adhd = list(domain = "ADHD", pheno = "adhd")
)

for (domain_name in names(domain_configs)) {
  config <- domain_configs[[domain_name]]
  message(paste0("Processing domain: ", config$domain))

  # Create domain processor
  processor <- DomainProcessorR6$new(
    domains = config$domain,
    pheno = config$pheno,
    input_file = "data-raw/neurocog.csv"
  )

  # Process domain data
  processor$process(
    generate_reports = TRUE,
    report_types = c("self", "observer"),
    generate_domain_files = TRUE
  )

  # Store processor
  domain_processors[[config$pheno]] <- processor
}

# Process psychiatric domain using neurobehav data
psych_processor <- DomainProcessorR6$new(
  domains = "Psychiatric Disorders",
  pheno = "emotion",
  input_file = "data-raw/neurobehav.csv",
  test_filters = list(
    self = c("pai_clinical", "pai_inatt"),
    observer = c("caars2_observer", "cefi_observer")
  )
)
psych_processor$process(
  generate_reports = TRUE,
  report_types = c("self", "observer"),
  generate_domain_files = TRUE
)
domain_processors[["emotion"]] <- psych_processor

# Step 4: Create the template report

# Create output/sections/sections directory (the double nesting is required by ReportTemplateR6)
if (!dir.exists("output/sections/sections")) {
  dir.create("output/sections/sections", recursive = TRUE)
}

# Also copy _02-01_iq_text.qmd to the output directory for proper inclusion
file.copy("_02-01_iq_text.qmd", "output/_02-01_iq_text.qmd", overwrite = TRUE)

# Create a simple _00-00_tests.qmd file
cat(
  "## Tests Administered\n\nThis section lists all tests administered during the evaluation.\n",
  file = "output/sections/sections/_00-00_tests.qmd"
)

# Copy existing QMD files to output/sections/sections
template_files <- c(
  "_01-00_nse_forensic.qmd",
  "_02-00_behav_obs.qmd",
  "_02-01_iq.qmd",
  "_03-00_sirf_text.qmd",
  "_03-01_recs.qmd"
)

for (file in template_files) {
  if (file.exists(file)) {
    file.copy(
      file,
      file.path("output/sections/sections", file),
      overwrite = TRUE
    )
  }
}

# Create other missing template files with placeholder content
missing_files <- c(
  "_02-03_verbal.qmd",
  "_02-04_spatial.qmd",
  "_02-05_memory.qmd",
  "_02-06_executive.qmd",
  "_02-09_adhd_adult.qmd",
  "_02-10_emotion_adult.qmd",
  "_03-00_sirf.qmd",
  "_03-02_signature.qmd",
  "_03-03_appendix.qmd"
)

for (file in missing_files) {
  cat(
    paste0(
      "## ",
      gsub("_[0-9]+-[0-9]+_(.*)\\.[qm].*$", "\\1", file),
      "\n\nPlaceholder content for ",
      file,
      "\n"
    ),
    file = file.path("output/sections/sections", file)
  )
}

# Now create the template manager with the correct paths
template_manager <- ReportTemplateR6$new(
  variables = patient_info,
  template_dir = "inst/extdata/_extensions/neurotyp-forensic",
  output_dir = "output",
  sections = c(
    "_00-00_tests.qmd",
    "_01-00_nse_forensic.qmd",
    "_02-00_behav_obs.qmd",
    "_02-01_iq.qmd",
    "_02-03_verbal.qmd",
    "_02-04_spatial.qmd",
    "_02-05_memory.qmd",
    "_02-06_executive.qmd",
    "_02-09_adhd_adult.qmd",
    "_02-10_emotion_adult.qmd",
    "_03-00_sirf.qmd",
    "_03-00_sirf_text.qmd",
    "_03-01_recs.qmd",
    "_03-02_signature.qmd",
    "_03-03_appendix.qmd"
  )
)

# Generate the template
template_manager$generate_template("forensic_report.qmd")

# Step 5: Render the complete report
template_manager$render_report(
  input_file = "output/forensic_report.qmd",
  output_format = "pdf",
  output_file = "Biggie_Neuropsych_Report.pdf"
)

message(
  "Report generation complete. Output file: output/Biggie_Neuropsych_Report.pdf"
)
