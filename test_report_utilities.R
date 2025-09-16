#!/usr/bin/env Rscript

# Test script for the improved ReportUtilitiesR6 class

cat("Testing ReportUtilitiesR6 class improvements...\n")
cat("==============================================\n\n")

# Load the neuro2 package (assuming we're in development mode)
if (file.exists("DESCRIPTION")) {
  suppressMessages(devtools::load_all("."))
} else {
  library(neuro2)
}

# Test 1: Basic initialization
cat("1. Testing initialization with default config...\n")
report_utils <- ReportUtilitiesR6$new()
cat("   ✓ Default config set:\n")
print(report_utils$config)
cat("\n")

# Test 2: Custom configuration
cat("2. Testing initialization with custom config...\n")
custom_config <- list(
  output_base_dir = "my_reports",
  template_dir = "my_templates",
  domains = c("memory", "attention"),
  template = "my_template.qmd"
)
report_utils_custom <- ReportUtilitiesR6$new(config = custom_config)
cat("   ✓ Custom config merged with defaults:\n")
print(report_utils_custom$config)
cat("\n")

# Test 3: Environment setup
cat("3. Testing environment setup...\n")
tryCatch(
  {
    report_utils$setup_environment()
    cat("   ✓ Environment setup completed successfully\n")
  },
  error = function(e) {
    cat("   ✗ Environment setup failed:", e$message, "\n")
  }
)
cat("\n")

# Test 4: Data preparation (simplified test)
cat("4. Testing data preparation method...\n")
tryCatch(
  {
    # Create a temporary input directory for testing
    test_input_dir <- tempfile("test_input")
    dir.create(test_input_dir)

    # Create a test file
    write.csv(
      data.frame(test = "test", score = 100),
      file.path(test_input_dir, "test_data.csv")
    )

    report_utils$prepare_data_files(test_input_dir, "test_output")
    cat("   ✓ Data preparation method executed (basic validation only)\n")

    # Clean up
    unlink(test_input_dir, recursive = TRUE)
    unlink("test_output", recursive = TRUE)
  },
  error = function(e) {
    cat("   ✗ Data preparation failed:", e$message, "\n")
  }
)
cat("\n")

# Test 5: Domain processing
cat("5. Testing domain processing method...\n")
tryCatch(
  {
    report_utils_custom$process_domains()
    cat("   ✓ Domain processing method executed (basic validation only)\n")
  },
  error = function(e) {
    cat("   ✗ Domain processing failed:", e$message, "\n")
  }
)
cat("\n")

# Test 6: Report rendering
cat("6. Testing report rendering method...\n")
tryCatch(
  {
    # Create a simple test template
    test_template <- tempfile("test_template", fileext = ".qmd")
    writeLines("---\ntitle: 'Test Report'\n---\n\n# Test Content", test_template)

    report_utils$render_report(test_template, "test_reports", "test_report")
    cat("   ✓ Report rendering method executed (basic validation only)\n")

    # Clean up
    unlink(test_template)
    unlink("test_reports", recursive = TRUE)
  },
  error = function(e) {
    cat("   ✗ Report rendering failed:", e$message, "\n")
  }
)
cat("\n")

# Test 7: Install dependencies (dry run - just test the method structure)
cat("7. Testing install dependencies method structure...\n")
tryCatch(
  {
    # This will just test that the method exists and can be called
    # We won't actually install packages in this test
    report_utils$install_dependencies(verbose = FALSE)
    cat("   ✓ Install dependencies method structure is valid\n")
  },
  error = function(e) {
    cat("   ✗ Install dependencies method failed:", e$message, "\n")
  }
)
cat("\n")

cat("Testing completed!\n")
cat("==============================================\n")
cat("The ReportUtilitiesR6 class improvements include:\n")
cat("• Proper configuration management with defaults\n")
cat("• Integrated install_dependencies method (no longer external script)\n")
cat("• Better error handling and validation\n")
cat("• Consistent parameter naming and defaults\n")
cat("• Improved documentation and examples\n")
cat("• TODO placeholders for future implementation\n")
