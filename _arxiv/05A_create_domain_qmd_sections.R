# Create Domain QMD Sections that Match Template Structure
# This creates the domain files referenced in _include_domains.qmd

library(tidyverse)
library(glue)
library(here)

# Ensure sections directory exists
dir.create("sections", showWarnings = FALSE)

# Function to create a domain QMD file
create_domain_qmd <- function(domain_key, domain_name, domain_num) {
  # Define scales for each domain
  domain_scales <- list(
    iq = c(
      "Full Scale (FSIQ)",
      "General Ability (GAI)",
      "Verbal Comprehension (VCI)",
      "Fluid Reasoning (FRI)",
      "Processing Speed (PSI)",
      "Working Memory (WMI)",
      "NAB Total Index",
      "RBANS Total Index"
    ),

    academics = c(
      "Word Reading",
      "Reading Comprehension",
      "Reading Fluency",
      "Spelling",
      "Math Problem Solving",
      "Numerical Operations"
    ),

    verbal = c(
      "Language Index (LAN)",
      "NAB Language Index",
      "Oral Production",
      "Auditory Comprehension",
      "Naming",
      "Writing",
      "Vocabulary",
      "Similarities"
    ),

    spatial = c(
      "Spatial Index (SPT)",
      "NAB Spatial Index",
      "Visual Discrimination",
      "Design Construction",
      "Figure Drawing Copy",
      "Block Design",
      "Matrix Reasoning"
    ),

    memory = c(
      "Memory Index (MEM)",
      "NAB Memory Index",
      "List Learning",
      "Story Learning",
      "Figure Learning",
      "Immediate Memory",
      "Delayed Memory",
      "Recognition Memory"
    ),

    executive = c(
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
    ),

    motor = c(
      "Grooved Pegboard",
      "Dominant Hand Time",
      "Nondominant Hand Time",
      "Finger Tapping"
    ),

    social = c(
      "Social Perception",
      "Affect Naming",
      "Theory of Mind",
      "Social Judgment"
    ),

    adhd_adult = c(
      "CAARS Inattentive Symptoms",
      "CAARS Hyperactive-Impulsive",
      "CAARS Total ADHD Symptoms",
      "CAARS ADHD Index",
      "CEFI Full Scale",
      "CEFI Attention",
      "CEFI Working Memory"
    ),

    emotion_adult = c(
      "PAI Depression",
      "PAI Anxiety",
      "PAI Anxiety-Related",
      "PAI Somatic Complaints",
      "PAI Mania",
      "PAI Paranoia",
      "PAI Schizophrenia",
      "PAI Antisocial",
      "PAI Borderline"
    ),

    adaptive = c(
      "Adaptive Behavior Composite",
      "Conceptual Skills",
      "Social Skills",
      "Practical Skills"
    ),

    daily_living = c(
      "NAB Daily Living",
      "Driving Scenes",
      "Bill Payment",
      "Daily Living Memory",
      "Medication Instructions",
      "Map Reading",
      "Judgment"
    )
  )

  # Get scales for this domain
  scales <- domain_scales[[domain_key]] %||% character(0)

  # Create the QMD content
  qmd_content <- glue(
    '
## {domain_name} {{#sec-{domain_key}}}

{{{{< include _02-{sprintf("%02d", as.numeric(domain_num))}_{domain_key}_text.qmd >}}}}

```{{r}}
#| label: setup-{domain_key}
#| include: false

# Domain configuration
domains <- c("{domain_name}")
pheno <- "{domain_key}"

# Load data
if (!exists("neurocog")) {{
  neurocog <- readr::read_csv(here::here("data/neurocog.csv"))
}}
if (!exists("neurobehav")) {{
  neurobehav <- readr::read_csv(here::here("data/neurobehav.csv"))
}}

# Select appropriate data source
if (pheno %in% c("adhd_adult", "emotion_adult")) {{
  data <- neurobehav
}} else {{
  data <- neurocog
}}

# Filter by domain
data <- data |>
  dplyr::filter(domain %in% domains)
```

```{{r}}
#| label: table-{domain_key}
#| tbl-cap: "{domain_name} Test Scores"
#| echo: false

# Define scales for this domain
scales_{domain_key} <- c({paste0(\'"\', scales, \'"\', collapse = ", ")})

# Filter data by scales
data_{domain_key} <- data |>
  dplyr::filter(scale %in% scales_{domain_key})

# Create table if data exists
if (nrow(data_{domain_key}) > 0) {{
  # Source table function if needed
  if (file.exists("TableGT.R")) {{
    source("TableGT.R")

    table_obj <- TableGT2$new(
      data = data_{domain_key},
      pheno = pheno,
      table_name = paste0("table_", pheno),
      title = "{domain_name} Test Scores",
      source_note = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
    )

    table_obj$build_table()
  }} else {{
    # Fallback to basic gt table
    library(gt)

    data_{domain_key} |>
      dplyr::select(test_name, scale, score, percentile, range) |>
      gt::gt(rowname_col = "scale", groupname_col = "test_name") |>
      gt::tab_header(title = "{domain_name} Test Scores") |>
      gt::cols_label(
        scale = "Scale",
        score = "Score",
        percentile = "%ile",
        range = "Range"
      )
  }}
}}
```

```{{r}}
#| label: fig-{domain_key}
#| fig-cap: "{domain_name} performance profile"
#| echo: false
#| fig-height: 5
#| fig-width: 7

# Create figure if we have subdomain data
if ("subdomain" %in% colnames(data_{domain_key}) &&
    "z_mean_subdomain" %in% colnames(data_{domain_key})) {{

  subdomain_data <- data_{domain_key} |>
    dplyr::group_by(subdomain) |>
    dplyr::summarise(
      z_mean = mean(z_mean_subdomain, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::filter(!is.na(z_mean))

  if (nrow(subdomain_data) > 0) {{
    if (file.exists("DotplotR6.R")) {{
      source("DotplotR6.R")

      dotplot_obj <- DotplotR6$new(
        data = subdomain_data,
        x = "z_mean",
        y = "subdomain",
        filename = paste0("fig_", pheno, "_subdomain.svg")
      )

      dotplot_obj$create_plot()
    }} else {{
      # Fallback to basic ggplot
      library(ggplot2)

      ggplot(subdomain_data, aes(x = z_mean, y = reorder(subdomain, z_mean))) +
        geom_segment(aes(xend = 0, yend = subdomain), color = "gray50") +
        geom_point(size = 4, color = "steelblue") +
        geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
        geom_vline(xintercept = c(-1, 1), linetype = "dotted", alpha = 0.3) +
        scale_x_continuous(limits = c(-3, 3), breaks = seq(-3, 3, 1)) +
        labs(x = "Z-Score", y = "",
             title = "{domain_name} Subdomain Performance") +
        theme_minimal() +
        theme(panel.grid.major.y = element_blank())
    }}
  }}
}}
```

',
    .open = "{{",
    .close = "}}"
  )

  # Write the file
  filename <- glue(
    "sections/_02-{sprintf('%02d', as.numeric(domain_num))}_{domain_key}.qmd"
  )
  writeLines(qmd_content, filename)

  # Also create the text file if it doesn't exist
  text_filename <- glue(
    "sections/_02-{sprintf('%02d', as.numeric(domain_num))}_{domain_key}_text.qmd"
  )
  if (!file.exists(text_filename)) {
    text_content <- glue(
      "
<summary>

Results for {domain_name} assessment pending clinical interpretation.

</summary>
"
    )
    writeLines(text_content, text_filename)
  }

  message(glue("✓ Created {filename}"))
}

# Create all domain files based on _include_domains.qmd structure
domains_to_create <- list(
  list(key = "iq", name = "General Cognitive Ability", num = 1),
  list(key = "academics", name = "Academic Achievement", num = 2),
  list(key = "verbal", name = "Verbal/Language", num = 3),
  list(key = "spatial", name = "Visual Perception/Construction", num = 4),
  list(key = "memory", name = "Memory", num = 5),
  list(key = "executive", name = "Attention/Executive", num = 6),
  list(key = "motor", name = "Motor", num = 7),
  list(key = "social", name = "Social Cognition", num = 8),
  list(key = "adhd_adult", name = "ADHD", num = 9),
  list(key = "emotion_adult", name = "Emotional/Behavioral", num = 10),
  list(key = "adaptive", name = "Adaptive Functioning", num = 11),
  list(key = "daily_living", name = "Daily Living", num = 12)
)

# Create each domain file
for (domain in domains_to_create) {
  create_domain_qmd(domain$key, domain$name, domain$num)
}

# Update _include_domains.qmd to include all created files
include_content <- paste0(
  "{{< include sections/_02-",
  sprintf("%02d", 1:12),
  "_",
  sapply(domains_to_create, function(x) x$key),
  ".qmd >}}\n",
  collapse = "\n"
)

writeLines(include_content, "sections/_include_domains.qmd")
message("\n✅ All domain sections created successfully!")
