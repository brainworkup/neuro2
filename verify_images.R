
# Verify all images are in place
cat("
Verifying image files...
")

qmd_files <- list.files(pattern = "\\.qmd$")
missing <- character()

for (qmd in qmd_files) {
  content <- readLines(qmd, warn = FALSE)
  
  # Extract image references
  images <- character()
  
  # From Typst let statements
  let_matches <- grep("#let file_(qtbl|fig) = ", content, value = TRUE)
  for (match in let_matches) {
    img <- gsub('.*#let file_(qtbl|fig) = "', "", match)
    img <- gsub('".*', "", img)
    if (nchar(img) > 0) images <- c(images, img)
  }
  
  # From direct image calls
  img_matches <- grep("image\\(", content, value = TRUE)
  for (match in img_matches) {
    img <- gsub('.*image\\("', "", match)
    img <- gsub('".*', "", img)
    if (nchar(img) > 0) images <- c(images, img)
  }
  
  # Check if images exist
  for (img in unique(images)) {
    if (!file.exists(img)) {
      missing <- c(missing, img)
      cat("  ❌ Missing:", img, "(referenced in", qmd, ")\n")
    }
  }
}

if (length(missing) == 0) {
  cat("✅ All referenced images exist!\n")
} else {
  cat("\n⚠️  Some images are still missing\n")
  cat("You may need to regenerate them with:\n")
  cat("  source('generate_all_domain_assets.R')\n")
}

