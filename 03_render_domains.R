# Render Domain Files and Generate Results
# Processes each domain and generates text summaries

library(tidyverse)
library(here)
library(glue)

# Load the processed data
neurocog <- read_csv("data/neurocog.csv")
neurobehav <- read_csv("data/neurobehav.csv")

# Function to generate domain text summary
generate_domain_summary <- function(domain_data, domain_name) {
  if (nrow(domain_data) == 0) {
    return("No data available for this domain.")
  }

  # Calculate overall performance
  mean_percentile <- mean(domain_data$percentile, na.rm = TRUE)

  # Determine overall range
  overall_range <- case_when(
    mean_percentile >= 98 ~ "Exceptionally High",
    mean_percentile >= 91 ~ "Above Average",
    mean_percentile >= 75 ~ "High Average",
    mean_percentile >= 25 ~ "Average",
    mean_percentile >= 9 ~ "Low Average",
    mean_percentile >= 2 ~ "Below Average",
    TRUE ~ "Exceptionally Low"
  )

  # Find strengths and weaknesses
  strengths <- domain_data %>%
    filter(percentile >= 75) %>%
    arrange(desc(percentile))

  weaknesses <- domain_data %>%
    filter(percentile < 25) %>%
    arrange(percentile)

  # Generate summary text
  summary_text <- glue("
<summary>

Testing of {tolower(domain_name)} revealed overall {tolower(overall_range)}
performance (mean percentile = {round(mean_percentile)}).
")

  if (nrow(strengths) > 0) {
    summary_text <- paste0(summary_text,
      "Areas of relative strength included ",
      paste(strengths$scale[1:min(3, nrow(strengths))],
            collapse = ", "),
      ". ")
  }

  if (nrow(weaknesses) > 0) {
    summary_text <- paste0(summary_text,
      "Areas of relative weakness included ",
      paste(weaknesses$scale[1:min(3, nrow(weaknesses))],
            collapse = ", "),
      ". ")
  }

  # Add functional interpretation
  summary_text <- paste0(
    summary_text,
    generate_functional_interpretation(
      domain_name, overall_range, weaknesses
    )
  )

  summary_text <- paste0(summary_text, "\n\n</summary>")

  return(summary_text)
}

# Function to generate functional interpretation
generate_functional_interpretation <- function(
  domain, range, weaknesses
) {
  interpretations <- list(
    "General Cognitive Ability" = list(
      "Below Average" = paste0(
        "These findings suggest Biggie may experience difficulties with ",
        "complex problem-solving and abstract reasoning in everyday ",
        "situations. He would benefit from structured support and clear, ",
        "concrete instructions."
      ),
      "Average" = paste0(
        "These results indicate Biggie has adequate intellectual resources ",
        "to meet most everyday cognitive demands when provided appropriate ",
        "structure and support."
      ),
      "Above Average" = paste0(
        "These findings indicate Biggie possesses strong intellectual ",
        "resources that can be leveraged to compensate for any specific ",
        "areas of difficulty."
      )
    ),
    "Verbal/Language" = list(
      "Below Average" = paste0(
        "These language difficulties may impact Biggie's ability to ",
        "communicate effectively, understand complex verbal instructions, ",
        "and express his thoughts clearly. Written communication may be ",
        "particularly challenging."
      ),
      "Average" = paste0(
        "Biggie demonstrates adequate verbal communication skills for most ",
        "daily interactions, though he may need additional time or ",
        "clarification for complex verbal information."
      ),
      "Above Average" = paste0(
        "Biggie's strong verbal abilities represent a cognitive strength ",
        "that can be utilized to support learning and communication ",
        "across settings."
      )
    ),
    "Visual Perception/Construction" = list(
      "Below Average" = paste0(
        "These visuospatial weaknesses may affect Biggie's ability to ",
        "navigate unfamiliar environments, organize visual information, ",
        "and complete construction or assembly tasks."
      ),
      "Average" = paste0(
        "Biggie shows adequate visual-perceptual abilities for most ",
        "daily tasks, though complex spatial reasoning may require ",
        "additional effort."
      ),
      "Above Average" = paste0(
        "Strong visuospatial abilities suggest Biggie can effectively ",
        "process and manipulate visual information, supporting tasks ",
        "requiring spatial reasoning."
      )
    ),
    "Memory" = list(
      "Below Average" = paste0(
        "Memory difficulties may significantly impact Biggie's daily ",
        "functioning, affecting his ability to learn new information, ",
        "remember appointments, and recall important details. ",
        "Compensatory strategies such as written reminders and ",
        "repetition are recommended."
      ),
      "Average" = paste0(
        "Biggie demonstrates adequate memory functioning for routine ",
        "daily activities, though he may benefit from organizational ",
        "strategies for complex information."
      ),
      "Above Average" = paste0(
        "Strong memory abilities represent a significant cognitive asset ",
        "that can support learning and daily functioning across contexts."
      )
    ),
    "Attention/Executive" = list(
      "Below Average" = paste0(
        "Executive functioning difficulties may manifest as problems with ",
        "organization, planning, multitasking, and behavioral regulation. ",
        "Biggie would benefit from external structure, routine, and ",
        "supervision for complex tasks."
      ),
      "Average" = paste0(
        "Biggie shows adequate attentional control and executive ",
        "functioning for structured tasks, though he may need support ",
        "with complex planning and organization."
      ),
      "Above Average" = paste0(
        "Strong executive abilities suggest good capacity for ",
        "self-regulation, planning, and adaptive problem-solving ",
        "in varied situations."
      )
    )
  )

  # Get appropriate interpretation
  if (domain %in% names(interpretations) &&
      range %in% names(interpretations[[domain]])) {
    return(interpretations[[domain]][[range]])
  }

  # Default interpretation
  return(glue(
    "Performance in this domain may impact daily functioning and would ",
    "benefit from appropriate support and accommodations."
  ))
}

# Process each domain
domains <- list(
  list(key = "iq", name = "General Cognitive Ability", num = "01"),
  list(key = "verbal", name = "Verbal/Language", num = "02"),
  list(key = "spatial", name = "Visual Perception/Construction", num = "03"),
  list(key = "memory", name = "Memory", num = "04"),
  list(key = "executive", name = "Attention/Executive", num = "05"),
  list(key = "motor", name = "Motor", num = "06"),
  list(key = "daily_living", name = "Daily Living", num = "07")
)

for (domain_info in domains) {
  # Filter data for this domain
  domain_data <- neurocog %>%
    filter(domain == domain_info$name |
           grepl(domain_info$name, domain, ignore.case = TRUE))

  # Generate summary text
  summary_text <- generate_domain_summary(domain_data, domain_info$name)

  # Write to text file
  text_file <- glue("_02-{domain_info$num}_{domain_info$key}_text.qmd")
  cat(summary_text, file = text_file)

  message(glue("✓ Generated summary for {domain_info$name}"))
}

# Generate overall summary
generate_overall_summary <- function() {
  all_data <- bind_rows(neurocog, neurobehav)

  # Calculate overall performance metrics
  mean_percentile <- mean(all_data$percentile, na.rm = TRUE)

  # Identify key findings
  significant_weaknesses <- all_data %>%
    filter(percentile < 5) %>%
    select(test_name, scale, percentile)

  significant_strengths <- all_data %>%
    filter(percentile > 95) %>%
    select(test_name, scale, percentile)

  summary_text <- glue('
<summary>

## Overall Evaluation Interpretation

Biggie, a 44-year-old male, was administered a comprehensive
neuropsychological battery to assess cognitive functioning across
multiple domains. Overall test results revealed a pattern of {ifelse(
  mean_percentile < 25,
  "significant cognitive difficulties",
  ifelse(
    mean_percentile < 50,
    "below average functioning",
    "adequate cognitive functioning"
  )
)} with a mean performance at the {round(mean_percentile)}th percentile.
')

  if (nrow(significant_strengths) > 0) {
    summary_text <- paste0(
      summary_text,
      "\n\nAreas of notable strength included:\n"
    )
    for (i in 1:min(3, nrow(significant_strengths))) {
      summary_text <- paste0(
        summary_text,
        glue(
          "• {significant_strengths$scale[i]} ",
          "({significant_strengths$percentile[i]}th percentile)\n"
        )
      )
    }
  }

  if (nrow(significant_weaknesses) > 0) {
    summary_text <- paste0(
      summary_text,
      "\n\nAreas of significant concern included:\n"
    )
    for (i in 1:min(3, nrow(significant_weaknesses))) {
      summary_text <- paste0(
        summary_text,
        glue(
          "• {significant_weaknesses$scale[i]} ",
          "({significant_weaknesses$percentile[i]}th percentile)\n"
        )
      )
    }
  }

  # Add diagnostic impression placeholder
  summary_text <- paste0(summary_text, '

## Diagnostic Impression

Based on the comprehensive evaluation, the following diagnostic
considerations are relevant:

• [To be completed by clinician based on full clinical picture]
• [Consider cognitive, emotional, and behavioral factors]
• [Include relevant DSM-5-TR or ICD-11 codes]

</summary>')

  return(summary_text)
}

# Write overall summary
summary_text <- generate_overall_summary()
cat(summary_text, file = "_03-00_summary_text.qmd")

# Update summary file to include the text
cat('
# SUMMARY/IMPRESSION

{{< include _03-00_summary_text.qmd >}}

```{r}
#| label: fig-overall
#| echo: false
#| fig-cap: "Overall cognitive profile across domains"

# Create overall profile figure
library(ggplot2)
source("DotplotR6.R")

neurocog <- read_csv("data/neurocog.csv")

# Aggregate by domain
domain_summary <- neurocog %>%
  group_by(domain) %>%
  summarise(
    mean_z = mean(z, na.rm = TRUE),
    mean_percentile = mean(percentile, na.rm = TRUE)
  ) %>%
  filter(!is.na(mean_z))

if (nrow(domain_summary) > 0) {
  dotplot_obj <- DotplotR6$new(
    data = domain_summary,
    x = "mean_z",
    y = "domain",
    filename = "fig_overall_profile.svg"
  )

  dotplot_obj$create_plot()
}
```
', file = "_03-00_summary.qmd")

message("\n✅ All domain summaries generated successfully!")
