#' Template Content Manager for Neuropsychological Reports
#'
#' @description
#' An R6 class that manages Quarto template content for neuropsychological report generation.
#' This class provides functionality to access and organize template domains used in
#' constructing comprehensive neuropsychological assessment reports.
#'
#' @details
#' The TemplateContentManagerR6 class scans a specified directory for template files (Quarto .qmd files
#' with names starting with underscore), categorizes them by section type based on filename
#' prefixes, and provides methods to access their content. This facilitates modular report
#' construction by allowing selective inclusion of domains based on assessment needs.
#'
#' The class categorizes template files into domains:
#' \itemize{
#'   \item Tests (_00*): Test descriptions and administration details
#'   \item NSE (Neurobehavioral Status Exam) (_01*): Clinical interview and behavioral observations
#'   \item Domains (_02*): Cognitive domain assessments (memory, attention, etc.)
#'   \item Conclusions (_03*): Summary, diagnostic impressions, and recommendations
#' }
#'
#' @examples
#' # Example 1: Initialize and list available domains
#' template_mgr <- TemplateContentManagerR6$new()
#' domains <- template_mgr$get_available_domains()
#' print(domains$domains) # List available domain templates
#'
#' # Example 2: Retrieve content from a specific template file
#' template_mgr <- TemplateContentManagerR6$new(
#'   template_dir = "inst/quarto/_extensions/brainworkup"
#' )
#' iq_content <- template_mgr$get_content("_02-01_iq.qmd")
#' if (!is.null(iq_content)) {
#'   # Process or display the IQ section content
#'   cat(paste(head(iq_content, 10), collapse = "\n"))
#' }
#'
#' @export
TemplateContentManagerR6 <- R6::R6Class(
  classname = "TemplateContentManagerR6",
  public = list(
    #' @field template_dir Character string specifying the directory containing template files (default: "inst/quarto/_extensions/brainworkup")
    template_dir = NULL,

    #' @field content_files Character vector of template filenames found in the template directory
    content_files = NULL,

    #' @description
    #' Initialize a new TemplateContentManagerR6 object
    #'
    #' @param template_dir Character string specifying the directory containing template files
    #'   (default: "inst/quarto/_extensions/brainworkup")
    #'
    #' @return A new `TemplateContentManagerR6` object
    initialize = function(
      template_dir = "inst/quarto/_extensions/brainworkup"
    ) {
      self$template_dir <- template_dir
      self$refresh_content_list()
    },

    #' @description
    #' Scan the template directory and update the list of available content files
    #'
    #' @details
    #' This method scans the template directory for Quarto files (pattern "^_.*\\.qmd$")
    #' and updates the content_files field with the list of available templates.
    #' It is called automatically during initialization and can be called again
    #' if the template directory contents change.
    #'
    #' @return Invisibly returns the TemplateContentManagerR6 object (for method chaining)
    refresh_content_list = function() {
      # Scan directory for content files
      self$content_files <- list.files(
        self$template_dir,
        pattern = "^_.*\\.qmd$",
        full.names = FALSE
      )
      invisible(self)
    },

    #' @description
    #' Retrieve the content of a specific template file
    #'
    #' @param file_name Character string specifying the filename to retrieve (without path)
    #'
    #' @return Character vector containing the lines of the file if found, NULL otherwise
    #'   with a warning
    get_content = function(file_name) {
      # Return content of a specific file
      file_path <- file.path(self$template_dir, file_name)
      if (file.exists(file_path)) {
        return(readLines(file_path, warn = FALSE))
      } else {
        warning("Content file not found: ", file_name)
        return(NULL)
      }
    },

    #' @description
    #' Get a categorized list of available template domains
    #'
    #' @details
    #' This method organizes the available template files into four categories based on
    #' their filename prefixes:
    #' \itemize{
    #'   \item tests: Files starting with "_00" (test descriptions)
    #'   \item nse: Files starting with "_01" (neurobehavioral status exam)
    #'   \item domains: Files starting with "_02" (cognitive domains)
    #'   \item conclusions: Files starting with "_03" (conclusions and recommendations)
    #' }
    #'
    #' @return A list with four named elements (tests, nse, domains, conclusions),
    #'   each containing character vectors of filenames
    get_available_domains = function() {
      # Return list of available domains grouped by type
      sections <- list(
        tests = grep("^_00", self$content_files, value = TRUE),
        nse = grep("^_01", self$content_files, value = TRUE),
        domains = grep("^_02", self$content_files, value = TRUE),
        conclusions = grep("^_03", self$content_files, value = TRUE)
      )
      return(sections)
    }
  )
)
