# Save this as generate_emotion_child_corrected.R

# Generate emotion child QMD corrected

generate_emotion_child_qmd_00 <- function(
  output_file = "_02-10_emotion_child.qmd"
) {
  # Removed source() calls - all functions are available from the neuro2 package:
  # source(here::here("R", "DomainProcessorR6.R"))
  # source(here::here("R", "NeuropsychResultsR6.R"))
  # source(here::here("R", "DotplotR6.R"))
  # source(here::here("R", "TableGTR6.R"))
  # source(here::here("R", "domain_processing_utils.R"))

  # ...existing code...

  qmd_content <- '## Behavioral/Emotional/Social {#sec-emotion}

```{r}
#| label: setup-emotion
#| include: false

# Load required packages
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(gt)
  library(gtExtras)
})

# Note: R6 classes and utilities are now available from the neuro2 package

# Define domains
domains <- c(
  "Behavioral/Emotional/Social",
  "Psychiatric Disorders",
  "Substance Use",
  "Personality Disorders",
  "Psychosocial Problems"
)

# Load and process data
processor <- DomainProcessorR6$new(
  domains = domains,
  pheno = "emotion",
  input_file = "data/neurobehav.parquet"
)

processor$load_data()
processor$filter_by_domain()
processor$select_columns()

# Main data object
emotion_data <- processor$data

# Separate data by rater
if ("rater" %in% names(emotion_data)) {
  emotion_self <- emotion_data[tolower(emotion_data$rater) == "self", ]
  emotion_parent <- emotion_data[tolower(emotion_data$rater) == "parent", ]
  emotion_teacher <- emotion_data[tolower(emotion_data$rater) == "teacher", ]
} else {
  emotion_self <- emotion_data
  emotion_parent <- data.frame()
  emotion_teacher <- data.frame()
}
```

### SELF-REPORT

{{< include _02-10_emotion_child_text_self.qmd >}}

```{r}
#| label: process-emotion-self
#| include: false

if (nrow(emotion_self) > 0) {
  # Generate table for self-report
  table_self <- TableGTR6$new(
    data = emotion_self,
    pheno = "emotion",
    table_name = "table_emotion_child_self",
    vertical_padding = 0
  )
  tbl_self <- table_self$build_table()
  table_self$save_table(tbl_self, dir = here::here())

  # Generate figure for self-report
  if (all(c("z_mean_subdomain", "subdomain") %in% names(emotion_self))) {
    dotplot_self <- DotplotR6$new(
      data = emotion_self,
      x = "z_mean_subdomain",
      y = "subdomain",
      filename = here::here("fig_emotion_child_self_subdomain.svg")
    )
    dotplot_self$create_plot()
  }
}

# Set plot title
plot_title_emotion_child_self <- "Emotional and behavioral functioning (self-report) reflects psychological adjustment."
```

```{=typst}
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [`{r} plot_title_emotion_child_self`],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
```

```{=typst}
// Define the title of the domain
#let title = "Behavioral/Emotional/Social Scores"

// Define the file name of the table
#let file_qtbl = "table_emotion_child_self.png"

// Define the file name of the figure
#let file_fig = "fig_emotion_child_self_subdomain.svg"

// The title is appended with " Scores"
#domain(title: [#title Scores], file_qtbl, file_fig)
```

```{=typst}
#domain(
  title: [Behavioral/Emotional/Social Scores],
  file_qtbl: "table_emotion_child_self.png",
  file_fig: "fig_emotion_child_self_subdomain.svg"
)
```

### PARENT RATINGS

{{< include _02-10_emotion_child_text_parent.qmd >}}

```{r}
#| label: process-emotion-parent
#| include: false

if (nrow(emotion_parent) > 0) {
  # Generate table for parent ratings
  table_parent <- TableGTR6$new(
    data = emotion_parent,
    pheno = "emotion",
    table_name = "table_emotion_child_parent",
    vertical_padding = 0
  )
  tbl_parent <- table_parent$build_table()
  table_parent$save_table(tbl_parent, dir = here::here())

  # Generate figure for parent ratings
  if (all(c("z_mean_subdomain", "subdomain") %in% names(emotion_parent))) {
    dotplot_parent <- DotplotR6$new(
      data = emotion_parent,
      x = "z_mean_subdomain",
      y = "subdomain",
      filename = here::here("fig_emotion_child_parent_subdomain.svg")
    )
    dotplot_parent$create_plot()
  }
}

# Set plot title
plot_title_emotion_child_parent <- "Emotional and behavioral functioning (parent report) reflects observed behaviors."
```

```{=typst}
#domain(
  title: [Behavioral/Emotional/Social Scores]
  file_qtbl: "table_emotion_child_parent.png"
  file_fig: "fig_emotion_child_parent_subdomain.svg"
)
```
'
  writeLines(qmd_content, output_file)
  message(paste("Generated corrected emotion child QMD:", output_file))
}
