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
#'   \item{create_text_placeholder}{Create placeholder text file if it doesn't exist.}
#'   \item{emit_quarto_text_chunk}{Static method to emit a Quarto text chunk with file creation.}
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
    #' Create a placeholder text file for a given domain if it doesn't already exist.
    #'
    #' @param domain_file The domain QMD file (e.g., "_02-01_iq.qmd")
    #' @return The text filename that was created or already existed
    create_text_placeholder = function() {
      if (!is.null(self$file) && nzchar(self$file) && !file.exists(self$file)) {
        file.create(self$file)
      }
      invisible(self$file)
    },

    #' @description
    #' Sort the data by percentile, remove duplicates, convert to text, and write to file as proper QMD content.
    #' Also creates the corresponding text placeholder file.
    #'
    #' @return Invisibly returns NULL after writing to the file.
    process = function() {
      # Create the text placeholder file first
      self$create_text_placeholder()

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
    },

    #' @description
    #' Static method to emit a Quarto text chunk with file creation code
    #'
    #' @param domain_key Character scalar domain key for chunk label
    #' @param data_var Character scalar data variable name
    #' @param file_path Character scalar file path for output
    #' @return Character string containing the complete chunk
    emit_quarto_text_chunk = function(domain_key, data_var, file_path) {
      stopifnot(
        is.character(domain_key),
        length(domain_key) == 1,
        is.character(data_var),
        length(data_var) == 1,
        is.character(file_path),
        length(file_path) == 1
      )

      lbl <- paste0("text-", domain_key)

      # Updated format with improved reliability:
      lines <- c(
        "```{r}",
        paste0("#| label: ", lbl),
        "#| cache: false",
        "#| include: false",
        "",
        "# Define the text file path",
        paste0("text_file <- \"", file_path, "\""),
        "",
        "# Check if file exists, if not create it",
        "if (!file.exists(text_file)) {",
        "  file.create(text_file)",
        "  message(paste(\"Created new text file:\", text_file))",
        "}",
        "",
        "# Generate text using R6 class",
        "results_processor <- NeuropsychResultsR6$new(",
        paste0("  data = ", data_var, ","),
        "  file = text_file",
        ")",
        "",
        "# Process and write the results",
        "results_processor$process()",
        "",
        "# Verify the file was written",
        "if (file.exists(text_file) && file.size(text_file) > 0) {",
        "  message(paste(\"Successfully generated text file:\", text_file,",
        "                \"with\", file.size(text_file), \"bytes\"))",
        "} else {",
        "  warning(paste(\"Text file generation may have failed for:\", text_file))",
        "}",
        "```",
        ""
      )
      paste(lines, collapse = "\n")
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
