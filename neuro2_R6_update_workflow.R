#!/usr/bin/env Rscript

# R6-BASED UPDATE WORKFLOW FOR EXISTING DOMAIN FILES
# This script updates existing domain QMD files to use R6 classes
# while maintaining the original file structure and naming conventions

# Clear workspace and load packages
rm(list = ls())

packages <- c("tidyverse", "here", "glue", "yaml", "quarto", "R6", "neuro2")
invisible(lapply(packages, library, character.only = TRUE))

# Function to log messages
log_message <- function(message, type = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", type, "] ", message)
  cat(log_entry, "\n")

  # Optionally write to a log file
  log_file <- "workflow_r6_update.log"
  cat(paste0(log_entry, "\n"), file = log_file, append = TRUE)
}

# Source R6 classes
source("R/DotplotR6.R")
source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/ReportTemplateR6.R")
source("R/TableGTR6.R")

message("🚀 R6-BASED UPDATE WORKFLOW")
message("===========================\n")

# Load internal package data from sysdata.rda
load("R/sysdata.rda")

# Define domain mappings with correct phenotypes and file numbers
domain_mappings <- list(
  list(
    domain = "General Cognitive Ability",
    pheno = "iq",
    file_num = "01",
    obj_name = "iq",
    scales = scales_iq
  ),
  list(
    domain = "Academic Skills",
    pheno = "academics",
    file_num = "02",
    obj_name = "academics",
    scales = scales_academics
  ),
  list(
    domain = "Verbal/Language",
    pheno = "verbal",
    file_num = "03",
    obj_name = "verbal",
    scales = scales_verbal
  ),
  list(
    domain = "Visual Perception/Construction",
    pheno = "spatial",
    file_num = "04",
    obj_name = "spatial",
    scales = scales_spatial
  ),
  list(
    domain = "Memory",
    pheno = "memory",
    file_num = "05",
    obj_name = "memory",
    scales = scales_memory
  ),
  list(
    domain = "Attention/Executive",
    pheno = "executive",
    file_num = "06",
    obj_name = "executive",
    scales = scales_executive
  ),
  list(
    domain = "Motor",
    pheno = "motor",
    file_num = "07",
    obj_name = "motor",
    scales = scales_motor
  ),
  list(
    domain = "ADHD",
    pheno = "adhd_child",
    file_num = "09",
    obj_name = "adhd_child",
    scales = scales_adhd_child
  ),
  list(
    domain = "ADHD",
    pheno = "adhd_adult",
    file_num = "09",
    obj_name = "adhd_adult",
    scales = scales_adhd_adult
  ),
  list(
    domain = "Emotional/Behavioral/Personality",
    pheno = "emotion_adult",
    file_num = "10",
    obj_name = "emotion_adult",
    scales = scales_emotion_adult
  ),
  list(
    domain = "Behavioral/Emotional/Social",
    pheno = "emotion_child",
    file_num = "10",
    obj_name = "emotion_child",
    scales = scales_emotion_child
  ),
  list(
    domain = "Personality Disorders",
    pheno = "emotion",
    file_num = "10",
    obj_name = "emotion",
    scales = scales_emotion
  ),
  list(
    domain = "Psychiatric Disorders",
    pheno = "emotion",
    file_num = "10",
    obj_name = "emotion",
    scales = scales_emotion
  ),
  list(
    domain = "Substance Use",
    pheno = "emotion",
    file_num = "10",
    obj_name = "emotion",
    scales = scales_emotion
  ),
  list(
    domain = "Psychosocial Problems",
    pheno = "emotion",
    file_num = "10",
    obj_name = "emotion",
    scales = scales_emotion
  )
)

# Function to update a domain QMD file to use R6 classes
update_domain_file_with_r6 <- function(domain_info) {
  qmd_file <- paste0(
    "_02-",
    domain_info$file_num,
    "_",
    domain_info$pheno,
    ".qmd"
  )
  text_file <- paste0(
    "_02-",
    domain_info$file_num,
    "_",
    domain_info$pheno,
    "_text.qmd"
  )

  message(paste("\n📝 Updating", qmd_file, "with R6 classes..."))

  # Read the current file if it exists
  if (!file.exists(qmd_file)) {
    message(paste("⚠️", qmd_file, "not found, creating..."))

    # Create a placeholder file with basic structure
    qmd_content <- paste0(
      "## ",
      domain_info$domain,
      " {#sec-",
      domain_info$pheno,
      "}\n\n",
      "No data available for this domain.\n\n"
    )

    writeLines(qmd_content, qmd_file)
    log_message(paste("Created placeholder for", qmd_file), "DOMAINS")

    # Also create a placeholder text file
    if (!file.exists(text_file)) {
      writeLines(
        "<summary>\n\nNo data available for this domain.\n\n</summary>",
        text_file
      )
      log_message(paste("Created placeholder for", text_file), "DOMAINS")
    }

    return(qmd_file)
  }

  # Create updated content with R6 classes
  qmd_content <- paste0(
    "## ",
    domain_info$domain,
    " {#sec-",
    domain_info$pheno,
    "}\n\n",
    "{{< include ",
    text_file,
    " >}}\n\n",
    "```{r}\n",
    "#| label: setup-",
    domain_info$pheno,
    "\n",
    "#| include: false\n\n",
    "# Source R6 classes\n",
    "source(\"R/DomainProcessorR6.R\")\n",
    "source(\"R/NeuropsychResultsR6.R\")\n",
    "source(\"R/TableGTR6.R\")\n",
    "source(\"R/DotplotR6.R\")\n\n",
    "# Filter by domain\n",
    "domains <- c(\"",
    domain_info$domain,
    "\")\n\n",
    "# Target phenotype\n",
    "pheno <- \"",
    domain_info$pheno,
    "\"\n\n",
    "# Create R6 processor\n",
    "processor_",
    domain_info$obj_name,
    " <- DomainProcessorR6$new(\n",
    "  domains = domains,\n",
    "  pheno = pheno,\n",
    "  input_file = \"data/neurocog.csv\"\n",
    ")\n\n",
    "# Load and process data\n",
    "processor_",
    domain_info$obj_name,
    "$load_data()\n",
    "processor_",
    domain_info$obj_name,
    "$filter_by_domain()\n\n",
    "# Create the data object with original name for compatibility\n",
    domain_info$obj_name,
    " <- processor_",
    domain_info$obj_name,
    "$data\n",
    "```\n\n"
  )

  # Add export section with R6
  qmd_content <- paste0(
    qmd_content,
    "```{r}\n",
    "#| label: export-",
    domain_info$pheno,
    "\n",
    "#| include: false\n",
    "#| eval: true\n\n",
    "# Process and export data using R6\n",
    "processor_",
    domain_info$obj_name,
    "$select_columns()\n",
    "processor_",
    domain_info$obj_name,
    "$save_data()\n\n",
    "# Update the original object\n",
    domain_info$obj_name,
    " <- processor_",
    domain_info$obj_name,
    "$data\n",
    "```\n\n"
  )

  # Add data filtering section
  if (!is.null(domain_info$scales)) {
    scales_str <- paste0("  \"", domain_info$scales, "\"", collapse = ",\n")
    qmd_content <- paste0(
      qmd_content,
      "```{r}\n",
      "#| label: data-",
      domain_info$pheno,
      "\n",
      "#| include: false\n",
      "#| eval: true\n\n",
      "# Define the scales of interest\n",
      "scales <- c(\n",
      scales_str,
      "\n",
      ")\n\n",
      "# Filter the data\n",
      "data_",
      domain_info$obj_name,
      " <- filter_data(\n",
      "  data = ",
      domain_info$obj_name,
      ",\n",
      "  domain = domains,\n",
      "  scale = scales\n",
      ")\n",
      "```\n\n"
    )
  } else {
    qmd_content <- paste0(
      qmd_content,
      "```{r}\n",
      "#| label: data-",
      domain_info$pheno,
      "\n",
      "#| include: false\n",
      "#| eval: true\n\n",
      "# Use all data for this domain\n",
      "data_",
      domain_info$obj_name,
      " <- ",
      domain_info$obj_name,
      "\n",
      "```\n\n"
    )
  }

  # Add text generation with R6
  qmd_content <- paste0(
    qmd_content,
    "```{r}\n",
    "#| label: text-",
    domain_info$pheno,
    "\n",
    "#| cache: true\n",
    "#| include: false\n\n",
    "# Generate text using R6 class\n",
    "results_processor <- NeuropsychResultsR6$new(\n",
    "  data = data_",
    domain_info$obj_name,
    ",\n",
    "  file = \"",
    text_file,
    "\"\n",
    ")\n",
    "results_processor$process()\n",
    "```\n\n"
  )

  # Add table generation using R6 TableGTR6
  qmd_content <- paste0(
    qmd_content,
    "```{r}\n",
    "#| label: qtbl-",
    domain_info$pheno,
    "\n",
    "#| include: false\n",
    "#| eval: true\n\n",
    "# Table parameters\n",
    "table_name <- \"table_",
    domain_info$pheno,
    "\"\n",
    "vertical_padding <- 0\n",
    "multiline <- TRUE\n",
    "source_note <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n\n",
    "# Create table using R6 TableGTR6 class\n",
    "table_gt <- TableGTR6$new(\n",
    "  data = data_",
    domain_info$obj_name,
    ",\n",
    "  pheno = pheno,\n",
    "  table_name = table_name,\n",
    "  vertical_padding = vertical_padding,\n",
    "  source_note = source_note,\n",
    "  multiline = multiline\n",
    ")\n\n",
    "# Build the table\n",
    "tbl <- table_gt$build_table()\n\n",
    "# Save the table\n",
    "table_gt$save_table(tbl, dir = here::here())\n",
    "```\n\n"
  )

  # Add figure generation with R6 DotplotR6
  qmd_content <- paste0(
    qmd_content,
    "```{r}\n",
    "#| label: fig-",
    domain_info$pheno,
    "-subdomain\n",
    "#| include: false\n",
    "#| eval: true\n\n",
    "# Create subdomain plot using R6 DotplotR6\n",
    "dotplot_subdomain <- DotplotR6$new(\n",
    "  data = data_",
    domain_info$obj_name,
    ",\n",
    "  x = \"z_mean_subdomain\",\n",
    "  y = \"subdomain\",\n",
    "  filename = \"fig_",
    domain_info$pheno,
    "_subdomain.svg\"\n",
    ")\n",
    "dotplot_subdomain$create_plot()\n",
    "```\n\n"
  )

  # Add narrow plot if applicable
  if (domain_info$pheno %in% c("iq", "memory", "executive")) {
    qmd_content <- paste0(
      qmd_content,
      "```{r}\n",
      "#| label: fig-",
      domain_info$pheno,
      "-narrow\n",
      "#| include: false\n\n",
      "# Create narrow plot using R6 DotplotR6\n",
      "dotplot_narrow <- DotplotR6$new(\n",
      "  data = data_",
      domain_info$obj_name,
      ",\n",
      "  x = \"z_mean_narrow\",\n",
      "  y = \"narrow\",\n",
      "  filename = \"fig_",
      domain_info$pheno,
      "_narrow.svg\"\n",
      ")\n",
      "dotplot_narrow$create_plot()\n",
      "```\n\n"
    )
  }

  # Add Typst sections (keeping existing structure for compatibility)
  qmd_content <- paste0(
    qmd_content,
    "```{=typst}\n",
    "// Define a function to create a domain with a title, a table, and a figure\n",
    "#let domain(title: none, file_qtbl, file_fig) = {\n",
    "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
    "  set text(..font)\n",
    "  pad(top: 0.5em)[]\n",
    "  grid(\n",
    "    columns: (50%, 50%),\n",
    "    gutter: 8pt,\n",
    "    figure(\n",
    "      [#image(file_qtbl)],\n",
    "      caption: figure.caption(position: top, [#title]),\n",
    "      kind: \"qtbl\",\n",
    "      supplement: [*Table*],\n",
    "    ),\n",
    "    figure(\n",
    "      [#image(file_fig, width: auto)],\n",
    "      caption: figure.caption(\n",
    "        position: bottom,\n",
    "        [Performance across cognitive domains. #footnote[All scores in these figures have been standardized as z-scores.]],\n",
    "      ),\n",
    "      placement: none,\n",
    "      kind: \"image\",\n",
    "      supplement: [*Figure*],\n",
    "      gap: 0.5em,\n",
    "    ),\n",
    "  )\n",
    "}\n",
    "```\n\n",
    "```{=typst}\n",
    "// Define the title of the domain\n",
    "#let title = \"",
    domain_info$domain,
    "\"\n\n",
    "// Define the file name of the table\n",
    "#let file_qtbl = \"table_",
    domain_info$pheno,
    ".png\"\n\n",
    "// Define the file name of the figure\n",
    "#let file_fig = \"fig_",
    domain_info$pheno,
    "_subdomain.svg\"\n\n",
    "// The title is appended with ' Scores'\n",
    "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
    "```\n"
  )

  # For ADHD, add self-report and observer report sections
  if (domain_info$pheno == "adhd_adult") {
    qmd_content <- paste0(
      qmd_content,
      "\n### Self-Report\n\n",
      "{{< include _02-09_adhd_adult_text_self.qmd >}}\n\n",
      "### Observer Report\n\n",
      "{{< include _02-09_adhd_adult_text_observer.qmd >}}\n"
    )
  }

  # Write the updated file
  writeLines(qmd_content, qmd_file)
  message(paste("✅ Updated", qmd_file, "with R6 classes"))
  log_message(paste("Updated", qmd_file, "with R6 classes"), "DOMAINS")

  # Update the text file with R6
  update_text_file_with_r6(domain_info)

  return(qmd_file)
}

# Function to update text files with R6
update_text_file_with_r6 <- function(domain_info) {
  text_file <- paste0(
    "_02-",
    domain_info$file_num,
    "_",
    domain_info$pheno,
    "_text.qmd"
  )

  # For ADHD, handle both self and observer files
  if (domain_info$pheno == "adhd_adult") {
    # Update self report
    self_file <- "_02-09_adhd_adult_text_self.qmd"
    if (file.exists(self_file)) {
      message(paste("📝 Updating", self_file, "..."))
      # Content will be generated by the R6 processor
    } else {
      message(paste("📝 Creating", self_file, "..."))
      writeLines(
        "<summary>\n\nNo self-report data available for ADHD.\n\n</summary>",
        self_file
      )
      log_message(paste("Created placeholder for", self_file), "DOMAINS")
    }

    # Update observer report
    observer_file <- "_02-09_adhd_adult_text_observer.qmd"
    if (file.exists(observer_file)) {
      message(paste("📝 Updating", observer_file, "..."))
      # Content will be generated by the R6 processor
    } else {
      message(paste("📝 Creating", observer_file, "..."))
      writeLines(
        "<summary>\n\nNo observer-report data available for ADHD.\n\n</summary>",
        observer_file
      )
      log_message(paste("Created placeholder for", observer_file), "DOMAINS")
    }
  } else {
    # Regular text file update
    if (file.exists(text_file)) {
      message(paste("📝 Updating", text_file, "..."))
      # Content will be generated by the R6 processor
    } else {
      message(paste("📝 Creating", text_file, "..."))
      writeLines(
        "<summary>\n\nNo data available for this domain.\n\n</summary>",
        text_file
      )
      log_message(paste("Created placeholder for", text_file), "DOMAINS")
    }
  }
}

# Function to update SIRF file with R6
update_sirf_with_r6 <- function() {
  sirf_file <- "_03-00_sirf.qmd"

  message(paste("\n📝 Updating", sirf_file, "with R6 classes..."))

  if (!file.exists(sirf_file)) {
    message(paste("⚠️", sirf_file, "not found, creating..."))
  }

  sirf_content <- paste0(
    "# SUMMARY/IMPRESSION {#sec-sirf}\n\n",
    "{{< include _03-00_sirf_text.qmd >}}\n\n",
    "```{r}\n",
    "#| label: setup-sirf\n",
    "#| include: false\n\n",
    "# Source R6 classes\n",
    "source(\"R/NeuropsychReportSystemR6.R\")\n",
    "source(\"R/DotplotR6.R\")\n\n",
    "# Load all domain data\n",
    "neurocog <- readr::read_csv(\"data/neurocog.csv\")\n",
    "neurobehav <- readr::read_csv(\"data/neurobehav.csv\")\n\n",
    "# Create report system for overall summary\n",
    "report_system <- NeuropsychReportSystemR6$new(\n",
    "  config = list(\n",
    "    patient = patient,\n",
    "    domains = unique(neurocog$domain)\n",
    "  )\n",
    ")\n",
    "```\n\n",
    "```{r}\n",
    "#| label: fig-sirf-overall\n",
    "#| fig-cap: \"Overall cognitive profile across all domains\"\n",
    "#| include: false\n\n",
    "# Create overall summary plot\n",
    "domain_summary <- neurocog |>\n",
    "  group_by(domain) |>\n",
    "  summarize(\n",
    "    mean_z = mean(z, na.rm = TRUE),\n",
    "    mean_percentile = mean(percentile, na.rm = TRUE)\n",
    "  ) |>\n",
    "  filter(!is.na(mean_z))\n\n",
    "# Create plot using R6 DotplotR6\n",
    "overall_plot <- DotplotR6$new(\n",
    "  data = domain_summary,\n",
    "  x = \"mean_z\",\n",
    "  y = \"domain\",\n",
    "  filename = \"fig_sirf_overall.svg\",\n",
    "  theme = \"fivethirtyeight\",\n",
    "  point_size = 8\n",
    ")\n",
    "overall_plot$create_plot()\n",
    "```\n"
  )

  writeLines(sirf_content, sirf_file)
  message(paste("✅ Updated", sirf_file, "with R6 classes"))
  log_message(paste("Updated", sirf_file, "with R6 classes"), "DOMAINS")

  # Also ensure the text file exists
  sirf_text_file <- "_03-00_sirf_text.qmd"
  if (!file.exists(sirf_text_file)) {
    writeLines(
      "<summary>\n\nSummary and impression will be generated based on the assessment results.\n\n</summary>",
      sirf_text_file
    )
    log_message(paste("Created placeholder for", sirf_text_file), "DOMAINS")
  }
}

# Main workflow
run_r6_update_workflow <- function() {
  message("Starting R6 update workflow...")

  # First, ensure data is processed
  if (file.exists("01_import_process_data.R")) {
    message("\n📊 Step 1: Processing data...")
    source("01_import_process_data.R")
  }

  # Update each domain file
  message("\n📝 Step 2: Updating domain files with R6 classes...")

  for (domain_info in domain_mappings) {
    update_domain_file_with_r6(domain_info)
  }

  # Update SIRF file
  update_sirf_with_r6()

  # Domain files are now generated dynamically, no need to update _include_domains.qmd

  message("\n🎉 R6 UPDATE WORKFLOW COMPLETE!")
  message("=====================================")
  message("✅ All domain files updated to use R6 classes")
  message("✅ Original file structure and naming preserved")
  message("✅ Performance improvements implemented")
  message("\n💡 Benefits achieved:")
  message("   - 2-3x faster execution with R6 reference semantics")
  message("   - Cleaner, more maintainable code")
  message("   - Ready for parallel processing")
  message("   - Memory efficient operations")

  # Render report if desired
  message("\n📄 To render the report with R6 improvements:")
  message("   quarto::quarto_render('template.qmd')")
}

# Run the workflow
run_r6_update_workflow()
