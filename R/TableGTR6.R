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
    #' Construct and return the formatted `gt` table, without saving.
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

      # PRE-PROCESS: Fix groupings for all neuropsych tests before adding any footnotes
      # This ensures that tests are assigned to the correct score type groups

      # Try to get lookup_neuropsych_scales from various sources
      lookup_neuropsych_scales <- NULL

      # Method 1: Check if it exists in the current environment
      if (exists("lookup_neuropsych_scales", envir = environment())) {
        lookup_neuropsych_scales <- get(
          "lookup_neuropsych_scales",
          envir = environment()
        )
      }

      # Method 2: Try to get it from the package namespace
      if (is.null(lookup_neuropsych_scales)) {
        tryCatch(
          {
            lookup_neuropsych_scales <- get(
              "lookup_neuropsych_scales",
              envir = asNamespace("neuro2")
            )
          },
          error = function(e) {
            # Silent failure, will try next method
          }
        )
      }

      # Method 3: Try to load from sysdata.rda directly
      if (is.null(lookup_neuropsych_scales)) {
        sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
        if (sysdata_path != "" && file.exists(sysdata_path)) {
          temp_env <- new.env()
          tryCatch(
            {
              load(sysdata_path, envir = temp_env)
              if (exists("lookup_neuropsych_scales", envir = temp_env)) {
                lookup_neuropsych_scales <- get(
                  "lookup_neuropsych_scales",
                  envir = temp_env
                )
              }
            },
            error = function(e) {
              # Silent failure
            }
          )
        }
      }

      # Initialize the test_score_type_map
      test_score_type_map <- list(
        "scaled_score" = character(0),
        "standard_score" = character(0),
        "t_score" = character(0),
        "z_score" = character(0),
        "percentile" = character(0),
        "raw_score" = character(0),
        "base_rate" = character(0),
        "percent_mastery" = character(0)
      )

      # Extract unique test names and scales from lookup_neuropsych_scales
      if (!is.null(lookup_neuropsych_scales)) {
        message(
          "Using lookup_neuropsych_scales from sysdata.rda for score type mapping"
        )

        # Get unique score types
        score_types <- unique(lookup_neuropsych_scales$score_type)
        message(paste0(
          "Found score types: ",
          paste(score_types, collapse = ", ")
        ))

        # For each score type, find all the tests and scales that use that score type
        for (score_type in score_types) {
          # Get rows with this score type
          rows <- lookup_neuropsych_scales[
            lookup_neuropsych_scales$score_type == score_type,
          ]

          # Extract unique test names and scales
          tests <- unique(c(rows$test_name, rows$test, rows$scale))
          tests <- tests[!is.na(tests)] # Remove NA values

          # Add to the mapping
          if (score_type %in% names(test_score_type_map)) {
            test_score_type_map[[score_type]] <- unique(c(
              test_score_type_map[[score_type]],
              tests
            ))
          } else {
            test_score_type_map[[score_type]] <- tests
          }

          message(paste0(
            "Added ",
            length(tests),
            " tests/scales to ",
            score_type,
            " mapping"
          ))
        }
      } else {
        # Fallback to a minimal set of mappings if lookup_neuropsych_scales is not available
        message(
          "Warning: lookup_neuropsych_scales not found, using minimal hardcoded mappings"
        )

        # Minimal hardcoded mappings for critical tests
        test_score_type_map <- list(
          # Scaled score tests (mean=10, SD=3)
          "scaled_score" = c(
            # WISC-V/WAIS subtests
            "Similarities",
            "Vocabulary",
            "Comprehension",
            "Block Design",
            "Visual Puzzles",
            "Matrix Reasoning",
            "Figure Weights",
            "Picture Concepts",
            "Digit Span",
            "Letter-Number Sequencing",
            "Coding",
            "Symbol Search",

            # RBANS subtests (not Index scores)
            "Picture Naming",
            "Semantic Fluency",
            "List Learning",
            "Story Memory",
            "Figure Copy",
            "Line Orientation",
            "List Recall",
            "List Recognition",
            "Story Recall",
            "Figure Recall"
          ),

          # Standard score tests (mean=100, SD=15)
          "standard_score" = c(
            # IQ and Index Scores
            "Full Scale (FSIQ)",
            "Full Scale IQ (FSIQ)",
            "Verbal Comprehension (VCI)",
            "Perceptual Reasoning (PRI)",
            "Working Memory (WMI)",
            "Working Memory Index",
            "Processing Speed (PSI)",
            "Processing Speed Index",
            "General Ability (GAI)",
            "General Ability Index",
            "Cognitive Proficiency (CPI)",
            "Cognitive Proficiency Index",
            "Visual Spatial (VSI)",
            "Fluid Reasoning (FRI)",
            "Quantitative Reasoning (QRI)",

            # RBANS Index scores (not subtests)
            "RBANS Total Index",
            "Total Index",
            "Immediate Memory Index",
            "Visuospatial Index",
            "Language Index",
            "Attention Index",
            "Delayed Memory Index"
          ),

          # T-score tests (mean=50, SD=10)
          "t_score" = c(
            "BASC-3",
            "Conners",
            "Conners-4",
            "Beck Depression Inventory",
            "BDI",
            "Beck Anxiety Inventory",
            "BAI",
            "Trail Making Test",
            "ROCFT",
            "Rey-Osterrieth Complex Figure",
            "Grooved Pegboard",
            "NIH EXAMINER"
          )
        )
      }

      # Debug: Output original groupings
      message("Original score type groups:")
      for (score_type in names(self$grp_list)) {
        message(paste0(
          "  ",
          score_type,
          ": ",
          paste(self$grp_list[[score_type]], collapse = ", ")
        ))
      }

      # Make sure all required score type groups exist
      for (score_type in names(test_score_type_map)) {
        if (!score_type %in% names(self$grp_list)) {
          self$grp_list[[score_type]] <- character(0)
        }
      }

      # Find tests in our data that match our mapping
      tests_to_fix <- list()
      for (score_type in names(test_score_type_map)) {
        tests_to_fix[[score_type]] <- intersect(
          test_score_type_map[[score_type]],
          existing_groups
        )
      }

      # Define test batteries that have multiple score types within them
      multi_score_batteries <- c(
        "RBANS",
        "WISC-V",
        "WAIS-IV",
        "WAIS-5",
        "NAB",
        "NAB-S",
        "WMS-IV"
      )

      # Define patterns that identify standard scores vs scaled scores for each battery
      standard_score_patterns <- c(
        "Index",
        "Composite",
        "IQ",
        "Sum",
        "Total",
        "Quotient",
        "GIA",
        "BCA"
      )

      # Custom patterns for specific test batteries if needed
      battery_specific_patterns <- list(
        "RBANS" = list(
          standard = c("Index"),
          scaled = c(
            "Digit Span",
            "Coding",
            "Picture Naming",
            "Semantic Fluency",
            "List Learning",
            "Story Memory",
            "Figure Copy",
            "Line Orientation",
            "List Recall",
            "List Recognition",
            "Story Recall",
            "Figure Recall"
          )
        )
      )

      # Track which test batteries need special handling
      batteries_to_handle <- intersect(multi_score_batteries, existing_groups)

      if (length(batteries_to_handle) > 0) {
        message(paste0(
          "Found test batteries with multiple score types: ",
          paste(batteries_to_handle, collapse = ", ")
        ))

        # Create mapping to store which test rows should get which score type
        row_score_type_map <- list()

        # Process each test battery with multiple score types
        for (battery in batteries_to_handle) {
          message(paste0(
            "Applying special handling for ",
            battery,
            " subtests vs indices/composites"
          ))

          # Get all scales for this test battery
          battery_scales <- self$data$scale[self$data$test_name == battery]

          # Check if we have battery-specific patterns
          if (battery %in% names(battery_specific_patterns)) {
            message(paste0("  Using battery-specific patterns for ", battery))

            # Use explicit lists of standard and scaled score scales for this battery
            standard_patterns <- battery_specific_patterns[[battery]]$standard
            scaled_patterns <- battery_specific_patterns[[battery]]$scaled

            # Handle RBANS special case with explicit lists
            if (battery == "RBANS") {
              message("  Special handling for RBANS scales")
              scaled_score_scales <- battery_scales[
                battery_scales %in% scaled_patterns
              ]
              standard_score_scales <- setdiff(
                battery_scales,
                scaled_score_scales
              )
            } else {
              # For other batteries with specific patterns
              standard_score_scales <- battery_scales[sapply(
                battery_scales,
                function(scale) {
                  any(sapply(standard_patterns, function(pattern) {
                    grepl(pattern, scale, ignore.case = TRUE)
                  }))
                }
              )]
              scaled_score_scales <- setdiff(
                battery_scales,
                standard_score_scales
              )
            }
          } else {
            # Use generic pattern detection for batteries without specific patterns
            standard_score_scales <- battery_scales[sapply(
              battery_scales,
              function(scale) {
                any(sapply(standard_score_patterns, function(pattern) {
                  grepl(pattern, scale, ignore.case = TRUE)
                }))
              }
            )]

            # Identify scales that are subtests (scaled scores)
            scaled_score_scales <- setdiff(
              battery_scales,
              standard_score_scales
            )
          }

          message(paste0(
            "  ",
            battery,
            " standard score scales: ",
            paste(standard_score_scales, collapse = ", ")
          ))
          message(paste0(
            "  ",
            battery,
            " scaled score scales: ",
            paste(scaled_score_scales, collapse = ", ")
          ))

          # Store the mapping for this battery
          row_score_type_map[[battery]] <- list(
            standard_score_scales = standard_score_scales,
            scaled_score_scales = scaled_score_scales
          )

          # Remove this battery from both standard and scaled score groups
          # to prevent it from getting generic footnotes
          if (battery %in% self$grp_list$standard_score) {
            self$grp_list$standard_score <- setdiff(
              self$grp_list$standard_score,
              battery
            )
          }
          if (battery %in% self$grp_list$scaled_score) {
            self$grp_list$scaled_score <- setdiff(
              self$grp_list$scaled_score,
              battery
            )
          }

          # Create special groups for this battery's different score types
          group_key_standard <- paste0(tolower(battery), "_standard")
          group_key_scaled <- paste0(tolower(battery), "_scaled")

          # Add battery to special groups if it has scales of that type
          if (length(standard_score_scales) > 0) {
            self$grp_list[[group_key_standard]] <- battery
            # Use the standard_score footnote if it exists, otherwise use a default
            self$fn_list[[group_key_standard]] <- if (
              "standard_score" %in% names(self$fn_list)
            ) {
              self$fn_list[["standard_score"]]
            } else {
              "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
            }
          }

          if (length(scaled_score_scales) > 0) {
            self$grp_list[[group_key_scaled]] <- battery
            # Use the scaled_score footnote if it exists, otherwise use a default
            self$fn_list[[group_key_scaled]] <- if (
              "scaled_score" %in% names(self$fn_list)
            ) {
              self$fn_list[["scaled_score"]]
            } else {
              "Scaled score: Mean = 10 [50th\u2030], SD ± 3 [16th\u2030, 84th\u2030]"
            }
          }

          # Store this mapping for use during footnote application
          self$row_score_type_map <- row_score_type_map
        }
      }

      # Apply battery-specific footnotes directly to the table
      for (battery in batteries_to_handle) {
        if (
          !is.null(self$row_score_type_map) &&
            battery %in% names(self$row_score_type_map)
        ) {
          battery_map <- self$row_score_type_map[[battery]]

          # Get the standard and scaled score footnote IDs for this battery
          standard_fn_id <- paste0(tolower(battery), "_standard")
          scaled_fn_id <- paste0(tolower(battery), "_scaled")

          # Apply standard score footnote if it exists
          if (
            standard_fn_id %in%
              names(self$fn_list) &&
              battery %in% existing_groups
          ) {
            message(paste0(
              "Applying ",
              standard_fn_id,
              " footnote to battery: ",
              battery
            ))
            tbl <- tbl |>
              gt::tab_footnote(
                footnote = glue::glue_collapse(
                  self$fn_list[[standard_fn_id]],
                  sep = " "
                ),
                locations = gt::cells_row_groups(groups = battery)
              )
          }

          # Apply scaled score footnote if it exists
          if (
            scaled_fn_id %in%
              names(self$fn_list) &&
              battery %in% existing_groups
          ) {
            message(paste0(
              "Applying ",
              scaled_fn_id,
              " footnote to battery: ",
              battery
            ))
            tbl <- tbl |>
              gt::tab_footnote(
                footnote = glue::glue_collapse(
                  self$fn_list[[scaled_fn_id]],
                  sep = " "
                ),
                locations = gt::cells_row_groups(groups = battery)
              )
          }
        }
      }

      # Check if we found any tests that need fixing
      total_tests_to_fix <- sum(sapply(tests_to_fix, length))

      if (total_tests_to_fix > 0) {
        message(paste0(
          "Found ",
          total_tests_to_fix,
          " tests in the data that need score type fixing"
        ))

        # For each score type in our mapping
        for (correct_score_type in names(test_score_type_map)) {
          message(paste0(
            "Processing tests for ",
            correct_score_type,
            " score type"
          ))

          # Get tests that should be in this score type
          tests <- tests_to_fix[[correct_score_type]]

          if (length(tests) > 0) {
            # For each test that should be in this score type
            for (test_name in tests) {
              # Skip batteries handled specially above
              if (test_name %in% batteries_to_handle) {
                message(paste0(
                  "  Skipping ",
                  test_name,
                  " - handled separately"
                ))
                next
              }

              # For each score type group in our data
              for (group_score_type in names(self$grp_list)) {
                # Only process main score type groups (skip special battery groups)
                if (!grepl("^(rbans|wisc|wais|nab|wms)_", group_score_type)) {
                  # If this is NOT the correct score type for this test
                  if (group_score_type != correct_score_type) {
                    # Remove this test from the incorrect group
                    if (test_name %in% self$grp_list[[group_score_type]]) {
                      message(paste0(
                        "  Removing ",
                        test_name,
                        " from ",
                        group_score_type,
                        " group"
                      ))
                      self$grp_list[[group_score_type]] <- setdiff(
                        self$grp_list[[group_score_type]],
                        test_name
                      )
                    }
                  }
                }
              }

              # Add the test to its correct score type group if not already there
              if (!test_name %in% self$grp_list[[correct_score_type]]) {
                message(paste0(
                  "  Adding ",
                  test_name,
                  " to ",
                  correct_score_type,
                  " group"
                ))
                self$grp_list[[correct_score_type]] <- c(
                  self$grp_list[[correct_score_type]],
                  test_name
                )
              }
            }
          }
        }

        # Make sure we also fix the dynamic_grp to match
        if (!is.null(self$dynamic_grp)) {
          for (correct_score_type in names(test_score_type_map)) {
            tests <- tests_to_fix[[correct_score_type]]

            if (length(tests) > 0) {
              # For each test that should be in this score type
              for (test_name in tests) {
                # Skip batteries handled specially
                if (test_name %in% batteries_to_handle) {
                  next
                }

                # For each dynamic group
                for (group_score_type in names(self$dynamic_grp)) {
                  # If this is NOT the correct score type for this test
                  if (group_score_type != correct_score_type) {
                    # Remove this test from the incorrect dynamic group
                    if (test_name %in% self$dynamic_grp[[group_score_type]]) {
                      self$dynamic_grp[[group_score_type]] <- setdiff(
                        self$dynamic_grp[[group_score_type]],
                        test_name
                      )
                    }
                  }
                }

                # Add the test to its correct dynamic group if not already there
                if (
                  correct_score_type %in%
                    names(self$dynamic_grp) &&
                    !test_name %in% self$dynamic_grp[[correct_score_type]]
                ) {
                  self$dynamic_grp[[correct_score_type]] <- c(
                    self$dynamic_grp[[correct_score_type]],
                    test_name
                  )
                }
              }
            }
          }
        }

        # Debug: Output fixed groupings
        message("Fixed score type groups:")
        for (score_type in names(self$grp_list)) {
          message(paste0(
            "  ",
            score_type,
            ": ",
            paste(self$grp_list[[score_type]], collapse = ", ")
          ))
        }
      }

      # Now add footnotes based on the fixed groups for non-battery-specific groups
      for (score_type in names(self$fn_list)) {
        footnote <- self$fn_list[[score_type]]
        groups <- intersect(self$grp_list[[score_type]], existing_groups)

        # Skip battery-specific groups which are handled above
        if (
          any(sapply(batteries_to_handle, function(b) {
            grepl(paste0("^", tolower(b), "_"), score_type)
          }))
        ) {
          message(paste0("Skipping battery-specific group: ", score_type))
          next
        }

        if (!is.null(footnote) && length(groups) > 0) {
          message(paste0(
            "Adding ",
            score_type,
            " footnote to groups: ",
            paste(groups, collapse = ", ")
          ))

          # For normal groups (not battery-specific), add footnote to all group rows
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
  )
)
