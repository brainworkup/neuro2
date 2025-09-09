#' Generate neuropsych summary via Ollama
#'
#' @param data Character string with neuropsych data in ### sections format
#' @return Bullet-point summary string
generate_neuropsych_summary <- function(data) {
  # Validate required format
  if (
    !grepl("### Cognitive Domains", data) ||
      !grepl("### Test Results", data) ||
      !grepl("### Clinical Impressions", data)
  ) {
    stop(
      "Input must contain ### sections for: Cognitive Domains, Test Results, Clinical Impressions"
    )
  }

  # Prepare Ollama API request
  body <- jsonlite::toJSON(
    list(model = "neuro2-summary", prompt = data, stream = FALSE),
    auto_unbox = TRUE
  )

  # Send to local Ollama server
  response <- httr::POST(
    "http://localhost:11434/api/generate",
    body = body,
    httr::add_headers(`Content-Type` = "application/json")
  )

  # Handle errors
  if (httr::http_error(response)) {
    msg <- httr::content(response, "text")
    stop("Ollama API error: ", msg, call. = FALSE)
  }

  # Extract and clean summary
  summary_text <- httr::content(response)$response
  gsub("^\\*\\s*", "* ", summary_text) # Fix bullet formatting
}
