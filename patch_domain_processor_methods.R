
# Patched methods for DomainProcessorR6
# Source this AFTER loading the original class

# Store original methods if they exist
if (exists("DomainProcessorR6")) {
  .original_generate_standard_qmd <- DomainProcessorR6$public_methods$generate_standard_qmd
  .original_generate_emotion_qmd <- DomainProcessorR6$public_methods$generate_emotion_qmd
  
  # Override the generate_standard_qmd method
  DomainProcessorR6$set("public", "generate_standard_qmd", function(domain_name, output_file) {
    # Ensure figs directory exists
    if (!dir.exists("figs")) {
      dir.create("figs", showWarnings = FALSE)
    }
    
    # Call original method if it exists
    if (!is.null(.original_generate_standard_qmd)) {
      result <- .original_generate_standard_qmd(domain_name, output_file)
    }
    
    # Fix the generated file to have correct paths
    if (file.exists(output_file)) {
      content <- readLines(output_file)
      
      # Fix file paths in the generated QMD
      content <- gsub(
        '#let file_qtbl = "table_',
        '#let file_qtbl = "figs/table_',
        content,
        fixed = TRUE
      )
      content <- gsub(
        '#let file_fig = "fig_',
        '#let file_fig = "figs/fig_',
        content,
        fixed = TRUE
      )
      
      writeLines(content, output_file)
    }
    
    return(output_file)
  })
  
  message("✅ Patched DomainProcessorR6 methods")
}

