# Setup Environment for Neuropsychological Report Generation (neuro2)
# This script installs necessary packages and sets up the environment

# Function to check and install packages
install_if_missing <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    message(paste("Installing package:", package))
    install.packages(package)
  } else {
    message(paste("Package already installed:", package))
  }
}

# Required packages
required_packages <- c(
  "R6",
  "dplyr",
  "readr",
  "purrr",
  "stringr",
  "tidyr",
  "here",
  "quarto"
)

# Install required packages
for (pkg in required_packages) {
  install_if_missing(pkg)
}

# Check for R6 class files in the current package
message("\nChecking for R6 class files in neuro2 package...")
r6_files <- c(
  "R/ReportTemplateR6.R",
  "R/NeuropsychResultsR6.R",
  "R/NeuropsychReportSystemR6.R",
  "R/DomainProcessorR6.R",
  "R/DotplotR6.R",
  "R/DrilldownR6.R",
  "R/DuckDBProcessorR6.R",
  "R/ReportUtilitiesR6.R",
  "R/TableGT.R",
  "R/TemplateContentManagerR6.R"
)

missing_files <- r6_files[!file.exists(r6_files)]
if (length(missing_files) > 0) {
  message("⚠️ Some R6 class files are missing:")
  for (file in missing_files) {
    message(paste0("  - ", file))
  }
  message("The workflow may not function correctly without these files.")
} else {
  message("✓ All required R6 class files are present.")
}

# Check for utility functions file
message("\nChecking for utility functions file...")
utility_file <- "R/utility_functions.R"
if (file.exists(utility_file)) {
  message("✓ utility_functions.R file found")
} else {
  message("⚠️ utility_functions.R file not found")
  message("Creating utility_functions.R with required functions...")

  # Create utility functions content using concatenated strings
  utility_content <- paste0(
    "#' Utility functions to replace NeurotypR dependencies\n",
    "#'\n",
    "#' This file contains utility functions that replace NeurotypR functions\n",
    "#' used in the neuro2 package.\n",
    "\n",
    "#' Filter data by domain and scale\n",
    "#'\n",
    "#' @param data Data frame to filter\n",
    "#' @param domain Domain(s) to filter by\n",
    "#' @param scale Scale(s) to filter by\n",
    "#' @return Filtered data frame\n",
    "#' @export\n",
    "filter_data <- function(data, domain = NULL, scale = NULL) {\n",
    "  if (is.null(data)) {\n",
    "    message(\"Data is NULL. Cannot filter.\")\n",
    "    return(NULL)\n",
    "  }\n",
    "  \n",
    "  # Filter by domain if provided\n",
    "  if (!is.null(domain)) {\n",
    "    if (\"domain\" %in% colnames(data)) {\n",
    "      data <- data[data$domain %in% domain, ]\n",
    "    } else {\n",
    "      message(\"Column 'domain' not found in data. Skipping domain filtering.\")\n",
    "    }\n",
    "  }\n",
    "  \n",
    "  # Filter by scale if provided\n",
    "  if (!is.null(scale)) {\n",
    "    if (\"scale\" %in% colnames(data)) {\n",
    "      data <- data[data$scale %in% scale, ]\n",
    "    } else {\n",
    "      message(\"Column 'scale' not found in data. Skipping scale filtering.\")\n",
    "    }\n",
    "  }\n",
    "  \n",
    "  return(data)\n",
    "}\n",
    "\n",
    "#' Create a dot plot\n",
    "#'\n",
    "#' @param data Data frame containing the data\n",
    "#' @param x Numeric vector for x-axis\n",
    "#' @param y Character vector for y-axis\n",
    "#' @param colors Optional color vector\n",
    "#' @param return_plot Whether to return the plot object\n",
    "#' @param filename Optional filename to save the plot\n",
    "#' @param na.rm Whether to remove NA values\n",
    "#' @return A ggplot object if return_plot is TRUE\n",
    "#' @export\n",
    "dotplot2 <- function(data, x, y, colors = NULL, return_plot = TRUE, filename = NULL, na.rm = TRUE) {\n",
    "  # Check if ggplot2 is available\n",
    "  if (!requireNamespace(\"ggplot2\", quietly = TRUE)) {\n",
    "    message(\"ggplot2 package is required for plotting. Please install it.\")\n",
    "    return(NULL)\n",
    "  }\n",
    "  \n",
    "  # Remove NA values if requested\n",
    "  if (na.rm) {\n",
    "    valid_indices <- !is.na(x) & !is.na(y)\n",
    "    x <- x[valid_indices]\n",
    "    y <- y[valid_indices]\n",
    "    if (!is.null(data)) {\n",
    "      data <- data[valid_indices, ]\n",
    "    }\n",
    "  }\n",
    "  \n",
    "  # Create a data frame for plotting\n",
    "  plot_data <- data.frame(x = x, y = y)\n",
    "  \n",
    "  # Create the plot\n",
    "  plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = x, y = y)) +\n",
    "    ggplot2::geom_point(size = 3) +\n",
    "    ggplot2::geom_vline(xintercept = 0, linetype = \"dashed\", color = \"gray50\") +\n",
    "    ggplot2::geom_vline(xintercept = c(-1, 1), linetype = \"dotted\", color = \"gray70\") +\n",
    "    ggplot2::scale_x_continuous(limits = c(-3, 3), breaks = seq(-3, 3, 1)) +\n",
    "    ggplot2::theme_minimal() +\n",
    "    ggplot2::labs(x = \"Z-Score\", y = \"\")\n",
    "  \n",
    "  # Save the plot if filename is provided\n",
    "  if (!is.null(filename)) {\n",
    "    ggplot2::ggsave(filename, plot, width = 6, height = 4)\n",
    "  }\n",
    "  \n",
    "  if (return_plot) {\n",
    "    return(plot)\n",
    "  } else {\n",
    "    return(invisible(NULL))\n",
    "  }\n",
    "}\n",
    "\n",
    "#' Create a GT table\n",
    "#'\n",
    "#' @param data Data frame to display in the table\n",
    "#' @param pheno Phenotype name\n",
    "#' @param table_name Table name\n",
    "#' @param vertical_padding Vertical padding\n",
    "#' @param source_note Source note\n",
    "#' @param dynamic_grp Dynamic group\n",
    "#' @param multiline Whether to allow multiline text\n",
    "#' @return A GT table object\n",
    "#' @export\n",
    "tbl_gt <- function(data, pheno, table_name = NULL, vertical_padding = 0, \n",
    "                   source_note = NULL, dynamic_grp = NULL, multiline = TRUE) {\n",
    "  # Check if gt package is available\n",
    "  if (!requireNamespace(\"gt\", quietly = TRUE)) {\n",
    "    message(\"gt package is required for table creation. Please install it.\")\n",
    "    return(NULL)\n",
    "  }\n",
    "  \n",
    "  # Check if data is valid\n",
    "  if (is.null(data) || nrow(data) == 0) {\n",
    "    message(\"No data available for table creation.\")\n",
    "    return(NULL)\n",
    "  }\n",
    "  \n",
    "  message(\"Creating table with \", nrow(data), \" rows\")\n",
    "  \n",
    "  # Create a basic gt table\n",
    "  table <- gt::gt(data)\n",
    "  \n",
    "  # Add title\n",
    "  if (!is.null(table_name)) {\n",
    "    table <- gt::tab_header(table, title = paste0(pheno, \" Scores\"))\n",
    "  }\n",
    "  \n",
    "  # Add source note\n",
    "  if (!is.null(source_note)) {\n",
    "    table <- gt::tab_source_note(table, source_note)\n",
    "  }\n",
    "  \n",
    "  # Save the table as an image\n",
    "  table_file <- paste0(\"data/table_\", pheno, \".png\")\n",
    "  message(\"Saving table to \", table_file)\n",
    "  \n",
    "  # Try to save the table\n",
    "  tryCatch({\n",
    "    gt::gtsave(table, filename = table_file, expand = 10)\n",
    "    message(\"Table saved successfully\")\n",
    "  }, error = function(e) {\n",
    "    message(\"Error saving table: \", e$message)\n",
    "  })\n",
    "  \n",
    "  return(table)\n",
    "}\n"
  )

  # Write the utility functions file
  cat(utility_content, file = utility_file)
  message("✓ Created utility_functions.R file")
}

# Check for required packages for utility functions
message("\nChecking for packages needed by utility functions...")
utility_packages <- c("ggplot2", "gt")
for (pkg in utility_packages) {
  install_if_missing(pkg)
}

# Check for template directories
template_dirs <- c(
  "inst/quarto/_extensions/brainworkup/neurotyp-adult",
  "inst/quarto/_extensions/brainworkup/neurotyp-forensic",
  "inst/quarto/_extensions/brainworkup/neurotyp-pediatric"
)

for (template_dir in template_dirs) {
  if (!dir.exists(template_dir)) {
    message("\nTemplate directory not found:", template_dir)
    message("Creating directory structure...")
    dir.create(template_dir, recursive = TRUE, showWarnings = FALSE)
    message("You need to ensure template files are placed in this directory.")
  } else {
    message("\n✓ Template directory exists:", template_dir)
  }
}

# Check for data directories
for (dir in c("data-raw", "data", "output")) {
  if (!dir.exists(dir)) {
    message(paste0("\nCreating directory: ", dir))
    dir.create(dir, showWarnings = FALSE)
  } else {
    message(paste0("\n✓ Directory exists: ", dir))
  }
}

# Check for CSV files in data-raw/csv
csv_files <- list.files(path = "data-raw/csv", pattern = "\\.csv$")
if (length(csv_files) == 0) {
  message("\n⚠️ No CSV files found in data-raw/csv directory.")
  message("You need to add CSV files before running the workflow.")
} else {
  message(paste0(
    "\n✓ Found ",
    length(csv_files),
    " CSV files in data-raw/csv directory:"
  ))
  for (file in csv_files) {
    message(paste0("  - ", file))
  }
}

# Check only for essential template files that should already exist
# Other template files will be copied by the WorkflowRunner later
qmd_files <- c(
  "template.qmd"  # Only check for the main template file
)

message("\nChecking for essential template files...")
for (file in qmd_files) {
  if (file.exists(file)) {
    message(paste0("✓ Found template file: ", file))
  } else {
    message(paste0("⚠️ Essential template file not found: ", file))
    message("  This file is required and should be created before running the workflow.")
  }
}

message("\n✓ Environment setup complete.")
message("You can now run the workflow with: source('run_test_workflow.R')")
