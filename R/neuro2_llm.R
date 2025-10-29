# neuro2_llm.R — Enhanced LLM implementation for neuro2
#
# ENHANCEMENTS (v2.0):
# 1. Updated model selections with 2024-2025 SOTA models
# 2. Model availability checker for Ollama
# 3. Enhanced error handling with intelligent retry logic
# 4. Clinical output validation and quality scoring
# 5. Parallel processing support for batch operations
#
# Public API:
#   - neuro2_llm_smoke_test()
#   - generate_domain_summary_from_master()
#   - run_llm_for_all_domains()
#   - run_llm_for_all_domains_parallel()  # NEW
#   - neuro2_run_llm_then_render()
#   - validate_clinical_output()  # NEW
#   - check_available_models()  # NEW
#   - get_model_config()  # NEW

# ----------------------- Utilities --------------------------

#' @title LLM Cache Directory
#' @description Returns the path to the LLM cache directory, creating it if it doesn't exist.
#' @return Character string of the cache directory path.
#' @export
llm_cache_dir <- function() {
  d <- file.path(tempdir(), "neuro2_llm_cache")
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE)
  }
  d
}

#' @title LLM Usage Log File
#' @description Returns path to usage log file for tracking LLM calls
#' @return Character string of log file path
#' @export
llm_usage_log <- function() {
  file.path(llm_cache_dir(), "usage_log.csv")
}

#' Strip <think> blocks that some local models emit
strip_think_blocks <- function(text) {
  stringr::str_replace_all(text, "(?is)<think>.*?</think>", "") |> trimws()
}

#' Write text atomically and defensively (avoids "invalid connection")
safe_write_text <- function(text, filepath) {
  dir.create(dirname(filepath), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(filepath, ".tmp")
  con <- file(tmp, open = "wb")
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  # ensure UTF-8 and binary write (no newline munging)
  writeBin(charToRaw(enc2utf8(paste(text, collapse = ""))), con)
  # atomic rename
  file.rename(tmp, filepath)
  invisible(filepath)
}

# Canonicalize keys so "pro.sirf" == "prosirf"
.canon <- function(x) gsub("[^A-Za-z0-9]+", "", x %||% "")

# Safe defaulting
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || !nzchar(x)) y else x
}

# Small helper to read YAML front matter + body from a QMD
#' @keywords internal
.read_qmd_front_matter <- function(text) {
  m <- stringr::str_match(text, "(?s)^\\s*---\\s*(.*?)\\s*---\\s*(.*)$")
  if (is.na(m[1, 2])) {
    return(NULL)
  }
  list(front = yaml::yaml.load(m[1, 2]), body = m[1, 3])
}

# ---------------------- Token counting & logging ----------------------

#' @title Estimate Token Count
#' @description Rough estimate of token count for text (GPT-style ~4 chars/token)
#' @param text Character string
#' @return Approximate number of tokens
#' @export
estimate_tokens <- function(text) {
  ceiling(nchar(text) / 4)
}

#' @title Log LLM Usage
#' @description Append usage statistics to log file
#' @param section Section type (domain/sirf/mega)
#' @param model Model name used
#' @param input_tokens Approximate input tokens
#' @param output_tokens Approximate output tokens
#' @param time_seconds Time taken in seconds
#' @param success Whether call succeeded
#' @param domain_keyword Optional domain keyword
#' @export
log_llm_usage <- function(
  section,
  model,
  input_tokens,
  output_tokens,
  time_seconds,
  success = TRUE,
  domain_keyword = NA_character_
) {
  log_file <- llm_usage_log()

  # Create log entry
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    section = section,
    model = model,
    domain = domain_keyword,
    input_tokens = input_tokens,
    output_tokens = output_tokens,
    total_tokens = input_tokens + output_tokens,
    time_seconds = round(time_seconds, 2),
    success = success,
    stringsAsFactors = FALSE
  )

  # Append to log (create if doesn't exist)
  if (file.exists(log_file)) {
    existing <- readr::read_csv(log_file, show_col_types = FALSE)
    combined <- rbind(existing, entry)
  } else {
    combined <- entry
  }

  readr::write_csv(combined, log_file)
  invisible(entry)
}

# ---------------------- Enhanced model configuration ----------------------

#' @title Get Model Configuration
#' @description Returns tiered model selections for different section types
#' @param section One of "domain" (8B), "sirf" (14B), "mega" (30B+)
#' @param tier Either "primary" (latest/best) or "fallback" (proven alternatives)
#' @return Character vector of model names in priority order
#' @export
get_model_config <- function(
  section = c("domain", "sirf", "mega"),
  tier = c("primary", "fallback")
) {
  section <- match.arg(section)
  tier <- match.arg(tier)

  # Define model families with quality tiers
  models <- list(
    domain = list(
      # Tier 1: Latest recommended (2025-)
      primary = c(
        "gemma3:4b-it-qat",
        "qwen3:4b-instruct-2507-q4_K_M",
        "llama3.2:3b-instruct-q4_K_M",
        "mistral:7b-instruct-v0.3-q4_K_M"
      ),
      # Tier 2: Proven fallbacks
      fallback = c(
        "qwen3:8b-q4_K_M", # Original model (proven)
        "phi3:medium-128k-q4_K_M", # Microsoft, handles long context
        "llama3:8b-instruct-q4_K_M" # Meta's stable version
      )
    ),

    sirf = list(
      # Tier 1: Best for complex reasoning + synthesis
      primary = c(
        "gemma3:12b-it-qat",
        "qwen3:8b-q8_0",
        "llama3:8b-instruct-q8_0",
        "mixtral:8x7b-instruct-q4_K_M",
        "command-r:35b-v0.1-q4_K_M"
      ),
      # Tier 2: Proven alternatives
      fallback = c(
        "qwen3:14b-q4_K_M", # Original 14B
        "solar:10.7b-instruct-q4_K_M", # Korean model, strong reasoning
        "yi:34b-chat-q4_K_M" # Chinese model, medical knowledge
      )
    ),

    mega = list(
      # Tier 1: Best overall for comprehensive analysis
      primary = c(
        "gemma3:27b-it-qat",
        "gpt-oss:20b",
        "qwen3:30b-a3b-instruct-2507-q4_K_M",
        "llama3.1:70b-instruct-q4_0", # If you have VRAM (lighter quant)
        "command-r:35b-v0.1-q4_K_M",
        "mixtral:8x22b-instruct-q4_0" # If extreme performance needed
      ),
      # Tier 2: Solid alternatives
      fallback = c(
        "qwen3:32b-q4_K_M", # Original 32B
        "yi:34b-chat-q4_K_M", # Strong medical knowledge
        "nous-hermes-2-mixtral:8x7b-dpo-q4_K_M" # Fine-tuned for instructions
      )
    )
  )

  return(models[[section]][[tier]])
}

#' @title Check Available Models
#' @description Check which models from a list are actually installed in Ollama
#' @param models Character vector of model names to check
#' @param backend Backend type ("ollama" or "openai")
#' @return Character vector of available models (intersection of requested & installed)
#' @export
check_available_models <- function(models, backend = "ollama") {
  if (backend != "ollama") {
    # For OpenAI, assume all models are available via API
    return(models)
  }

  tryCatch(
    {
      # Get list of installed Ollama models
      result <- system("ollama list", intern = TRUE, ignore.stderr = TRUE)

      if (length(result) <= 1) {
        warning("No Ollama models appear to be installed")
        return(character(0))
      }

      # Parse model names (first column, remove size/date info)
      installed <- gsub("\\s+.*$", "", result[-1])

      # Some models might have :latest suffix in ollama list
      installed_base <- gsub(":latest$", "", installed)
      models_base <- gsub(":latest$", "", models)

      # Find matches (case-insensitive)
      available <- character(0)
      for (m in models) {
        m_base <- gsub(":latest$", "", m)
        if (
          any(grepl(paste0("^", m_base), installed_base, ignore.case = TRUE))
        ) {
          available <- c(available, m)
        }
      }

      return(available)
    },
    error = function(e) {
      warning("Could not check Ollama models: ", conditionMessage(e))
      return(models) # Optimistic fallback
    }
  )
}

#' @title Get Best Available Model
#' @description Get the best available model for a section, checking what's installed
#' @param section Section type
#' @param backend Backend type
#' @param prefer_tier Preferred tier ("primary" or "fallback")
#' @return Single model name (best available)
#' @export
get_best_available_model <- function(
  section = c("domain", "sirf", "mega"),
  backend = "ollama",
  prefer_tier = "primary"
) {
  section <- match.arg(section)

  # Try primary tier first
  primary_models <- get_model_config(section, "primary")
  available_primary <- check_available_models(primary_models, backend)

  if (length(available_primary) > 0) {
    message(sprintf(
      "Using primary %s model: %s",
      section,
      available_primary[1]
    ))
    return(available_primary[1])
  }

  # Fall back to fallback tier
  fallback_models <- get_model_config(section, "fallback")
  available_fallback <- check_available_models(fallback_models, backend)

  if (length(available_fallback) > 0) {
    message(sprintf(
      "Using fallback %s model: %s",
      section,
      available_fallback[1]
    ))
    return(available_fallback[1])
  }

  # Ultimate fallback - use first model from primary list
  warning(sprintf(
    "No %s models installed. Please install one of: %s",
    section,
    paste(primary_models[1:3], collapse = ", ")
  ))
  return(primary_models[1])
}

# ---------------------- Clinical output validation ----------------------

#' @title Validate Clinical Output
#' @description Validate that LLM output meets clinical reporting standards
#' @param text Generated text
#' @param data_context Optional data context for additional checks
#' @param strict Whether to use strict validation rules
#' @return List with validation results (valid, issues, score)
#' @export
validate_clinical_output <- function(
  text,
  data_context = NULL,
  strict = FALSE
) {
  issues <- character(0)
  warnings <- character(0)

  # Clean text first
  text_clean <- strip_think_blocks(text)

  # Check 1: Length (not too short)
  min_length <- if (strict) 150 else 100
  if (nchar(text_clean) < min_length) {
    issues <- c(
      issues,
      sprintf(
        "Output too short (%d chars, minimum %d)",
        nchar(text_clean),
        min_length
      )
    )
  }

  # Check 2: Not too long (avoid rambling)
  max_length <- if (strict) 800 else 1000
  if (nchar(text_clean) > max_length) {
    warnings <- c(
      warnings,
      sprintf(
        "Output lengthy (%d chars, target <%d)",
        nchar(text_clean),
        max_length
      )
    )
  }

  # Check 3: Percentile mentions (should be sparse)
  percentile_pattern <- "\\d+(?:st|nd|rd|th)\\s*percentile"
  percentile_matches <- gregexpr(
    percentile_pattern,
    text_clean,
    ignore.case = TRUE
  )[[1]]
  score_mentions <- sum(percentile_matches > 0)

  if (score_mentions > 5) {
    issues <- c(
      issues,
      sprintf(
        "Too many percentile mentions (%d) - should be sparse (<5)",
        score_mentions
      )
    )
  } else if (score_mentions > 3) {
    warnings <- c(
      warnings,
      sprintf(
        "Frequent percentile mentions (%d) - consider reducing",
        score_mentions
      )
    )
  }

  # Check 4: Test name avoidance
  test_names <- c(
    "WAIS",
    "WISC",
    "WPPSI",
    "WIAT",
    "KTEA",
    "NEPSY",
    "D-KEFS",
    "CVLT",
    "ROCFT",
    "Rey",
    "Trail Making",
    "BASC",
    "BRIEF",
    "Conners",
    "CAARS",
    "CEFI",
    "NAB",
    "RBANS"
  )

  test_mentions <- sum(sapply(test_names, function(t) {
    grepl(t, text_clean, ignore.case = TRUE)
  }))

  if (test_mentions > 0) {
    if (strict) {
      issues <- c(
        issues,
        sprintf(
          "Should avoid test names in summary (found %d mentions)",
          test_mentions
        )
      )
    } else {
      warnings <- c(
        warnings,
        sprintf(
          "Test names mentioned (%d) - consider using general terms",
          test_mentions
        )
      )
    }
  }

  # Check 5: Score values (T-scores, standard scores, scaled scores)
  score_pattern <- "(?:T-score|standard score|scaled score|raw score)\\s*(?:of|=|:)?\\s*\\d+"
  score_matches <- gregexpr(score_pattern, text_clean, ignore.case = TRUE)[[1]]
  raw_score_mentions <- sum(score_matches > 0)

  if (raw_score_mentions > 2) {
    if (strict) {
      issues <- c(
        issues,
        sprintf(
          "Excessive raw score reporting (%d mentions)",
          raw_score_mentions
        )
      )
    } else {
      warnings <- c(warnings, "Consider reducing specific score mentions")
    }
  }

  # Check 6: Clinical language quality
  # Should have clinical terms like "cognitive", "skills", "functioning"
  clinical_terms <- c(
    "cognitive",
    "functioning",
    "ability",
    "skills",
    "performance",
    "difficulties",
    "challenges",
    "strengths",
    "weaknesses"
  )

  clinical_mentions <- sum(sapply(clinical_terms, function(t) {
    grepl(t, text_clean, ignore.case = TRUE)
  }))

  if (clinical_mentions < 2) {
    warnings <- c(warnings, "May lack clinical terminology")
  }

  # Check 7: Structure (should be coherent sentences)
  sentence_pattern <- "[.!?]\\s+"
  num_sentences <- length(unlist(strsplit(text_clean, sentence_pattern)))

  if (num_sentences < 2) {
    issues <- c(issues, "Output should contain multiple sentences")
  }

  # Calculate quality score (0-100)
  base_score <- 100
  base_score <- base_score - (length(issues) * 25) # Major issues: -25 each
  base_score <- base_score - (length(warnings) * 10) # Warnings: -10 each
  quality_score <- max(0, min(100, base_score))

  # Determine overall validity
  is_valid <- length(issues) == 0 && quality_score >= 60

  return(list(
    valid = is_valid,
    quality_score = quality_score,
    issues = issues,
    warnings = warnings,
    metrics = list(
      length = nchar(text_clean),
      percentile_mentions = score_mentions,
      test_name_mentions = test_mentions,
      score_mentions = raw_score_mentions,
      clinical_terms = clinical_mentions,
      num_sentences = num_sentences
    )
  ))
}

# ---------------------- Prompt loader (QMD only) ----------------

#' @title Read Prompts From Directory of QMD files
#' @description Loads prompts from a folder of .qmd files that contain YAML front matter (name, keyword) and a body.
#' @param dir Directory path. Defaults to the installed `inst/prompts` via `system.file("prompts", package = "neuro2")`.
#' @return List of prompts with fields `name`, `keyword`, `text`.
#' @export
read_prompts_from_dir <- function(
  dir = system.file("prompts", package = "neuro2")
) {
  if (!nzchar(dir) || !dir.exists(dir)) {
    stop("Prompts directory not found: ", dir)
  }
  files <- fs::dir_ls(dir, regexp = "\\.qmd$", type = "file")
  if (!length(files)) {
    stop("No .qmd prompt files found in: ", dir)
  }

  out <- lapply(files, function(f) {
    x <- readr::read_file(f)
    qb <- .read_qmd_front_matter(x)
    if (is.null(qb)) {
      stop("Missing YAML front matter in: ", f)
    }
    fm <- qb$front
    body <- qb$body
    if (is.null(fm$keyword) || !nzchar(fm$keyword)) {
      stop("Missing 'keyword' in YAML: ", f)
    }
    if (is.null(fm$name)) {
      fm$name <- fm$keyword
    }
    list(
      name = as.character(fm$name),
      keyword = as.character(fm$keyword),
      text = as.character(body)
    )
  })

  # Keep only those that declare a target @_NN-*.qmd line
  has_target <- vapply(
    out,
    function(x) {
      isTRUE(grepl(
        "(?m)^\\s*@\\s*(_\\d{2}-[^\\s]+\\.qmd)\\s*$",
        x$text,
        perl = TRUE
      ))
    },
    logical(1)
  )
  out[has_target]
}

# ---------------------- Prompt text processors --------------------

#' @title Detect Target QMD
#' @description Extracts the target @_NN-*.qmd file from the prompt text.
#' @param prompt_text Character string of the prompt text.
#' @return Character string of the target qmd filename or `NA_character_`.
#' @export
detect_target_qmd <- function(prompt_text) {
  m <- stringr::str_match(
    prompt_text,
    "(?m)^\\s*@\\s*(_\\d{2}-[^\\s]+\\.qmd)\\s*$"
  )
  if (!is.na(m[1, 2])) m[1, 2] else NA_character_
}

#' @title Expand Includes in Text
#' @description Replaces `{{@file}}` references with file content and collects dependencies.
#' @param text Character string to expand.
#' @param base_dir Base directory for file paths, default `"."`.
#' @param on_missing `"note"` inserts the literal marker `[[MISSING FILE: ...]]`; `"skip"` drops silently.
#' @return List with expanded `text` and dependency `deps`.
#' @export
expand_includes <- function(
  text,
  base_dir = ".",
  on_missing = c("note", "skip")
) {
  on_missing <- match.arg(on_missing)
  deps <- character(0)
  expanded <- stringr::str_replace_all(
    text,
    "\\{\\{@([^}]+)\\}\\}",
    function(m) {
      rel <- sub("\\{\\{@([^}]+)\\}\\}", "\\1", m)
      fn <- file.path(base_dir, rel)
      if (file.exists(fn)) {
        deps <<- unique(c(deps, fn))
        readr::read_file(fn)
      } else {
        if (on_missing == "skip") "" else paste0("[[MISSING FILE: ", rel, "]]")
      }
    }
  )
  list(text = expanded, deps = deps)
}

#' @title Sanitize System Prompt
#' @description Removes chain-of-thought directions from the system prompt text.
#' @param text Character string of the system prompt.
#' @return Sanitized character string.
#' @export
sanitize_system_prompt <- function(text) {
  text <- stringr::str_replace_all(
    text,
    "(?is)Before writing.*?<summary>.*?</summary>\\s*",
    ""
  )
  text <- stringr::str_replace_all(
    text,
    "(?is)<neurocognitive_assessment_analysis>.*?</neurocognitive_assessment_analysis>",
    ""
  )
  text
}

#' @title Read File or Return Empty
#' @description Reads file content if exists, otherwise returns `""`.
#' @param path Character string path to file.
#' @return Character string of file content or empty string.
#' @export
read_file_or_empty <- function(path) {
  if (file.exists(path)) readr::read_file(path) else ""
}

#' @title Inject Summary Block into QMD
#' @description Injects or replaces the `<summary>` block in a QMD file with metadata
#' @param qmd_path Path to the QMD file.
#' @param generated Generated summary text.
#' @param metadata Optional metadata to include (model, version, timestamp, quality)
#' @return Invisible `TRUE`.
#' @export
inject_summary_block <- function(qmd_path, generated, metadata = NULL) {
  raw_qmd <- read_file_or_empty(qmd_path)
  if (!nzchar(raw_qmd)) {
    raw_qmd <- ""
  }

  # Build summary block
  summary_content <- generated

  # Optionally add metadata comment
  if (!is.null(metadata)) {
    meta_comment <- sprintf(
      "<!-- Generated: %s | Model: %s | Quality: %s -->",
      metadata$timestamp %||% format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      metadata$model %||% "unknown",
      metadata$quality_score %||% "N/A"
    )
    summary_content <- paste0(meta_comment, "\n\n", summary_content)
  }

  has_block <- grepl(
    "<summary>\\s*.*?\\s*</summary>",
    raw_qmd,
    perl = TRUE,
    ignore.case = TRUE
  )

  if (has_block) {
    new_qmd <- sub(
      pattern = "<summary>\\s*.*?\\s*</summary>",
      replacement = paste0("<summary>\n\n", summary_content, "\n\n</summary>"),
      x = raw_qmd,
      perl = TRUE
    )
  } else if (
    grepl("<summary\\s*/>", raw_qmd, perl = TRUE, ignore.case = TRUE)
  ) {
    new_qmd <- sub(
      pattern = "<summary\\s*/>",
      replacement = paste0("<summary>\n\n", summary_content, "\n\n</summary>"),
      x = raw_qmd,
      perl = TRUE
    )
  } else {
    new_qmd <- paste0(
      "<summary>\n\n",
      summary_content,
      "\n\n</summary>\n\n",
      raw_qmd
    )
  }

  readr::write_file(new_qmd, qmd_path)
  invisible(TRUE)
}

#' @title Hash Inputs for Caching
#' @description Creates a hash key from system prompt, user text, and dependencies' contents.
#' @param system_prompt Character string.
#' @param user_text Character string.
#' @param deps Character vector of dependency paths.
#' @importFrom digest digest
#' @return Character string hash.
#' @export
hash_inputs <- function(system_prompt, user_text, deps) {
  dep_txt <- paste0(
    vapply(deps, read_file_or_empty, ""),
    collapse = "\n<<FILE>>\n"
  )
  digest::digest(
    paste(system_prompt, user_text, dep_txt, sep = "\n---\n"),
    algo = "xxhash64"
  )
}

# --------------------- Model selection (backend) -----------------

#' @title Create a chat bot for neuro2
#' @description Selects an LLM backend and model by section with intelligent defaults
#' @param system_prompt System prompt string.
#' @param section One of `"domain"` (8B), `"sirf"` (14B), `"mega"` (30B+).
#' @param model_override Optional exact model name to force.
#' @param backend `"ollama"` (default) or `"openai"`.
#' @param temperature Numeric temperature. Domain-specific defaults if NULL.
#' @param echo Echo mode for ellmer.
#' @return A chat object from ellmer package.
#' @export
create_llm_chat <- function(
  system_prompt,
  section = c("domain", "sirf", "mega"),
  model_override = NULL,
  backend = "ollama",
  temperature = NULL,
  echo = "none"
) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop(
      "The 'ellmer' package is required. Install: install.packages('ellmer')"
    )
  }

  section <- match.arg(section)
  backend <- match.arg(backend, c("ollama", "openai"))

  # Set section-specific temperature defaults if not provided
  if (is.null(temperature)) {
    temperature <- switch(
      section,
      domain = 0.2, # More deterministic for routine summaries
      sirf = 0.35, # More creative for synthesis
      mega = 0.3 # Balanced for comprehensive analysis
    )
  }

  # Model selection logic
  if (!is.null(model_override) && nzchar(model_override)) {
    model <- model_override
  } else {
    model <- get_best_available_model(section, backend)
  }

  # Create chat bot
  if (backend == "ollama") {
    bot <- ellmer::chat_ollama(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = temperature),
      api_args = list(stream = FALSE),
      echo = echo
    )
  } else {
    bot <- ellmer::chat_openai(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = temperature),
      api_args = list(stream = FALSE),
      echo = echo
    )
  }

  return(bot)
}

# Generic text extractor (handles different response formats)
.extract_text_generic <- function(res) {
  if (is.character(res)) {
    return(res)
  }
  if (is.list(res)) {
    if (!is.null(res$message) && !is.null(res$message$content)) {
      return(res$message$content)
    }
    if (!is.null(res$content)) {
      return(res$content)
    }
    if (!is.null(res$text)) {
      return(res$text)
    }
  }
  as.character(res)
}

#' @title Call LLM Once (Basic)
#' @description Single LLM call without retry logic
#' @param system_prompt System prompt text
#' @param user_text User prompt text
#' @param section Section type for model selection
#' @param model_override Optional model override
#' @param backend Backend type
#' @param temperature Temperature setting
#' @param echo Echo mode
#' @return Generated text string
#' @export
call_llm_once <- function(
  system_prompt,
  user_text,
  section = "domain",
  model_override = NULL,
  backend = "ollama",
  temperature = NULL,
  echo = "none"
) {
  bot <- create_llm_chat(
    system_prompt = system_prompt,
    section = section,
    model_override = model_override,
    backend = backend,
    temperature = temperature,
    echo = echo
  )

  res <- bot$chat(user_text)
  text_out <- .extract_text_generic(res)
  return(text_out)
}

#' @title Call LLM with Retry Logic (Enhanced)
#' @description Call LLM with intelligent retry logic and fallback models
#' @param system_prompt System prompt text
#' @param user_text User prompt text
#' @param section Section type
#' @param model_override Optional specific model
#' @param backend Backend type
#' @param temperature Temperature
#' @param max_retries Maximum retry attempts
#' @param validate Whether to validate output
#' @param echo Echo mode
#' @param domain_keyword Optional domain keyword for logging
#' @return Generated text string
#' @export
call_llm_with_retry <- function(
  system_prompt,
  user_text,
  section = "domain",
  model_override = NULL,
  backend = "ollama",
  temperature = NULL,
  max_retries = 2,
  validate = TRUE,
  echo = "none",
  domain_keyword = NA_character_
) {
  # Track timing for logging
  start_time <- Sys.time()

  # Estimate input tokens for logging
  input_tokens <- estimate_tokens(paste(system_prompt, user_text))

  # If model override provided, just try that one model
  if (!is.null(model_override) && nzchar(model_override)) {
    models_to_try <- list(primary = c(model_override), fallback = character(0))
  } else {
    # Get models based on section
    models_to_try <- list(
      primary = get_model_config(section, "primary"),
      fallback = get_model_config(section, "fallback")
    )

    # Filter to available models
    models_to_try$primary <- check_available_models(
      models_to_try$primary,
      backend
    )
    models_to_try$fallback <- check_available_models(
      models_to_try$fallback,
      backend
    )
  }

  # Try primary models first, then fallbacks
  for (tier in c("primary", "fallback")) {
    models <- models_to_try[[tier]]

    if (length(models) == 0) {
      next
    }

    for (attempt in seq_len(max_retries)) {
      for (model in models) {
        tryCatch(
          {
            message(sprintf(
              "🤖 Generating with %s (%s tier, attempt %d/%d)...",
              model,
              tier,
              attempt,
              max_retries
            ))

            # Call LLM
            result <- call_llm_once(
              system_prompt = system_prompt,
              user_text = user_text,
              section = section,
              model_override = model,
              backend = backend,
              temperature = temperature,
              echo = echo
            )

            # Clean output
            result_clean <- strip_think_blocks(result)

            # Validate if requested
            if (validate) {
              validation <- validate_clinical_output(
                result_clean,
                strict = FALSE
              )

              if (!validation$valid) {
                warning(sprintf(
                  "Validation failed for %s (score: %d): %s",
                  model,
                  validation$quality_score,
                  paste(validation$issues, collapse = "; ")
                ))

                # If quality is very poor, try next model
                if (validation$quality_score < 40) {
                  next
                }
              } else {
                message(sprintf(
                  "✅ Quality score: %d/100",
                  validation$quality_score
                ))
              }
            }

            # Success - log and return
            elapsed_time <- as.numeric(difftime(
              Sys.time(),
              start_time,
              units = "secs"
            ))
            output_tokens <- estimate_tokens(result_clean)

            log_llm_usage(
              section = section,
              model = model,
              input_tokens = input_tokens,
              output_tokens = output_tokens,
              time_seconds = elapsed_time,
              success = TRUE,
              domain_keyword = domain_keyword
            )

            message(sprintf(
              "✅ Generated successfully with %s in %.1fs",
              model,
              elapsed_time
            ))

            return(result_clean)
          },
          error = function(e) {
            warning(sprintf(
              "❌ Failed with %s (tier: %s, attempt %d/%d): %s",
              model,
              tier,
              attempt,
              max_retries,
              conditionMessage(e)
            ))

            # Log failure
            elapsed_time <- as.numeric(difftime(
              Sys.time(),
              start_time,
              units = "secs"
            ))
            log_llm_usage(
              section = section,
              model = model,
              input_tokens = input_tokens,
              output_tokens = 0,
              time_seconds = elapsed_time,
              success = FALSE,
              domain_keyword = domain_keyword
            )
          }
        )
      }
    }
  }

  # If we get here, all attempts failed
  stop(sprintf(
    "All LLM attempts failed for section '%s' after %d retries. Check logs at: %s",
    section,
    max_retries,
    llm_usage_log()
  ))
}

# --------------------- Domain Summary Generation ----------------------

#' @title Generate Domain Summary From Master Prompts (QMD-based)
#' @description Generate summary for a single domain keyword using QMD prompts
#' @param prompts_dir Optional prompts directory
#' @param domain_keyword Domain keyword (e.g., "instacad", "prosirf")
#' @param model_override Optional model override
#' @param backend Backend type
#' @param temperature Temperature setting
#' @param base_dir Base directory for text files
#' @param echo Echo mode
#' @param mega Whether to use mega model (for SIRF)
#' @param validate Whether to validate output
#' @param max_retries Maximum retries
#' @return List with generation results (invisible)
#' @export
generate_domain_summary_from_master <- function(
  prompts_dir = NULL,
  domain_keyword,
  model_override = NULL,
  backend = "ollama",
  temperature = 0.1,
  base_dir = ".",
  echo = "none",
  mega = FALSE,
  validate = TRUE,
  max_retries = 2
) {
  if (is.null(prompts_dir) || !nzchar(prompts_dir)) {
    prompts_dir <- system.file("prompts", package = "neuro2")
  }
  if (!dir.exists(prompts_dir)) {
    stop("Prompts directory not found: ", prompts_dir)
  }

  prompts <- read_prompts_from_dir(prompts_dir)
  idx <- which(vapply(
    prompts,
    function(p) {
      identical(.canon(p$keyword), .canon(domain_keyword))
    },
    logical(1)
  ))

  if (!length(idx)) {
    message(sprintf(
      "No prompt found for domain keyword '%s'. Available keywords: %s",
      domain_keyword,
      paste(sapply(prompts, `[[`, "keyword"), collapse = ", ")
    ))
    return(invisible(NULL))
  }

  pobj <- prompts[[idx[1]]]
  ptx <- pobj$text
  target_qmd <- detect_target_qmd(ptx)

  if (is.na(target_qmd)) {
    message(sprintf("No @target.qmd detected for keyword '%s'", domain_keyword))
    return(invisible(NULL))
  }

  target_path <- file.path(base_dir, target_qmd)
  if (!file.exists(target_path)) {
    message(sprintf(
      "Target file '%s' does not exist for domain keyword '%s'. Skipping.",
      target_qmd,
      domain_keyword
    ))
    return(invisible(NULL))
  }

  # Check for primary domain file
  domain_qmd <- sub("_text.*\\.qmd$", ".qmd", target_path)
  if (!identical(domain_qmd, target_path) && !file.exists(domain_qmd)) {
    message(sprintf(
      "Skipping domain keyword '%s' because primary domain file '%s' is missing.",
      domain_keyword,
      basename(domain_qmd)
    ))
    return(invisible(NULL))
  }

  # Prepare prompts
  sys_prompt <- sanitize_system_prompt(ptx)
  inc <- expand_includes(ptx, base_dir = base_dir, on_missing = "skip")
  target_text <- read_file_or_empty(target_path)

  user_text <- paste(
    "Use the following patient/domain text to produce a single-paragraph clinical summary.",
    "Avoid test names and raw/standard/T/Scaled scores; sparingly use percentiles only if extreme.",
    "",
    "=== TARGET DOMAIN TEXT BEGIN ===",
    target_text,
    "=== TARGET DOMAIN TEXT END ===",
    "",
    "=== INCLUDED CONTEXT BEGIN ===",
    inc$text,
    "=== INCLUDED CONTEXT END ===",
    sep = "\n"
  )

  # Determine section
  key_can <- .canon(domain_keyword)
  section <- if (identical(key_can, "instsirf")) {
    if (isTRUE(mega)) "mega" else "sirf"
  } else {
    "domain"
  }

  # Check cache
  key <- hash_inputs(sys_prompt, user_text, deps = c(target_path, inc$deps))
  cache_file <- file.path(
    llm_cache_dir(),
    paste0(.canon(domain_keyword), "_", key, ".txt")
  )

  if (file.exists(cache_file)) {
    message(sprintf("📦 Using cached result for %s", domain_keyword))
    generated <- readr::read_file(cache_file)

    # Still validate cached content
    if (validate) {
      validation <- validate_clinical_output(generated, strict = FALSE)
      if (!validation$valid) {
        message("⚠️ Cached content failed validation, regenerating...")
        file.remove(cache_file)
      } else {
        inject_summary_block(target_path, generated)
        return(invisible(list(
          keyword = domain_keyword,
          qmd = target_path,
          text = generated,
          section = section,
          cached = TRUE
        )))
      }
    } else {
      inject_summary_block(target_path, generated)
      return(invisible(list(
        keyword = domain_keyword,
        qmd = target_path,
        text = generated,
        section = section,
        cached = TRUE
      )))
    }
  }

  # Generate with retry logic
  generated <- call_llm_with_retry(
    system_prompt = sys_prompt,
    user_text = user_text,
    section = section,
    model_override = model_override,
    backend = backend,
    temperature = temperature,
    max_retries = max_retries,
    validate = validate,
    echo = echo,
    domain_keyword = domain_keyword
  )

  # Cache the result
  safe_write_text(generated, cache_file)

  # Inject with metadata
  validation <- if (validate) {
    validate_clinical_output(generated, strict = FALSE)
  } else {
    list(quality_score = NA)
  }

  inject_summary_block(
    target_path,
    generated,
    metadata = list(
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      model = "auto-selected",
      quality_score = validation$quality_score
    )
  )

  invisible(list(
    keyword = domain_keyword,
    qmd = target_path,
    text = generated,
    section = section,
    cached = FALSE
  ))
}

# ---------------------- Parallel processing ----------------------

#' @title Run LLM for All Domains in Parallel
#' @description Process multiple domains in parallel for faster batch generation
#' @param prompts_dir Prompts directory
#' @param domain_keywords Vector of domain keywords
#' @param model_override Optional model override
#' @param backend Backend type
#' @param temperature Temperature
#' @param base_dir Base directory
#' @param echo Echo mode
#' @param mega_for_sirf Use mega model for SIRF
#' @param validate Validate outputs
#' @param max_retries Maximum retries per domain
#' @param n_cores Number of parallel workers (default: detectCores() - 1)
#' @return List of results per domain (invisible)
#' @export
run_llm_for_all_domains_parallel <- function(
  prompts_dir = NULL,
  domain_keywords = NULL,
  model_override = NULL,
  backend = "ollama",
  temperature = NULL,
  base_dir = ".",
  echo = "none",
  mega_for_sirf = FALSE,
  validate = TRUE,
  max_retries = 2,
  n_cores = NULL
) {
  # Auto-detect domain keywords if not provided
  if (is.null(domain_keywords)) {
    domains_with_data <- get_domains_with_data()
    domain_keywords <- domain_names_to_keywords(domains_with_data)

    if (length(domain_keywords) == 0) {
      warning("No domains found with data to process.")
      return(invisible(list()))
    }
  }

  # Check for parallel packages
  if (
    !requireNamespace("future", quietly = TRUE) ||
      !requireNamespace("future.apply", quietly = TRUE)
  ) {
    warning(
      "Parallel processing requires 'future' and 'future.apply' packages. ",
      "Falling back to sequential processing. ",
      "Install with: install.packages(c('future', 'future.apply'))"
    )
    return(run_llm_for_all_domains(
      prompts_dir = prompts_dir,
      domain_keywords = domain_keywords,
      model_override = model_override,
      backend = backend,
      temperature = temperature,
      base_dir = base_dir,
      echo = echo,
      mega_for_sirf = mega_for_sirf
    ))
  }

  # Determine number of cores
  if (is.null(n_cores)) {
    n_cores <- max(1, parallel::detectCores() - 1)
  }

  message(sprintf(
    "🚀 Processing %d domains in parallel using %d cores",
    length(domain_keywords),
    n_cores
  ))

  # Set up parallel backend
  future::plan(future::multisession, workers = n_cores)
  on.exit(future::plan(future::sequential), add = TRUE)

  # Process in parallel
  start_time <- Sys.time()

  out <- future.apply::future_lapply(
    domain_keywords,
    function(k) {
      try(
        {
          generate_domain_summary_from_master(
            prompts_dir = prompts_dir,
            domain_keyword = k,
            model_override = model_override,
            backend = backend,
            temperature = temperature,
            base_dir = base_dir,
            echo = echo,
            mega = if (.canon(k) == "instsirf") {
              isTRUE(mega_for_sirf)
            } else {
              FALSE
            },
            validate = validate,
            max_retries = max_retries
          )
        },
        silent = TRUE
      )
    },
    future.seed = TRUE
  )

  elapsed_time <- difftime(Sys.time(), start_time, units = "secs")

  names(out) <- domain_keywords

  # Report results
  successes <- sum(sapply(out, function(x) !inherits(x, "try-error")))
  message(sprintf(
    "✅ Completed %d/%d domains in %.1f seconds (avg: %.1fs per domain)",
    successes,
    length(domain_keywords),
    elapsed_time,
    elapsed_time / length(domain_keywords)
  ))

  invisible(out)
}

#' @title Run LLM for All Domains (Sequential, original)
#' @description Batch runs LLM generation for multiple domains using QMD prompts
#' @param prompts_dir Optional prompts directory
#' @param domain_keywords Vector of domain keywords
#' @param model_override Optional model override
#' @param backend Backend type
#' @param temperature Temperature
#' @param base_dir Base directory
#' @param echo Echo mode
#' @param mega_for_sirf Use mega model for SIRF
#' @return List of results per domain (invisible)
#' @export
run_llm_for_all_domains <- function(
  prompts_dir = NULL,
  domain_keywords = NULL,
  model_override = NULL,
  backend = "ollama",
  temperature = NULL,
  base_dir = ".",
  echo = "none",
  mega_for_sirf = FALSE
) {
  # Auto-detect domain keywords if not provided
  if (is.null(domain_keywords)) {
    domains_with_data <- get_domains_with_data()
    domain_keywords <- domain_names_to_keywords(domains_with_data)

    if (length(domain_keywords) == 0) {
      warning("No domains found with data to process.")
      return(invisible(list()))
    }
  }

  message(sprintf(
    "Processing %d domains sequentially...",
    length(domain_keywords)
  ))

  out <- lapply(domain_keywords, function(k) {
    try(
      {
        generate_domain_summary_from_master(
          prompts_dir = prompts_dir,
          domain_keyword = k,
          model_override = model_override,
          backend = backend,
          temperature = temperature,
          base_dir = base_dir,
          echo = echo,
          mega = if (.canon(k) == "instsirf") isTRUE(mega_for_sirf) else FALSE
        )
      },
      silent = TRUE
    )
  })

  names(out) <- domain_keywords
  invisible(out)
}

# --------------------- Diagnostics / Smoke test ---------------------

#' @title neuro2 LLM smoke test
#' @description Pings the configured model and returns a short response plus timing
#' @param model Model name (default: auto-select best available domain model)
#' @param backend "ollama" or "openai"
#' @param prompt User prompt string
#' @param system_prompt System prompt string
#' @return A list with fields `seconds`, `preview`, `raw`, `model`
#' @export
neuro2_llm_smoke_test <- function(
  model = NULL,
  backend = "ollama",
  prompt = "Reply with the single word: OK",
  system_prompt = "Be terse."
) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("The 'ellmer' package is required.")
  }

  # Auto-select best model if not specified
  if (is.null(model)) {
    model <- get_best_available_model("domain", backend)
    message("Auto-selected model: ", model)
  }

  backend <- match.arg(backend, c("ollama", "openai"))

  if (backend == "ollama") {
    bot <- ellmer::chat_ollama(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = 0.2),
      api_args = list(stream = FALSE),
      echo = "none"
    )
  } else {
    bot <- ellmer::chat_openai(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = 0.2),
      api_args = list(stream = FALSE),
      echo = "none"
    )
  }

  t0 <- Sys.time()
  res <- bot$chat(prompt)
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out <- .extract_text_generic(res)

  list(model = model, seconds = dt, preview = substr(out, 1, 240), raw = out)
}

# --------------------- Glue: run + render ---------------------

#' @title Run LLM then render Quarto
#' @description Executes the LLM stage first, then renders one or more Quarto documents
#' @param base_dir Base directory where `*_text.qmd` live
#' @param prompts_dir Prompts directory (default installed)
#' @param render_paths Character vector of paths to `.qmd` files to render after LLM runs
#' @param quarto_profile Optional Quarto profile (e.g., "prod")
#' @param render_format Preferred Quarto output format (default: detect or "typst")
#' @param render_all_formats Render every configured format (`FALSE` renders just one)
#' @param domain_keywords Vector of keywords to generate
#' @param backend Backend type
#' @param mega_for_sirf Use mega model for SIRF
#' @param temperature LLM temperature
#' @param echo ellmer echo mode
#' @param parallel Whether to use parallel processing
#' @param n_cores Number of cores for parallel processing
#' @return Invisibly returns a list with `llm` results and `rendered` output paths
#' @export
neuro2_run_llm_then_render <- function(
  base_dir = ".",
  prompts_dir = NULL,
  render_paths = character(0),
  quarto_profile = NULL,
  render_format = NULL,
  render_all_formats = FALSE,
  domain_keywords = NULL,
  backend = "ollama",
  mega_for_sirf = FALSE,
  temperature = NULL,
  echo = "none",
  parallel = FALSE,
  n_cores = NULL
) {
  # Run LLM generation (parallel or sequential)
  if (parallel) {
    llm_res <- run_llm_for_all_domains_parallel(
      prompts_dir = prompts_dir,
      domain_keywords = domain_keywords,
      backend = backend,
      temperature = temperature,
      base_dir = base_dir,
      echo = echo,
      mega_for_sirf = mega_for_sirf,
      n_cores = n_cores
    )
  } else {
    llm_res <- run_llm_for_all_domains(
      prompts_dir = prompts_dir,
      domain_keywords = domain_keywords,
      backend = backend,
      temperature = temperature,
      base_dir = base_dir,
      echo = echo,
      mega_for_sirf = mega_for_sirf
    )
  }

  # Render Quarto documents
  rendered <- character(0)
  if (length(render_paths)) {
    if (!requireNamespace("quarto", quietly = TRUE)) {
      stop("The 'quarto' package is required to render.")
    }

    for (rp in render_paths) {
      if (!file.exists(rp)) {
        warning("Skipping non-existent file: ", rp)
        next
      }

      message(sprintf("📄 Rendering %s...", basename(rp)))

      format_label <- if (isTRUE(render_all_formats)) {
        "all formats"
      } else {
        .neuro2_preferred_quarto_format(render_format)
      }

      message(sprintf("   • Using Quarto format: %s", format_label))

      .neuro2_render_quarto(
        input = rp,
        profile = quarto_profile,
        render_format = render_format,
        render_all_formats = render_all_formats
      )
      rendered <- c(rendered, rp)
    }
  }

  invisible(list(llm = llm_res, rendered = rendered))
}

# --------------------- Process Domains with LLM ---------------------

#' @title Process Domains with LLM
#' @description Main entry point for LLM processing of domain summaries
#' @param patient Patient name (default: "Biggie")
#' @param force_reprocess Force reprocessing even if cached (default: FALSE)
#' @param backend Backend type for LLM ("ollama" or "openai")
#' @param parallel Whether to use parallel processing (default: FALSE)
#' @param n_cores Number of cores for parallel processing (default: NULL)
#' @return List of processing results (invisible)
#' @export
process_domains_with_llm <- function(
  patient = "Biggie",
  force_reprocess = FALSE,
  backend = "ollama",
  parallel = TRUE,
  n_cores = NULL
) {
  message(sprintf("🤖 Processing domains with LLM for patient: %s", patient))

  # Determine which domains actually have data
  domains_with_data <- get_domains_with_data()

  if (length(domains_with_data) == 0) {
    warning(
      "No domains found with data. Check that data files exist and contain valid data."
    )
    return(invisible(list()))
  }

  # Convert domain names to keywords for LLM processing
  domain_keywords <- domain_names_to_keywords(domains_with_data)

  message(sprintf(
    "Found %d domains with data: %s",
    length(domains_with_data),
    paste(domains_with_data, collapse = ", ")
  ))

  # Run LLM processing only for domains that have data
  if (parallel && length(domain_keywords) > 1) {
    results <- run_llm_for_all_domains_parallel(
      domain_keywords = domain_keywords,
      backend = backend,
      base_dir = ".",
      n_cores = n_cores
    )
  } else {
    results <- run_llm_for_all_domains(
      domain_keywords = domain_keywords,
      backend = backend,
      base_dir = "."
    )
  }

  message("✅ LLM processing complete")
  invisible(results)
}

#' @title Get Domains With Data
#' @description Determines which domains actually have data available
#' @return Character vector of domain names that have data
#' @export
get_domains_with_data <- function() {
  domains_with_data <- character(0)

  # Check for data files
  data_files <- c(
    neurocog = "data/neurocog.parquet",
    neurobehav = "data/neurobehav.parquet",
    validity = "data/validity.parquet"
  )

  # Load data if files exist
  data_list <- list()
  for (data_type in names(data_files)) {
    file_path <- data_files[[data_type]]
    if (file.exists(file_path)) {
      tryCatch(
        {
          if (requireNamespace("arrow", quietly = TRUE)) {
            data_list[[data_type]] <- arrow::read_parquet(file_path)
          }
        },
        error = function(e) {
          warning(sprintf("Could not load %s: %s", file_path, e$message))
        }
      )
    }
  }

  # Define domain configurations
  domain_configs <- list(
    iq = list(name = "General Cognitive Ability", data_type = "neurocog"),
    academics = list(name = "Academic Skills", data_type = "neurocog"),
    verbal = list(name = "Verbal/Language", data_type = "neurocog"),
    spatial = list(
      name = "Visual Perception/Construction",
      data_type = "neurocog"
    ),
    memory = list(name = "Memory", data_type = "neurocog"),
    executive = list(name = "Attention/Executive", data_type = "neurocog"),
    motor = list(name = "Motor", data_type = "neurocog"),
    social = list(name = "Social Cognition", data_type = "neurocog"),
    adhd = list(name = "ADHD/Executive Function", data_type = "neurobehav"),
    emotion = list(
      name = "Emotional/Behavioral/Social/Personality",
      data_type = "neurobehav"
    ),
    adaptive = list(name = "Adaptive Functioning", data_type = "neurobehav"),
    daily_living = list(name = "Daily Living", data_type = "neurocog"),
    validity = list(name = "Validity", data_type = "validity")
  )

  # Check each domain for data
  for (domain_key in names(domain_configs)) {
    config <- domain_configs[[domain_key]]
    data_type <- config$data_type

    if (!is.null(data_list[[data_type]])) {
      domain_data <- data_list[[data_type]] |>
        dplyr::filter(domain == config$name) |>
        dplyr::filter(!is.na(percentile) | !is.na(score))

      if (nrow(domain_data) > 0) {
        domains_with_data <- c(domains_with_data, domain_key)
      }
    }
  }

  return(domains_with_data)
}

#' @title Convert Domain Names to Keywords
#' @description Converts domain names to LLM keyword format
#' @param domain_names Character vector of domain names
#' @return Character vector of LLM keywords
#' @export
domain_names_to_keywords <- function(domain_names) {
  # Mapping from domain names to LLM keywords
  keyword_mapping <- list(
    iq = "proiq",
    academics = "proacad",
    verbal = "proverb",
    spatial = "provis",
    memory = "promem",
    executive = "proexe",
    motor = "promot",
    social = "prosoc",
    adhd = "proadhd",
    adhd = "proadhd_o",
    adhd = "proadhd_p",
    adhd = "proadhd_t",
    emotion = "proemo",
    emotion = "proemo_p",
    emotion = "proemo_t",
    adaptive = "proadapt",
    daily_living = "prodl",
    validity = "provalid"
  )

  keywords <- character(0)
  for (domain in domain_names) {
    keyword <- keyword_mapping[[domain]]
    if (!is.null(keyword)) {
      keywords <- c(keywords, keyword)
    }
  }

  return(keywords)
}

# --------------------- Utility: View usage stats ---------------------

#' @title View LLM Usage Statistics
#' @description Read and summarize the LLM usage log
#' @param summary_only Whether to return just summary stats (default TRUE)
#' @return Data frame of usage stats or summary list
#' @export
view_llm_usage <- function(summary_only = TRUE) {
  log_file <- llm_usage_log()

  if (!file.exists(log_file)) {
    message("No usage log found yet. Run some LLM generations first.")
    return(NULL)
  }

  log_data <- readr::read_csv(log_file, show_col_types = FALSE)

  if (!summary_only) {
    return(log_data)
  }

  # Calculate summary statistics
  summary <- list(
    total_calls = nrow(log_data),
    successful_calls = sum(log_data$success),
    failed_calls = sum(!log_data$success),
    total_tokens = sum(log_data$total_tokens),
    total_time_minutes = sum(log_data$time_seconds) / 60,
    avg_time_seconds = mean(log_data$time_seconds),
    models_used = unique(log_data$model),
    domains_processed = unique(na.omit(log_data$domain))
  )

  # Print summary
  cat("\n📊 LLM Usage Summary\n")
  cat("===================\n")
  cat(sprintf(
    "Total calls: %d (%d successful, %d failed)\n",
    summary$total_calls,
    summary$successful_calls,
    summary$failed_calls
  ))
  cat(sprintf(
    "Total tokens: %s\n",
    format(summary$total_tokens, big.mark = ",")
  ))
  cat(sprintf("Total time: %.1f minutes\n", summary$total_time_minutes))
  cat(sprintf(
    "Average time per call: %.1f seconds\n",
    summary$avg_time_seconds
  ))
  cat(sprintf("Models used: %s\n", paste(summary$models_used, collapse = ", ")))
  cat(sprintf(
    "Domains processed: %d unique domains\n",
    length(summary$domains_processed)
  ))

  invisible(summary)
}
