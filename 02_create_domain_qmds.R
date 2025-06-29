# Create Domain QMD Files for Forensic Report
# This script generates individual domain .qmd files and text files for results

library(here)
library(glue)

# Define domains for forensic template
forensic_domains <- list(
  iq = list(
    name = "General Cognitive Ability",
    scales = c(
      "Full Scale (FSIQ)",
      "General Ability (GAI)",
      "Verbal Comprehension (VCI)",
      "Fluid Reasoning (FRI)",
      "Processing Speed (PSI)",
      "Working Memory (WMI)",
      "NAB Total Index",
      "Test of Premorbid Functioning"
    )
  ),
  verbal = list(
    name = "Verbal/Language",
    scales = c(
      "Language Index (LAN)",
      "NAB Language Index",
      "Oral Production",
      "Auditory Comprehension",
      "Naming",
      "Reading Comprehension",
      "Writing",
      "Vocabulary",
      "Similarities"
    )
  ),
  spatial = list(
    name = "Visual Perception/Construction",
    scales = c(
      "Spatial Index (SPT)",
      "NAB Spatial Index",
      "Visual Discrimination",
      "Design Construction",
      "Figure Drawing Copy",
      "Block Design",
      "Matrix Reasoning",
      "Figure Weights"
    )
  ),
  memory = list(
    name = "Memory",
    scales = c(
      "Memory Index (MEM)",
      "NAB Memory Index",
      "List Learning",
      "Story Learning",
      "Figure Learning",
      "Immediate Recall",
      "Delayed Recall",
      "Recognition Memory"
    )
  ),
  executive = list(
    name = "Attention/Executive",
    scales = c(
      "Attention Index (ATT)",
      "Executive Functions Index (EXE)",
      "NAB Attention Index",
      "NAB Executive Functions Index",
      "Digits Forward",
      "Digits Backward",
      "Coding",
      "Symbol Search",
      "Mazes",
      "Categories",
      "Word Generation"
    )
  ),
  motor = list(
    name = "Motor",
    scales = c(
      "Grooved Pegboard",
      "Dominant Hand Time",
      "Nondominant Hand Time"
    )
  ),
  daily_living = list(
    name = "Daily Living",
    scales = c(
      "NAB Daily Living",
      "Driving Scenes",
      "Bill Payment",
      "Daily Living Memory",
      "Medication Instructions",
      "Map Reading",
      "Judgment"
    )
  )
)

# Template for domain QMD files
create_domain_qmd <- function(domain_key, domain_info, domain_num) {
  qmd_content <- glue(
    '
## {domain_info$name} {{#sec-{domain_key}}}

{{{{< include _02-{sprintf("%02d", domain_num)}_{domain_key}_text.qmd >}}}}

```{{r}}
#| label: setup-{domain_key}
#| include: false

# Load required libraries
library(tidyverse)
library(here)
library(gt)
library(gtExtras)
source("DotplotR6.R")
source("TableGT.R")

# Load data
neurocog <- read_csv(here("data/neurocog.csv"))
neurobehav <- read_csv(here("data/neurobehav.csv"))

# Filter by domain
domain_name <- "{domain_info$name}"
pheno <- "{domain_key}"

# Filter data for this domain
domain_data <- neurocog |>
  filter(domain == domain_name |
         scale %in% c({paste0(\'"\', domain_info$scales, \'"\', collapse = ", ")}))
```

```{{r}}
#| label: table-{domain_key}
#| echo: false

# Create table
if (nrow(domain_data) > 0) {{
  table_obj <- TableGT2$new(
    data = domain_data,
    pheno = pheno,
    table_name = paste0("table_", pheno),
    title = paste0(domain_name, " Test Scores"),
    source_note = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
  )

  table_obj$build_table()
}}
```

```{{r}}
#| label: figure-{domain_key}
#| echo: false
#| fig-cap: "{domain_info$name} subdomain scores"

# Create dotplot figure
if (nrow(domain_data) > 0 && "z_mean_subdomain" %in% colnames(domain_data)) {{
  subdomain_data <- domain_data |>
    group_by(subdomain) |>
    summarise(z_mean = mean(z_mean_subdomain, na.rm = TRUE)) |>
    filter(!is.na(z_mean))

  if (nrow(subdomain_data) > 0) {{
    dotplot_obj <- DotplotR6$new(
      data = subdomain_data,
      x = "z_mean",
      y = "subdomain",
      filename = paste0("fig_", pheno, "_subdomain.svg")
    )

    dotplot_obj$create_plot()
  }}
}}
```
'
  )

  # Write QMD file
  qmd_filename <- glue("_02-{sprintf('%02d', domain_num)}_{domain_key}.qmd")
  cat(qmd_content, file = qmd_filename)

  # Create empty text file for results
  text_filename <- glue(
    "_02-{sprintf('%02d', domain_num)}_{domain_key}_text.qmd"
  )
  cat("<summary>\n\nResults pending...\n\n</summary>", file = text_filename)

  message(glue("✓ Created {qmd_filename} and {text_filename}"))
}

# Create all domain files
domain_num <- 1
for (domain_key in names(forensic_domains)) {
  create_domain_qmd(domain_key, forensic_domains[[domain_key]], domain_num)
  domain_num <- domain_num + 1
}

# Create additional required files

# 1. Tests Administered
cat(
  '
# TESTS ADMINISTERED

```{r}
#| label: tests-list
#| echo: false

# Generate list of tests administered
neurocog <- read_csv(here("data/neurocog.csv"))
neurobehav <- read_csv(here("data/neurobehav.csv"))

tests <- unique(c(
  neurocog$test_name,
  neurobehav$test_name
))

# Format as bullet list
cat(paste("•", tests, collapse = "\n"))
```
',
  file = "_00-00_tests.qmd"
)

# 2. Neurobehavioral Status Exam
cat(
  '
# NEUROBEHAVIORAL STATUS EXAM

## Reason for Referral

Biggie, a 44-year-old right-handed male, was referred for neuropsychological assessment...

## Background/History

### Developmental/Medical History

[To be completed based on clinical interview]

### Behavioral/Emotional/Social Functioning

[To be completed based on clinical interview and behavioral observations]

### Mental Status/Behavioral Observations

• **Attention/Orientation**: [To be completed]
• **Appearance**: [To be completed]
• **Behavior/Attitude**: [To be completed]
• **Speech/Language**: [To be completed]
• **Mood/Affect**: [To be completed]
• **Sensory/Motor**: [To be completed]
• **Cognitive Process**: [To be completed]
• **Effort/Validity**: [To be completed]
',
  file = "_01-00_nse.qmd"
)

# 3. Summary/Impression
cat(
  '
# SUMMARY/IMPRESSION

## Overall Evaluation Interpretation

[Summary of findings to be generated after domain analyses]

## Diagnostic Impression

[Diagnostic conclusions based on test results]
',
  file = "_03-00_summary.qmd"
)

# 4. Recommendations
cat(
  '
# RECOMMENDATIONS

## Clinical Recommendations

[Specific recommendations based on test findings]

## Educational/Vocational Recommendations

[As appropriate based on referral question]

## Follow-up Recommendations

[Timeline and nature of recommended follow-up]
',
  file = "_03-01_recommendations.qmd"
)

message("\n✅ All domain QMD files created successfully!")
