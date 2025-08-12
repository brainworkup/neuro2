#' NeuropsychResultsR6 Class
#'
#' An R6 class that concatenates and flattens neuropsych results by scale.
#' This is an R6 implementation of the cat_neuropsych_results function with identical functionality.
#'
#' @field data A dataframe containing the data
#' @field file A character string specifying the name of the file
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new NeuropsychResultsR6 object with data and file path.}
#'   \item{process}{Sort the data by percentile, remove duplicates, convert to text, and append to file.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter arrange distinct desc mutate
#' @export
NeuropsychResultsR6 <- R6::R6Class(
  classname = "NeuropsychResultsR6",
  public = list(
    data = NULL,
    file = NULL,

    #' @description
    #' Initialize a new NeuropsychResultsR6 object with data and file path.
    #'
    #' @param data A dataframe containing the data
    #' @param file A character string specifying the name of the file
    #' @param ... Additional arguments (ignored)
    #'
    #' @return A new NeuropsychResultsR6 object
    initialize = function(data, file, ...) {
      self$data <- data
      self$file <- file
    },

    #' @description
    #' Sort the data by percentile, remove duplicates, convert to text, and write to file as proper QMD content.
    #'
    #' @return Invisibly returns NULL after writing to the file.
    process = function() {
      # Sorting the data by percentile and removing duplicates
      sorted_data <- self$data |>
        dplyr::arrange(dplyr::desc(percentile)) |>
        dplyr::distinct(.keep_all = FALSE)

      # Create proper QMD content without HTML tags that could cause parsing issues
      if (nrow(sorted_data) > 0) {
        qmd_content <- c(paste0(sorted_data$result))
      } else {
        qmd_content <- c("No data available for this domain.")
      }

      # Write the QMD content to file (overwrite, don't append)
      cat(qmd_content, file = self$file, sep = "\n", append = FALSE)

      invisible(NULL)
    }
  )
)

#' Concatenate and Flatten Neuropsych Results by Scale (Function Wrapper)
#'
#' This function sorts the data by percentile, removes duplicates and converts the data to text.
#' Finally, it appends the converted data to a file. It's a wrapper around the NeuropsychResultsR6 class.
#'
#' @param data A dataframe containing the data
#' @param file A character string specifying the name of the file
#' @param ... Additional arguments passed to other functions
#' @return A file containing the flattened and scaled text
#' @importFrom dplyr filter arrange distinct desc mutate
#' @export
#' @rdname cat_neuropsych_results
cat_neuropsych_results <- function(data, file, ...) {
  # Create a NeuropsychResultsR6 object and process the data
  results_obj <- NeuropsychResultsR6$new(data = data, file = file, ...)

  results_obj$process()

  invisible(NULL)
}
