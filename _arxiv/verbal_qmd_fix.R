``
`{r}
#| label: qtbl-verbal
#| dev: tikz
#| fig-process: pdf2png
#| include: false
#| eval: true

# Set the default engine for tikz to "xetex"
options(tikzDefaultEngine = "xetex")

data_verbal_tbl <- dplyr::filter(data_verbal, !is.na(percentile))

# args
table_name <- "table_verbal"
vertical_padding <- 0
multiline <- TRUE

# Source the TableGT.R file
if (file.exists("TableGT.R")) {
  source("TableGT.R")

  # Create table using TableGT2 R6 class
  table_obj <- TableGT2$new(
    data = data_verbal_tbl,
    pheno = pheno,
    table_name = table_name,
    title = "Verbal/Language Test Scores",
    source_note = "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
  )

  table_obj$build_table()

} else {
  # Fallback to basic gt table if TableGT.R not found
  library(gt)

  data_verbal_tbl |>
    dplyr::select(test_name, scale, score, percentile, range) |>
    gt::gt(rowname_col = "scale", groupname_col = "test_name") |>
    gt::tab_header(title = "Verbal/Language Test Scores") |>
    gt::cols_label(
      scale = "Scale",
      score = "Score",
      percentile = "%ile",
      range = "Range"
    ) |>
    gt::tab_source_note("Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]") |>
    gt::gtsave(paste0(table_name, ".png"))
}
`
``
