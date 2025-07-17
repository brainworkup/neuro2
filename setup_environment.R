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
  "R/IQReportGeneratorR6.R",
  "R/DomainProcessorR6.R"
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

  # Create a basic utility_functions.R file if it doesn't exist
  utility_content <- '
#\' Utility functions to replace NeurotypR dependencies
#\'
#\' This file contains utility functions that replace NeurotypR functions
#\' used in the neuro2 package.

#\' Filter data by domain and scale
#\'
#\' @param data Data frame to filter
#\' @param domain Domain(s) to filter by
#\' @param scale Scale(s) to filter by
#\' @return Filtered data frame
#\' @export
filter_data <- function(data, domain = NULL, scale = NULL) {
  if (is.null(data)) {
    message("Data is NULL. Cannot filter.")
    return(NULL)
  }
  
  # Filter by domain if provided
  if (!is.null(domain)) {
    if ("domain" %in% colnames(data)) {
      data <- data[data$domain %in% domain, ]
    } else {
      message("Column \'domain\' not found in data. Skipping domain filtering.")
    }
  }
  
  # Filter by scale if provided
  if (!is.null(scale)) {
    if ("scale" %in% colnames(data)) {
      data <- data[data$scale %in% scale, ]
    } else {
      message("Column \'scale\' not found in data. Skipping scale filtering.")
    }
  }
  
  return(data)
}

#\' Create a dot plot
#\'
#\' @param data Data frame containing the data
#\' @param x Numeric vector for x-axis
#\' @param y Character vector for y-axis
#\' @param colors Optional color vector
#\' @param return_plot Whether to return the plot object
#\' @param filename Optional filename to save the plot
#\' @param na.rm Whether to remove NA values
#\' @return A ggplot object if return_plot is TRUE
#\' @export
dotplot2 <- function(data, x, y, colors = NULL, return_plot = TRUE, filename = NULL, na.rm = TRUE) {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 package is required for plotting. Please install it.")
    return(NULL)
  }
  
  # Remove NA values if requested
  if (na.rm) {
    valid_indices <- !is.na(x) & !is.na(y)
    x <- x[valid_indices]
    y <- y[valid_indices]
    if (!is.null(data)) {
      data <- data[valid_indices, ]
    }
  }
  
  # Create a data frame for plotting
  plot_data <- data.frame(x = x, y = y)
  
  # Create the plot
  plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    ggplot2::geom_vline(xintercept = c(-1, 1), linetype = "dotted", color = "gray70") +
    ggplot2::scale_x_continuous(limits = c(-3, 3), breaks = seq(-3, 3, 1)) +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = "Z-Score", y = "")
  
  # Save the plot if filename is provided
  if (!is.null(filename)) {
    ggplot2::ggsave(filename, plot, width = 6, height = 4)
  }
  
  if (return_plot) {
    return(plot)
  } else {
    return(invisible(NULL))
  }
}

#\' Create a GT table
#\'
#\' @param data Data frame to display in the table
#\' @param pheno Phenotype name
#\' @param table_name Table name
#\' @param vertical_padding Vertical padding
#\' @param source_note Source note
#\' @param dynamic_grp Dynamic group
#\' @param multiline Whether to allow multiline text
#\' @return A GT table object
#\' @export
tbl_gt <- function(data, pheno, table_name = NULL, vertical_padding = 0, 
                   source_note = NULL, dynamic_grp = NULL, multiline = TRUE) {
  # Check if gt package is available
  if (!requireNamespace("gt", quietly = TRUE)) {
    message("gt package is required for table creation. Please install it.")
    return(NULL)
  }
  
  # Check if data is valid
  if (is.null(data) || nrow(data) == 0) {
    message("No data available for table creation.")
    return(NULL)
  }
  
  message("Creating table with ", nrow(data), " rows")
  
  # Create a basic gt table
  table <- gt::gt(data)
  
  # Add title
  if (!is.null(table_name)) {
    table <- gt::tab_header(table, title = paste0(pheno, " Scores"))
  }
  
  # Add source note
  if (!is.null(source_note)) {
    table <- gt::tab_source_note(table, source_note)
  }
  
  # Save the table as an image
  table_file <- paste0("data/table_", pheno, ".png")
  message("Saving table to ", table_file)
  
  # Try to save the table
  tryCatch({
    gt::gtsave(table, filename = table_file, expand = 10)
    message("Table saved successfully")
  }, error = function(e) {
    message("Error saving table: ", e$message)
  })
  
  return(table)
}
'

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

# Check for template directory
template_dir <- "inst/extdata/_extensions/neurotyp-forensic"
if (!dir.exists(template_dir)) {
  message("\nTemplate directory not found:", template_dir)
  message("Creating directory structure...")
  dir.create(template_dir, recursive = TRUE, showWarnings = FALSE)
  message("You need to ensure template files are placed in this directory.")
} else {
  message("\n✓ Template directory exists:", template_dir)
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

# Check for CSV files in data-raw
csv_files <- list.files(path = "data-raw", pattern = "\\.csv$")
if (length(csv_files) == 0) {
  message("\n⚠️ No CSV files found in data-raw directory.")
  message("You need to add CSV files before running the workflow.")
} else {
  message(paste0(
    "\n✓ Found ",
    length(csv_files),
    " CSV files in data-raw directory:"
  ))
  for (file in csv_files) {
    message(paste0("  - ", file))
  }
}

# Check for template QMD files
qmd_files <- c(
  "_01-00_nse_forensic.qmd",
  "_02-00_behav_obs.qmd",
  "_02-01_iq_text.qmd",
  "_02-05_memory_text.qmd",
  "_03-00_sirf_text.qmd",
  "_03-01_recs.qmd"
)

missing_qmd <- qmd_files[!file.exists(qmd_files)]
if (length(missing_qmd) > 0) {
  message("\n⚠️ Some template QMD files are missing:")
  for (file in missing_qmd) {
    message(paste0("  - ", file))
  }
  message("These files are needed for the report template.")
} else {
  message("\n✓ All template QMD files are present.")
}

message("\n✓ Environment setup complete.")
message("You can now run the workflow with: source('run_test_workflow.R')")
