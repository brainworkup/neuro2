#' Get Configuration Settings
#'
#' @description
#' Retrieves configuration settings for the package.
#' This function provides a centralized way to access configuration options.
#'
#' @param key Configuration key to retrieve
#' @param default Default value if key is not found
#' @return Configuration value or default
#' @keywords internal
get_config <- function() {
  # Create a config object with get method
  config <- new.env(parent = emptyenv())

  # Default configuration values
  defaults <- list(verbose = FALSE, parallel_processing = FALSE, n_cores = 1)

  # Store defaults in config environment
  for (name in names(defaults)) {
    config[[name]] <- defaults[[name]]
  }

  # Add getter method
  config$get <- function(key, default = NULL) {
    if (exists(key, envir = config)) {
      return(get(key, envir = config))
    }
    return(default)
  }

  return(config)
}
