#' TableGT R6 Class
#'
#' An R6 class to create and save formatted `gt` tables for neurocognitive domain data.
#'
#' @field data A data frame with columns such as test_name, scale, score, percentile, and range.
#' @field pheno Phenotype identifier string.
#' @field table_name Name of the table to be saved.
#' @field source_note A string to appear as a source note in the table.
#' @field names A list of column name labels.
#' @field title Table title string.
#' @field tab_stubhead Label for the stubhead (leftmost column group).
#' @field caption Caption for the table.
#' @field process_md Logical; whether to process markdown in cells.
#' @field fn_list A named list of footnotes for score types (e.g., t_score, scaled_score).
#' @field grp_list A named list of row groups for applying footnotes.
#' @field dynamic_grp A named list defining which groups support which score types.
#' @field vertical_padding Numeric scale for vertical padding in the table.
#' @field multiline Logical; whether footnotes should wrap onto multiple lines.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new TableGT object with configuration and data.}
#'   \item{build_table}{Construct and return the formatted `gt` table, with optional saving as PNG and PDF. This method processes the data, applies styling, adds footnotes, and saves the output if configured.}
#' }
#'
#' @param data A data frame to use in table generation.
#' @param pheno A string specifying the phenotype identifier (default NULL).
#' @param table_name File-safe name for saving the table (default NULL).
#' @param source_note A footnote to be added as a source note (default NULL).
#' @param names Optional renamed column headers (default NULL).
#' @param title Table title (default NULL).
#' @param tab_stubhead Label for the stubhead (default NULL).
#' @param caption Optional caption text (default NULL).
#' @param process_md Logical. Whether to parse markdown syntax in labels or values (default FALSE).
#' @param fn_list Named list of score type footnotes (default list()).
#' @param grp_list Named list of score type row groups (default list()).
#' @param dynamic_grp Named list of valid score types per group (default NULL).
#' @param vertical_padding Numeric scale (0–3) to control padding (default NULL).
#' @param multiline Logical; whether to use multiline footnotes (default TRUE).
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr select mutate across if_else
#' @importFrom tidyr replace_na
#' @importFrom gt gt cols_label tab_stub_indent tab_header sub_missing tab_options
#'   cols_align tab_source_note gtsave tab_style tab_stubhead tab_caption
#'   tab_spanner cell_text cells_source_notes md tab_footnote opt_vertical_padding
#'   cells_row_groups
#' @importFrom gtExtras gt_theme_538
#' @importFrom glue glue glue_collapse
#' @export
TableGT <- R6::R6Class(
  classname = "TableGT",
  public = list(
    data = NULL,
    pheno = NULL,
    table_name = NULL,
    source_note = NULL,
    names = NULL,
    title = NULL,
    tab_stubhead = NULL,
    caption = NULL,
    process_md = FALSE,
    fn_list = list(),
    grp_list = list(),
    dynamic_grp = NULL,
    vertical_padding = NULL,
    multiline = TRUE,

    #' @description
    #' Initialize a new TableGT object with configuration and data.
    #'
    #' @param data A data frame to use in table generation.
    #' @param pheno A string specifying the phenotype identifier (default NULL).
    #' @param table_name File-safe name for saving the table (default NULL).
    #' @param source_note A footnote to be added as a source note (default NULL).
    #' @param names Optional renamed column headers (default NULL).
    #' @param title Table title (default NULL).
    #' @param tab_stubhead Label for the stubhead (default NULL).
    #' @param caption Optional caption text (default NULL).
    #' @param process_md Logical. Whether to parse markdown syntax in labels or values (default FALSE).
    #' @param fn_list Named list of score type footnotes (default list()).
    #' @param grp_list Named list of score type row groups (default list()).
    #' @param dynamic_grp Named list of valid score types per group (default NULL).
    #' @param vertical_padding Numeric scale (0–3) to control padding (default NULL).
    #' @param multiline Logical; whether to use multiline footnotes (default TRUE).
    #'
    #' @return A new TableGT object
    initialize = function(
      data,
      pheno = NULL,
      table_name = NULL,
      source_note = NULL,
      names = NULL,
      title = NULL,
      tab_stubhead = NULL,
      caption = NULL,
      process_md = FALSE,
      fn_list = list(),
      grp_list = list(),
      dynamic_grp = NULL,
      vertical_padding = NULL,
      multiline = TRUE
    ) {
      self$data <- data
      self$pheno <- pheno
      self$table_name <- table_name
      self$source_note <- source_note
      self$names <- names
      self$title <- title
      self$tab_stubhead <- tab_stubhead
      self$caption <- caption
      self$process_md <- process_md
      self$fn_list <- fn_list
      self$grp_list <- grp_list
      self$dynamic_grp <- dynamic_grp
      self$vertical_padding <- vertical_padding
      self$multiline <- multiline
    },
    
    #' @description
    #' Construct and return the formatted `gt` table, with optional saving as PNG and PDF.
    #' This method processes the data, applies styling, adds footnotes, and saves the output if configured.
    #'
    #' @return A formatted `gt` table object
    build_table = function() {
      data_counts <- self$data |>
        dplyr::select(test_name, scale, score, percentile, range) |>
        dplyr::mutate(across(
          c(score, percentile),
          ~ tidyr::replace_na(., replace = 0)
        )) |>
        dplyr::mutate(
          score = dplyr::if_else(score == 0, NA_integer_, score),
          percentile = dplyr::if_else(percentile == 0, NA_integer_, percentile),
          test_name = as.character(test_name),
          scale = as.character(scale)
        )

      tbl <- gt::gt(
        data_counts,
        rowname_col = "scale",
        groupname_col = "test_name",
        process_md = self$process_md,
        caption = self$caption,
        rownames_to_stub = FALSE,
        id = paste0("table_", self$pheno)
      ) |>
        gt::cols_label(
          test_name = gt::md("**Test**"),
          scale = gt::md("**Scale**"),
          score = gt::md("**Score**"),
          percentile = gt::md("**\u2030 Rank**"),
          range = gt::md("**Range**")
        ) |>
        gt::tab_header(title = self$title) |>
        gt::tab_stubhead(label = self$tab_stubhead) |>
        gt::sub_missing(missing_text = "--") |>
        gt::tab_stub_indent(rows = scale, indent = 2) |>
        gt::cols_align(
          align = "center",
          columns = c("score", "percentile", "range")
        )

      # Add conditional footnotes
      existing_groups <- unique(self$data$test_name)
      for (score_type in names(self$fn_list)) {
        footnote <- self$fn_list[[score_type]]
        groups <- intersect(self$grp_list[[score_type]], existing_groups)
        if (
          !is.null(footnote) && any(groups %in% self$dynamic_grp[[score_type]])
        ) {
          tbl <- tbl |>
            gt::tab_footnote(
              footnote = glue::glue_collapse(footnote, sep = " "),
              locations = gt::cells_row_groups(groups = groups)
            )
        }
      }

      # Add source note and styling
      tbl <- tbl |>
        gt::tab_style(
          style = gt::cell_text(size = "small"),
          locations = gt::cells_source_notes()
        ) |>
        gt::tab_source_note(source_note = self$source_note) |>
        gtExtras::gt_theme_538() |>
        gt::tab_options(
          row_group.font.weight = "bold",
          footnotes.multiline = self$multiline,
          footnotes.font.size = "small"
        ) |>
        gt::opt_vertical_padding(scale = self$vertical_padding)

      # Save outputs
      gt::gtsave(tbl, glue::glue("table_{self$pheno}.png"))
      gt::gtsave(tbl, glue::glue("table_{self$pheno}.pdf"))

      return(tbl)
    }
  )
)
