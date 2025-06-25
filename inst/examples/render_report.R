# Load the package
library(neuro2)

# 1. Create the generator with HTML-compatible params
gen <- ReportGenerator$new(
  params = list(
    patient = "Jane Doe",
    dob = "2010-04-15",
    author = "Clinician Name",
    date = format(Sys.Date(), "%Y-%m-%d")
  ),
  output_dir = "reports2"
)

# 2. Render directly using HTML format
gen$render(output_file = "jane_doe_report.pdf")
