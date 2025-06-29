#' @title TableGT R6 Class
#' @description An R6 class to create and save formatted `gt` tables for neurocognitive domain data.
#' @docType class
#' @format An R6 class object.
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
#'   \item{\code{initialize(data, pheno = NULL, table_name = NULL, source_note = NULL, names = NULL, title = NULL, tab_stubhead = NULL, caption = NULL, process_md = FALSE, fn_list = list(), grp_list = list(), dynamic_grp = NULL, vertical_padding = NULL, multiline = TRUE)}}{
#'     Initialize a new TableGT object with configuration and data.
#'   }
#'   \item{\code{build_table()}}{
#'     Construct and return the formatted gt table, with optional saving as PNG and PDF.
#'   }
#' }
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
#' @param data A data frame to use in table generation.
#' @param pheno A string specifying the phenotype identifier.
#' @param table_name File-safe name for saving the table.
#' @param source_note A footnote to be added as a source note.
#' @param names Optional renamed column headers.
#' @param title Table title.
#' @param tab_stubhead Label for the stubhead.
#' @param caption Optional caption text.
#' @param process_md Logical. Whether to parse markdown syntax in labels or values.
#' @param fn_list Named list of score type footnotes.
#' @param grp_list Named list of score type row groups.
#' @param dynamic_grp Named list of valid score types per group.
#' @param vertical_padding Numeric scale to control padding.
#' @param multiline Logical; whether to use multiline footnotes.
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
          percentile = gt::md("**\\u2030 Rank**"),
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

#' @title TableGT2 R6 Class for NeurotypR-Style Tables
#' @description An enhanced R6 class to create formatted `gt` tables that match the original NeurotypR::tbl_gt2 formatting exactly.
#' This class automatically detects score types and applies appropriate footnotes with numbered references.
#' @docType class
#' @format An R6 class object.
#'
#' @field data A data frame with columns test_name, scale, score, percentile, and range.
#' @field pheno Phenotype identifier string used for file naming.
#' @field table_name Name of the table file to be saved.
#' @field title Table title string.
#' @field source_note Optional source note for the table.
#' @field vertical_padding Numeric scale for vertical padding in the table.
#' @field multiline Logical; whether footnotes should wrap onto multiple lines.
#'
#' @section Methods:
#' \describe{
#'   \item{\code{initialize(data, pheno, table_name, title = NULL, source_note = NULL, vertical_padding = 0, multiline = TRUE)}}{
#'     Initialize a new TableGT2 object with configuration and data.
#'   }
#'   \item{\code{build_table()}}{
#'     Construct and return the formatted gt table with automatic score type detection and footnotes.
#'   }
#'   \item{\code{create_footnote_mapping(data)}}{
#'     Create footnote mapping based on test names using standard neuropsychological test conventions.
#'   }
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr select mutate
#' @importFrom gt gt cols_label tab_stub_indent tab_header sub_missing tab_options
#'   cols_align gtsave tab_style cells_row_groups md tab_footnote opt_vertical_padding
#'   text_transform html cell_text cell_borders px
#' @importFrom gtExtras gt_theme_538
#' @importFrom glue glue
#' @export
#' @param data A data frame to use in table generation.
#' @param pheno A string specifying the phenotype identifier.
#' @param table_name File-safe name for saving the table.
#' @param title Table title.
#' @param source_note Optional source note for the table.
#' @param vertical_padding Numeric scale for vertical padding in the table.
#' @param multiline Logical; whether footnotes should wrap onto multiple lines.
TableGT2 <- R6::R6Class(
  classname = "TableGT2",
  public = list(
    data = NULL,
    pheno = NULL,
    table_name = NULL,
    title = NULL,
    source_note = NULL,
    vertical_padding = 0,
    multiline = TRUE,

    initialize = function(
      data,
      pheno,
      table_name,
      title = NULL,
      source_note = NULL,
      vertical_padding = 0,
      multiline = TRUE
    ) {
      self$data <- data
      self$pheno <- pheno
      self$table_name <- table_name
      self$title <- title
      self$source_note <- source_note
      self$vertical_padding <- vertical_padding
      self$multiline <- multiline
    },

    build_table = function() {
      # Prepare data
      data_counts <- self$data |>
        dplyr::select(test_name, scale, score, percentile, range) |>
        dplyr::mutate(
          score = ifelse(is.na(score) | score == 0, NA_integer_, score),
          percentile = ifelse(
            is.na(percentile) | percentile == 0,
            NA_real_,
            percentile
          ),
          test_name = as.character(test_name),
          scale = as.character(scale)
        )

      # Determine score types and create footnotes
      footnote_mapping <- self$create_footnote_mapping(data_counts)

      # Create base table
      table <- data_counts |>
        gt::gt(
          rowname_col = "scale",
          groupname_col = "test_name",
          process_md = FALSE,
          rownames_to_stub = TRUE,
          id = paste0("table_", self$pheno)
        ) |>
        gt::cols_label(
          score = gt::md("**SCORE**"),
          percentile = gt::md("**\\u2030 RANK**"),
          range = gt::md("**RANGE**")
        ) |>
        gt::sub_missing(missing_text = "--") |>
        gt::tab_stub_indent(rows = everything(), indent = 2) |>
        gt::cols_align(align = "center", columns = c(score, percentile)) |>
        gt::cols_align(align = "left", columns = range)

      # Add title if provided
      if (!is.null(self$title)) {
        table <- table |> gt::tab_header(title = self$title)
      }

      # Add footnotes with superscript numbers
      footnote_counter <- 1

      for (test_name in names(footnote_mapping)) {
        footnote_text <- footnote_mapping[[test_name]]

        # Add superscript number to group name and footnote
        table <- table |>
          gt::tab_style(
            style = gt::cell_text(transform = "uppercase", weight = "bold"),
            locations = gt::cells_row_groups(groups = test_name)
          ) |>
          gt::text_transform(
            locations = gt::cells_row_groups(groups = test_name),
            fn = function(x) {
              paste0(x, gt::html(paste0("<sup>", footnote_counter, "</sup>")))
            }
          ) |>
          gt::tab_footnote(
            footnote = gt::html(paste0(
              "<sup>",
              footnote_counter,
              "</sup>",
              footnote_text
            )),
            locations = gt::cells_row_groups(groups = test_name)
          )

        footnote_counter <- footnote_counter + 1
      }

      # Apply styling to match original NeurotypR format
      table <- table |>
        gt::tab_style(
          style = gt::cell_text(size = "small"),
          locations = gt::cells_source_notes()
        ) |>
        gt::tab_style(
          style = gt::cell_text(weight = "bold", transform = "uppercase"),
          locations = gt::cells_row_groups()
        ) |>
        gt::tab_style(
          style = gt::cell_borders(
            sides = "bottom",
            color = "gray",
            weight = gt::px(1)
          ),
          locations = gt::cells_row_groups()
        ) |>
        gtExtras::gt_theme_538() |>
        gt::tab_options(
          row_group.font.weight = "bold",
          footnotes.multiline = self$multiline,
          footnotes.font.size = "small",
          table.font.size = "small",
          row_group.border.top.style = "solid",
          row_group.border.top.width = gt::px(2),
          row_group.border.top.color = "black",
          row_group.border.bottom.style = "solid",
          row_group.border.bottom.width = gt::px(1),
          row_group.border.bottom.color = "gray"
        ) |>
        gt::opt_vertical_padding(scale = self$vertical_padding)

      # Save table files
      gt::gtsave(table, glue::glue("{self$table_name}.pdf"))
      gt::gtsave(table, glue::glue("{self$table_name}.png"))

      return(table)
    },

    create_footnote_mapping = function(data) {
      # Get unique test names
      test_names <- unique(data$test_name)
      footnote_mapping <- list()

      for (test_name in test_names) {
        # Determine score type based on test name patterns
        if (
          grepl(
            "WAIS|WISC|WPPSI|NEPSY|D-KEFS|RBANS",
            test_name,
            ignore.case = TRUE
          )
        ) {
          footnote_mapping[[
            test_name
          ]] <- "Scaled score: Mean = 10 [50th\\u2030], SD \\u00B1 3 [16th\\u2030, 84th\\u2030]"
        } else if (grepl("NAB|CELF|ABAS", test_name, ignore.case = TRUE)) {
          footnote_mapping[[
            test_name
          ]] <- "Standard score: Mean = 100 [50th\\u2030], SD \\u00B1 15 [16th\\u2030, 84th\\u2030]"
        } else if (
          grepl(
            "NIH|EXAMINER|PAI|CAARS|BASC|Trail|TMT",
            test_name,
            ignore.case = TRUE
          )
        ) {
          footnote_mapping[[
            test_name
          ]] <- "T-score: Mean = 50 [50th\\u2030], SD \\u00B1 10 [16th\\u2030, 84th\\u2030]"
        } else {
          # Default to standard score for unknown tests
          footnote_mapping[[
            test_name
          ]] <- "Standard score: Mean = 100 [50th\\u2030], SD \\u00B1 15 [16th\\u2030, 84th\\u2030]"
        }
      }

      return(footnote_mapping)
    }
  )
)

#' Create NeurotypR-Style Table (Function Wrapper)
#'
#' A function wrapper around the TableGT2 R6 class for backward compatibility and easier usage.
#'
#' @param data A data frame with columns test_name, scale, score, percentile, range
#' @param pheno Phenotype identifier string for file naming
#' @param table_name Name for saved table files
#' @param title Optional table title
#' @param source_note Optional source note
#' @param vertical_padding Numeric scale for vertical padding (default 0)
#' @param multiline Logical for multiline footnotes (default TRUE)
#'
#' @return A formatted gt table object
#' @export
create_neurotyp_table <- function(
  data,
  pheno,
  table_name,
  title = NULL,
  source_note = NULL,
  vertical_padding = 0,
  multiline = TRUE
) {
  # Create and use TableGT2 object
  table_obj <- TableGT2$new(
    data = data,
    pheno = pheno,
    table_name = table_name,
    title = title,
    source_note = source_note,
    vertical_padding = vertical_padding,
    multiline = multiline
  )

  return(table_obj$build_table())
}

#' tbl_gt2 - Alias for NeurotypR compatibility
#'
#' This function provides compatibility with NeurotypR::tbl_gt2 calls
#'
#' @param data A data frame with columns test_name, scale, score, percentile, range
#' @param pheno Phenotype identifier string for file naming (default "table")
#' @param table_name Name for saved table files (optional, defaults to pheno)
#' @param title Optional table title
#' @param source_note Optional source note
#' @param vertical_padding Numeric scale for vertical padding (default 0)
#' @param multiline Logical for multiline footnotes (default TRUE)
#'
#' @return A formatted gt table object
#' @export
tbl_gt2 <- function(
  data,
  pheno = "table",
  table_name = NULL,
  title = NULL,
  source_note = NULL,
  vertical_padding = 0,
  multiline = TRUE
) {
  # Use pheno as table_name if not specified
  if (is.null(table_name)) {
    table_name <- pheno
  }

  # Call the create_neurotyp_table function
  return(create_neurotyp_table(
    data = data,
    pheno = pheno,
    table_name = table_name,
    title = title,
    source_note = source_note,
    vertical_padding = vertical_padding,
    multiline = multiline
  ))
}
