# Check available plot titles in sysdata.rda

library(here)

# Load sysdata
load(here::here("R", "sysdata.rda"))

# Find all plot_title variables
plot_titles <- ls(pattern = "^plot_title_")
cat("Available plot titles:\n")
for (title_var in plot_titles) {
  cat("\n", title_var, ":\n", sep = "")
  cat(get(title_var), "\n")
}