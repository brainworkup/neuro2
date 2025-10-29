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
      # 1) Ensure the text file exists and contains up-to-date context
      if (exists("neuro2_write_results", mode = "function")) {
        neuro2_write_results(self$data, self$file)
      }
      private$write_default_context()

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
      llm_success <- tryCatch(
        {
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
          TRUE
        },
        error = function(e) {
          warning(
            sprintf(
              paste0(
                "LLM generation failed for %s (%s). ",
                "Keeping placeholder summary. Details: %s"
              ),
              basename(self$file),
              domain_keyword %||% "unknown-domain",
              conditionMessage(e)
            ),
            call. = FALSE
          )
          FALSE
        }
      )

      if (!llm_success) {
        private$write_default_context()
      }

      invisible(TRUE)
    }
  ),
  private = list(
    summary_placeholder = "<summary>\n\n</summary>",

    write_default_context = function() {
      if (is.null(self$file) || !nzchar(self$file)) {
        stop("NeuropsychResultsR6$file must be a non-empty path")
      }

      dir.create(dirname(self$file), recursive = TRUE, showWarnings = FALSE)

      existing <- read_file_or_empty(self$file)
      summary_block <- private$extract_summary(existing)
      if (!nzchar(summary_block)) {
        summary_block <- private$summary_placeholder
      }

      remainder <- private$remove_summary(existing)
      remainder <- private$remove_context_block(remainder)
      remainder <- private$normalize_ws(remainder)

      context_block <- private$build_context_block(self$data)

      parts <- c(
        private$trim_trailing(summary_block),
        if (nzchar(context_block)) context_block,
        remainder
      )
      parts <- parts[nzchar(parts)]

      new_content <- paste(parts, collapse = "\n\n")
      if (!nzchar(new_content)) {
        new_content <- private$summary_placeholder
      }

      readr::write_file(paste0(new_content, "\n"), self$file)
    },

    extract_summary = function(text) {
      if (!nzchar(text)) return("")
      m <- regexpr("<summary>\\s*.*?\\s*</summary>", text, perl = TRUE, ignore.case = TRUE)
      if (m[1] == -1) return("")
      regmatches(text, m)[[1]]
    },

    remove_summary = function(text) {
      if (!nzchar(text)) return("")
      gsub("<summary>\\s*.*?\\s*</summary>", "", text, perl = TRUE, ignore.case = TRUE)
    },

    remove_context_block = function(text) {
      if (!nzchar(text)) return("")
      gsub(
        "<!--\\s*LLM_CONTEXT_START\\s*-->.*?<!--\\s*LLM_CONTEXT_END\\s*-->",
        "",
        text,
        perl = TRUE,
        ignore.case = TRUE
      )
    },

    normalize_ws = function(text) {
      if (!nzchar(text)) return("")
      trimmed <- trimws(text, which = "both")
      if (!nzchar(trimmed)) "" else trimmed
    },

    trim_trailing = function(text) {
      if (!nzchar(text)) return("")
      sub("\\s+$", "", text)
    },

    build_context_block = function(data) {
      if (is.null(data) || !nrow(data)) return("")

      df <- as.data.frame(data, stringsAsFactors = FALSE)
      if (!nrow(df)) return("")

      domain_name <- private$first_non_empty(df$domain)
      raters <- NULL
      if ("rater" %in% names(df)) {
        raters <- sort(unique(df$rater[!is.na(df$rater) & nzchar(trimws(df$rater))]))
      }

      header <- c(
        "<!-- LLM_CONTEXT_START -->",
        if (nzchar(domain_name)) paste0("Domain: ", domain_name) else NULL,
        paste0("Records: ", nrow(df)),
        if (length(raters)) paste0("Raters: ", paste(raters, collapse = ", ")) else NULL,
        ""
      )

      lines <- vapply(
        seq_len(nrow(df)),
        function(idx) private$format_context_line(df[idx, , drop = FALSE]),
        character(1)
      )
      lines <- lines[nzchar(lines)]

      paste(
        c(header, lines, "<!-- LLM_CONTEXT_END -->"),
        collapse = "\n"
      )
    },

    format_context_line = function(row_df) {
      row <- lapply(row_df, function(x) if (length(x)) x else NA)

      pieces <- character()

      label <- private$first_non_empty(c(row$scale, row$test_name))
      if (nzchar(label)) pieces <- c(pieces, label)

      descriptor <- private$first_non_empty(c(row$subdomain, row$narrow))
      if (nzchar(descriptor) && !identical(descriptor, label)) {
        pieces <- c(pieces, descriptor)
      }

      range <- private$first_non_empty(row$range)
      if (nzchar(range)) pieces <- c(pieces, paste0("Range: ", range))

      percentile <- private$format_numeric(row$percentile, prefix = "Percentile: ")
      if (nzchar(percentile)) pieces <- c(pieces, percentile)

      score_part <- ""
      if (!is.null(row$score_type) && nzchar(private$first_non_empty(row$score_type))) {
        score_part <- private$format_numeric(
          row$score,
          prefix = paste0(private$first_non_empty(row$score_type), ": ")
        )
      }
      if (!nzchar(score_part) && !is.null(row$score)) {
        score_part <- private$format_numeric(row$score, prefix = "Score: ")
      }
      if (nzchar(score_part)) pieces <- c(pieces, score_part)

      raw_part <- private$format_numeric(row$raw_score, prefix = "Raw: ")
      if (nzchar(raw_part)) pieces <- c(pieces, raw_part)

      result_text <- private$first_non_empty(row$result)
      if (nzchar(result_text)) {
        pieces <- c(pieces, result_text)
      }

      if (!length(pieces)) return("")
      paste0("- ", paste(pieces, collapse = " | "))
    },

    first_non_empty = function(values) {
      if (is.null(values)) return("")
      vals <- as.character(values)
      vals <- vals[!is.na(vals)]
      vals <- trimws(vals)
      vals <- vals[nzchar(vals)]
      if (length(vals) == 0) "" else vals[1]
    },

    format_numeric = function(value, prefix = "", suffix = "") {
      if (is.null(value) || length(value) == 0) return("")
      val <- suppressWarnings(as.numeric(value[1]))
      if (!is.finite(val)) return("")
      formatted <- formatC(val, digits = 3, format = "fg", flag = "")
      formatted <- sub("\\.?0+$", "", formatted)
      paste0(prefix, formatted, if (nzchar(suffix)) suffix else "")
    }
  )
)
