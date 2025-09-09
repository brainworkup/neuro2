#' Analyze the batch_domain_processor.R file to find the loop problem
#' Run this to see what's causing multiple executions

# Read the problematic file
batch_file <- "inst/scripts/batch_domain_processor.R"

if (!file.exists(batch_file)) {
  stop("batch_domain_processor.R not found!")
}

cat("=== ANALYZING BATCH PROCESSOR ===\n\n")

# Read the file
content <- readLines(batch_file, warn = FALSE)

# Find all loops
loop_types <- list(
  for_loops = grep("^[^#]*for\\s*\\(", content),
  while_loops = grep("^[^#]*while\\s*\\(", content),
  repeat_loops = grep("^[^#]*repeat\\s*\\{", content),
  lapply_calls = grep("^[^#]*lapply\\(", content),
  sapply_calls = grep("^[^#]*sapply\\(", content),
  map_calls = grep("^[^#]*map\\(|purrr::", content)
)

# Report findings
total_loops <- sum(lengths(loop_types))
cat("Found", total_loops, "loop constructs:\n")

for (type in names(loop_types)) {
  if (length(loop_types[[type]]) > 0) {
    cat("\n", type, "(", length(loop_types[[type]]), "instances ):\n")
    for (line_num in loop_types[[type]]) {
      cat("  Line", line_num, ":", trimws(content[line_num]), "\n")
      
      # Check for nested loops (look ahead 10 lines)
      check_end <- min(line_num + 10, length(content))
      check_lines <- content[(line_num+1):check_end]
      nested <- grep("for\\s*\\(|while\\s*\\(|lapply\\(", check_lines)
      if (length(nested) > 0) {
        cat("    ⚠️  POSSIBLE NESTED LOOP at line", line_num + nested[1], "\n")
      }
    }
  }
}

# Look for specific problem patterns
cat("\n=== CHECKING FOR PROBLEM PATTERNS ===\n")

# Pattern 1: Multiple domain iterations
domain_iterations <- grep("domains|domain_list|domain_config", content, ignore.case = TRUE)
if (length(domain_iterations) > 5) {
  cat("⚠️  Found", length(domain_iterations), "references to domains - possible repeated processing\n")
}

# Pattern 2: Recursive function calls
process_calls <- grep("process|generate|create", content, ignore.case = TRUE)
if (length(process_calls) > 10) {
  cat("⚠️  Found", length(process_calls), "process/generate calls - check for recursion\n")
}

# Pattern 3: Multiple file generations
file_writes <- grep("write|save|ggsave|cat.*file", content, ignore.case = TRUE)
if (length(file_writes) > 0) {
  cat("⚠️  Found", length(file_writes), "file write operations\n")
  
  # Check if they're in loops
  for (fw in file_writes) {
    # Find the nearest loop before this line
    loops_before <- which(loop_types$for_loops < fw)
    if (length(loops_before) > 0) {
      nearest_loop <- loop_types$for_loops[max(loops_before)]
      if (fw - nearest_loop < 20) {  # Within 20 lines
        cat("    Line", fw, "is inside a loop starting at line", nearest_loop, "\n")
      }
    }
  }
}

# Pattern 4: Check for the actual domain list
cat("\n=== DOMAIN PROCESSING STRUCTURE ===\n")

# Find where domains are defined
domain_defs <- grep("domains?\\s*<-|domains?\\s*=", content)
if (length(domain_defs) > 0) {
  cat("Domain definitions found at lines:", paste(domain_defs, collapse = ", "), "\n")
  for (dd in domain_defs[1:min(3, length(domain_defs))]) {
    cat("  Line", dd, ":", trimws(content[dd]), "\n")
  }
}

# Find the main processing loop
main_loops <- character()
for (i in loop_types$for_loops) {
  # Check if this loop mentions domains
  loop_context <- content[i:min(i+5, length(content))]
  if (any(grepl("domain", loop_context, ignore.case = TRUE))) {
    main_loops <- c(main_loops, paste("Line", i, ":", trimws(content[i])))
  }
}

if (length(main_loops) > 0) {
  cat("\nMain domain processing loops:\n")
  for (ml in main_loops) {
    cat("  ", ml, "\n")
  }
}

# Suggestion for fix
cat("\n=== SUGGESTED FIX ===\n")
cat("The script appears to have multiple loops processing domains.\n")
cat("To fix the triple execution:\n")
cat("1. Consolidate all domain processing into a SINGLE loop\n")
cat("2. Remove nested loops that re-process the same domains\n")
cat("3. Use a flag to track which domains have been processed\n")
cat("4. Consider using vectorized operations instead of loops\n")

# Create a simple template for proper batch processing
cat("\n=== RECOMMENDED STRUCTURE ===\n")
cat('
# Good batch processor structure:
domains_to_process <- c("iq", "memory", "executive", ...)

# Single loop, single execution per domain
processed_domains <- list()

for (domain in domains_to_process) {
  # Check if already processed
  if (domain %in% names(processed_domains)) {
    message("Skipping already processed: ", domain)
    next
  }
  
  # Process ONCE
  result <- process_domain(domain)
  processed_domains[[domain]] <- result
  
  # No nested loops, no recursive calls
}
')
