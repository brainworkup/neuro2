# Load the neuro2 package
devtools::load_all()

# Define domain constants first
domain_iq <- "General Cognitive Ability"
domain_academics <- "Academic Skills"
domain_verbal <- "Verbal/Language"
domain_spatial <- "Visual Perception/Construction"
domain_memory <- "Memory"
domain_executive <- "Attention/Executive"
domain_motor <- "Motor"
domain_social <- "Social Cognition"
domain_adhd_adult <- "ADHD"
domain_emotion_adult <- "Emotional/Behavioral/Personality"

# Now use the report system
report_system <- NeuropsychReportSystemR6$new(
  config = list(
    patient = "Biggie",
    domains = c(domain_memory, domain_executive),
    template_file = "template.qmd"
  )
)

# Just initialize but don't run the full workflow for this test
# Comment out the workflow run line for testing
# report_system$run_workflow()

# Print confirmation that the system initialized correctly
cat(
  "Report system initialized successfully with domains:",
  paste(report_system$config$domains, collapse = ", "),
  "\n"
)
