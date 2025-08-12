#' PackageManagerR6 Class
#'
#' @title Package Manager for neuro2 (documentation stub)
#' @description R6 class to manage dependency installation, loading, version checks,
#'   and simple conflict reporting. This documentation file exists separately from the
#'   implementation to satisfy roxygen2 checks.
#'
#' @docType class
#' @name PackageManagerR6
#' @format An R6 class generator object.
#'
#' @section Public fields:
#' \describe{
#'   \item{\code{required_packages}}{Named list of required package groups.}
#'   \item{\code{optional_packages}}{Named list of optional package groups.}
#'   \item{\code{loaded_packages}}{Character vector of successfully detected/loaded packages.}
#'   \item{\code{failed_packages}}{Character vector of packages that failed to install or load.}
#' }
#'
#' @section Methods:
#' \describe{
#'   \item{\code{$initialize()}}{Construct the manager with default groups.}
#'   \item{\code{$check_and_install(install_missing = FALSE, include_optional = TRUE, verbose = TRUE)}}{Check availability and optionally install.}
#'   \item{\code{$check_package_group(packages, install_missing = FALSE, required = TRUE, verbose = TRUE)}}{Check a vector of packages.}
#'   \item{\code{$check_single_package(pkg, install_missing = FALSE, verbose = TRUE)}}{Check/install a single package.}
#'   \item{\code{$load_packages(packages = NULL, verbose = TRUE)}}{Call \code{library()} on a set of packages.}
#'   \item{\code{$show_summary()}}{Print a summary of availability and failures.}
#'   \item{\code{$get_missing_packages()}}{Return required packages not yet available.}
#'   \item{\code{$install_missing_packages(verbose = TRUE)}}{Attempt to install any missing required packages.}
#'   \item{\code{$check_conflicts(verbose = TRUE)}}{If \pkg{conflicted} is available, report conflicts.}
#'   \item{\code{$create_package_loading_script(file = "load_packages.R")}}{Write a package-loading script for Quarto docs.}
#' }
#'
#' @section Parameters (for methods above):
#' \describe{
#'   \item{\code{install_missing}}{Logical; install packages when not available.}
#'   \item{\code{include_optional}}{Logical; also evaluate optional packages.}
#'   \item{\code{verbose}}{Logical; print progress.}
#'   \item{\code{packages}}{Character vector of package names.}
#'   \item{\code{required}}{Logical; treat unavailability as an error when \code{TRUE}.}
#'   \item{\code{pkg}}{Single package name.}
#'   \item{\code{file}}{File path for the generated loading script.}
#' }
#'
#' @return
#' Methods typically return the manager invisibly for chaining; query helpers return character vectors.
#'
#' @examples
#' \dontrun{
#' pm <- PackageManagerR6$new()
#' pm$check_and_install()
#' pm$load_packages()
#' }
#'
#' @export
NULL
