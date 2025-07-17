# Script to create sysdata.rda with proper data structure

# Read the CSV files
neurocog <- read.csv("data/neurocog.csv", stringsAsFactors = FALSE)
neurobehav <- read.csv("data/neurobehav.csv", stringsAsFactors = FALSE)
neuropsych <- read.csv("data/neuropsych.csv", stringsAsFactors = FALSE)
validity <- read.csv("data/validity.csv", stringsAsFactors = FALSE)

# Save to sysdata.rda
save(
  neurocog,
  neurobehav,
  neuropsych,
  validity,
  file = "R/sysdata.rda",
  compress = "xz"
)

# Check the structure
cat("neurocog columns:\n")
print(names(neurocog))
cat("\nNumber of rows:", nrow(neurocog), "\n")
