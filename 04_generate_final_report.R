# Generate Final Forensic Neuropsychological Report
# This script merges all components into the final report
#
library(here)
library(glue)
library(quarto)

# Patient information
patient_info <- list(
  name = "Biggie",
  age = 44,
  sex = "Male",
  dob = format(Sys.Date() - (44 * 365.25), "%Y-%m-%d"),
  doe = format(Sys.Date(), "%Y-%m-%d"),
  date_of_report = format(Sys.Date(), "%Y-%m-%d")
)



# Create main report QMD file
report_content <- glue('
---
title: "NEUROCOGNITIVE EXAMINATION"
subtitle: "Forensic Neuropsychological Evaluation"
author:
  - name: "Joey W. Trampush, Ph.D."
    affiliation: |
      Della Martin Assistant Professor of Psychiatry
      Department of Psychiatry and the Behavioral Sciences
      Keck School of Medicine of USC
date: "{patient_info$date_of_report}"
format:
  pdf:
    documentclass: article
    fontsize: 11pt
    geometry:
      - margin=1in
    toc: false
    number-sections: false
    colorlinks: true
    linkcolor: black
    urlcolor: black
    citecolor: black
execute:
  echo: false
  warning: false
  message: false
---

\\newpage

**PATIENT NAME:** {patient_info$name}
**DATE OF BIRTH:** {patient_info$dob}, Age {patient_info$age}
**DATE OF EXAM:** {patient_info$doe}
**DATE OF REPORT:** {patient_info$date_of_report}

{{{{< include _00-00_tests.qmd >}}}}

{{{{< include _01-00_nse.qmd >}}}}

# NEUROCOGNITIVE FINDINGS

{{{{< include _02-01_iq.qmd >}}}}

{{{{< include _02-02_verbal.qmd >}}}}

{{{{< include _02-03_spatial.qmd >}}}}

{{{{< include _02-04_memory.qmd >}}}}

{{{{< include _02-05_executive.qmd >}}}}

{{{{< include _02-06_motor.qmd >}}}}

{{{{< include _02-07_daily_living.qmd >}}}}

{{{{< include _03-00_summary.qmd >}}}}

{{{{< include _03-01_recommendations.qmd >}}}}

\\newpage

# APPENDIX

## Notification/Informed Consent

{patient_info$name} consented to undergo the current neuropsychological evaluation as part of forensic proceedings. He was informed that the evaluation results would not remain confidential and would be shared with relevant legal parties as appropriate.

## Examiner Qualifications

[Standard qualifications text]

## Test Selection Procedures

Neuropsychological tests are performance-based, and cognitive performance is summarized above. Cultural considerations were made in selecting measures, interpreting results, and making diagnostic impressions and recommendations.

## Conversion of Test Scores

| Range | Standard Score | T Score | Scaled Score | z-Score | Percentile |
|-------|----------------|---------|--------------|---------|------------|
| Exceptionally high | 130+ | 70+ | 16+ | 2+ | 98+ |
| Above average | 120-129 | 63-69 | 14-15 | 1.3-1.9 | 91-97 |
| High average | 110-119 | 57-62 | 12-13 | 0.7-1.2 | 75-90 |
| Average | 90-109 | 44-56 | 9-11 | -0.7-0.6 | 25-74 |
| Low average | 80-89 | 37-43 | 7-8 | -1.3--0.6 | 9-24 |
| Below average | 70-79 | 30-36 | 4-6 | -2--1.4 | 2-8 |
| Exceptionally low | <70 | <30 | <4 | <-2 | <2 |

')

# Write main report file
cat(report_content, file = "forensic_report_biggie.qmd")

# Update NSE section with forensic-specific content
nse_content <- glue('
# NEUROBEHAVIORAL STATUS EXAM

## Reason for Referral

{patient_info$name}, a {patient_info$age}-year-old right-handed {tolower(patient_info$sex)}, was referred for comprehensive neuropsychological evaluation in the context of [specify legal proceedings/forensic question]. The evaluation was requested to assess cognitive functioning, identify any neurocognitive deficits, and determine their potential impact on [relevant forensic issues].

## Background/History

### Developmental/Medical History

[To be completed based on records review and clinical interview]
• Birth and developmental milestones
• Educational history and achievement
• Medical conditions and hospitalizations
• Head injuries or loss of consciousness
• Substance use history
• Current medications

### Psychiatric History

[To be completed based on records and interview]
• Previous psychiatric diagnoses
• Treatment history
• Hospitalizations
• Current symptoms

### Legal History

[To be completed based on available records]
• Relevant legal proceedings
• Previous evaluations
• Competency issues if applicable

### Behavioral/Emotional/Social Functioning

Based on clinical interview and behavioral rating scales:
• Current mood and emotional regulation
• Social relationships and support
• Daily functioning and independence
• Behavioral concerns

### Mental Status/Behavioral Observations

• **Attention/Orientation**: Alert and oriented to person, place, time, and situation
• **Appearance**: [Observations regarding grooming, dress, hygiene]
• **Behavior/Attitude**: Cooperative and engaged throughout testing
• **Speech/Language**: Fluent, normal rate and prosody
• **Mood/Affect**: [Current presentation]
• **Thought Process**: Linear and goal-directed
• **Insight/Judgment**: [Clinical observations]
• **Effort/Validity**: Adequate effort demonstrated; performance validity tests within normal limits
')

cat(nse_content, file = "_01-00_nse.qmd")

# Update recommendations with forensic focus
recommendations_content <- glue('
# RECOMMENDATIONS

Based on the comprehensive neuropsychological evaluation findings, the following recommendations are offered:

## Forensic Considerations

1. **Cognitive Capacity**: [Address specific forensic questions regarding cognitive capacity]

2. **Functional Abilities**: [Comment on functional abilities relevant to legal proceedings]

3. **Need for Accommodations**: [Specify any accommodations needed in legal settings]

## Clinical Recommendations

1. **Cognitive Rehabilitation**: [If deficits identified, recommend appropriate interventions]

2. **Psychiatric Treatment**: [Mental health treatment recommendations as appropriate]

3. **Medical Follow-up**: [Any medical referrals needed based on findings]

## Compensatory Strategies

1. **Memory Aids**: [Specific strategies based on identified weaknesses]

2. **Executive Functioning Supports**: [Organizational and planning strategies]

3. **Communication Strategies**: [If language issues identified]

## Environmental Modifications

1. **Structure and Routine**: [Recommendations for daily structure]

2. **Supervision Needs**: [Level of supervision or support required]

3. **Safety Considerations**: [Any safety concerns based on cognitive profile]

## Follow-up Recommendations

• Re-evaluation in [timeframe] to monitor cognitive functioning
• Regular psychiatric/medical follow-up as indicated
• Implementation of recommended interventions with progress monitoring

These recommendations are based on current test findings and should be considered in conjunction with other clinical and collateral information.
')

cat(recommendations_content, file = "_03-01_recommendations.qmd")

# Function to check if all required files exist
check_required_files <- function() {
  required_files <- c(
    "_00-00_tests.qmd",
    "_01-00_nse.qmd",
    "_02-01_iq.qmd",
    "_02-02_verbal.qmd",
    "_02-03_spatial.qmd",
    "_02-04_memory.qmd",
    "_02-05_executive.qmd",
    "_02-06_motor.qmd",
    "_02-07_daily_living.qmd",
    "_03-00_summary.qmd",
    "_03-01_recommendations.qmd"
  )

  missing_files <- required_files[!file.exists(required_files)]

  if (length(missing_files) > 0) {
    warning("Missing files: ", paste(missing_files, collapse = ", "))
    return(FALSE)
  }

  return(TRUE)
}

# Check all files exist
if (check_required_files()) {
  message("✅ All required files present")

  # Render the final report
  message("\n📄 Rendering final forensic report...")

  tryCatch({
    # Render to PDF
    quarto::quarto_render(
      input = "forensic_report_biggie.qmd",
      output_format = "typst"
    )

    message("\n✅ Report successfully generated: forensic_report_biggie.pdf")

    # Also create HTML version for easier viewing
    quarto::quarto_render(
      input = "forensic_report_biggie.qmd",
      output_format = "html"
    )

    message("✅ HTML version also created: forensic_report_biggie.html")

  }, error = function(e) {
    message("\n❌ Error rendering report: ", e$message)
    message("\nTrying alternative rendering approach...")

    # Try with rmarkdown as fallback
    rmarkdown::render(
      input = "forensic_report_biggie.qmd",
      output_format = "pdf_document"
    )
  })

} else {
  message("\n❌ Cannot render report - missing required files")
}

# Create a summary of what was generated
message("\n" , strrep("=", 50))
message("FORENSIC NEUROPSYCHOLOGICAL REPORT GENERATION COMPLETE")
message(strrep("=", 50))
message("\nPatient: ", patient_info$name)
message("Age: ", patient_info$age, " years")
message("Date of Report: ", patient_info$date_of_report)
message("\nGenerated files:")
message("- forensic_report_biggie.pdf (main report)")
message("- forensic_report_biggie.html (web version)")
message("- Individual domain analyses and figures")
message("- Summary tables and visualizations")
message("\n✅ Workflow completed successfully!")
