# Script to inspect sysdata.rda contents
# This will help us understand the structure of internal scale data

# Load the sysdata.rda file
load("R/sysdata.rda")

# List all objects in the loaded data
cat("=== Objects in sysdata.rda ===\n")
print(ls())

# Look for ADHD-related scale datasets
adhd_objects <- ls(pattern = "adhd|ADHD")
cat("\n=== ADHD-related objects ===\n")
print(adhd_objects)

# Check for scales_adhd_adult specifically
if ("scales_adhd_adult" %in% ls()) {
  cat("\n=== Structure of scales_adhd_adult ===\n")
  str(scales_adhd_adult)
  
  cat("\n=== First few entries of scales_adhd_adult ===\n")
  print(head(scales_adhd_adult, 20))
  
  cat("\n=== Class of scales_adhd_adult ===\n")
  print(class(scales_adhd_adult))
  
  # If it's a data frame or tibble, show column names
  if (is.data.frame(scales_adhd_adult)) {
    cat("\n=== Column names ===\n")
    print(names(scales_adhd_adult))
    
    # Look for scale names column
    if ("scale" %in% names(scales_adhd_adult)) {
      cat("\n=== Unique scale values ===\n")
      print(unique(scales_adhd_adult$scale))
    }
    
    if ("scale_name" %in% names(scales_adhd_adult)) {
      cat("\n=== Unique scale_name values ===\n")
      print(unique(scales_adhd_adult$scale_name))
    }
  }
  
  # If it's a character vector, show all values
  if (is.character(scales_adhd_adult)) {
    cat("\n=== All scale names ===\n")
    print(scales_adhd_adult)
  }
}

# Look for any other scale-related objects
scale_objects <- ls(pattern = "scale|Scale")
cat("\n=== All scale-related objects ===\n")
print(scale_objects)

# Check domains_map which we saw in create_sysdata.R
if ("domains_map" %in% ls()) {
  cat("\n=== Structure of domains_map ===\n")
  str(domains_map)
  
  # Look for ADHD domain
  if ("ADHD" %in% names(domains_map)) {
    cat("\n=== ADHD domain in domains_map ===\n")
    print(domains_map$ADHD)
  }
}