#' TableGTR6 R6 Class
#'
#' A modified version of the TableGT R6 class that doesn't automatically save the table.
#' This class is identical to TableGT but removes the automatic saving in the build_table() method.
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
#' @field row_score_type_map A named list mapping test batteries to their scale-specific score types.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new TableGTR6 object with configuration and data.}
#'   \item{build_table}{Construct and return the formatted `gt` table, without saving.}
#'   \item{save_table}{Save the table to PNG and PDF files.}
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
TableGTR6 <- R6::R6Class(
  classname = "TableGTR6",
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
    row_score_type_map = NULL,

    #' @description
    #' Initialize a new TableGTR6 object with configuration and data.
    #'
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
    #' @param row_score_type_map Named list mapping test batteries to their scale-specific score types.
    #'
    #' @return A new TableGTR6 object
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
      multiline = TRUE,
      row_score_type_map = NULL
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
      self$row_score_type_map <- row_score_type_map
    },

    #' @description
    #' Construct and return the formatted `gt` table using optimized score type handling.
    #' This method builds the table without automatically saving it, using cached score type
    #' mappings for improved performance.
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
          percentile = gt::md("**‰ Rank**"),
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

      # Use cached score type mappings instead of rebuilding every time
      existing_groups <- unique(self$data$test_name)

      # Initialize/ensure cache is built (this runs only once across all domains)
      if (!exists(".score_type_cache")) {
        source("R/score_type_cache.R") # Load the cache from above
      }
      .score_type_cache$build_mappings()

      # Get score type groups efficiently
      if (length(self$grp_list) == 0) {
        # Auto-detect score groups using cache
        self$grp_list <- .score_type_cache$get_score_groups(existing_groups)
        message(paste(
          "Auto-detected score groups for",
          length(existing_groups),
          "tests"
        ))
      }

      # Get relevant footnotes efficiently
      score_types_needed <- names(self$grp_list)
      if (length(self$fn_list) == 0) {
        self$fn_list <- .score_type_cache$get_footnotes(score_types_needed)
      }

      # Handle multi-score batteries efficiently
      multi_score_batteries <- existing_groups[sapply(
        existing_groups,
        function(x) {
          .score_type_cache$is_multi_score_battery(x)
        }
      )]

      if (length(multi_score_batteries) > 0) {
        message(paste(
          "Found multi-score batteries:",
          paste(multi_score_batteries, collapse = ", ")
        ))

        # Process multi-score batteries with simplified logic
        for (battery in multi_score_batteries) {
          private$handle_multi_score_battery(battery, tbl)
        }
      }

      # Add footnotes for regular score type groups
      for (score_type in names(self$fn_list)) {
        footnote <- self$fn_list[[score_type]]
        groups <- intersect(self$grp_list[[score_type]], existing_groups)

        # Skip battery-specific groups
        if (
          any(sapply(multi_score_batteries, function(b) {
            grepl(paste0("^", tolower(b), "_"), score_type)
          }))
        ) {
          next
        }

        if (!is.null(footnote) && length(groups) > 0) {
          message(paste(
            "Adding",
            score_type,
            "footnote to",
            length(groups),
            "groups"
          ))

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

      return(tbl)
    },

    # Add this private method to handle multi-score batteries
    handle_multi_score_battery = function(battery, tbl) {
      # Simplified multi-score battery handling
      battery_scales <- self$data$scale[self$data$test_name == battery]

      # Define standard score patterns
      standard_patterns <- c(
        "Index",
        "Composite",
        "IQ",
        "Sum",
        "Total",
        "Quotient"
      )

      # Classify scales
      standard_scales <- battery_scales[sapply(battery_scales, function(scale) {
        any(sapply(standard_patterns, function(pattern) {
          grepl(pattern, scale, ignore.case = TRUE)
        }))
      })]

      scaled_scales <- setdiff(battery_scales, standard_scales)

      # Add battery-specific footnotes
      if (length(standard_scales) > 0) {
        fn_key <- paste0(tolower(battery), "_standard")
        self$fn_list[[fn_key]] <- .score_type_cache$fn_list$standard_score

        tbl <- tbl |>
          gt::tab_footnote(
            footnote = self$fn_list[[fn_key]],
            locations = gt::cells_row_groups(groups = battery)
          )
      }

      if (length(scaled_scales) > 0) {
        fn_key <- paste0(tolower(battery), "_scaled")
        self$fn_list[[fn_key]] <- .score_type_cache$fn_list$scaled_score

        tbl <- tbl |>
          gt::tab_footnote(
            footnote = self$fn_list[[fn_key]],
            locations = gt::cells_row_groups(groups = battery)
          )
      }
    },

    #' @description
    #' Save the table to PNG and PDF files.
    #'
    #' @param tbl A gt table object to save.
    #' @param dir Directory to save the files in (default: current directory).
    #' @return Invisibly returns self for method chaining.
    save_table = function(tbl, dir = ".") {
      # Save PNG
      gt::gtsave(
        tbl,
        filename = file.path(dir, paste0(self$table_name, ".png"))
      )

      # Save PDF
      gt::gtsave(
        tbl,
        filename = file.path(dir, paste0(self$table_name, ".pdf"))
      )

      invisible(self)
    }
  ),
)
