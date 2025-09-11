# LLM Integration for Neurocognitive Report Writing
# This file provides functions to apply LLM prompts to Quarto documents

#' Apply LLM Prompt to Quarto Document
#'
#' This function reads a JSON prompt file and a Quarto document, then uses an LLM
#' to generate interpretations based on the prompt instructions.
#'
#' @param qmd_path Path to the Quarto document containing the assessment results
#' @param prompt_path Path to the JSON file containing the prompt
#' @param model Character string specifying the model to use (default: "claude-3-5-sonnet-20241022")
#' @param provider Character string specifying the provider ("anthropic", "openai", "ollama")
#' @param api_key Optional API key. If NULL, will look for environment variables
#' @param temperature Numeric value for response variability (0-1, default: 0.3)
#' @param max_tokens Maximum tokens in response (default: 2000)
#'
#' @return Character string containing the LLM-generated interpretation
#' @export
#'
#' @examples
#' \dontrun{
#' result <- apply_llm_prompt(
#'   qmd_path = "_02-01_iq_text.qmd",
#'   prompt_path = "Prompt General Cognitive Ability.json",
#'   provider = "anthropic"
#' )
#' }
apply_llm_prompt <- function(
  qmd_path,
  prompt_path,
  model = "claude-3-5-sonnet-20241022",
  provider = "anthropic",
  api_key = NULL,
  temperature = 0.3,
  max_tokens = 2000
) {
  # Load required packages
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop(
      "Package 'elmer' is required. Install it with: remotes::install_github('hadley/elmer')"
    )
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop(
      "Package 'jsonlite' is required. Install it with: install.packages('jsonlite')"
    )
  }

  # Read the prompt file
  if (!file.exists(prompt_path)) {
    stop("Prompt file not found: ", prompt_path)
  }

  prompt_data <- jsonlite::read_json(prompt_path)

  # Extract the prompt text (assuming structure from your file)
  if (is.list(prompt_data) && length(prompt_data) > 0) {
    prompt_text <- prompt_data[[1]]$text
  } else {
    stop("Unable to extract prompt text from JSON file")
  }

  # Read the Quarto document
  if (!file.exists(qmd_path)) {
    stop("Quarto document not found: ", qmd_path)
  }

  qmd_content <- readLines(qmd_path, warn = FALSE)
  qmd_text <- paste(qmd_content, collapse = "\n")

  # Combine prompt and content
  full_prompt <- paste(
    prompt_text,
    "\n\n",
    "Here is the assessment data:\n\n",
    qmd_text,
    sep = ""
  )

  # Set up API key
  if (is.null(api_key)) {
    if (provider == "anthropic") {
      api_key <- Sys.getenv("ANTHROPIC_API_KEY")
    } else if (provider == "openai") {
      api_key <- Sys.getenv("OPENAI_API_KEY")
    }

    if (api_key == "") {
      stop(
        "API key not found. Please set it as an environment variable or pass it as an argument."
      )
    }
  }

  # Create chat instance based on provider
  chat <- switch(
    provider,
    "anthropic" = elmer::chat_claude(
      model = model,
      api_key = api_key,
      temperature = temperature,
      max_tokens = max_tokens
    ),
    "openai" = elmer::chat_openai(
      model = model,
      api_key = api_key,
      temperature = temperature,
      max_tokens = max_tokens
    ),
    "ollama" = elmer::chat_ollama(
      model = model,
      temperature = temperature,
      max_tokens = max_tokens
    ),
    stop("Unsupported provider: ", provider)
  )

  # Send prompt to LLM
  response <- chat$chat(full_prompt)

  return(response)
}


#' Process Multiple Neurocognitive Domains with LLM
#'
#' This function processes multiple Quarto documents with their corresponding prompts
#'
#' @param domain_files Named list where names are domains and values are qmd file paths
#' @param prompt_dir Directory containing the JSON prompt files
#' @param output_dir Directory to save the generated interpretations
#' @param ... Additional arguments passed to apply_llm_prompt
#'
#' @return List of generated interpretations
#' @export
process_neurocog_domains <- function(
  domain_files,
  prompt_dir = ".",
  output_dir = "llm_output",
  ...
) {
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  results <- list()

  for (domain in names(domain_files)) {
    message("Processing domain: ", domain)

    qmd_path <- domain_files[[domain]]

    # Look for corresponding prompt file
    prompt_pattern <- paste0("Prompt.*", domain, ".*\\.json")
    prompt_files <- list.files(
      prompt_dir,
      pattern = prompt_pattern,
      full.names = TRUE,
      ignore.case = TRUE
    )

    if (length(prompt_files) == 0) {
      warning("No prompt file found for domain: ", domain)
      next
    }

    prompt_path <- prompt_files[1] # Use first match

    # Apply LLM prompt
    tryCatch(
      {
        interpretation <- apply_llm_prompt(
          qmd_path = qmd_path,
          prompt_path = prompt_path,
          ...
        )

        results[[domain]] <- interpretation

        # Save to file
        output_file <- file.path(
          output_dir,
          paste0(domain, "_interpretation.txt")
        )
        writeLines(interpretation, output_file)

        message("  ✓ Saved to: ", output_file)
      },
      error = function(e) {
        warning("Failed to process domain ", domain, ": ", e$message)
        results[[domain]] <- NA
      }
    )
  }

  return(results)
}


#' Interactive LLM Report Builder
#'
#' This function provides an interactive workflow for building neurocognitive reports
#'
#' @param project_dir Directory containing the Quarto documents and prompts
#' @param ... Additional arguments passed to apply_llm_prompt
#'
#' @export
build_neurocog_report_interactive <- function(project_dir = ".", ...) {
  # Find all qmd files
  qmd_files <- list.files(
    project_dir,
    pattern = "\\.qmd$",
    full.names = TRUE,
    recursive = TRUE
  )

  if (length(qmd_files) == 0) {
    stop("No .qmd files found in project directory")
  }

  # Find all prompt files
  prompt_files <- list.files(
    project_dir,
    pattern = "Prompt.*\\.json$",
    full.names = TRUE,
    recursive = TRUE
  )

  if (length(prompt_files) == 0) {
    stop("No prompt JSON files found in project directory")
  }

  # Interactive selection
  message("\nAvailable Quarto documents:")
  for (i in seq_along(qmd_files)) {
    message(sprintf("[%d] %s", i, basename(qmd_files[i])))
  }

  qmd_choice <- as.numeric(readline("Select Quarto document number: "))

  message("\nAvailable prompt files:")
  for (i in seq_along(prompt_files)) {
    message(sprintf("[%d] %s", i, basename(prompt_files[i])))
  }

  prompt_choice <- as.numeric(readline("Select prompt file number: "))

  # Apply the prompt
  result <- apply_llm_prompt(
    qmd_path = qmd_files[qmd_choice],
    prompt_path = prompt_files[prompt_choice],
    ...
  )

  # Display result
  cat("\n--- Generated Interpretation ---\n")
  cat(result)
  cat("\n--- End of Interpretation ---\n")

  # Ask if user wants to save
  save_choice <- readline("Save to file? (y/n): ")

  if (tolower(save_choice) == "y") {
    output_file <- readline("Enter filename (or press Enter for default): ")

    if (output_file == "") {
      output_file <- paste0(
        tools::file_path_sans_ext(basename(qmd_files[qmd_choice])),
        "_interpretation.txt"
      )
    }

    writeLines(result, output_file)
    message("Saved to: ", output_file)
  }

  return(invisible(result))
}


#' Setup LLM Environment
#'
#' Helper function to set up API keys and test the connection
#'
#' @param provider Character string specifying the provider
#' @param api_key API key to set
#' @param test_connection Logical, whether to test the connection
#'
#' @export
setup_llm_environment <- function(
  provider = "anthropic",
  api_key = NULL,
  test_connection = TRUE
) {
  if (!is.null(api_key)) {
    if (provider == "anthropic") {
      Sys.setenv(ANTHROPIC_API_KEY = api_key)
    } else if (provider == "openai") {
      Sys.setenv(OPENAI_API_KEY = api_key)
    }
    message("API key set for ", provider)
  }

  if (test_connection) {
    message("Testing connection...")

    tryCatch(
      {
        test_prompt <- "Say 'Connection successful' if you can read this."

        chat <- switch(
          provider,
          "anthropic" = elmer::chat_claude(api_key = api_key),
          "openai" = elmer::chat_openai(api_key = api_key),
          "ollama" = elmer::chat_ollama(),
          stop("Unsupported provider: ", provider)
        )

        response <- chat$chat(test_prompt)
        message("✓ ", response)
      },
      error = function(e) {
        stop("Connection failed: ", e$message)
      }
    )
  }

  invisible(TRUE)
}
