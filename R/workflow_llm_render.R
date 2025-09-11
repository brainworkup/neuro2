
# workflow_llm_render.R
# Glue to run neuro2 LLM generation just before Quarto render.

#' @title Run neuro2 LLM stage then render Quarto
#' @description
#' Runs LLM generation for all domains using the prompts in `inst/prompts/`
#' (or an installed copy), then renders the target Quarto report(s).
#'
#' @param base_dir Directory containing the patient/domain *_text.qmd files.
#'   Typically the working directory for a single patient case.
#' @param prompts_dir Optional directory with prompt QMDs. During development
#'   pass "inst/prompts". If NULL, uses the installed copy via
#'   `system.file("prompts", package = "neuro2")`.
#' @param domain_keywords Character vector of domain keywords to run. Defaults to
#'   the standard set including "prsirf" at the end.
#' @param mega_for_sirf logical; if TRUE, SIRF uses the 30B / 256k context model.
#' @param model_override Optional exact Ollama model name to force for all sections.
#' @param temperature Numeric temperature for generation (default 0.2).
#' @param render_paths Character vector of report QMD paths to render after LLM stage.
#'   If NULL, no rendering is performed.
#' @param quarto_profile Optional Quarto profile name, e.g., "prod".
#' @param quiet Render quietly (passed to `quarto::quarto_render`).
#' @return A list with fields `llm_results` and `render_results` (if rendering).
#' @export
neuro2_run_llm_then_render <- function(
  base_dir = ".",
  prompts_dir = NULL,
  domain_keywords = c(
    "priq","pracad","prverb","prspt","prmem","prexe","prmot","prsoc",
    "pradhdchild","pradhdadult","premotchild","premotadult",
    "pradapt","prdaily","prsirf","prrecs"
  ),
  mega_for_sirf = FALSE,
  model_override = NULL,
  temperature = 0.2,
  render_paths = NULL,
  quarto_profile = NULL,
  quiet = TRUE
) {
  if (!dir.exists(base_dir)) stop("base_dir not found: ", base_dir)
  # 1) Run LLM generation across domains
  llm_results <- run_llm_for_all_domains(
    prompts_dir   = prompts_dir,
    domain_keywords = domain_keywords,
    model_override  = model_override,
    temperature     = temperature,
    base_dir        = base_dir,
    echo            = "none",
    mega_for_sirf   = mega_for_sirf
  )

  # 2) Optionally render Quarto reports
  render_results <- NULL
  if (!is.null(render_paths) && length(render_paths)) {
    if (!requireNamespace("quarto", quietly = TRUE)) {
      stop("The 'quarto' package is required to render. Install Quarto CLI and the R package 'quarto'.")
    }
    render_results <- lapply(render_paths, function(p) {
      qmd <- if (fs::is_absolute_path(p)) p else fs::path(base_dir, p)
      if (!file.exists(qmd)) stop("Render target not found: ", qmd)
      args <- list(input = qmd, quiet = quiet)
      if (!is.null(quarto_profile)) args$profile <- quarto_profile
      do.call(quarto::quarto_render, args)
    })
    names(render_results) <- render_paths
  }

  invisible(list(llm_results = llm_results, render_results = render_results))
}

#' @title Convenience: develop with local prompts
#' @description
#' Shorthand for running LLM generation using prompts in "inst/prompts" without rendering.
#' @inheritParams neuro2_run_llm_then_render
#' @return LLM results list.
#' @export
neuro2_llm_dev <- function(
  base_dir = ".",
  domain_keywords = c(
    "priq","pracad","prverb","prspt","prmem","prexe","prmot","prsoc",
    "pradhdchild","pradhdadult","premotchild","premotadult",
    "pradapt","prdaily","prsirf","prrecs"
  ),
  mega_for_sirf = FALSE,
  model_override = NULL,
  temperature = 0.2
) {
  run_llm_for_all_domains(
    prompts_dir     = "inst/prompts",
    domain_keywords = domain_keywords,
    model_override  = model_override,
    temperature     = temperature,
    base_dir        = base_dir,
    echo            = "none",
    mega_for_sirf   = mega_for_sirf
  )
}
