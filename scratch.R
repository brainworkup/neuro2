library(neuro2)
library(attachment)

# dependencies
att_amend_desc()
att_from_qmd()


# RBANS -------------------------------------------------------------------

# updated/integrated 7/22/25
input_file <- "EF2025_4_17_2025_scores.csv"
patient_id <- "Ethan"
test_prefix <- "RBANS Update Form A "
lookup_file <- "/Users/joey/Dropbox/neuropsych_lookup_table.csv"
output_file <- "data-raw/csv/rbans.csv"
summary_file <- "rbans_summary.csv"

manual_percentiles <- list(
  "Line Orientation" = 13,
  "Picture Naming" = 37,
  "List Recall" = 37,
  "List Recognition" = 63
)

manual_entries <- NULL
debug <- TRUE

# run rbans
process_rbans_unified(
  input_file = input_file,
  patient_id = patient_id,
  test_prefix = test_prefix,
  lookup_file = lookup_file,
  output_file = output_file,
  summary_file = summary_file,
  manual_percentiles = manual_percentiles,
  manual_entries = manual_entries,
  debug = debug
)

# Data processing ---------------------------------------------------------


styler::style_pkg(strict = TRUE, exclude_dirs = c("renv", ".history", "_arxiv"),)

usethis::use_rmarkdown_template("pluck")


rocft <- system.file("extdata", "rocft.csv", package = "neuro2")
usethis::use_data(rocft, internal = TRUE, overwrite = TRUE)
usethis::use_data_raw(neurocog, internal = TRUE, overwrite = TRUE)
usethis::use_data_raw(nabs, internal = TRUE, overwrite = TRUE)


neurocog <- read_csv("inst/extdata/neurocog.csv")
raw <- "neurocog"
usethis::use_data_raw(raw)
data_obj <- neurocog
usethis::use_data(data_obj, overwrite = TRUE, internal = TRUE)


# 1. Define your report variables
params <- list(
  patient = "Biggie Smalls",
  first_name = "Biggie",
  last_name = "Smalls",
  dob = "1972-05-21",
  age = 52,
  date_of_report = Sys.Date()
)

# 2. Instantiate and render
gen <- ReportGenerator$new(params, output_dir = "reports")
gen$render("biggie_report.pdf")

example("render_report", package = "neuro2")

# R6 ----------------------------------------------------------------------

pkgload::load_all("~/neuro2")

gen <- ReportGenerator$new(params = list(), output_dir = "out")

gen$load_data(c(
  "data-raw/neurocog.csv",
  "data-raw/neurobehav.csv"
))$filter_data(domains = c("Memory"))$calculate_stats(
  group_vars = c("domain", "scale")
)$generate_tables()$generate_plots()$generate_text(
  "raw.txt",
  "clean.md",
  "BEGIN",
  "END"
)$render("final_report.pdf")

gen$render_sections(
  domains_dir = system.file(
    "quarto",
    "_extensions",
    "brainworkup",
    "domains",
    package = "neuro2"
  ),
  placeholder = "{{domains}}",
  output_file = "jane_doe_report.pdf"
)


# Either supply actual template parameters…
gen <- ReportGenerator$new(
  params = list(
    patient = "Jane Doe",
    dob = "2010-04-15",
    age = 15,
    date_of_report = Sys.Date()
  ),
  output_dir = "out"
)
gen <- ReportGenerator$new(output_dir = "out")

# This will read template.qmd + any execute‐params,
# run quarto_render(), and write out “out/report.pdf”:
gen$render(output_file = "report.pdf")

# buildignore -------------------------------------------------------------

usethis::use_build_ignore(c(
  "README.md",
  "LICENSE",
  "reports",
  "data-raw",
  "data-raw.R",
  "scratch.R",
  "dev",
  "neuro2/inst/quarto/_extensions/brainworkup/.quarto",
  ".specstory",
  ".dbxignore",
  ".editorconfig",
  ".github",
  "src/",
  ".venv/"
))

usethis::use_build_ignore("data/")
usethis::use_build_ignore(".claude/")
usethis::use_build_ignore("‘01_setup_environment.R’ ‘02_unified_neuropsych_workflow.sh’
    ‘CODEBASE_ANALYSIS.md’ ‘EF2025_4_17_2025_scores.csv’ ‘FINAL_FIXES.md’
    ‘INTEGRATED_WORKFLOW_FIXES.md’ ‘UNIFIED_WORKFLOW_README.md’
    ‘WORKFLOW_FIXES_README.md’ ‘WORKFLOW_FIXES_README_UPDATED.md’
    ‘_02-00_behav_obs.pdf’ ‘check_all_templates.R’ ‘check_plot_titles.R’
    ‘config.yml’ ‘data_processor_module.R’ ‘docs’
    ‘domain_generator_module.R’ ‘domain_workflow_code_updates.R’
    ‘generate_all_domain_assets.R’ ‘generate_domain_files.R’
    ‘generate_figures.R’ ‘generate_spatial_tbl_img_files.R’
    ‘generate_tables.R’ ‘install_dependencies.R’ ‘migration_guide.md’
    ‘neuro2.code-workspace’ ‘neuro2_duckdb_workflow_DEMO.R’
    ‘package_management.md’ ‘pluck_rbans_harry.Rmd’
    ‘report_generator_module.R’ ‘run_test_workflow.sh’ ‘run_workflow.R’
    ‘safe_sysdata_update_examples.R’ ‘setup_templates.R’ ‘shiny-pegboard’
    ‘template_master.pdf’ ‘template_master.typ’
    ‘test_adhd_standardization.R’ ‘test_config.yml’
    ‘test_domain_generation.R’ ‘test_domain_mapping.R’
    ‘test_emotion_domain.R’ ‘test_emotion_processor.R’ ‘test_fixes.R’
    ‘test_output_emotion_adult.qmd’ ‘test_output_emotion_child.qmd’
    ‘test_output_filename.R’ ‘test_parquet_fixes.R’
    ‘test_plot_title_generation.R’ ‘test_table_generation.R’
    ‘test_testname_rater.csv’ ‘test_unified_workflow.R’
    ‘test_workflow.log’ ‘test_workflow.sh’
    ‘unified_neuropsych_workflow.sh’ ‘unified_workflow_architecture.md’
    ‘unified_workflow_runner.R’ ‘verify_adhd_scales.R’ ‘workflow.log’
    ‘workflow_r6_update.log’")


# CLAUDE -------------------------------------------------------------
# 1. First, make sure the package is properly installed
devtools::install("~/neuro2") # or wherever your package is located
library(neuro2)

# 2. Create a minimal working example
# Set up parameters matching your template variables
params <- list(
  patient = "Biggie Smalls",
  first_name = "Biggie",
  last_name = "Smalls",
  dob = "1972-05-21",
  doe = "2024-09-08",
  doe2 = "2024-09-11",
  doe3 = "2024-09-15",
  age = 52,
  sex = "male",
  education = 12,
  handedness = "right",
  referral = "Dr. Dre",
  dx1 = "ADHD",
  dx2 = "anxiety",
  dx3 = "depression",
  he_she = "he",
  he_she_cap = "He",
  his_her = "his",
  his_her_cap = "His",
  him_her = "him",
  him_her_cap = "Him",
  mr_mrs = "Mr.",
  date_of_report = format(Sys.Date(), "%Y-%m-%d")
)

# 3. Create output directory if it doesn't exist
dir.create("reports", showWarnings = FALSE)

# 4. Initialize the generator
gen <- ReportGenerator$new(params = params, output_dir = "reports")

# 5. Load example data (if using package data)
gen$load_data() # This loads the example datasets

# 6. Generate the report
gen$render("biggie_report.pdf")


# Rebuild the package
devtools::document()
devtools::install()

# Then test it
library(neuro2)
gen <- ReportGenerator$new(params = params, output_dir = "reports")
gen$load_data()
gen$render("biggie_report.pdf")


# ----------------------------------------------------------------------

tbl <- TableGTR6$new(
  data = neurocog,
  pheno = "attention",
  title = "Attention Domain Scores",
  source_note = "Data derived from standardized measures",
  fn_list = list(
    scaled_score = "Scaled score footnote.",
    t_score = "T score footnote."
  ),
  grp_list = list(
    scaled_score = c("CPT", "Trails A"),
    t_score = c("Stroop", "Digit Span")
  ),
  dynamic_grp = list(
    scaled_score = c("CPT", "Trails A", "Trails B"),
    t_score = c("Stroop", "Digit Span")
  ),
  vertical_padding = 2
)

gt_table <- tbl$build_table()

# R6 New System---------------------------------------------------
# How to Use the New System
# Here's a simple example of how to use the new system:
# Create a report system for a specific patient
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient_name = "Biggie Smalls",
    domains = c("General Cognitive Ability", "ADHD", "Memory"),
    template_file = "custom_template.qmd",
    output_file = "biggie_report.pdf"
  )
)

# Run the complete workflow
report_system$run_workflow()

# ----------------------
# Or use the wrapper function for an even simpler interface:
# Generate a complete report with one function call
generate_neuropsych_report_system(
  patient_name = "Biggie Smalls",
  domains = c("General Cognitive Ability", "ADHD", "Memory"),
  output_file = "biggie_report.pdf"
)


# dynamic domains
# All classes have been documented, installed, and are ready to use. You can now generate domain-specific files with the correct numbering pattern by simply calling:

processor <- DomainProcessorR6$new(
  domains = "ADHD",
  pheno = "adhd",
  input_file = "data-raw/neurocog.csv"
)
processor$generate_domain_qmd() # Creates _02-09_adhd.qmd with correct numbering

# Or use the complete system with:
generate_neuropsych_report_system(
  patient_name = "Biggie Smalls",
  domains = c("General Cognitive Ability", "ADHD", "Memory"),
  generate_domain_files = TRUE
)

# Trail Making Test -------------------------------------------------------

age <- 20
a <- 27
b <- 67
tmt_a_result <- score_tmtA(a, age)
tmt_a_result
tmt_b_result <- score_tmtB(b, age)
cat(tmt_b_result)

# ROCFT -------------------------------------------------------------------

library(bwu)
age <- 36
# rocft copy raw score
raw_score_copy <- 36
# rocft delayed recall raw score
raw_score_recall <- 30

rocft_copy <- bwu::rocft_copy_t_score(age, raw_score_copy)
cat(rocft_copy)


rocft_recall <- bwu::rocft_recall_t_score(age, raw_score_recall)
cat(rocft_recall)

# examiner_ut -------------------------------------------------------------
## EXAMINER UT

# age 12
ut <- bwu:::examiner_ut
ut_age12 <- bwu:::examiner_ut[["12"]]


# Grooved Pegboard --------------------------------------------------------

## dominant hand
age <- 20
raw_score <- 71
dominant <- pegboard_dominant_hand(age, raw_score)
dominant

## Nondominant hand
age <- 20
raw_score <- 64
nondominant <- pegboard_nondominant_hand(age, raw_score)
nondominant

## tmt new predicted child norms

tmtA_norms(age = 25, raw_score = 30) # For a 25-year-old
tmtA_norms(age = 10, raw_score = 40) # For a 10-year-old

score_tmtA(age = 25, raw_score = 30)
score_tmtA(age = 10, raw_score = 40)


source("merge_rda_files.R")
merge_rda_files(
  c("R/sysdata.rda", "R/sysdata_bwu.rda", "R/sysdata_neurotypr.rda"),
  output_file = "R/sysdata.rda",
  conflict_resolution = "skip" # Since dots is identical
)

input_file <- file.path(file.choose())
df <- readr::read_csv(
  input_file,
  col_names = FALSE,
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-16LE")
)
test_prefix <- "RBANS"
patient_id <- "Ethan"
lookup_file <- lookup_neuropsych_scales
line_orientation_pct_rank <- 13
picture_naming_pct_rank <- 37
list_recall_pct_rank <- 37
list_recognition_pct_rank <- 63
manual_entries <- NULL
output_file <- "data-raw/rbans.csv"

process_rbans_data(
  input_file = input_file,
  test_prefix = test_prefix,
  patient_id = patient,
  lookup_file = lookup_file,
  line_orientation_pct_rank = line_orientation_pct_rank,
  picture_naming_pct_rank = picture_naming_pct_rank,
  list_recall_pct_rank = list_recall_pct_rank,
  list_recognition_pct_rank = list_recognition_pct_rank,
  manual_entries = NULL,
  output_file = output_file
)

# TABLES
config <- list(
  labels = list(
    score = "**SCORE**",
    percentile = "**% RANK**",
    range = "**RANGE**"
  ),
  stubhead = "Test / Subtest",
  caption = NULL,
  source_note = NULL,
  theme = "538",
  vertical_padding = 0,
  multiline = TRUE
)
