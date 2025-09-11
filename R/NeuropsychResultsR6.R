#' NeuropsychResultsR6 Class
#'
#' An R6 class that concatenates and flattens neuropsych results by scale,
#' optionally runs an LLM (via Ollama) to generate a summary, and writes
#' output to a Quarto text file.
#'
#' @field data A dataframe containing the neuropsych results with at least a \code{result} column.
#' @field file A character string specifying the path to the target QMD text file (e.g., "_02-01_iq.qmd").
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new NeuropsychResultsR6 object with data and file path.}
#'   \item{process}{Sort data by percentile, remove duplicates, write to file, and optionally run LLM.}
#'   \item{create_text_placeholder}{Create placeholder text file if it doesn't exist.}
#'   \item{emit_quarto_text_chunk}{Static method to emit a Quarto R chunk for generating this file.}
#'   \item{run_llm}{Internal method: Run Ollama LLM to generate a domain summary and inject into file.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr arrange distinct desc
#' @export
NeuropsychResultsR6 <- R6::R6Class(
  classname = "NeuropsychResultsR6",
  public = list(
    data = NULL,
    file = NULL,

    #' @description
    #' Initialize a new NeuropsychResultsR6 object with data and file path.
    #'
    #' @param data A dataframe containing the neuropsych results.
    #' @param file A character string specifying the path to the output QMD text file.
    #' @param ... Additional arguments (ignored).
    #'
    #' @return A new NeuropsychResultsR6 object.
    initialize = function(data, file, ...) {
      self$data <- data
      self$file <- file
    },

    #' @description
    #' Create a placeholder text file for the domain if it doesn't already exist.
    #'
    #' @return The file path that was created or already existed (invisibly).
    create_text_placeholder = function() {
      if (!is.null(self$file) && nzchar(self$file) && !file.exists(self$file)) {
        file.create(self$file)
        message(paste("Created placeholder file:", self$file))
      }
      invisible(self$file)
    },

    #' @description
    #' Sort the data by percentile, remove duplicates, convert to text, write to file,
    #' and optionally invoke an LLM to generate a summary block.
    #'
    #' @param llm Logical; whether to run an LLM after writing the raw results. Default: \code{TRUE}.
    #' @param prompts_dir Path to directory containing prompt templates. Defaults to \code{system.file("prompts", package = "neuro2")}.
    #' @param backend LLM backend to use. Default: \code{"ollama"}.
    #' @param temperature Temperature setting for LLM sampling. Default: \code{0.2}.
    #' @param model_override Optional model name override. Default: \code{NULL}.
    #' @param mega_for_sirf Logical; if \code{TRUE}, use 'mega' model for SIRF domains. Default: \code{FALSE}.
    #' @param echo Control for \code{knitr} chunk echoing. Default: \code{"none"}.
    #' @param base_dir Base directory where QMD files are located. Default: \code{"."}.
    #' @param domain_keyword Explicit keyword for prompt matching. If \code{NULL}, inferred from \code{self$file}.
    #'
    #' @return Invisibly returns \code{TRUE} on success.
    process = function(
      llm = TRUE,
      prompts_dir = NULL,
      backend = getOption("neuro2.llm.backend", "ollama"),
      temperature = getOption("neuro2.llm.temperature", 0.2),
      model_override = getOption("neuro2.llm.model_override", NULL),
      mega_for_sirf = getOption("neuro2.llm.mega_for_sirf", FALSE),
      echo = "none",
      base_dir = ".",
      domain_keyword = NULL
    ) {
      # Guard against recursive processing
      if (isTRUE(private$processing_flag)) {
        message('Already processing, skipping to prevent recursion')
        return(invisible(FALSE))
      }
      private$processing_flag <- TRUE
      on.exit(private$processing_flag <- FALSE, add = TRUE)

      # 1. Ensure placeholder file exists
      self$create_text_placeholder()

      # 2. Sort data by percentile descending, remove duplicates
      sorted_data <- self$data |>
        dplyr::arrange(dplyr::desc(percentile)) |>
        dplyr::distinct(.keep_all = FALSE)

      # 3. Format as plain text (one result per line)
      if (nrow(sorted_data) > 0) {
        qmd_content <- sorted_data$result
      } else {
        qmd_content <- "No data available for this domain."
      }

      # 4. Write content to file (overwrite)
      cat(qmd_content, file = self$file, sep = "\n", append = FALSE)
      message(paste("Wrote", length(qmd_content), "lines to", self$file))

      # 5. Optionally run LLM to generate summary and inject <summary>...</summary> block
      if (isTRUE(llm)) {
        self$run_llm(
          prompts_dir = prompts_dir,
          backend = backend,
          temperature = temperature,
          model_override = model_override,
          mega_for_sirf = mega_for_sirf,
          echo = echo,
          base_dir = base_dir,
          domain_keyword = domain_keyword
        )
      }

      invisible(TRUE)
    },

    #' @description
    #' Static method to emit a Quarto R code chunk that will generate the QMD file using this class.
    #'
    #' @param domain_key Character scalar; domain identifier (e.g., "iq", "executive").
    #' @param data_var Character scalar; name of the data variable in the Quarto document.
    #' @param file_path Character scalar; path to the output .qmd text file.
    #'
    #' @return Character string containing a complete Quarto R chunk.
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

      lines <- c(
        "```{r}",
        paste0("#| label: ", lbl),
        "#| cache: true",
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
        "# Generate text using NeuropsychResultsR6 class",
        "results_processor <- NeuropsychResultsR6$new(",
        paste0("  data = ", data_var, ","),
        "  file = text_file",
        ")",
        "",
        "# Process and optionally run LLM",
        "results_processor$process(llm = TRUE)",
        "",
        "# Verify output",
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
    },

    #' @description
    #' Internal method: Run an LLM (via Ollama) to generate a domain summary and inject it
    #' into the QMD file as a <summary>...</summary> block.
    #'
    #' @param prompts_dir Path to prompt templates. Defaults to \code{system.file("prompts", package = "neuro2")}.
    #' @param backend LLM backend (e.g., "ollama"). Default: \code{getOption("neuro2.llm.backend", "ollama")}.
    #' @param temperature Sampling temperature. Default: \code{0.2}.
    #' @param model_override Optional model name. Default: \code{NULL}.
    #' @param mega_for_sirf Logical; if \code{TRUE}, use 'mega' model for SIRF domains. Default: \code{FALSE}.
    #' @param echo \code{knitr} chunk echo control. Default: \code{"none"}.
    #' @param base_dir Base directory where QMD files reside. Default: \code{"."}.
    #' @param domain_keyword Explicit domain keyword for prompt matching. If \code{NULL}, inferred from \code{self$file}.
    #'
    #' @return Invisibly returns \code{TRUE}.
    run_llm = function(
      prompts_dir = NULL,
      backend = "ollama",
      temperature = 0.2,
      model_override = NULL,
      mega_for_sirf = FALSE,
      echo = "none",
      base_dir = ".",
      domain_keyword = NULL
    ) {
      # Infer domain_keyword from file if not provided
      if (is.null(domain_keyword)) {
        prompts <- read_prompts_from_dir(
          prompts_dir %||% system.file("prompts", package = "neuro2")
        )
        hits <- vapply(
          prompts,
          function(p) identical(detect_target_qmd(p$text), basename(self$file)),
          logical(1)
        )
        if (sum(hits) == 1L) {
          domain_keyword <- prompts[[which(hits)]]$keyword
        } else if (sum(hits) > 1L) {
          stop(
            "Multiple prompts target ",
            self$file,
            "; please set domain_keyword explicitly."
          )
        } else {
          stop(
            "Could not infer domain_keyword for ",
            self$file,
            ". Supply domain_keyword= explicitly."
          )
        }
      }

      # Decide whether to use 'mega' model for SIRF
      mega <- identical(gsub("[^A-Za-z0-9]+", "", domain_keyword), "prsirf") &&
        isTRUE(mega_for_sirf)

      # Call the consolidated generator to inject <summary> block into self$file
      generate_domain_summary_from_master(
        prompts_dir = prompts_dir,
        domain_keyword = domain_keyword,
        model_override = model_override,
        backend = backend,
        temperature = temperature,
        base_dir = base_dir,
        echo = echo,
        mega = mega
      )

      message(paste("LLM summary injected into:", self$file))
      invisible(TRUE)
    }
  ),
  private = list(
    # Flag to prevent recursive calls within process()
    processing_flag = FALSE
  )
)

#' Concatenate and Flatten Neuropsych Results by Scale (Function Wrapper)
#'
#' This function sorts the data by percentile, removes duplicates, converts to text,
#' writes to a file, and optionally invokes an LLM to generate a summary.
#' It's a wrapper around the \code{NeuropsychResultsR6} class.
#'
#' @param data A dataframe containing the neuropsych results.
#' @param file A character string specifying the path to the output QMD text file.
#' @param ... Additional arguments passed to \code{NeuropsychResultsR6$process()}.
#'
#' @return Invisibly returns \code{NULL}.
#' @importFrom dplyr arrange distinct desc
#' @export
#' @rdname cat_neuropsych_results
cat_neuropsych_results <- function(data, file, ...) {
  results_obj <- NeuropsychResultsR6$new(data = data, file = file)
  results_obj$process(...)
  invisible(NULL)
}
