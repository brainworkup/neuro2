pkgname <- "neuro2"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('neuro2')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("ReportUtilitiesR6")
### * ReportUtilitiesR6

flush(stderr()); flush(stdout())

### Name: ReportUtilitiesR6
### Title: Report Utilities for Neuropsychological Assessment
### Aliases: ReportUtilitiesR6

### ** Examples

# Example 1: Basic usage
# Initialize the utilities class
report_utils <- ReportUtilitiesR6$new(
  config = list(
    output_base_dir = "reports",
    template_dir = "templates"
  )
)

# Set up the environment and prepare data
report_utils$setup_environment()
report_utils$prepare_data_files("raw_data", "processed_data")

# Example 2: Process domains and render a report
# Initialize with a specific configuration
report_utils <- ReportUtilitiesR6$new(
  config = list(
    domains = c("memory", "executive", "attention"),
    template = "comprehensive_report.qmd"
  )
)

# Process the domains and render the report
report_utils$process_domains(
  domains = report_utils$config$domains,
  output_dir = "output/domains"
)
report_utils$render_report(
  template_file = report_utils$config$template,
  output_dir = "reports",
  output_name = "neuropsych_evaluation"
)




cleanEx()
nameEx("TemplateContentManagerR6")
### * TemplateContentManagerR6

flush(stderr()); flush(stdout())

### Name: TemplateContentManagerR6
### Title: Template Content Manager for Neuropsychological Reports
### Aliases: TemplateContentManagerR6

### ** Examples

# Example 1: Initialize and list available sections
template_mgr <- TemplateContentManagerR6$new()
sections <- template_mgr$get_available_sections()
print(sections$domains) # List available domain templates

# Example 2: Retrieve content from a specific template file
template_mgr <- TemplateContentManagerR6$new(
  template_dir = "inst/extdata/_extensions/neurotyp-adult"
)
iq_content <- template_mgr$get_content("_02-01_iq.qmd")
if (!is.null(iq_content)) {
  # Process or display the IQ section content
  cat(paste(head(iq_content, 10), collapse = "\n"))
}




cleanEx()
nameEx("concatenate_results")
### * concatenate_results

flush(stderr()); flush(stdout())

### Name: concatenate_results
### Title: Concatenate Results
### Aliases: concatenate_results

### ** Examples

df <- data.frame(
  scale = c("IQ", "Memory"),
  score = c(100, 80),
  range = c("Above Average", "Below Average"),
  percentile = c(75, 25),
  ci_95 = c("[95, 105]", "[75, 85]"),
  description = c("intelligence", "memory")
)
concatenate_results(df)




cleanEx()
nameEx("neurotypr_utils")
### * neurotypr_utils

flush(stderr()); flush(stdout())

### Name: neurotypr_utils
### Title: Enhanced Utility Functions for NeurotypR
### Aliases: neurotypr_utils %||%
### Keywords: Coalescing Null Operator internal

### ** Examples

# Returns "default" because x is NULL
x <- NULL
x %||% "default"

# Returns "value" because x is not NULL
x <- "value"
x %||% "default"



### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
