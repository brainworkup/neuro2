# Script to check if R6 classes are properly loaded
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

# Check key R6 classes used in the workflow
classes_to_check <- c(
  "ReportTemplateR6",
  "NeuropsychResultsR6",
  "DomainProcessorR6",
  "IQReportGeneratorR6",
  "NeuropsychReportSystemR6"
)

all_available <- TRUE
for (class_name in classes_to_check) {
  if (!check_class(class_name)) {
    all_available <- FALSE
  }
}

# Provide guidance based on results
if (!all_available) {
  message("\n⚠️ Some required classes are not available.")
  message("This suggests that either:")
  message("1. The NeurotypR package is not installed correctly")
  message("2. The R6 classes are not properly exported from the package")
  message("3. The classes have different names than expected")
  message("\nYou may need to:")
  message("- Reinstall the package")
  message("- Check the package documentation for correct class names")
  message("- Ensure the package exports these classes")
} else {
  message(
    "\n✓ All required classes are available. The workflow should work correctly."
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
