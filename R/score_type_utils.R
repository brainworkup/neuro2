#' Score Type Utilities
#'
#' Functions to handle dynamic score type footnotes and source notes. This file
#' provides utility functions and ensures the score type cache is properly
#' initialized
#'
#' @name score_type_utils
#' @keywords internal

# Initialize the global cache if it doesn't exist
if (!exists(".ScoreTypeCacheR6")) {
  .ScoreTypeCacheR6 <- ScoreTypeCacheR6$new()
  .ScoreTypeCacheR6$build_mappings()
}


#' Get score type groups for test names
#' @param test_names Character vector of test names
#' @return Named list of score type groups
.get_score_groups <- function(test_names) {
  if (exists(".ScoreTypeCacheR6")) {
    return(.ScoreTypeCacheR6$.get_score_groups(test_names))
  } else {
    # Fallback - return empty list
    return(list())
  }
}

#' Get footnotes for score types
#' @param score_types Character vector of score types
#' @return Named list of footnotes
.get_score_footnotes <- function(score_types) {
  if (exists(".ScoreTypeCacheR6")) {
    return(.ScoreTypeCacheR6$get_footnotes(score_types))
  } else {
    # Fallback - return empty list
    return(list())
  }
}

#' Initialize score type cache safely
#' @return Logical indicating success
.init_score_type_cache <- function() {
  tryCatch(
    {
      if (!exists(".ScoreTypeCacheR6")) {
        .ScoreTypeCacheR6 <<- ScoreTypeCacheR6$new()
      }
      if (!.ScoreTypeCacheR6$initialized) {
        .ScoreTypeCacheR6$build_mappings()
      }
      return(TRUE)
    },
    error = function(e) {
      warning("Failed to initialize score type cache: ", e$message)
      return(FALSE)
    }
  )
}

#' Get Source Note Based on Score Type
#'
#' Determines the appropriate source note based on the score types present in the data
#'
#' @param data A data frame containing a score_type column
#' @param default_note The default source note to use if no score types are found
#' @return A character string containing the appropriate source note
#' @export
get_source_note_by_score_type <- function(data, default_note = NULL) {
  # Define the score type footnotes
  score_type_notes <- list(
    t_score = "T score: Mean = 50 [50th\u2030], SD \u00B1 10 [16th\u2030, 84th\u2030]",
    scaled_score = "Scaled score: Mean = 10 [50th\u2030], SD \u00B1 3 [16th\u2030, 84th\u2030]",
    standard_score = "Standard score: Mean = 100 [50th\u2030], SD \u00B1 15 [16th\u2030, 84th\u2030]",
    z_score = "z-score: Mean = 0 [50th\u2030], SD \u00B1 1 [16th\u2030, 84th\u2030]"
  )

  # Check if data has score_type column
  if (!"score_type" %in% names(data)) {
    if (!is.null(default_note)) {
      return(default_note)
    }
    # If no score_type column and no default, return standard score note
    return(score_type_notes$standard_score)
  }

  # Get unique score types in the data
  unique_score_types <- unique(data$score_type)
  unique_score_types <- unique_score_types[!is.na(unique_score_types)]

  # If no valid score types, use default
  if (length(unique_score_types) == 0) {
    if (!is.null(default_note)) {
      return(default_note)
    }
    return(score_type_notes$standard_score)
  }

  # If only one score type, return its note
  if (length(unique_score_types) == 1) {
    score_type <- unique_score_types[1]
    if (score_type %in% names(score_type_notes)) {
      return(score_type_notes[[score_type]])
    }
  }

  # If multiple score types, combine them
  notes <- character()
  for (score_type in unique_score_types) {
    if (score_type %in% names(score_type_notes)) {
      notes <- c(notes, score_type_notes[[score_type]])
    }
  }

  # If we found matching notes, combine them
  if (length(notes) > 0) {
    return(paste(notes, collapse = "; "))
  }

  # Otherwise use default or standard score
  if (!is.null(default_note)) {
    return(default_note)
  }
  return(score_type_notes$standard_score)
}

#' Get All Score Type Notes
#'
#' Returns a list of all available score type notes
#'
#' @return A list containing all score type notes
#' @export
get_all_score_type_notes <- function() {
  list(
    t_score = gt::md(
      "T score: Mean = 50 [50th\u2030], SD \u00B1 10 [16th\u2030, 84th\u2030]"
    ),
    scaled_score = gt::md(
      "Scaled score: Mean = 10 [50th\u2030], SD \u00B1 3 [16th\u2030, 84th\u2030]"
    ),
    standard_score = gt::md(
      "Standard score: Mean = 100 [50th\u2030], SD \u00B1 15 [16th\u2030, 84th\u2030]"
    ),
    z_score = gt::md(
      "z-score: Mean = 0 [50th\u2030], SD \u00B1 1 [16th\u2030, 84th\u2030]"
    )
  )
}

#' Get Score Types from Lookup Table
#'
#' Retrieves score types for given scales/tests from the master lookup table
#'
#' @param data A data frame containing test, test_name, and scale columns
#' @return A list mapping each unique test_name to its score types
#' @export
get_score_types_from_lookup <- function(data) {
  # Load the lookup table from sysdata.rda
  lookup_table <- NULL

  # Try to get it from the package namespace first
  if (exists("lookup_neuropsych_scales", envir = .GlobalEnv)) {
    lookup_table <- get("lookup_neuropsych_scales", envir = .GlobalEnv)
  } else {
    # Load from sysdata.rda
    sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
    if (file.exists(sysdata_path)) {
      temp_env <- new.env()
      load(sysdata_path, envir = temp_env)
      if (exists("lookup_neuropsych_scales", envir = temp_env)) {
        lookup_table <- get("lookup_neuropsych_scales", envir = temp_env)
      }
    }

    # Try alternative path (for development)
    if (is.null(lookup_table)) {
      dev_sysdata_path <- here::here("R", "sysdata.rda")
      if (file.exists(dev_sysdata_path)) {
        temp_env <- new.env()
        load(dev_sysdata_path, envir = temp_env)
        if (exists("lookup_neuropsych_scales", envir = temp_env)) {
          lookup_table <- get("lookup_neuropsych_scales", envir = temp_env)
        }
      }
    }
  }

  if (is.null(lookup_table)) {
    warning("Could not load lookup_neuropsych_scales from sysdata.rda")
    return(list())
  }

  # Create a mapping of test_name to score types
  score_type_map <- list()

  # Get unique test names from the data
  unique_test_names <- unique(data$test_name)

  for (test_name in unique_test_names) {
    # Find all matching rows in lookup table
    matching_rows <- lookup_table[lookup_table$test_name == test_name, ]

    if (nrow(matching_rows) > 0) {
      # Get unique score types for this test
      score_types <- unique(matching_rows$score_type)
      score_types <- score_types[!is.na(score_types)]

      if (length(score_types) > 0) {
        score_type_map[[test_name]] <- score_types
      }
    }
  }

  # Special handling for WISC-V subtests which should only be scaled scores
  wisc_subtests <- c("Similarities", "Vocabulary", "Comprehension")

  # Log the current state for debugging
  if (getOption("neuro2.verbose", TRUE)) {
    message("Before WISC-V fix, score_type_map contains:")
    for (name in names(score_type_map)) {
      message(sprintf(
        "  %s: %s",
        name,
        paste(score_type_map[[name]], collapse = ", ")
      ))
    }
  }

  # Apply fix for WISC-V subtests - case insensitive matching
  for (test_name in names(score_type_map)) {
    # Check if this is a WISC-V subtest (case insensitive)
    is_wisc_subtest <- FALSE
    for (subtest in wisc_subtests) {
      if (tolower(test_name) == tolower(subtest)) {
        is_wisc_subtest <- TRUE
        break
      }
    }

    # If it's a WISC-V subtest, ensure it only has scaled_score
    if (is_wisc_subtest) {
      if (getOption("neuro2.verbose", TRUE)) {
        message(sprintf(
          "Found WISC-V subtest: %s with score types: %s",
          test_name,
          paste(score_type_map[[test_name]], collapse = ", ")
        ))
      }

      # Force it to be only scaled_score, regardless of what was in the lookup table
      score_type_map[[test_name]] <- "scaled_score"

      if (getOption("neuro2.verbose", TRUE)) {
        message(sprintf(
          "  After fix: %s",
          paste(score_type_map[[test_name]], collapse = ", ")
        ))
      }
    }
  }

  # Also fix for 'WISC-V' as a test name if it exists
  if ("WISC-V" %in% names(score_type_map)) {
    for (subtest in wisc_subtests) {
      if (subtest %in% names(score_type_map)) {
        score_type_map[[subtest]] <- "scaled_score"
      }
    }
  }

  # Log the final state
  if (getOption("neuro2.verbose", TRUE)) {
    message("After WISC-V fix, score_type_map contains:")
    for (name in names(score_type_map)) {
      message(sprintf(
        "  %s: %s",
        name,
        paste(score_type_map[[name]], collapse = ", ")
      ))
    }
  }

  return(score_type_map)
}

#' Get Score Type by Test and Scale
#'
#' Returns the score type for a specific test and scale combination
#'
#' @param test Character string specifying the test
#' @param scale Character string specifying the scale
#' @param test_name Character string specifying the test name (optional)
#' @return Character string of the score type
#' @export
get_score_type_by_test_scale <- function(test, scale, test_name = NULL) {
  # Load the lookup table
  lookup_table <- NULL

  # Try to get it from the package namespace first
  if (exists("lookup_neuropsych_scales", envir = .GlobalEnv)) {
    lookup_table <- get("lookup_neuropsych_scales", envir = .GlobalEnv)
  } else {
    # Load from sysdata.rda
    sysdata_path <- system.file("R", "sysdata.rda", package = "neuro2")
    if (file.exists(sysdata_path)) {
      temp_env <- new.env()
      load(sysdata_path, envir = temp_env)
      if (exists("lookup_neuropsych_scales", envir = temp_env)) {
        lookup_table <- get("lookup_neuropsych_scales", envir = temp_env)
      }
    }

    # Try alternative path (for development)
    if (is.null(lookup_table)) {
      dev_sysdata_path <- here::here("R", "sysdata.rda")
      if (file.exists(dev_sysdata_path)) {
        temp_env <- new.env()
        load(dev_sysdata_path, envir = temp_env)
        if (exists("lookup_neuropsych_scales", envir = temp_env)) {
          lookup_table <- get("lookup_neuropsych_scales", envir = temp_env)
        }
      }
    }
  }

  if (is.null(lookup_table)) {
    return("standard_score") # Default
  }

  # Try to find exact match
  if (!is.null(test_name)) {
    match <- lookup_table[
      lookup_table$test_name == test_name & lookup_table$scale == scale,
    ]
  } else {
    match <- lookup_table[
      lookup_table$test == test & lookup_table$scale == scale,
    ]
  }

  if (nrow(match) > 0 && !is.na(match$score_type[1])) {
    return(match$score_type[1])
  }

  # Default to standard score
  return("standard_score")
}
