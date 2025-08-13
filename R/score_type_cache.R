#' ScoreTypeCacheR6 - Cached Score Type Manager
#'
#' @description Manages score type mappings with caching to avoid repetitive lookups
ScoreTypeCacheR6 <- R6::R6Class(
  classname = "ScoreTypeCacheR6",
  public = list(
    # Cache storage
    test_score_type_map = NULL,
    fn_list = NULL,
    lookup_data = NULL,
    initialized = FALSE,

    #' @description Initialize the cache
    initialize = function() {
      self$fn_list <- list(
        standard_score = "Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]",
        scaled_score = "Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]",
        t_score = "T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]",
        z_score = "z-score: Mean = 0 [50th‰], SD ± 1 [16th‰, 84th‰]",
        raw_score = "Raw score: Untransformed test score",
        base_rate = "Base rate: Percentage of the normative sample at or below this score",
        percentile = "Percentile rank: Percentage of normative sample scoring at or below this level",
        percent_mastery = "Percent mastery: Percentage of items answered correctly"
      )

      # Initialize empty mapping
      self$test_score_type_map <- list(
        "scaled_score" = character(0),
        "standard_score" = character(0),
        "t_score" = character(0),
        "z_score" = character(0),
        "percentile" = character(0),
        "raw_score" = character(0),
        "base_rate" = character(0),
        "percent_mastery" = character(0)
      )
    },

    #' @description Build the score type mappings (runs once)
    build_mappings = function() {
      if (self$initialized) {
        return(invisible(self))
      }

      message("Building score type mappings (one-time operation)...")

      # Try to get lookup_neuropsych_scales
      lookup_neuropsych_scales <- private$get_lookup_data()

      if (!is.null(lookup_neuropsych_scales)) {
        message("✓ Using lookup_neuropsych_scales from sysdata.rda")

        # Get unique score types
        score_types <- unique(lookup_neuropsych_scales$score_type)
        message(paste(
          "Found score types:",
          paste(score_types, collapse = ", ")
        ))

        # Build mappings for each score type
        for (score_type in score_types) {
          if (score_type %in% names(self$test_score_type_map)) {
            # Get rows with this score type
            rows <- lookup_neuropsych_scales[
              lookup_neuropsych_scales$score_type == score_type,
            ]

            # Extract unique test names and scales
            tests <- unique(c(rows$test_name, rows$test, rows$scale))
            tests <- tests[!is.na(tests)]

            # Add to mapping
            self$test_score_type_map[[score_type]] <- unique(c(
              self$test_score_type_map[[score_type]],
              tests
            ))

            message(paste(
              "✓ Added",
              length(tests),
              "tests/scales to",
              score_type,
              "mapping"
            ))
          }
        }
      } else {
        message("⚠ Using fallback hardcoded mappings")
        private$use_fallback_mappings()
      }

      self$initialized <- TRUE
      message("✓ Score type mappings built and cached")

      invisible(self)
    },

    #' @description Get score type groups for specific test names
    #' @param test_names Vector of test names to classify
    #' @return List of score type groups
    get_score_groups = function(test_names) {
      if (!self$initialized) {
        self$build_mappings()
      }

      grp_list <- list()

      # Classify each test
      for (score_type in names(self$test_score_type_map)) {
        matching_tests <- intersect(
          self$test_score_type_map[[score_type]],
          test_names
        )
        if (length(matching_tests) > 0) {
          grp_list[[score_type]] <- matching_tests
        }
      }

      return(grp_list)
    },

    #' @description Get footnotes for score types
    #' @param score_types Vector of score types needed
    #' @return List of footnotes
    get_footnotes = function(score_types) {
      footnotes <- list()
      for (score_type in score_types) {
        if (score_type %in% names(self$fn_list)) {
          footnotes[[score_type]] <- self$fn_list[[score_type]]
        }
      }
      return(footnotes)
    },

    #' @description Check if a test uses multiple score types (like RBANS, WISC-V)
    #' @param test_name Test name to check
    #' @return Boolean
    is_multi_score_battery = function(test_name) {
      multi_score_batteries <- c(
        "RBANS",
        "WISC-V",
        "WAIS-IV",
        "WAIS-5",
        "NAB",
        "NAB-S",
        "WMS-IV"
      )
      return(any(sapply(multi_score_batteries, function(x) {
        grepl(x, test_name, ignore.case = TRUE)
      })))
    }
  ),

  private = list(
    #' @description Get lookup data from various sources
    get_lookup_data = function() {
      lookup_neuropsych_scales <- NULL

      # Method 1: Check current environment
      if (exists("lookup_neuropsych_scales", envir = parent.frame(2))) {
        lookup_neuropsych_scales <- get(
          "lookup_neuropsych_scales",
          envir = parent.frame(2)
        )
      }

      # Method 2: Try package namespace
      if (is.null(lookup_neuropsych_scales)) {
        tryCatch(
          {
            lookup_neuropsych_scales <- get(
              "lookup_neuropsych_scales",
              envir = asNamespace("neuro2")
            )
          },
          error = function(e) NULL
        )
      }

      # Method 3: Try sysdata.rda
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
            error = function(e) NULL
          )
        }
      }

      return(lookup_neuropsych_scales)
    },

    #' @description Use fallback mappings if lookup data not available
    use_fallback_mappings = function() {
      # Minimal hardcoded mappings for critical tests
      self$test_score_type_map <- list(
        "scaled_score" = c(
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
        "standard_score" = c(
          "Full Scale (FSIQ)",
          "Full Scale IQ",
          "Verbal Comprehension (VCI)",
          "Perceptual Reasoning (PRI)",
          "Working Memory (WMI)",
          "Processing Speed (PSI)",
          "General Ability (GAI)",
          "Cognitive Proficiency (CPI)",
          "Visual Spatial (VSI)",
          "Fluid Reasoning (FRI)",
          "RBANS Total Index",
          "Total Index",
          "Immediate Memory Index",
          "Visuospatial Index",
          "Language Index",
          "Attention Index",
          "Delayed Memory Index"
        ),
        "t_score" = c(
          "BASC3",
          "BASC-3",
          "Conners",
          "Conners-3",
          "BRIEF",
          "BRIEF-2"
        ),
        "z_score" = character(0),
        "percentile" = character(0),
        "raw_score" = character(0),
        "base_rate" = character(0),
        "percent_mastery" = character(0)
      )
    }
  )
)

# Create global cache instance
if (!exists(".score_type_cache")) {
  .score_type_cache <- ScoreTypeCacheR6$new()
}
