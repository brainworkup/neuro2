# R/NeuropsychResultsR6.R
# neuro2 — Results writer + LLM injector

#' NeuropsychResultsR6
#' @description Writes the per-domain results into the domain's `*_text.qmd`
#'   and (optionally) runs the LLM to inject a `<summary>…</summary>` block.
#' @export
NeuropsychResultsR6 <- R6::R6Class(
  "NeuropsychResultsR6",
  public = list(
    #' @field data The data.frame/tibble of domain results
    data = NULL,
    #' @field file The path to the domain text QMD (e.g., "_02-06_executive_text.qmd")
    file = NULL,

    #' @description Constructor
    #' @param data data.frame/tibble with domain results
    #' @param file character path to the domain text QMD you include in the report
    initialize = function(data, file) {
      self$data <- data
      self$file <- file
    },

    #' @description Main entry: write results, then (optionally) run LLM injection
    #' @param llm logical; run LLM after writing results (default TRUE)
    #' @param prompts_dir directory of QMD prompts (default: installed `inst/prompts`)
    #' @param backend "ollama" (default) or "openai"
    #' @param temperature numeric (default 0.2)
    #' @param model_override optional exact model name
    #' @param mega_for_sirf logical; if TRUE, SIRF uses the "mega" model route
    #' @param echo ellmer echo mode (default "none")
    #' @param base_dir where `*_text.qmd` live (default ".")
    #' @param domain_keyword override prompt keyword; inferred by target @_NN-*.qmd if NULL
    #' @param ... ignored; allows forward compatibility without "unused arguments" errors
    process = function(
      llm = TRUE,
      prompts_dir = NULL,
      backend = getOption("neuro2.llm.backend", "ollama"),
      temperature = getOption("neuro2.llm.temperature", 0.2),
      model_override = getOption("neuro2.llm.model_override", NULL),
      mega_for_sirf = getOption("neuro2.llm.mega_for_sirf", FALSE),
      echo = "none",
      base_dir = ".",
      domain_keyword = NULL,
      ...
    ) {
      # 1) Write your results into self$file (keep your existing approach).
      #    If you have a package-level writer defined, we'll call it automatically.
      #    Otherwise, if self$file already has content, we won't touch it.
      if (isTRUE(file.exists(self$file))) {
        # do nothing; assume a prior step wrote into self$file
      } else if (exists("neuro2_write_results", mode = "function")) {
        # optional hook: implement elsewhere if you want to generate text here
        neuro2_write_results(self$data, self$file)
      } else {
        # create an empty file so downstream steps can proceed
        dir.create(dirname(self$file), recursive = TRUE, showWarnings = FALSE)
        cat("", file = self$file)
      }

      # 2) LLM stage: inject <summary>…</summary> into self$file
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

    #' @description Run LLM for this domain file and inject <summary>…</summary>
    #' @param prompts_dir directory of QMD prompts
    #' @param backend "ollama" or "openai"
    #' @param temperature numeric
    #' @param model_override optional exact model name
    #' @param mega_for_sirf logical; if TRUE and keyword is SIRF, use the "mega" model section
    #' @param echo ellmer echo mode
    #' @param base_dir where `*_text.qmd` live
    #' @param domain_keyword override; otherwise inferred from prompt target @_NN-*.qmd
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
      # Ensure the file exists; generate_domain_summary_from_master() expects to read it
      if (!file.exists(self$file)) {
        dir.create(dirname(self$file), recursive = TRUE, showWarnings = FALSE)
        cat("", file = self$file)
      }

      # 1) If domain_keyword not supplied, infer from prompts (match @_NN-*.qmd target)
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
            "; pass domain_keyword explicitly."
          )
        } else {
          stop(
            "Could not infer domain_keyword for ",
            self$file,
            "; pass domain_keyword= explicitly."
          )
        }
      }

      # 2) Route SIRF to the larger model if requested
      mega <- identical(gsub("[^A-Za-z0-9]+", "", domain_keyword), "prsirf") &&
        isTRUE(mega_for_sirf)

      # 3) Generate & inject <summary> into self$file
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

      invisible(TRUE)
    }
  )
)
