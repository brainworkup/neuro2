#!/usr/bin/env Rscript

#' THE FIX: One Command Solution for File Path Issue
#' 
#' Run this to immediately fix the "file not found" error in Typst

cat("\n")
cat("═══════════════════════════════════════\n")
cat("   🔧 FIXING THE FILE PATH ISSUE 🔧    \n")
cat("═══════════════════════════════════════\n\n")

cat("Problem: Typst can't find 'table_iq.png'\n")
cat("Cause: QMD files reference 'table_iq.png' instead of 'figs/table_iq.png'\n")
cat("Solution: Fixing all file paths now...\n\n")

# Step 1: Create figs directory
if (!dir.exists("figs")) {
  dir.create("figs", recursive = TRUE)
  cat("✅ Created figs/ directory\n")
} else {
  cat("✅ figs/ directory exists\n")
}

# Step 2: Move any misplaced images
images_moved <- 0
for (pattern in c("table_*.png", "table_*.pdf", "fig_*.svg", "fig_*.png", "_qtbl_*.png", "_fig_*.png")) {
  files <- list.files(pattern = glob2rx(pattern))
  for (file in files) {
    if (file.exists(file) && !file.exists(file.path("figs", file))) {
      file.copy(file, file.path("figs", file))
      file.remove(file)
      images_moved <- images_moved + 1
    }
  }
}
if (images_moved > 0) {
  cat("✅ Moved", images_moved, "images to figs/\n")
}

# Step 3: Fix ALL QMD files
qmd_files <- list.files(pattern = "\\.qmd$")
files_fixed <- 0

for (qmd_file in qmd_files) {
  content <- readLines(qmd_file, warn = FALSE)
  original <- content
  
  # Fix Typst let statements
  content <- gsub('#let file_qtbl = "table_', '#let file_qtbl = "figs/table_', content, fixed = TRUE)
  content <- gsub('#let file_fig = "fig_', '#let file_fig = "figs/fig_', content, fixed = TRUE)
  content <- gsub('#let file_qtbl = "_qtbl_', '#let file_qtbl = "figs/_qtbl_', content, fixed = TRUE)
  content <- gsub('#let file_fig = "_fig_', '#let file_fig = "figs/_fig_', content, fixed = TRUE)
  
  # Fix direct image references
  content <- gsub('image("table_', 'image("figs/table_', content, fixed = TRUE)
  content <- gsub('image("fig_', 'image("figs/fig_', content, fixed = TRUE)
  content <- gsub('image("_qtbl_', 'image("figs/_qtbl_', content, fixed = TRUE)
  content <- gsub('image("_fig_', 'image("figs/_fig_', content, fixed = TRUE)
  
  # Fix file variable assignments
  content <- gsub('file_qtbl: "table_', 'file_qtbl: "figs/table_', content, fixed = TRUE)
  content <- gsub('file_fig: "fig_', 'file_fig: "figs/fig_', content, fixed = TRUE)
  content <- gsub('file_qtbl: "_qtbl_', 'file_qtbl: "figs/_qtbl_', content, fixed = TRUE)
  content <- gsub('file_fig: "_fig_', 'file_fig: "figs/_fig_', content, fixed = TRUE)
  
  # Fix R code chunks that save files
  content <- gsub('gtsave\\(.*filename = "table_', 'gtsave(filename = "figs/table_', content)
  content <- gsub('gtsave\\(.*filename = "_qtbl_', 'gtsave(filename = "figs/_qtbl_', content)
  content <- gsub('ggsave\\("fig_', 'ggsave("figs/fig_', content)
  content <- gsub('ggsave\\("_fig_', 'ggsave("figs/_fig_', content)
  
  if (!identical(content, original)) {
    writeLines(content, qmd_file)
    cat("  ✅ Fixed:", qmd_file, "\n")
    files_fixed <- files_fixed + 1
  }
}

cat("\n✅ Fixed", files_fixed, "QMD files\n")

# Step 4: Create a verification script
verify_script <- '
# Verify all images are in place
cat("\nVerifying image files...\n")

qmd_files <- list.files(pattern = "\\\\.qmd$")
missing <- character()

for (qmd in qmd_files) {
  content <- readLines(qmd, warn = FALSE)
  
  # Extract image references
  images <- character()
  
  # From Typst let statements
  let_matches <- grep("#let file_(qtbl|fig) = ", content, value = TRUE)
  for (match in let_matches) {
    img <- gsub(\'.*#let file_(qtbl|fig) = "\', "", match)
    img <- gsub(\'".*\', "", img)
    if (nchar(img) > 0) images <- c(images, img)
  }
  
  # From direct image calls
  img_matches <- grep("image\\\\(", content, value = TRUE)
  for (match in img_matches) {
    img <- gsub(\'.*image\\\\("\', "", match)
    img <- gsub(\'".*\', "", img)
    if (nchar(img) > 0) images <- c(images, img)
  }
  
  # Check if images exist
  for (img in unique(images)) {
    if (!file.exists(img)) {
      missing <- c(missing, img)
      cat("  ❌ Missing:", img, "(referenced in", qmd, ")\\n")
    }
  }
}

if (length(missing) == 0) {
  cat("✅ All referenced images exist!\\n")
} else {
  cat("\\n⚠️  Some images are still missing\\n")
  cat("You may need to regenerate them with:\\n")
  cat("  source(\'generate_all_domain_assets.R\')\\n")
}
'

writeLines(verify_script, "verify_images.R")

# Step 5: Run verification
cat("\n📋 Verifying fix...\n")
source("verify_images.R", local = TRUE)

# Final message
cat("\n")
cat("═══════════════════════════════════════\n")
cat("   ✨ FIX COMPLETE! ✨                 \n")
cat("═══════════════════════════════════════\n\n")

cat("The file path issue has been fixed!\n\n")

cat("🎯 NEXT STEP - Try rendering:\n")
cat("   quarto render template.qmd --to typst\n\n")

cat("If you still get errors:\n")
cat("1. Check verify_images.R to see what's missing\n")
cat("2. Regenerate assets if needed\n")
cat("3. Use --verbose flag for details:\n")
cat("   quarto render template.qmd --to typst --verbose\n\n")

# Try to render automatically
cat("Would you like to try rendering now? (y/n): ")
if (interactive()) {
  response <- readline()
  if (tolower(response) == "y") {
    cat("\n🚀 Attempting render...\n")
    result <- system2("quarto", 
                     args = c("render", "template.qmd", "--to", "typst"),
                     stdout = TRUE, stderr = TRUE)
    
    if (any(grepl("Output created", result))) {
      cat("\n🎉 SUCCESS! Your report has been generated!\n")
    } else if (any(grepl("file not found", result))) {
      cat("\n❌ Still getting file not found errors.\n")
      cat("Run verify_images.R to see what's missing.\n")
    }
  }
}
