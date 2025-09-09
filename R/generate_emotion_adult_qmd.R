# Generate emotion adult QMD corrected

generate_emotion_adult_qmd <- function(
  output_file = "_02-10_emotion_adult.qmd"
) {
  qmd_content <- '## Emotional/Behavioral/Personality {#sec-emotion}

```{r}
#| label: setup-emotion-adult
#| include: false

# Load required packages
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(gt)
  library(gtExtras)
  library(neuro2)
})

# Define domains
domains <- c(
  "Emotional/Behavioral/Personality",
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

# Separate data by test type (which determines rater)
self_report_tests <- c(
  "basc3_srp_college", "pai_clinical", "pai_validity", "pai_inatt", "pai", "mmpi3"
)

emotion_data <- emotion_data[emotion_data$test %in% self_report_tests, ]
```

{{< include _02-10_emotion_adult_text.qmd >}}

```{r}
#| label: text-emotion-adult
#| cache: true
#| include: false
#| results: asis

# Generate text using R6 class
if (nrow(emotion_data) > 0) {
  results_processor_emotion <- NeuropsychResultsR6$new(
    data = emotion_data,
    file = "_02-10_emotion_adult_text.qmd"
  )
  results_processor_emotion$process()
}
```

```{r}
#| label: qtbl-emotion-adult
#| dev: tikz
#| fig-process: pdf2png
#| include: false
#| eval: true
options(tikzDefaultEngine = "xetex")

if (nrow(emotion_data) > 0) {
  # Generate table
  table_emotion <- TableGTR6$new(
    data = emotion_data,
    pheno = "emotion",
    table_name = "table_emotion_adult",
    vertical_padding = 0
  )
  tbl <- table_emotion$build_table()
  table_emotion$save_table(tbl, dir = here::here())
}
```

```{r}
#| label: fig-emotion-adult-subdomain
#| include: false
#| cache: true

if (nrow(emotion_data) > 0) {
  # Generate table
  table_emotion <- TableGTR6$new(
    data = emotion_data,
    pheno = "emotion",
    table_name = "table_emotion_adult",
    vertical_padding = 0
  )
  tbl <- table_emotion$build_table()
  table_emotion$save_table(tbl, dir = here::here())
}
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
        ["{r} plot_title_emotion_adult_self"],
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
#let title = "Emotional/Behavioral/Personality"
#let file_qtbl = "table_emotion_adult.png"
#let file_fig = "fig_emotion_adult.svg"
#domain(title: [#title Scores], file_qtbl, file_fig)
```


'
  writeLines(qmd_content, output_file)
  message(paste("Generated corrected emotion adult QMD:", output_file))
}
