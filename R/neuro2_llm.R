# neuro2_llm.R — consolidated LLM implementation for neuro2
# Public API:
#   - neuro2_llm_smoke_test()
#   - generate_domain_summary_from_master()
#   - run_llm_for_all_domains()
#   - neuro2_run_llm_then_render()

# -------------------------- utilities --------------------------

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


# Canonicalize keys so "pr.sirf" == "prsirf"
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

# ---------------------- prompt loader (QMD only) ----------------

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

# ------------------- prompt text processors --------------------

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
#' @description Injects or replaces the `<summary>` block in a QMD file.
#' @param qmd_path Path to the QMD file.
#' @param generated Generated summary text.
#' @return Invisible `TRUE`.
#' @export
inject_summary_block <- function(qmd_path, generated) {
  raw_qmd <- read_file_or_empty(qmd_path)
  if (!nzchar(raw_qmd)) {
    raw_qmd <- ""
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
      replacement = paste0("<summary>\n\n", generated, "\n\n</summary>"),
      x = raw_qmd,
      perl = TRUE
    )
  } else if (
    grepl("<summary\\s*/>", raw_qmd, perl = TRUE, ignore.case = TRUE)
  ) {
    new_qmd <- sub(
      pattern = "<summary\\s*/>",
      replacement = paste0("<summary>\n\n", generated, "\n\n</summary>"),
      x = raw_qmd,
      perl = TRUE
    )
  } else {
    new_qmd <- paste0("<summary>\n\n", generated, "\n\n</summary>\n\n", raw_qmd)
  }
  readr::write_file(new_qmd, qmd_path)
  invisible(TRUE)
}

#' @title Strip <think> blocks
#' @description Remove any <think>…</think> traces from LLM output.
#' @param text Character string
#' @return Cleaned character string
strip_think_blocks <- function(text) {
  stringr::str_replace_all(text, "(?is)<think>.*?</think>", "") |> trimws()
}

#' @title Hash Inputs for Caching
#' @description Creates a hash key from system prompt, user text, and dependencies' contents.
#' @param system_prompt Character string.
#' @param user_text Character string.
#' @param deps Character vector of dependency paths.
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

# --------------------- model selection (backend) -----------------

#' @title Create a chat bot for neuro2 (Ollama by default; OpenAI optional)
#' @description Selects an LLM backend and model by section: `"domain"` (8B), `"sirf"` (14B instruct), `"mega"` (30B instruct).
#' @param system_prompt System prompt string.
#' @param section One of `"domain"`, `"sirf"`, `"mega"`.
#' @param model_override Optional exact model name to force.
#' @param backend `"ollama"` (default) or `"openai"`.
#' @param temperature Numeric temperature (default `0.2`).
#' @param echo ellmer echo mode (default `"none"`).
#' @return ellmer chat object.
#' @export
neuro2_llm_bot <- function(
  system_prompt,
  section = c("domain", "sirf", "mega"),
  model_override = NULL,
  backend = c("ollama", "openai"),
  temperature = 0.2,
  echo = "none"
) {
  section <- match.arg(section)
  backend <- match.arg(backend)
  model <- model_override %||%
    switch(
      section,
      domain = "qwen3:8b-q4_K_M",
      sirf = "qwen2.5:14b-instruct",
      mega = "qwen3:30b-a3b-instruct-2507-q4_K_M"
    )

  if (backend == "ollama") {
    ellmer::chat_ollama(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = temperature),
      api_args = list(stream = FALSE), # non-streaming
      echo = echo
    )
  } else {
    ellmer::chat_openai(
      system_prompt = system_prompt,
      model = model,
      params = ellmer::params(temperature = temperature),
      api_args = list(stream = FALSE),
      echo = echo
    )
  }
}

# ---------------------- LLM call wrapper -----------------------

# Generic extractor (no ellmer::as_text dependency)
.extract_text_generic <- function(obj) {
  if (identical(Sys.getenv("NEURO2_LLM_DEBUG"), "1")) {
    tf <- file.path(
      tempdir(),
      sprintf("neuro2_llm_debug_%s.txt", format(Sys.time(), "%Y%m%d_%H%M%S"))
    )
    writeLines(c(capture.output(str(obj, max.level = 3)), ""), tf)
  }
  if (is.list(obj)) {
    ch <- obj$choices
    if (is.list(ch) && length(ch) > 0) {
      parts <- vapply(
        ch,
        function(c1) {
          if (!is.null(c1$message$content)) {
            return(paste(c1$message$content, collapse = " "))
          }
          if (!is.null(c1$text)) {
            return(paste(c1$text, collapse = " "))
          }
          if (!is.null(c1$delta$content)) {
            return(paste(c1$delta$content, collapse = " "))
          }
          ""
        },
        character(1)
      )
      cand <- trimws(stringr::str_squish(paste(parts, collapse = " ")))
      if (nzchar(cand)) {
        return(cand)
      }
    }
    if (!is.null(obj$content) && is.character(obj$content)) {
      cand <- trimws(stringr::str_squish(paste(obj$content, collapse = " ")))
      if (nzchar(cand)) {
        return(cand)
      }
    }
    if (!is.null(obj$output) && is.character(obj$output)) {
      cand <- trimws(stringr::str_squish(paste(obj$output, collapse = " ")))
      if (nzchar(cand)) {
        return(cand)
      }
    }
    flat <- try(unlist(obj, use.names = FALSE), silent = TRUE)
    if (!inherits(flat, "try-error") && is.character(flat) && length(flat)) {
      cand <- trimws(stringr::str_squish(paste(flat, collapse = " ")))
      if (nzchar(cand)) {
        return(cand)
      }
    }
  }
  if (is.character(obj) && length(obj)) {
    cand <- trimws(stringr::str_squish(paste(obj, collapse = " ")))
    if (nzchar(cand)) {
      return(cand)
    }
  }
  trimws(stringr::str_squish(paste(capture.output(print(obj)), collapse = " ")))
}

#' @title Call LLM Once with retries
#' @description Calls the selected model and returns text; retries on transient errors.
#' @param system_prompt System prompt string.
#' @param user_text User content string.
#' @param section `"domain"`, `"sirf"`, or `"mega"`.
#' @param model_override Optional exact model name (bypasses routing).
#' @param backend `"ollama"` or `"openai"`.
#' @param temperature Numeric temperature.
#' @param echo Echo mode for streaming.
#' @param retries Number of retries (default 3).
#' @param backoff Initial backoff seconds (default 1; doubles each retry).
#' @return Character text output.
#' @export
call_llm_once <- function(
  system_prompt,
  user_text,
  section = "domain",
  model_override = NULL,
  backend = "ollama",
  temperature = 0.2,
  echo = "none",
  retries = 3,
  backoff = 1
) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("The 'ellmer' package is required.")
  }

  attempt <- 0
  repeat {
    attempt <- attempt + 1
    bot <- neuro2_llm_bot(
      system_prompt = system_prompt,
      section = section,
      model_override = model_override,
      backend = backend,
      temperature = temperature,
      echo = echo
    )
    res <- tryCatch(bot$chat(user_text), error = identity)
    if (inherits(res, "error")) {
      if (attempt <= retries) {
        Sys.sleep(backoff)
        backoff <- backoff * 2
        next
      }
      stop("LLM call failed after retries: ", conditionMessage(res))
    }
    out <- .extract_text_generic(res)
    if (!nzchar(out)) {
      if (attempt <= retries) {
        Sys.sleep(backoff)
        backoff <- backoff * 2
        next
      }
      stop("LLM returned empty content after retries.")
    }
    return(out)
  }
}

# --------------------- main entry points -----------------------

#' @title Generate Domain Summary from QMD Prompts
#' @description Generates a summary for a domain using QMD prompts and injects `<summary>` into the target QMD.
#' @param prompts_dir Directory of QMD prompts. Defaults to installed `inst/prompts/`.
#' @param domain_keyword Keyword for the domain (e.g., `"priq"`, `"prsirf"`).
#' @param model_override Optional exact model name; otherwise chosen by keyword (SIRF → 14B/30B; others → 8B).
#' @param backend `"ollama"` (default) or `"openai"`.
#' @param temperature Temperature (default `0.2`).
#' @param base_dir Base directory where `*_text.qmd` files live (default `"."`).
#' @param echo Echo mode for ellmer (default `"none"`).
#' @param mega logical; if `TRUE` and keyword is SIRF, use the `"mega"` model section.
#' @return Invisible list with `keyword`, `qmd`, `text`, `section`.
#' @export
generate_domain_summary_from_master <- function(
  prompts_dir = NULL,
  domain_keyword,
  model_override = NULL,
  backend = "ollama",
  temperature = 0.2,
  base_dir = ".",
  echo = "none",
  mega = FALSE
) {
  prompts <- read_prompts_from_dir(
    prompts_dir %||% system.file("prompts", package = "neuro2")
  )

  idx <- which(vapply(
    prompts,
    function(x) .canon(x$keyword) == .canon(domain_keyword),
    logical(1)
  ))
  if (length(idx) == 0) {
    stop(
      "No prompt found for keyword: ",
      domain_keyword,
      "\nAvailable: ",
      paste0(vapply(prompts, function(x) x$keyword, ""), collapse = ", ")
    )
  }
  p <- prompts[[idx]]
  ptx <- p$text

  target_qmd <- detect_target_qmd(ptx)
  if (is.na(target_qmd)) {
    stop("Prompt lacks a target @_NN-*.qmd line for keyword: ", domain_keyword)
  }
  target_path <- file.path(base_dir, target_qmd)
  if (!file.exists(target_path)) {
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
    file.create(target_path)
  }

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

  key_can <- .canon(domain_keyword)
  section <- if (identical(key_can, "prsirf")) {
    if (isTRUE(mega)) "mega" else "sirf"
  } else {
    "domain"
  }

  key <- hash_inputs(sys_prompt, user_text, deps = c(target_path, inc$deps))
  cache_file <- file.path(
    llm_cache_dir(),
    paste0(.canon(domain_keyword), "_", key, ".txt")
  )

  if (file.exists(cache_file)) {
    generated <- readr::read_file(cache_file)
  } else {
    # FIX: Pass the correct parameters to call_llm_once
    generated <- call_llm_once(
      system_prompt = sys_prompt,
      user_text = user_text,
      section = section, # <- Pass the section we calculated
      model_override = model_override, # <- Use model_override, not model
      backend = backend, # <- Add backend parameter
      temperature = temperature,
      echo = echo
    )
    # remove any reasoning traces BEFORE caching
    generated <- strip_think_blocks(generated)
    # robust, atomic write to avoid "invalid connection"
    safe_write_text(generated, cache_file)
  }
  generated <- strip_think_blocks(generated)

  inject_summary_block(target_path, generated)
  invisible(list(
    keyword = domain_keyword,
    qmd = target_path,
    text = generated,
    section = section
  ))
}

#' @title Run LLM for All Domains (QMD-only)
#' @description Batch runs LLM generation for multiple domains using QMD prompts.
#' @param prompts_dir Optional prompts directory. Defaults to installed `inst/prompts/`.
#' @param domain_keywords Vector of domain keywords.
#' @param model_override Optional exact model name to force for all.
#' @param backend `"ollama"` or `"openai"`.
#' @param temperature Temperature.
#' @param base_dir Base directory for `*_text.qmd`.
#' @param echo Echo.
#' @param mega_for_sirf logical; if TRUE, SIRF uses the `"mega"` model.
#' @return List of results per domain (invisible).
#' @export
run_llm_for_all_domains <- function(
  prompts_dir = NULL,
  domain_keywords = c(
    "prnse",
    "prcog",
    "pracad",
    "prverb",
    "prvis",
    "prmem",
    "prexe",
    "prmot",
    "prsoc",
    "pradhd_c",
    "pradhd_a",
    "premo_c",
    "premo_a",
    "pradapt",
    "prdl",
    "prsirf",
    "prrec"
  ),
  model_override = NULL,
  backend = "ollama",
  temperature = 0.2,
  base_dir = ".",
  echo = "none",
  mega_for_sirf = FALSE
) {
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
          mega = if (.canon(k) == "prsirf") isTRUE(mega_for_sirf) else FALSE
        )
      },
      silent = TRUE
    )
  })
  names(out) <- domain_keywords
  invisible(out)
}

# --------------------- diagnostics / smoke test ---------------------

#' @title neuro2 LLM smoke test
#' @description Pings the configured model (Ollama by default) and returns a short response plus timing.
#' @param model Model name (Ollama by default, e.g., "qwen3:8b-q4_K_M").
#' @param backend "ollama" or "openai".
#' @param prompt User prompt string.
#' @param system_prompt System prompt string.
#' @return A list with fields `seconds`, `preview`, and `raw`.
#' @export
neuro2_llm_smoke_test <- function(
  model = "qwen3:8b-q4_K_M",
  backend = "ollama",
  prompt = "Reply with the single word: OK",
  system_prompt = "Be terse."
) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("The 'ellmer' package is required.")
  }
  if (match.arg(backend, c("ollama", "openai")) == "ollama") {
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
  list(seconds = dt, preview = substr(out, 1, 240), raw = out)
}

# --------------------- glue: run + render ---------------------

#' @title Run LLM then render Quarto
#' @description Executes the LLM stage first, then renders one or more Quarto documents.
#' @param base_dir Base directory where `*_text.qmd` live.
#' @param prompts_dir Prompts directory (default installed).
#' @param render_paths Character vector of paths to `.qmd` files to render after LLM runs.
#' @param quarto_profile Optional Quarto profile (e.g., "prod").
#' @param domain_keywords Vector of keywords to generate; default is a standard set including "prsirf".
#' @param backend `"ollama"` (default) or `"openai"`.
#' @param mega_for_sirf Use the mega model for SIRF.
#' @param temperature LLM temperature.
#' @param echo ellmer echo mode.
#' @return Invisibly returns a list with `llm` results and `rendered` output paths.
#' @export
neuro2_run_llm_then_render <- function(
  base_dir = ".",
  prompts_dir = NULL,
  render_paths = character(0),
  quarto_profile = NULL,
  domain_keywords = c(
    "prnse",
    "prcog",
    "pracad",
    "prverb",
    "prvis",
    "prmem",
    "prexe",
    "prmot",
    "prsoc",
    "pradhd_c",
    "pradhd_a",
    "premo_c",
    "premo_a",
    "pradapt",
    "prdl",
    "prsirf",
    "prrec"
  ),
  backend = "ollama",
  mega_for_sirf = FALSE,
  temperature = 0.2,
  echo = "none"
) {
  llm_res <- run_llm_for_all_domains(
    prompts_dir = prompts_dir,
    domain_keywords = domain_keywords,
    backend = backend,
    temperature = temperature,
    base_dir = base_dir,
    echo = echo,
    mega_for_sirf = mega_for_sirf
  )

  rendered <- character(0)
  if (length(render_paths)) {
    if (!requireNamespace("quarto", quietly = TRUE)) {
      stop("The 'quarto' package is required to render.")
    }
    for (rp in render_paths) {
      if (!file.exists(rp)) {
        next
      }
      if (is.null(quarto_profile)) {
        quarto::quarto_render(rp)
      } else {
        withr::with_envvar(c(QUARTO_PROFILE = quarto_profile), {
          quarto::quarto_render(rp)
        })
      }
      rendered <- c(rendered, rp)
    }
  }

  invisible(list(llm = llm_res, rendered = rendered))
}
