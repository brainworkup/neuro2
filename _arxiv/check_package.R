# Script to check if R6 classes and utility functions are properly loaded
# Run this script to verify class availability and functionality

# Load required R6 library
tryCatch(
  {
    library(R6)
    message("✓ R6 package loaded successfully")
  },
  error = function(e) {
    message("✗ Error loading R6 package:")
    message(e$message)
    message("\nPlease install the R6 package with: install.packages('R6')")
    return(FALSE)
  }
)

# Load R6 class files from current package
message("\nLoading R6 class files from neuro2 package...")
r6_files <- list.files("R", pattern = "R6\\.R$", full.names = TRUE)
for (file in r6_files) {
  tryCatch(
    {
      source(file)
      message(paste0("✓ Loaded ", basename(file)))
    },
    error = function(e) {
      message(paste0("✗ Error loading ", basename(file), ": ", e$message))
    }
  )
}

# Load utility functions
message("\nLoading utility functions...")
utility_file <- "R/utility_functions.R"
if (file.exists(utility_file)) {
  tryCatch(
    {
      source(utility_file)
      message("✓ Loaded utility_functions.R")
    },
    error = function(e) {
      message("✗ Error loading utility_functions.R: ", e$message)
    }
  )
} else {
  message("✗ utility_functions.R file not found")
}

# Check if the R6 classes are available
check_class <- function(class_name) {
  result <- tryCatch(
    {
      exists(class_name, mode = "environment") ||
        exists(paste0(class_name, "$new"), mode = "function")
    },
    error = function(e) {
      return(FALSE)
    }
  )

  if (result) {
    message(paste0("✓ Class '", class_name, "' is available"))
  } else {
    message(paste0("✗ Class '", class_name, "' is NOT available"))
  }

  return(result)
}

# Check if utility functions are available
check_function <- function(function_name) {
  result <- exists(function_name, mode = "function")

  if (result) {
    message(paste0("✓ Function '", function_name, "' is available"))
  } else {
    message(paste0("✗ Function '", function_name, "' is NOT available"))
  }

  return(result)
}

# Check key R6 classes used in the workflow
classes_to_check <- c(
  "ReportTemplateR6",
  "NeuropsychResultsR6",
  "DomainProcessorR6",
  "IQReportGeneratorR6",
  "NeuropsychReportSystemR6"
)

all_classes_available <- TRUE
for (class_name in classes_to_check) {
  if (!check_class(class_name)) {
    all_classes_available <- FALSE
  }
}

# Check utility functions
message("\nChecking utility functions...")
functions_to_check <- c("filter_data", "dotplot2", "tbl_gt")

all_functions_available <- TRUE
for (function_name in functions_to_check) {
  if (!check_function(function_name)) {
    all_functions_available <- FALSE
  }
}

# Provide guidance based on results
if (!all_classes_available) {
  message("\n⚠️ Some required R6 classes are not available.")
  message("This suggests that either:")
  message("1. The R6 class files are not in the expected location")
  message("2. There are errors in the R6 class definitions")
  message("3. The classes have different names than expected")
  message("\nYou may need to:")
  message("- Check that all R6 class files are in the R/ directory")
  message("- Fix any errors in the R6 class definitions")
} else {
  message("\n✓ All required R6 classes are available.")
}

if (!all_functions_available) {
  message("\n⚠️ Some utility functions are not available.")
  message("This suggests that either:")
  message("1. The utility_functions.R file is not being sourced correctly")
  message("2. There are errors in the utility function definitions")
  message("\nYou may need to:")
  message("- Check that utility_functions.R is in the R/ directory")
  message("- Fix any errors in the utility function definitions")
} else {
  message("\n✓ All utility functions are available.")
}

if (all_classes_available && all_functions_available) {
  message(
    "\n✓ All required components are available. The workflow should work correctly."
  )
}

# Try to create an instance of one of the classes
message("\nTrying to create an instance of ReportTemplateR6...")
tryCatch(
  {
    test_instance <- ReportTemplateR6$new()
    message("✓ Successfully created an instance of ReportTemplateR6")
  },
  error = function(e) {
    message("✗ Error creating instance:")
    message(e$message)
  }
)

# Try to use one of the utility functions
message("\nTrying to use filter_data function...")
tryCatch(
  {
    test_data <- data.frame(
      domain = c("General Cognitive Ability", "Memory", "Executive"),
      scale = c("FSIQ", "Memory Index", "Executive Index"),
      score = c(100, 95, 105)
    )

    result <- filter_data(test_data, domain = "Memory")
    if (nrow(result) == 1) {
      message("✓ Successfully used filter_data function")
    } else {
      message("✗ filter_data function did not work as expected")
    }
  },
  error = function(e) {
    message("✗ Error using filter_data function:")
    message(e$message)
  }
)
