# Updated Workflow to Integrate with Existing Quarto/Typst Templates
# This version works with your established template system

library(tidyverse)
library(here)
library(yaml)
library(glue)
library(quarto)

# STEP 1: Update Variables YAML with Patient Information
update_variables_yaml <- function(
  patient_name = "Biggie",
  first_name = "Biggie",
  last_name = "Smalls",
  age = 44,
  sex = "male",
  template_type = "forensic"
) {
  # Read existing variables
  variables <- yaml::read_yaml("_variables.yml")

  # Update with new patient information
  variables$patient <- patient_name
  variables$first_name <- first_name
  variables$last_name <- last_name
  variables$age <- age
  variables$sex <- sex
  variables$sex_cap <- stringr::str_to_title(sex)

  # Calculate DOB based on age
  variables$dob <- format(Sys.Date() - (age * 365.25), "%Y-%m-%d")

  # Update dates
  variables$doe <- format(Sys.Date() - 30, "%Y-%m-%d") # 30 days ago
  variables$doe2 <- format(Sys.Date() - 27, "%Y-%m-%d") # 27 days ago
  variables$doe3 <- format(Sys.Date() - 24, "%Y-%m-%d") # 24 days ago
  variables$date_of_report <- format(Sys.Date(), "%Y-%m-%d")

  # Update pronouns based on sex
  if (tolower(sex) == "male") {
    variables$mr_mrs <- "Mr."
    variables$he_she <- "he"
    variables$he_she_cap <- "He"
    variables$his_her <- "his"
    variables$his_her_cap <- "His"
    variables$him_her <- "him"
    variables$him_her_cap <- "Him"
  } else if (tolower(sex) == "female") {
    variables$mr_mrs <- "Ms."
    variables$he_she <- "she"
    variables$he_she_cap <- "She"
    variables$his_her <- "her"
    variables$his_her_cap <- "Her"
    variables$him_her <- "her"
    variables$him_her_cap <- "Her"
  }

  # Write back to YAML
  yaml::write_yaml(variables, "_variables.yml")
  message("✓ Updated _variables.yml with patient information")
}

# STEP 2: Create/Update Domain Files in sections/ Directory
create_domain_sections <- function() {
  # Create sections directory if it doesn't exist
  dir.create("sections", showWarnings = FALSE)

  # Load the processed data
  neurocog <- readr::read_csv("data/neurocog.csv")
  neurobehav <- readr::read_csv("data/neurobehav.csv")

  # Domain mapping for file names
  domain_files <- list(
    "General Cognitive Ability" = "_02-01_iq",
    "Academic Achievement" = "_02-02_academics",
    "Verbal/Language" = "_02-03_verbal",
    "Visual Perception/Construction" = "_02-04_spatial",
    "Memory" = "_02-05_memory",
    "Attention/Executive" = "_02-06_executive",
    "Motor" = "_02-07_motor",
    "Social Cognition" = "_02-08_social",
    "ADHD" = "_02-09_adhd_adult",
    "Emotional/Behavioral" = "_02-10_emotion_adult",
    "Adaptive Functioning" = "_02-11_adaptive",
    "Daily Living" = "_02-12_daily_living"
  )

  # Process each domain
  for (domain_name in names(domain_files)) {
    file_base <- domain_files[[domain_name]]

    # Filter data for this domain
    domain_data <- neurocog |> filter(domain == domain_name)

    if (nrow(domain_data) > 0) {
      # Create the main domain QMD file
      create_domain_qmd_file(domain_data, domain_name, file_base)

      # Create the text summary file
      create_domain_text_file(domain_data, domain_name, file_base)

      message(glue("✓ Created sections/{file_base}.qmd and text file"))
    }
  }
}

# Function to create domain QMD file - FIXED VERSION
create_domain_qmd_file <- function(data, domain_name, file_base) {
  # Define domain-specific scales based on file_base
  scales <- get_domain_scales(file_base)

  # Create section ID
  section_id <- gsub("_", "-", file_base)

  # Build scales string
  if (length(scales) > 0) {
    scales_str <- paste0('"', scales, '"', collapse = ", ")
  } else {
    scales_str <- ""
  }

  # Build the content using paste to avoid glue parsing issues
  qmd_content <- paste0(
    "## ",
    domain_name,
    " {#sec-",
    section_id,
    "}\n\n",
    "{{< include ",
    file_base,
    "_text.qmd >}}\n\n",
    "```{r}\n",
    "#| label: setup-",
    section_id,
    "\n",
    "#| include: false\n\n",
    "# Domain-specific data\n",
    'domains <- c("',
    domain_name,
    '")\n',
    'pheno <- "',
    gsub("^_02-\\d+_", "", file_base),
    '"\n',
    "```\n\n",
    "```{r}\n",
    "#| label: data-",
    section_id,
    "\n",
    "#| include: false\n\n",
    "# Filter data\n",
    "data <- NeurotypR::filter_data(\n",
    "  data = neurocog,\n",
    "  domain = domains\n",
    ")\n\n",
    "# Filter by scales\n",
    "scales <- c(",
    scales_str,
    ")\n",
    "data_scales <- NeurotypR::filter_data(\n",
    "  data = data,\n",
    "  scale = scales\n",
    ")\n",
    "```\n\n",
    "```{r}\n",
    "#| label: table-",
    section_id,
    "\n",
    '#| tbl-cap: "',
    domain_name,
    ' Test Scores"\n\n',
    "# Create table\n",
    "NeurotypR::tbl_gt(\n",
    "  data = data_scales,\n",
    "  pheno = pheno,\n",
    '  table_name = paste0("table_", pheno),\n',
    '  source_note = "Standard score: Mean = 100 [50th‰], SD ± 15",\n',
    "  dynamic_grp = pheno\n",
    ")\n",
    "```\n\n",
    "```{r}\n",
    "#| label: fig-",
    section_id,
    "-subdomain\n",
    '#| fig-cap: "',
    domain_name,
    ' subdomain scores"\n',
    "#| fig-height: 4\n",
    "#| fig-width: 6\n\n",
    "# Create subdomain plot\n",
    "data_subdomain <- data |>\n",
    "  dplyr::group_by(subdomain) |>\n",
    "  dplyr::summarise(\n",
    "    z_mean_subdomain = mean(z_mean_subdomain, na.rm = TRUE)\n",
    "  ) |>\n",
    "  dplyr::filter(!is.na(z_mean_subdomain))\n\n",
    "NeurotypR::dotplot(\n",
    "  data = data_subdomain,\n",
    "  x = data_subdomain$z_mean_subdomain,\n",
    "  y = data_subdomain$subdomain,\n",
    '  filename = paste0("fig_", pheno, "_subdomain.svg")\n',
    ")\n",
    "```\n"
  )

  # Write to sections directory
  writeLines(qmd_content, file.path("sections", paste0(file_base, ".qmd")))
}


# Function to create domain text summary file
create_domain_text_file <- function(data, domain_name, file_base) {
  # Use the same summary generation logic from before
  mean_percentile <- mean(data$percentile, na.rm = TRUE)

  overall_range <- case_when(
    mean_percentile >= 98 ~ "Exceptionally High",
    mean_percentile >= 91 ~ "Above Average",
    mean_percentile >= 75 ~ "High Average",
    mean_percentile >= 25 ~ "Average",
    mean_percentile >= 9 ~ "Low Average",
    mean_percentile >= 2 ~ "Below Average",
    TRUE ~ "Exceptionally Low"
  )

  summary_text <- glue(
    "
<summary>

Testing of {tolower(domain_name)} revealed overall {tolower(overall_range)}
performance (mean percentile = {round(mean_percentile)}).

</summary>
"
  )

  # Write to sections directory
  writeLines(
    summary_text,
    file.path("sections", paste0(file_base, "_text.qmd"))
  )
}

# Function to get domain-specific scales
get_domain_scales <- function(file_base) {
  scale_mapping <- list(
    "_02-01_iq" = c(
      "Full Scale (FSIQ)",
      "General Ability (GAI)",
      "Verbal Comprehension (VCI)",
      "Fluid Reasoning (FRI)",
      "Processing Speed (PSI)",
      "Working Memory (WMI)"
    ),
    "_02-03_verbal" = c(
      "Language Index (LAN)",
      "Oral Production",
      "Auditory Comprehension",
      "Naming",
      "Writing"
    ),
    "_02-04_spatial" = c(
      "Spatial Index (SPT)",
      "Visual Discrimination",
      "Design Construction",
      "Block Design"
    ),
    "_02-05_memory" = c(
      "Memory Index (MEM)",
      "List Learning",
      "Story Learning",
      "Figure Learning"
    ),
    "_02-06_executive" = c(
      "Attention Index (ATT)",
      "Executive Functions Index (EXE)",
      "Digits Forward",
      "Digits Backward"
    )
  )

  return(scale_mapping[[file_base]] %||% character(0))
}

# STEP 3: Update the _include_domains.qmd file
# STEP 3: Update the _include_domains.qmd file
update_include_domains <- function() {
  # Check which domain files exist
  section_files <- list.files(
    "sections",
    pattern = "^_02-\\d+_.*\\.qmd$",
    full.names = FALSE
  )

  # Filter out text files
  section_files <- section_files[!grepl("_text\\.qmd$", section_files)]

  # Create include statements
  includes <- paste0("{{< include sections/", section_files, " >}}\n")

  # Write to _include_domains.qmd
  writeLines(includes, "_include_domains.qmd")

  message("✓ Updated _include_domains.qmd")
}

# STEP 4: Update other required sections
update_required_sections <- function(template_type = "forensic") {
  # Update tests administered
  tests_content <- '
# TESTS ADMINISTERED

```{r}
#| label: tests-list
#| echo: false

# Load data to get test names
neurocog <- readr::read_csv("data/neurocog.csv")
neurobehav <- readr::read_csv("data/neurobehav.csv")

# Get unique test names
tests_cog <- unique(neurocog$test_name)
tests_beh <- unique(neurobehav$test_name)

# Combine and format
all_tests <- unique(c(tests_cog, tests_beh))
all_tests <- all_tests[!is.na(all_tests)]

# Print as bullet list
cat(paste("•", all_tests), sep = "\n")
```
'
  writeLines(tests_content, "_00-00_tests.qmd")

  # Update NSE based on template type
  if (template_type == "forensic") {
    nse_content <- '
# NEUROBEHAVIORAL STATUS EXAM

## Reason for Referral

{{< var mr_mrs >}} {{< var last_name >}}, a {{< var age >}}-year-old {{< var handedness >}}-handed {{< var sex >}}, was referred for comprehensive neuropsychological evaluation in the context of [forensic proceedings]. The evaluation was requested to assess cognitive functioning and determine any neurocognitive factors relevant to the current legal matter.

## Background Information

[To be completed based on clinical interview and records review]

## Mental Status/Behavioral Observations

• **Orientation**: Alert and oriented to person, place, time, and situation
• **Appearance**: Appropriately groomed and dressed
• **Behavior**: Cooperative and engaged throughout testing
• **Speech**: Fluent with normal rate and prosody
• **Mood/Affect**: Euthymic with appropriate range
• **Effort**: Adequate effort demonstrated on validity measures
'
  } else {
    nse_content <- '
# NEUROBEHAVIORAL STATUS EXAM

## Reason for Referral

{{< var mr_mrs >}} {{< var last_name >}} is a {{< var age >}}-year-old {{< var sex >}} who was referred by {{< var referral >}} for neuropsychological evaluation to assess cognitive functioning.

## Background Information

[Standard clinical template content]
'
  }

  writeLines(nse_content, "_01-00_nse_adult.qmd")

  message("✓ Updated required sections")
}

# STEP 5: Render the Report Using Quarto
render_neuropsych_report <- function(
  format = "neurotyp-adult-typst",
  output_file = NULL
) {
  # Check template.qmd exists
  if (!file.exists("template.qmd")) {
    stop("template.qmd not found!")
  }

  # Render using Quarto
  message("\n📄 Rendering report with Quarto...")

  quarto::quarto_render(
    input = "template.qmd",
    output_format = format,
    output_file = output_file
  )

  message("✅ Report rendered successfully!")
}

# Main workflow function
run_integrated_workflow <- function(
  patient_name = "Biggie",
  first_name = "Biggie",
  last_name = "Smalls",
  age = 44,
  sex = "male",
  template_type = "forensic"
) {
  message("\n", strrep("=", 60))
  message("NEUROPSYCHOLOGICAL REPORT GENERATION")
  message("Using Existing Quarto/Typst Templates")
  message(strrep("=", 60), "\n")

  # Step 1: Import and process data (using existing script)
  message("📊 STEP 1: Processing data...")
  source("01_import_process_data.R")

  # Step 2: Update variables YAML
  message("\n📝 STEP 2: Updating patient variables...")
  update_variables_yaml(
    patient_name = patient_name,
    first_name = first_name,
    last_name = last_name,
    age = age,
    sex = sex,
    template_type = template_type
  )

  # Step 3: Create domain sections
  message("\n📑 STEP 3: Creating domain sections...")
  create_domain_sections()

  # Step 4: Update include files
  message("\n🔗 STEP 4: Updating include files...")
  update_include_domains()
  update_required_sections(template_type)

  # Step 5: Render report
  message("\n📄 STEP 5: Rendering final report...")
  render_neuropsych_report(
    format = ifelse(
      template_type == "forensic",
      "neurotyp-forensic-typst",
      "neurotyp-adult-typst"
    )
  )

  message("\n✅ Workflow complete!")
}


# Run the workflow
run_integrated_workflow(
  patient_name = "Biggie",
  first_name = "Biggie",
  last_name = "Smalls",
  age = 44,
  sex = "male",
  template_type = "forensic"
)
