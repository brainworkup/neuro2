#' TableGT2 R6 Class
#'
#' An R6 class to create and save formatted `gt` tables for neurocognitive domain data.
#' An updated version of the TableGT class with enhanced functionality.
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
#' @field fn_scaled_score Footnote for scaled score.
#' @field fn_standard_score Footnote for standard score.
#' @field fn_t_score Footnote for t score.
#' @field fn_z_score Footnote for z score.
#' @field fn_raw_score Footnote for raw scores.
#' @field grp_scaled_score Groups for scaled score.
#' @field grp_standard_score Groups for standard score.
#' @field grp_t_score Groups for t score.
#' @field grp_z_score Groups for z score.
#' @field grp_raw_score Groups for raw scores.
#' @field dynamic_grp A named list defining which groups support which score types.
#' @field vertical_padding Numeric scale for vertical padding in the table.
#' @field multiline Logical; whether footnotes should wrap onto multiple lines.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new TableGT2 object with configuration and data.}
#'   \item{build_table}{Construct and return the formatted `gt` table, with optional saving as PNG and PDF. This method processes the data, applies styling, adds footnotes, and saves the output if configured.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr across mutate group_by summarize arrange select if_else .data
#' @importFrom tidyr replace_na
#' @importFrom gt gt cols_label tab_stub_indent tab_header sub_missing tab_options
#'   cols_align tab_source_note gtsave tab_style tab_stubhead tab_caption
#'   tab_spanner cell_text cells_body cells_row_groups md tab_footnote opt_vertical_padding
#' @importFrom gtExtras gt_theme_538
#' @importFrom glue glue
#' @export
TableGT2 <- R6::R6Class(
  classname = "TableGT2",
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
    fn_scaled_score = NULL,
    fn_standard_score = NULL,
    fn_t_score = NULL,
    fn_z_score = NULL,
    fn_raw_score = NULL,
    grp_scaled_score = NULL,
    grp_standard_score = NULL,
    grp_t_score = NULL,
    grp_z_score = NULL,
    grp_raw_score = NULL,
    dynamic_grp = NULL,
    vertical_padding = NULL,
    multiline = TRUE,

    #' @description
    #' Initialize a new TableGT2 object with configuration and data.
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
    #' @param fn_scaled_score Footnote for scaled score (default NULL).
    #' @param fn_standard_score Footnote for standard score (default NULL).
    #' @param fn_t_score Footnote for t score (default NULL).
    #' @param fn_z_score Footnote for z score (default NULL).
    #' @param fn_raw_score Footnote for raw scores (default NULL).
    #' @param grp_scaled_score Groups for scaled score (default NULL).
    #' @param grp_standard_score Groups for standard score (default NULL).
    #' @param grp_t_score Groups for t score (default NULL).
    #' @param grp_z_score Groups for z score (default NULL).
    #' @param grp_raw_score Groups for raw scores (default NULL).
    #' @param dynamic_grp Named list of valid score types per group (default NULL).
    #' @param vertical_padding Numeric scale (0–3) to control padding (default NULL).
    #' @param multiline Logical; whether to use multiline footnotes (default TRUE).
    #' @param ... Additional arguments (ignored).
    #'
    #' @return A new TableGT2 object
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
      fn_scaled_score = NULL,
      fn_standard_score = NULL,
      fn_t_score = NULL,
      fn_z_score = NULL,
      fn_raw_score = NULL,
      grp_scaled_score = NULL,
      grp_standard_score = NULL,
      grp_t_score = NULL,
      grp_z_score = NULL,
      grp_raw_score = NULL,
      dynamic_grp = NULL,
      vertical_padding = NULL,
      multiline = TRUE,
      ...
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
      self$fn_scaled_score <- fn_scaled_score
      self$fn_standard_score <- fn_standard_score
      self$fn_t_score <- fn_t_score
      self$fn_z_score <- fn_z_score
      self$fn_raw_score <- fn_raw_score
      self$grp_scaled_score <- grp_scaled_score
      self$grp_standard_score <- grp_standard_score
      self$grp_t_score <- grp_t_score
      self$grp_z_score <- grp_z_score
      self$grp_raw_score <- grp_raw_score
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
      # Create data counts
      data_counts <- self$data |>
        dplyr::select(
          .data$test_name,
          .data$scale,
          .data$score,
          .data$percentile,
          .data$range
        ) |>
        dplyr::mutate(across(
          c(.data$score, .data$percentile),
          ~ tidyr::replace_na(., replace = 0)
        ))

      # Create table
      table <- data_counts |>
        dplyr::mutate(
          score = dplyr::if_else(.data$score == 0, NA_integer_, .data$score),
          percentile = dplyr::if_else(
            .data$percentile == 0,
            NA_integer_,
            .data$percentile
          ),
          test_name = as.character(paste0(.data$test_name)),
          scale = as.character(.data$scale)
        ) |>
        gt::gt(
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
          percentile = gt::md("**% Rank**"),
          range = gt::md("**Range**")
        ) |>
        gt::tab_header(title = self$title) |>
        gt::tab_stubhead(label = self$tab_stubhead) |>
        gt::sub_missing(missing_text = "--") |>
        # Indent rows except the main index row
        gt::tab_stub_indent(
          rows = !scale %in%
            c(
              "Attention Index (ATT)",
              "Executive Functions Index (EXE)",
              "Spatial Index (SPT)",
              "Language Index (LAN)",
              "Memory Index (MEM)",
              "NAB Attention Index",
              "NAB Executive Functions Index",
              "NAB Total Index",
              "NAB Memory Index",
              "NAB Language Index",
              "NAB Spatial Index",
              "Attention Index",
              "RBANS Total Index",
              "Delayed Memory Index",
              "Immediate Memory Index",
              "Language Index",
              "Visuospatial/Constructional Index",
              "Full Scale (FSIQ)",
              "General Ability (GAI)",
              "Verbal Comprehension (VCI)",
              "Processing Speed (PSI)",
              "Perceptual Reasoning (PRI)",
              "Working Memory (WMI)",
              "Cognitive Proficiency (CPI)",
              "Fluid Reasoning (FRI)",
              "Visual Spatial (VSI)",
              "Vocabulary Acquisition (VAI)",
              "Nonverbal (NVI)"
            ),
          indent = 2
        ) |>
        # Bold the index rows in the stub column
        gt::tab_style(
          style = gt::cell_text(
            weight = "bold",
            font = c(
              gt::google_font(name = "Roboto Slab"),
              gt::google_font(name = "IBM Plex Mono"),
              gt::default_fonts()
            )
          ),
          locations = gt::cells_stub(
            rows = scale %in%
              c(
                "Attention Index (ATT)",
                "Executive Functions Index (EXE)",
                "Spatial Index (SPT)",
                "Language Index (LAN)",
                "Memory Index (MEM)",
                "NAB Attention Index",
                "NAB Executive Functions Index",
                "NAB Total Index",
                "NAB Memory Index",
                "NAB Language Index",
                "NAB Spatial Index",
                "Attention Index",
                "RBANS Total Index",
                "Delayed Memory Index",
                "Immediate Memory Index",
                "Language Index",
                "Visuospatial/Constructional Index",
                "Full Scale (FSIQ)",
                "General Ability (GAI)",
                "Verbal Comprehension (VCI)",
                "Processing Speed (PSI)",
                "Perceptual Reasoning (PRI)",
                "Working Memory (WMI)",
                "Cognitive Proficiency (CPI)",
                "Fluid Reasoning (FRI)",
                "Visual Spatial (VSI)",
                "Vocabulary Acquisition (VAI)",
                "Nonverbal (NVI)"
              )
          )
        ) |>
        gt::cols_align(
          align = "center",
          columns = c("score", "percentile", "range")
        ) # <-- End of pipe chain

      # Add footnotes individually
      if (!is.null(self$fn_scaled_score)) {
        table <- table |>
          gt::tab_footnote(
            footnote = self$fn_scaled_score,
            locations = gt::cells_row_groups(groups = self$grp_scaled_score)
          )
      }
      if (!is.null(self$fn_standard_score)) {
        table <- table |>
          gt::tab_footnote(
            footnote = self$fn_standard_score,
            locations = gt::cells_row_groups(groups = self$grp_standard_score)
          )
      }
      if (!is.null(self$fn_t_score)) {
        table <- table |>
          gt::tab_footnote(
            footnote = self$fn_t_score,
            locations = gt::cells_row_groups(groups = self$grp_t_score)
          )
      }
      if (!is.null(self$fn_z_score)) {
        table <- table |>
          gt::tab_footnote(
            footnote = self$fn_z_score,
            locations = gt::cells_row_groups(groups = self$grp_z_score)
          )
      }
      if (!is.null(self$fn_raw_score)) {
        table <- table |>
          gt::tab_footnote(
            footnote = self$fn_raw_score,
            locations = gt::cells_row_groups(groups = self$grp_raw_score)
          )
      }

      # Adding source note and styling
      table <- table |>
        gt::tab_style(
          style = gt::cell_text(size = "small"),
          locations = gt::cells_source_notes()
        ) |>
        gt::tab_source_note(source_note = self$source_note) |>
        gtExtras::gt_theme_538() |>
        gt::tab_options(
          row_group.font.weight = "bold",
          footnotes.multiline = self$multiline,
          footnotes.font.size = "small",
          footnotes.sep = "  " # Adjust spacing between footnotes
        ) |>
        gt::opt_vertical_padding(scale = self$vertical_padding)

      # Save outputs
      gt::gtsave(table, glue::glue("table_{self$pheno}.png"))
      gt::gtsave(table, glue::glue("table_{self$pheno}.pdf"))

      return(table)
    }
  )
)

#' Make Table Using gt Package for Neurocognitive Domains (Function Wrapper)
#'
#' A function wrapper around the TableGT2 R6 class for backward compatibility.
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
#' @param fn_scaled_score Footnote for scaled score (default NULL).
#' @param fn_standard_score Footnote for standard score (default NULL).
#' @param fn_t_score Footnote for t score (default NULL).
#' @param fn_z_score Footnote for z score (default NULL).
#' @param fn_raw_score Footnote for raw scores (default NULL).
#' @param grp_scaled_score Groups for scaled score (default NULL).
#' @param grp_standard_score Groups for standard score (default NULL).
#' @param grp_t_score Groups for t score (default NULL).
#' @param grp_z_score Groups for z score (default NULL).
#' @param grp_raw_score Groups for raw scores (default NULL).
#' @param dynamic_grp Named list of valid score types per group (default NULL).
#' @param vertical_padding Numeric scale (0–3) to control padding (default NULL).
#' @param multiline Logical; whether to use multiline footnotes (default TRUE).
#' @param ... Additional arguments to be passed to the function.
#' @return A formatted table with domain counts.
#' @rdname tbl_gt2
#' @export
tbl_gt2 <- function(
  data,
  pheno = NULL,
  table_name = NULL,
  source_note = NULL,
  names = NULL,
  title = NULL,
  tab_stubhead = NULL,
  caption = NULL,
  process_md = FALSE,
  fn_scaled_score = NULL,
  fn_standard_score = NULL,
  fn_t_score = NULL,
  fn_z_score = NULL,
  fn_raw_score = NULL,
  grp_scaled_score = NULL,
  grp_standard_score = NULL,
  grp_t_score = NULL,
  grp_z_score = NULL,
  grp_raw_score = NULL,
  dynamic_grp = NULL,
  vertical_padding = NULL,
  multiline = TRUE,
  ...
) {
  # Create TableGT2 object and build the table
  table_obj <- TableGT2$new(
    data = data,
    pheno = pheno,
    table_name = table_name,
    source_note = source_note,
    names = names,
    title = title,
    tab_stubhead = tab_stubhead,
    caption = caption,
    process_md = process_md,
    fn_scaled_score = fn_scaled_score,
    fn_standard_score = fn_standard_score,
    fn_t_score = fn_t_score,
    fn_z_score = fn_z_score,
    fn_raw_score = fn_raw_score,
    grp_scaled_score = grp_scaled_score,
    grp_standard_score = grp_standard_score,
    grp_t_score = grp_t_score,
    grp_z_score = grp_z_score,
    grp_raw_score = grp_raw_score,
    dynamic_grp = dynamic_grp,
    vertical_padding = vertical_padding,
    multiline = multiline
  )

  return(table_obj$build_table())
}
