# Complete Sections Generator for Neuropsych Reports
# Generates all required sections for the Quarto/Typst template

library(tidyverse)
library(glue)
library(here)

# Function to generate all required sections
generate_all_sections <- function(template_type = "forensic") {
  
  # Ensure sections directory exists
  dir.create("sections", showWarnings = FALSE)
  
  # Load data for generating content
  neurocog <- readr::read_csv("data/neurocog.csv", show_col_types = FALSE)
  neurobehav <- readr::read_csv("data/neurobehav.csv", show_col_types = FALSE)
  
  # 1. Behavioral Observations
  create_behavioral_observations()
  
  # 2. Summary/Impressions (SIRF)
  create_summary_sections(neurocog, neurobehav)
  
  # 3. Recommendations
  create_recommendations(template_type)
  
  # 4. Signature block
  create_signature()
  
  # 5. Appendix
  create_appendix()
  
  message("✅ All sections generated successfully!")
}

# Create behavioral observations section
create_behavioral_observations <- function() {
  
  content <- '
## Behavioral Observations

{{< var mr_mrs >}} {{< var last_name >}} presented as a {{< var age >}}-year-old {{< var sex >}} who appeared {{< var his_her >}} stated age. {{< var he_she_cap >}} arrived on time for the evaluation and was appropriately dressed and groomed. {{< var he_she_cap >}} was alert and oriented to person, place, time, and situation throughout the assessment.

### Test Session Behavior

{{< var mr_mrs >}} {{< var last_name >}} was cooperative and appeared to put forth adequate effort throughout the evaluation. {{< var his_her_cap >}} attention and concentration were generally sustained, though {{< var he_she >}} occasionally required redirection on more complex tasks. {{< var he_she_cap >}} demonstrated appropriate frustration tolerance and persistence when faced with challenging items.

### Communication

Speech was fluent with normal rate, rhythm, and prosody. {{< var he_she_cap >}} demonstrated adequate receptive and expressive language skills for the evaluation. {{< var he_she_cap >}} was able to follow multi-step instructions and responded appropriately to questions.

### Motor Functioning

No gross motor abnormalities were observed. Fine motor coordination appeared intact for paper-and-pencil tasks. {{< var he_she_cap >}} is {{< var handedness >}}-hand dominant.

### Emotional/Behavioral Presentation

{{< var mr_mrs >}} {{< var last_name >}} presented with a euthymic mood and appropriate affect throughout the evaluation. {{< var he_she_cap >}} denied current symptoms of depression, anxiety, or other significant emotional distress. No evidence of thought disorder, perceptual disturbances, or other psychiatric symptoms was observed.

### Validity Considerations

Performance validity testing and behavioral observations suggest that the current test results provide a valid estimate of {{< var mr_mrs >}} {{< var last_name >}}\'s current cognitive functioning. {{< var he_she_cap >}} appeared to understand task demands and put forth adequate effort throughout the evaluation.
'
  
  writeLines(content, "sections/_02-00_behav_obs.qmd")
  message("✓ Created behavioral observations section")
}

# Create summary/impressions sections
create_summary_sections <- function(neurocog, neurobehav) {
  
  # Main SIRF section
  sirf_content <- '
# SUMMARY, IMPRESSIONS, & RECOMMENDATIONS

## Summary of Findings

```{r}
#| label: summary-stats
#| include: false

# Calculate overall performance metrics
all_data <- bind_rows(
  neurocog %>% mutate(source = "cognitive"),
  neurobehav %>% mutate(source = "behavioral")
)

mean_percentile <- mean(all_data$percentile, na.rm = TRUE)
domains_assessed <- unique(all_data$domain)
n_tests <- length(unique(all_data$test_name))

# Identify strengths and weaknesses
strengths <- all_data %>%
  filter(percentile >= 75) %>%
  arrange(desc(percentile)) %>%
  slice_head(n = 5)

weaknesses <- all_data %>%
  filter(percentile <= 25) %>%
  arrange(percentile) %>%
  slice_head(n = 5)
```

{{< var mr_mrs >}} {{< var last_name >}} completed a comprehensive neuropsychological evaluation consisting of `{r} n_tests` standardized measures assessing multiple cognitive domains. Overall, {{< var his_her >}} performance across measures yielded a mean percentile rank of `{r} round(mean_percentile)`, suggesting `{r} ifelse(mean_percentile < 25, "significant cognitive difficulties", ifelse(mean_percentile < 50, "below avera