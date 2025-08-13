# Function to ensure all .qmd files end with newline
ensure_final_newlines <- function(pattern = "*.qmd") {
  files <- list.files(pattern = pattern, full.names = TRUE, recursive = TRUE)

  for (file in files) {
    content <- readBin(file, "raw", file.info(file)$size)
    if (length(content) > 0 && tail(content, 1) != as.raw(10)) {
      # Add newline if missing
      writeBin(c(content, as.raw(10)), file)
      message("Added newline to: ", file)
    }
  }
}

# Run before rendering
ensure_final_newlines("_02-*.qmd")
