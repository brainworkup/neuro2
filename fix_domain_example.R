# This is a simplified example to demonstrate the domain_iq error fix

# The error happens because domain_iq is referenced in the NeuropsychReportSystemR6 class
# before it's defined. In the original code, this happens in the initialize method:

# Original problematic code structure:
# ```r
# NeuropsychReportSystemR6 <- R6::R6Class(
#   "NeuropsychReportSystemR6",
#   public = list(
#     initialize = function(config = list()) {
#       default_config <- list(
#         domains = c(
#           domain_iq,    # Error: object 'domain_iq' not found
#           domain_memory,
#           domain_executive
#         )
#       )
#       # ...
#     }
#   )
# )
# ```

# Let's demonstrate a simplified version of the error and the solution
demonstrate_error <- function() {
  # This would fail if run:
  # domains <- c(domain_iq, domain_memory)  # Error: object 'domain_iq' not found

  # But this works because we define the constants first:
  domain_iq <- "General Cognitive Ability"
  domain_memory <- "Memory"
  domains <- c(domain_iq, domain_memory)

  return(domains)
}

# --------------------------
# Call our demonstration function
# --------------------------
domains <- demonstrate_error()

# Output the domains to verify
cat(
  "Successfully created domains array:",
  paste(domains, collapse = ", "),
  "\n"
)

cat(
  "NOTE: In your R6_IMPLEMENTATION_GUIDE.md, we've added the domain constant definitions\n",
  "before creating the NeuropsychReportSystemR6 instance to prevent the 'object not found' error.\n"
)
