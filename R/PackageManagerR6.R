#' PackageManagerR6 Class
#'
#' @title Package Manager for neuro2
#' @description Enhanced package management for neuro2.
#'   Handles dependency installation, loading, and version checking.
#'
#' @docType class
#' @format An R6 class object
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize}}{See method docs below.}
#'   \item{\code{$check_and_install}}{See method docs below.}
#'   \item{\code{$check_package_group}}{See method docs below.}
#'   \item{\code{$check_single_package}}{See method docs below.}
#'   \item{\code{$load_packages}}{See method docs below.}
#'   \item{\code{$show_summary}}{See method docs below.}
#'   \item{\code{$get_missing_packages}}{See method docs below.}
#'   \item{\code{$install_missing_packages}}{See method docs below.}
#'   \item{\code{$check_conflicts}}{See method docs below.}
#'   \item{\code{$create_package_loading_script}}{See method docs below.}
#' }
#'
#' @field required_packages List of required package groups
#' @field optional_packages List of optional package groups
#' @field loaded_packages Character vector of successfully loaded packages
#' @field failed_packages Character vector of packages that failed to load
#'
#' @export
PackageManagerR6 <- R6::R6Class(
  classname = "PackageManagerR6",
  public = list(
    required_packages = NULL,
    optional_packages = NULL,
    loaded_packages = NULL,
    failed_packages = NULL,

    #' @description Constructor. Initialize the package manager with config and optional groups.

    #' @param config Optional configuration object for package management.

    #' @param package_groups Optional named list mapping group names to vectors of package names.

    #' @return A new PackageManagerR6 object (invisible).

    initialize = function() {
      self$required_packages <- list(
        # Core R packages
        base = list(
          packages = c("stats", "utils", "grDevices", "graphics"),
          description = "Base R functionality"
        ),

        # Data manipulation
        data = list(
          packages = c("dplyr", "tidyr", "readr", "here", "janitor"),
          description = "Data manipulation and file I/O"
        ),

        # R6 and object system
        oop = list(
          packages = c("R6"),
          description = "Object-oriented programming"
        ),

        # Configuration and YAML
        config = list(
          packages = c("yaml"),
          description = "Configuration management"
        ),

        # Report generation
        reporting = list(
          packages = c("knitr", "quarto"),
          description = "Report generation"
        ),

        # Tables and visualization
        viz = list(
          packages = c("gt", "ggplot2"),
          description = "Tables and basic visualization"
        )
      )

      self$optional_packages <- list(
        # Advanced data processing
        advanced_data = list(
          packages = c("arrow", "DBI", "duckdb"),
          description = "Advanced data processing (Parquet, DuckDB)"
        ),

        # Enhanced visualization
        advanced_viz = list(
          packages = c("ggthemes", "ggtext", "highcharter"),
          description = "Enhanced visualization"
        ),

        # Table formatting
        tables = list(
          packages = c("gtExtras"),
          description = "Enhanced table formatting"
        ),

        # User interface
        ui = list(packages = c("cli"), description = "Enhanced user interface"),

        # Performance
        performance = list(
          packages = c("memoise", "future", "future.apply"),
          description = "Performance enhancements"
        ),

        # Text processing
        text = list(
          packages = c("glue", "stringr"),
          description = "Text processing"
        )
      )

      self$loaded_packages <- character()
      self$failed_packages <- character()
    },

    #' @description Check required packages (and groups) and install any that are missing.

    #' @param groups Optional character vector of group names to check; NULL = all defined groups.

    #' @param ask Logical; if TRUE, interactively confirm before installing.

    #' @param install_missing Logical; if TRUE, install any missing packages.
    #' @param include_optional Logical; include optional (non-required) groups/packages if TRUE.
    #' @param verbose Logical; print detailed progress messages if TRUE.
    #' @return Invisibly returns self.

    check_and_install = function(
      install_missing = FALSE,
      include_optional = TRUE,
      verbose = TRUE
    ) {
      if (verbose) {
        cli::cli_h2("Checking Package Dependencies")
      }

      # Check required packages
      for (group_name in names(self$required_packages)) {
        group <- self$required_packages[[group_name]]

        if (verbose) {
          cli::cli_h3(group$description)
        }

        self$check_package_group(
          group$packages,
          install_missing = install_missing,
          required = TRUE,
          verbose = verbose
        )
      }

      # Check optional packages if requested
      if (include_optional) {
        if (verbose) {
          cli::cli_h2("Checking Optional Dependencies")
        }

        for (group_name in names(self$optional_packages)) {
          group <- self$optional_packages[[group_name]]

          if (verbose) {
            cli::cli_h3(group$description)
          }

          self$check_package_group(
            group$packages,
            install_missing = install_missing,
            required = FALSE,
            verbose = verbose
          )
        }
      }

      # Summary
      if (verbose) {
        self$show_summary()
      }

      invisible(self)
    },

    #' @description Check availability of all packages in a named group.

    #' @param group Character name of the package group.

    #' @param packages Character vector of package names.
    #' @param install_missing Logical; if TRUE, install any missing packages.
    #' @param required Logical or character; if provided, restrict to required packages or a subset.
    #' @param verbose Logical; print detailed progress messages if TRUE.
    #' @return Logical; TRUE if all packages in the group are available.

    check_package_group = function(
      packages,
      install_missing = FALSE,
      required = TRUE,
      verbose = TRUE
    ) {
      for (pkg in packages) {
        status <- self$check_single_package(pkg, install_missing, verbose)

        if (!status && required) {
          stop(paste(
            "Required package",
            pkg,
            "is not available and could not be installed"
          ))
        }
      }
    },

    #' @description Check whether a single package is installed and loadable.

    #' @param pkg Character name of the package.

    #' @param install_missing Logical; if TRUE, install any missing packages.
    #' @param verbose Logical; print detailed progress messages if TRUE.
    #' @return Logical; TRUE if package is available.

    check_single_package = function(
      pkg,
      install_missing = FALSE,
      verbose = TRUE
    ) {
      # Check if package is already loaded
      if (pkg %in% self$loaded_packages) {
        if (verbose) {
          cli::cli_alert_success("{pkg} (already loaded)")
        }
        return(TRUE)
      }

      # Check if package is available
      if (requireNamespace(pkg, quietly = TRUE)) {
        self$loaded_packages <- c(self$loaded_packages, pkg)
        if (verbose) {
          cli::cli_alert_success("{pkg}")
        }
        return(TRUE)
      }

      # Package not available - try to install if requested
      if (install_missing) {
        if (verbose) {
          cli::cli_alert_info("Installing {pkg}...")
        }

        install_result <- tryCatch(
          {
            # Try CRAN first
            install.packages(pkg, quiet = TRUE)

            # Verify installation
            requireNamespace(pkg, quietly = TRUE)
          },
          error = function(e) {
            FALSE
          }
        )

        if (install_result) {
          self$loaded_packages <- c(self$loaded_packages, pkg)
          if (verbose) {
            cli::cli_alert_success("{pkg} (installed)")
          }
          return(TRUE)
        } else {
          self$failed_packages <- c(self$failed_packages, pkg)
          if (verbose) {
            cli::cli_alert_danger("{pkg} (installation failed)")
          }
          return(FALSE)
        }
      } else {
        self$failed_packages <- c(self$failed_packages, pkg)
        if (verbose) {
          cli::cli_alert_warning("{pkg} (not available)")
        }
        return(FALSE)
      }
    },

    #' @description Load one or more packages, optionally by group.

    #' @param packages Character vector of package names to load (ignored if `groups` provided).

    #' @param groups Optional character vector of package groups to load.

    #' @param quiet Logical; if TRUE, suppress startup messages.

    #' @param verbose Logical; print detailed progress messages if TRUE.
    #' @return Invisibly returns self.

    load_packages = function(packages = NULL, verbose = TRUE) {
      if (is.null(packages)) {
        # Load all available required packages
        all_required <- unlist(lapply(self$required_packages, function(x) {
          x$packages
        }))
        packages <- intersect(all_required, self$loaded_packages)
      }

      if (verbose) {
        cli::cli_h2("Loading Packages")
      }

      successfully_loaded <- character()

      for (pkg in packages) {
        tryCatch(
          {
            library(pkg, character.only = TRUE, quietly = !verbose)
            successfully_loaded <- c(successfully_loaded, pkg)
            if (verbose) {
              cli::cli_alert_success("Loaded {pkg}")
            }
          },
          error = function(e) {
            if (verbose) {
              cli::cli_alert_danger("Failed to load {pkg}: {e$message}")
            }
          }
        )
      }

      if (verbose) {
        cli::cli_alert_info(
          "Successfully loaded {length(successfully_loaded)} packages"
        )
      }

      invisible(successfully_loaded)
    },

    #' @description Display a summary of package availability, versions, and groups.

    #' @return Invisibly returns self.

    show_summary = function() {
      cli::cli_h2("Package Summary")

      total_required <- length(unlist(lapply(
        self$required_packages,
        function(x) x$packages
      )))
      total_optional <- length(unlist(lapply(
        self$optional_packages,
        function(x) x$packages
      )))

      available_required <- length(setdiff(
        self$loaded_packages,
        self$failed_packages
      ))
      failed_count <- length(self$failed_packages)

      cli::cli_alert_info(
        "Required packages: {available_required}/{total_required} available"
      )
      cli::cli_alert_info(
        "Optional packages: {length(self$loaded_packages) - available_required} available"
      )

      if (failed_count > 0) {
        cli::cli_alert_warning(
          "Failed packages: {paste(self$failed_packages, collapse = ', ')}"
        )
        cli::cli_alert_info(
          "Run with install_missing = TRUE to attempt installation"
        )
      } else {
        cli::cli_alert_success("All checked packages are available")
      }
    },

    #' @description Return a character vector of missing packages across provided groups (or all).

    #' @param groups Optional character vector of group names; NULL = all.

    #' @return Character vector of missing package names.

    get_missing_packages = function() {
      all_required <- unlist(lapply(self$required_packages, function(x) {
        x$packages
      }))
      missing <- setdiff(all_required, self$loaded_packages)
      return(missing)
    },

    #' @description Install missing packages (optionally restricted to groups).

    #' @param groups Optional character vector of group names; NULL = all.

    #' @param repos CRAN repos URL or vector passed to install.packages().

    #' @param upgrade Logical or 'never'/'always' as used by package managers; upgrade if TRUE.

    #' @param verbose Logical; print detailed progress messages if TRUE.
    #' @return Invisibly returns self.

    install_missing_packages = function(verbose = TRUE) {
      missing <- self$get_missing_packages()

      if (length(missing) == 0) {
        if (verbose) {
          cli::cli_alert_success("No missing packages to install")
        }
        return(invisible(self))
      }

      if (verbose) {
        cli::cli_h2("Installing Missing Packages")
        cli::cli_alert_info("Installing: {paste(missing, collapse = ', ')}")
      }

      for (pkg in missing) {
        self$check_single_package(
          pkg,
          install_missing = TRUE,
          verbose = verbose
        )
      }

      invisible(self)
    },

    # # Check for potential package conflicts
    # #' @description Check for function name conflicts across loaded packages.
    # #' @param packages Optional character vector; if NULL, check currently loaded packages.
    # #' @param verbose Logical; print detailed progress messages if TRUE.
    # #' @return A data.frame (or list) describing conflicts.

    # check_conflicts = function(verbose = TRUE) {
    #   if (!requireNamespace("conflicted", quietly = TRUE)) {
    #     if (verbose) {
    #       cli::cli_alert_info("Install 'conflicted' package for conflict detection")
    #     }
    #     return(invisible(self))
    #   }

    #   # This would show any namespace conflicts
    #   conflicts <- conflicted::conflict_scout()

    #   if (length(conflicts) > 0 && verbose) {
    #     cli::cli_h2("Package Conflicts Detected")
    #     for (conflict in conflicts) {
    #       cli::cli_alert_warning("Conflict: {conflict}")
    #     }
    #     cli::cli_alert_info("Consider using conflicted::conflict_prefer() to resolve")
    #   }

    #   invisible(self)
    # },

    # Create a package loading script for Quarto documents
    #' @description Write a helper R script that loads required packages/groups for reproducible environments.
    #' @param path Output path to write the .R script.
    #' @param groups Optional character vector of groups to include; NULL = all.
    #' @param file Output path for the generated loading script file.
    #' @return Path to the created script (character).

    create_package_loading_script = function(file = "load_packages.R") {
      all_required <- unlist(lapply(self$required_packages, function(x) {
        x$packages
      }))
      available <- intersect(all_required, self$loaded_packages)

      script_content <- c(
        "# Generated package loading script for neuro2",
        "# This script loads all required packages for neuropsychological reports",
        "",
        "# Required packages",
        paste0("library(", available, ")"),
        "",
        "# Set options",
        "options(warn = -1)  # Suppress warnings",
        "knitr::opts_chunk$set(warning = FALSE, message = FALSE)",
        "",
        "# Package loading complete",
        paste0(
          "message('Loaded ",
          length(available),
          " packages successfully')"
        )
      )

      writeLines(script_content, file)
      cli::cli_alert_success("Package loading script saved to: {file}")

      invisible(self)
    }
  )
)

# Convenience functions
#' Set up neuro2 package environment
#' @param install_missing Whether to install missing packages
#' @param include_optional Whether to check optional packages
#' @param verbose Whether to show progress
#' @export
setup_neuro2_packages <- function(
  install_missing = FALSE,
  include_optional = TRUE,
  verbose = TRUE
) {
  pkg_manager <- PackageManagerR6$new()
  pkg_manager$check_and_install(install_missing, include_optional, verbose)

  # Load core packages
  core_packages <- c("R6", "dplyr", "readr", "here", "yaml")
  pkg_manager$load_packages(core_packages, verbose)

  return(pkg_manager)
}

#' Quick package check for essential functionality
#' @export
quick_package_check <- function() {
  essential <- c("R6", "dplyr", "readr", "gt", "knitr")

  missing <- character()
  for (pkg in essential) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    cli::cli_alert_danger(
      "Missing essential packages: {paste(missing, collapse = ', ')}"
    )
    cli::cli_alert_info("Run setup_neuro2_packages(install_missing = TRUE)")
    return(FALSE)
  } else {
    cli::cli_alert_success("All essential packages available")
    return(TRUE)
  }
}
