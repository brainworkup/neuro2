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
#'   \item{build_table}{Construct and return the formatted `gt` table, with optional saving as PNG and PDF.}
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

      # Save outputs - explicitly using webshot2 for PNG
      gt::gtsave(
        tbl,
        glue::glue("table_{self$pheno}.png"),
        webshot = webshot2::webshot
      )
      gt::gtsave(tbl, glue::glue("table_{self$pheno}.pdf"))

      return(tbl)
    }
  )
)

#' TableGT2 R6 Class for NeurotypR-Style Tables
#'
#' An enhanced R6 class to create formatted `gt` tables that match the original NeurotypR::tbl_gt2 formatting exactly.
#' This class automatically detects score types and applies appropriate footnotes with numbered references.
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
#'   \item{initialize(data, pheno, table_name, title, source_note, vertical_padding, multiline)}{Initialize a new TableGT2 object}
#'   \item{build_table()}{Construct and return the formatted gt table with automatic footnotes}
#'   \item{create_footnote_mapping(data)}{Internal method to create footnote mappings based on test names}
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

    #' @description
    #' Initialize a new TableGT2 object with configuration and data.
    #'
    #' @param data A data frame with required columns: test_name, scale, score, percentile, range
    #' @param pheno Phenotype identifier string for file naming
    #' @param table_name Name for saved table files
    #' @param title Optional table title
    #' @param source_note Optional source note
    #' @param vertical_padding Numeric scale for vertical padding (default 0)
    #' @param multiline Logical for multiline footnotes (default TRUE)
    #'
    #' @return A new TableGT2 object
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

    #' @description
    #' Construct and return the formatted gt table with automatic score type detection and footnotes.
    #'
    #' @return A formatted gt table object
    build_table = function() {
      # Prepare data
      data_counts <- self$data %>%
        dplyr::select(test_name, scale, score, percentile, range) %>%
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
      table <- data_counts %>%
        gt::gt(
          rowname_col = "scale",
          groupname_col = "test_name",
          process_md = FALSE,
          rownames_to_stub = TRUE,
          id = paste0("table_", self$pheno)
        ) %>%
        gt::cols_label(
          score = gt::md("**SCORE**"),
          percentile = gt::md("**\u2030 RANK**"),
          range = gt::md("**RANGE**")
        ) %>%
        gt::sub_missing(missing_text = "--") %>%
        gt::tab_stub_indent(rows = everything(), indent = 2) %>%
        gt::cols_align(align = "center", columns = c(score, percentile)) %>%
        gt::cols_align(align = "left", columns = range)

      # Add title if provided
      if (!is.null(self$title)) {
        table <- table %>% gt::tab_header(title = self$title)
      }

      # Add footnotes with superscript numbers
      footnote_counter <- 1

      for (test_name in names(footnote_mapping)) {
        footnote_text <- footnote_mapping[[test_name]]

        # Add superscript number to group name and footnote
        table <- table %>%
          gt::tab_style(
            style = gt::cell_text(transform = "uppercase", weight = "bold"),
            locations = gt::cells_row_groups(groups = test_name)
          ) %>%
          gt::text_transform(
            locations = gt::cells_row_groups(groups = test_name),
            fn = function(x) {
              paste0(x, gt::html(paste0("<sup>", footnote_counter, "</sup>")))
            }
          ) %>%
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
      table <- table %>%
        gt::tab_style(
          style = gt::cell_text(size = "small"),
          locations = gt::cells_source_notes()
        ) %>%
        gt::tab_style(
          style = gt::cell_text(weight = "bold", transform = "uppercase"),
          locations = gt::cells_row_groups()
        ) %>%
        gt::tab_style(
          style = gt::cell_borders(
            sides = "bottom",
            color = "gray",
            weight = gt::px(1)
          ),
          locations = gt::cells_row_groups()
        ) %>%
        gtExtras::gt_theme_538() %>%
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
        ) %>%
        gt::opt_vertical_padding(scale = self$vertical_padding)

      # Save table files - explicitly using webshot2 for PNG
      gt::gtsave(table, glue::glue("{self$table_name}.pdf"))
      gt::gtsave(
        table,
        glue::glue("{self$table_name}.png"),
        webshot = webshot2::webshot
      )

      return(table)
    },

    #' @description
    #' Create footnote mapping based on test names using standard neuropsychological test conventions.
    #'
    #' @param data Data frame containing test_name column
    #'
    #' @return Named list mapping test names to appropriate footnote text
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
          ]] <- "Scaled score: Mean = 10 [50th\\u2030], SD \\u00b1 3 [16th\\u2030, 84th\\u2030]"
        } else if (grepl("NAB|CELF|ABAS", test_name, ignore.case = TRUE)) {
          footnote_mapping[[
            test_name
          ]] <- "Standard score: Mean = 100 [50th\\u2030], SD \\u00b1 15 [16th\\u2030, 84th\\u2030]"
        } else if (
          grepl(
            "NIH|EXAMINER|PAI|CAARS|BASC|Trail|TMT",
            test_name,
            ignore.case = TRUE
          )
        ) {
          footnote_mapping[[
            test_name
          ]] <- "T-score: Mean = 50 [50th\\u2030], SD \\u00b1 10 [16th\\u2030, 84th\\u2030]"
        } else {
          # Default to standard score for unknown tests
          footnote_mapping[[
            test_name
          ]] <- "Standard score: Mean = 100 [50th\\u2030], SD \\u00b1 15 [16th\\u2030, 84th\\u2030]"
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


#' Build a gt table with the unified R6 class (helper wrapper)
#'
#' Mirrors your old `tbl_gt2()` signature so you can swap with minimal changes.
#'
#' @export
tbl_gt_unified <- function(
  data,
  pheno,
  table_name,
  # optional pieces:
  source_note = NULL,
  fn_scaled_score = NULL,
  fn_standard_score = NULL,
  fn_t_score = NULL,
  fn_z_score = NULL,
  grp_scaled_score = NULL,
  grp_standard_score = NULL,
  grp_t_score = NULL,
  grp_z_score = NULL,
  dynamic_grp = NULL,
  labels = list(
    score = "**SCORE**",
    percentile = "**\u2030 RANK**",
    range = "**RANGE**"
  ),
  stubhead = "Test / Subtest",
  caption = NULL,
  vertical_padding = 0,
  multiline = TRUE,
  show_source_note = TRUE,
  keep_intermediate = FALSE,
  save = FALSE,
  out_dir = ".",
  formats = c("png"),
  dpi = 300,
  width = NULL,
  height = NULL
) {
  footnotes_manual <- purrr::compact(list(
    scaled_score = fn_scaled_score,
    standard_score = fn_standard_score,
    t_score = fn_t_score,
    z_score = fn_z_score
  ))

  groups_manual <- purrr::compact(list(
    scaled_score = grp_scaled_score,
    standard_score = grp_standard_score,
    t_score = grp_t_score,
    z_score = grp_z_score
  ))

  cfg <- list(
    labels = labels,
    stubhead = stubhead,
    caption = caption,
    vertical_padding = vertical_padding,
    multiline = multiline,
    show_source_note = show_source_note,
    keep_intermediate = keep_intermediate,
    theme = "538"
  )

  obj <- TableGTUnified$new(
    data = data,
    pheno = pheno,
    table_name = table_name,
    config = cfg,
    footnotes_manual = footnotes_manual,
    groups_manual = groups_manual,
    dynamic_grp = dynamic_grp,
    source_note = source_note
  )

  g <- obj$build_table()

  if (isTRUE(save)) {
    obj$save(
      out_dir = out_dir,
      formats = formats,
      dpi = dpi,
      width = width,
      height = height
    )
  }

  g
}

#' TableGTUnified R6 Class
#'
#' Create formatted neuropsych tables with **gt**, supporting both automated and manual
#' footnotes/groupings. This merges functionality of your previous `TableGT` variants.
#'
#' @docType class
#' @name TableGTUnified
#' @rdname TableGTUnified
#'
#' @description
#' The class:
#' - Accepts raw data plus configuration (labels, caption, padding, etc.).
#' - Detects score-type groups & footnotes automatically, but allows manual overrides.
#' - Builds a `gt` table and can save it to PNG/PDF/HTML.
#'
#' @field data A data frame with columns such as test_name, scale, score, percentile, and range.
#' @field pheno Phenotype identifier string or object. Not used internally by default.
#' @field table_name Character string. Basename used when saving tables.
#' @field gt_object The built gt_tbl object (after build_table()).
#' @field config Named list of options (labels, stubhead, caption, theme, vertical_padding, multiline, etc.).
#' @field footnotes_manual Named list: score type -> gt::md() footnote text. Overrides/extends auto footnotes.
#' @field groups_manual Named list: score type -> character vector of row labels to group. Overrides/extends auto groups.
#' @field dynamic_grp Optional named list of groups computed externally; if NULL, auto-detected.
#' @field source_note Optional single gt::md() or character to add as a source note.
#'
#' @section Methods:
#' \describe{
#'   \item{$initialize(data, pheno, table_name, config, footnotes_manual, groups_manual, dynamic_grp, source_note)}{Constructor. Stores inputs and merges defaults.}
#'   \item{$build_table()}{Builds and returns the `gt` object (also stored in `gt_object`).}
#'   \item{$save(out_dir, formats, dpi, width, height, ...)}{Saves the `gt` object to disk (PNG/PDF/HTML).}
#'   \item{$set_source_note(note)}{Replace/set the source note.}
#'   \item{$add_manual_footnotes(named_list)}{Add or override manual footnotes.}
#'   \item{$add_manual_groups(named_list)}{Add or override manual groups.}
#' }
#'
#' @param data `data.frame`. Passed to `$initialize()`.
#' @param pheno Optional object. Passed to `$initialize()`.
#' @param table_name `character`. Passed to `$initialize()`.
#' @param config `list`. Configuration (labels, stubhead, caption, etc.). Passed to `$initialize()`.
#' @param footnotes_manual `list`. Named list of manual footnotes. Passed to `$initialize()`.
#' @param groups_manual `list`. Named list of manual row groups. Passed to `$initialize()`.
#' @param dynamic_grp `list` or `NULL`. Precomputed groups. Passed to `$initialize()`.
#' @param source_note `character`/`gt::md()`. Passed to `$initialize()` or `set_source_note()`.
#'
#' @param out_dir `character`. Directory to save output (`$save()`).
#' @param formats `character`. Vector of extensions (e.g., `"png"`, `"pdf"`, `"html"`) for `$save()`.
#' @param dpi `numeric`. Resolution for raster formats in `$save()`.
#' @param width `numeric` or `NULL`. Width dimension passed to `gt::gtsave()` in `$save()`.
#' @param height `numeric` or `NULL`. Height dimension passed to `gt::gtsave()` in `$save()`.
#' @param ... Additional arguments passed to `gt::gtsave()` in `$save()`.
#' @param named_list `list`. For manual footnotes/groups methods.
#' @param note `character`/`gt::md()`. New source note for `set_source_note()`.
#'
#' @return
#' - `$build_table()` returns a `gt_tbl`.
#' - `$save()` returns (invisibly) `TRUE`.
#' - Other mutator methods return the object (invisibly) for chaining.
#'
#' @examples
#' \dontrun{
#' tbl <- TableGTUnified$new(
#'   data = data_memory_tbl,
#'   pheno = pheno,
#'   table_name = "table_memory",
#'   config = list(
#'     labels = list(score = "**SCORE**", percentile = "**\u2030 RANK**", range = "**RANGE**"),
#'     stubhead = "Test / Subtest",
#'     caption = NULL,
#'     theme = "538",
#'     vertical_padding = 0,
#'     multiline = TRUE
#'   ),
#'   footnotes_manual = list(
#'     scaled_score   = gt::md("Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]"),
#'     standard_score = gt::md("Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]")
#'   ),
#'   groups_manual = list(
#'     scaled_score   = c("WAIS-IV", "WISC-V"),
#'     standard_score = c("NAB")
#'   )
#' )
#'
#' g <- tbl$build_table()
#' tbl$save(out_dir = "tables", formats = c("png","pdf"))
#' }
#'
#' @import R6
#' @importFrom dplyr mutate case_when select
#' @importFrom gt gt cols_label tab_stubhead tab_caption tab_source_note tab_footnote
#'   opt_vertical_padding cells_row_groups cells_title gtsave tab_row_group
#' @importFrom gt cell_borders tab_style cells_body cells_stub md cells_body
#' @importFrom gtExtras gt_theme_538
#' @keywords tables
#' @export
TableGTUnified <- R6::R6Class(
  classname = "TableGTUnified",
  public = list(
    # Public fields
    data = NULL,
    pheno = NULL,
    table_name = NULL,
    gt_object = NULL,

    config = NULL,
    footnotes_manual = NULL,
    groups_manual = NULL,
    dynamic_grp = NULL,
    source_note = NULL,

    #' @description
    #' Create a new `TableGTUnified` object.
    #'
    #' @return A `TableGTUnified` object.
    initialize = function(
      data,
      pheno = NULL,
      table_name,
      config = list(),
      footnotes_manual = list(),
      groups_manual = list(),
      dynamic_grp = NULL,
      source_note = NULL
    ) {
      stopifnot(is.data.frame(data))
      self$data <- data
      self$pheno <- pheno
      self$table_name <- table_name

      self$config <- .merge_list_defaults(
        config,
        list(
          labels = list(
            score = "**Score**",
            percentile = "**% Rank**",
            range = "**Range**"
          ),
          stubhead = "Scale / Subtest",
          caption = NULL,
          theme = "538",
          vertical_padding = 0,
          multiline = TRUE,
          show_source_note = TRUE,
          keep_intermediate = FALSE
        )
      )

      self$footnotes_manual <- footnotes_manual
      self$groups_manual <- groups_manual
      self$dynamic_grp <- dynamic_grp
      self$source_note <- source_note
    },

    #' @description
    #' Build the `gt` table from the current state and store it in `gt_object`.
    #' @return A `gt_tbl` object.
    build_table = function() {
      d <- self$data

      # Expected columns (best-effort check)
      expected_cols <- c("scale", "score", "percentile", "range", "test_name")
      missing <- setdiff(expected_cols, names(d))
      if (length(missing)) {
        warning(
          "Missing columns: ",
          paste(missing, collapse = ", "),
          ". Some features may not work."
        )
      }

      # Footnotes & groups (auto + manual)
      auto_foot <- private$create_footnote_mapping()
      all_foot <- utils::modifyList(auto_foot, self$footnotes_manual)

      auto_group <- private$detect_groups()
      all_groups <- private$merge_groups(auto_group, self$groups_manual)

      g <- gt::gt(d)

      # Labels
      g <- private$apply_labels(g)

      # Stub head
      g <- gt::tab_stubhead(g, label = self$config$stubhead)

      # Caption
      if (!is.null(self$config$caption)) {
        g <- gt::tab_caption(g, title = self$config$caption)
      }

      # Theme & basic opts
      g <- private$apply_theme(g)

      # Add row groups
      g <- private$add_row_groups(g, all_groups)

      # Footnotes
      g <- private$add_footnotes(g, all_foot, all_groups)

      # Source note (respect toggle)
      if (isTRUE(self$config$show_source_note) && !is.null(self$source_note)) {
        g <- gt::tab_source_note(g, source_note = self$source_note)
      }

      self$gt_object <- g
      g
    },

    #' @description
    #' Save the built table to disk.
    #' @return (Invisibly) TRUE on success.
    save = function(
      out_dir = ".",
      formats = c("png"),
      dpi = 300,
      width = NULL,
      height = NULL,
      ...
    ) {
      stopifnot(!is.null(self$gt_object))
      dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

      for (ext in formats) {
        file <- file.path(out_dir, paste0(self$table_name, ".", ext))
        gt::gtsave(
          data = self$gt_object,
          filename = file,
          vwidth = width,
          vheight = height,
          dpi = dpi,
          ...
        )
      }
      invisible(TRUE)
    },

    #' @description
    #' Set or replace the source note.
    #' @return The object (invisibly) for chaining.
    set_source_note = function(note) {
      self$source_note <- note
      invisible(self)
    },

    #' @description
    #' Add or override manual footnotes.
    #' @return The object (invisibly) for chaining.
    add_manual_footnotes = function(named_list) {
      stopifnot(is.list(named_list))
      self$footnotes_manual <- utils::modifyList(
        self$footnotes_manual,
        named_list
      )
      invisible(self)
    },

    #' @description
    #' Add or override manual groups.
    #' @return The object (invisibly) for chaining.
    add_manual_groups = function(named_list) {
      stopifnot(is.list(named_list))
      self$groups_manual <- private$merge_groups(self$groups_manual, named_list)
      invisible(self)
    }
  ),

  private = list(
    apply_labels = function(g) {
      labs <- self$config$labels
      lbls <- labs[names(labs) %in% names(self$data)]
      if (length(lbls)) {
        g <- gt::cols_label(g, !!!lbls)
      }
      g
    },

    apply_theme = function(g) {
      if (identical(self$config$theme, "538")) {
        g <- gtExtras::gt_theme_538(g)
      }
      g <- gt::opt_vertical_padding(g, scale = self$config$vertical_padding)
      g
    },

    detect_groups = function() {
      if (!is.null(self$dynamic_grp)) {
        return(self$dynamic_grp)
      }
      if (!"test_name" %in% names(self$data)) {
        return(list())
      }
      split(self$data$scale, self$data$test_name)
    },

    merge_groups = function(g1, g2) {
      out <- g1
      for (nm in names(g2)) {
        out[[nm]] <- unique(c(out[[nm]], g2[[nm]]))
      }
      out
    },

    add_row_groups = function(g, groups) {
      if (is.null(groups) || !length(groups)) {
        return(g)
      }
      for (nm in names(groups)) {
        rows_here <- groups[[nm]]
        if (length(rows_here)) {
          g <- gt::tab_row_group(g, group = nm, rows = scale %in% rows_here)
        }
      }
      g
    },

    create_footnote_mapping = function() {
      defaults <- list(
        scaled_score = gt::md(
          "Scaled score: M = 10 [50th\u2030], SD = 3 [16th\u2030, 84th\u2030]"
        ),
        standard_score = gt::md(
          "Standard score: M = 100 [50th\u2030], SD = 15 [16th\u2030, 84th\u2030]"
        ),
        t_score = gt::md(
          "T score: M = 50 [50th\u2030], SD = 10 [16th\u2030, 84th\u2030]"
        ),
        z_score = gt::md(
          "z score: M = 0 [50th\u2030], SD = 1 [16th\u2030, 84th\u2030]"
        )
      )

      present <- character(0)
      if (!is.null(self$groups_manual)) {
        present <- union(present, names(self$groups_manual))
      }
      if (!is.null(self$dynamic_grp)) {
        present <- union(present, names(self$dynamic_grp))
      }

      defaults[names(defaults) %in% present]
    },

    add_footnotes = function(g, foot_map, groups) {
      if (is.null(foot_map) || !length(foot_map)) {
        return(g)
      }

      for (nm in names(foot_map)) {
        note <- foot_map[[nm]]
        if (!is.null(groups[[nm]]) && length(groups[[nm]])) {
          g <- gt::tab_footnote(
            g,
            footnote = note,
            locations = gt::cells_row_groups(groups = nm)
          )
        } else {
          g <- gt::tab_footnote(
            g,
            footnote = note,
            locations = gt::cells_title(groups = "title")
          )
        }
      }
      g
    }
  )
)

#' @noRd
.merge_list_defaults <- function(x, defaults) {
  utils::modifyList(defaults, x)
}
