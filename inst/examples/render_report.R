# Set working directory to package root
setwd(system.file(package = "neuro2"))

library(neuro2)


# 1. Create the generator
gen <- ReportGenerator$new(
  params = list(patient = "Jane Doe", dob = "2010-04-15"),
  output_dir = "reports2"
)

# 2. Point to the installed sections folder
sys_dir <- system.file(
  "quarto",
  "templates",
  "typst-report",
  "sections",
  package = "neuro2"
)

# 3. Build & render in one go
gen$render_sections(
  sections_dir = sys_dir,
  placeholder = "{{sections}}",
  output_file = "jane_doe_report.pdf"
)
