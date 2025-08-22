# Score Type Cache Initialization
# This file ensures the score type cache is properly initialized for the package

# Removed: source("R/ScoreTypeCacheR6.R") - not needed in R package

#' Ensure Score Type Utils
#'
#' Ensures that the score type utilities are loaded and available
#' @export
ensure_score_type_utils <- function() {
  if (!exists(".ScoreTypeCacheR6", envir = .GlobalEnv)) {
    .GlobalEnv$.ScoreTypeCacheR6 <- ScoreTypeCacheR6$new()
    .GlobalEnv$.ScoreTypeCacheR6$build_mappings()
  }

  # Compatibility
  if (!exists(".score_type_cache", envir = .GlobalEnv)) {
    .GlobalEnv$.score_type_cache <- .GlobalEnv$.ScoreTypeCacheR6
  }

  return(TRUE)
}
