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

#' @title Read Master Prompts
#' @description Reads prompts from a JSON file and filters for those with keyword, text, and target qmd.
#' @param json_path Character string path to the JSON file.
#' @return List of filtered prompt objects.
#' @export
read_master_prompts <- function(json_path) {
  stopifnot(file.exists(json_path))
  # Force list-of-lists; stable even if items have different fields
  items <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)

  if (!is.list(items)) {
    stop("Expected a JSON array of objects at: ", json_path)
  }

  # Keep only prompt-like entries with 'keyword' and 'text' fields
  items <- Filter(
    function(x) is.list(x) && !is.null(x$keyword) && !is.null(x$text),
    items
  )

  # Optional: keep only prompts that declare a target @_02-*.qmd line
  has_target <- vapply(
    items,
    function(x) {
      isTRUE(grepl("(?m)^@(_02-[^\\s]+\\.qmd)\\s*$", x$text, perl = TRUE))
    },
    logical(1)
  )
  items[has_target]
}

#' @title Detect Target QMD
#' @description Extracts the target @_02-*.qmd file from the prompt text.
#' @param prompt_text Character string of the prompt text.
#' @return Character string of the target qmd filename or NA.
#' @export
detect_target_qmd <- function(prompt_text) {
  m <- stringr::str_match(prompt_text, "(?m)^\\s*@\\s*(_02-[^\\s]+\\.qmd)\\s*$")
  if (!is.na(m[1, 2])) m[1, 2] else NA_character_
}

#' @title Expand Includes in Text
#' @description Replaces {{@file}} references with file content and collects dependencies.
#' @param text Character string to expand.
#' @param base_dir Base directory for file paths, default ".".
#' @return List with expanded text and dependency paths.
#' @export
expand_includes <- function(text, base_dir = ".") {
  deps <- character(0)
  expanded <- stringr::str_replace_all(
    text,
    "\\{\\{@([^}]+)\\}\\}",
    function(m) {
      fn <- file.path(base_dir, sub("\\{\\{@([^}]+)\\}\\}", "\\1", m))
      if (file.exists(fn)) {
        deps <<- unique(c(deps, fn))
        readr::read_file(fn)
      } else {
        paste0("[[MISSING FILE: ", fn, "]]")
      }
    }
  )
  list(text = expanded, deps = deps)
}

#' @title Sanitize System Prompt
#' @description Removes chain-of-thought directions from system prompt.
#' @param text Character string of the system prompt.
#' @return Sanitized character string.
#' @export
sanitize_system_prompt <- function(text) {
  # Remove sections that instruct the model to reveal "analysis/thinking" blocks
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
#' @description Reads file content if exists, otherwise returns empty string.
#' @param path Character string path to file.
#' @return Character string of file content or "".
#' @export
read_file_or_empty <- function(path) {
  if (file.exists(path)) readr::read_file(path) else ""
}

#' @title Inject Summary Block into QMD
#' @description Injects or replaces the <summary> block in a QMD file.
#' @param qmd_path Path to the QMD file.
#' @param generated Generated summary text.
#' @return Invisible, writes to file.
#' @export
inject_summary_block <- function(qmd_path, generated) {
  raw_qmd <- read_file_or_empty(qmd_path)
  if (!nzchar(raw_qmd)) {
    raw_qmd <- ""
  }

  has_summary <- grepl(
    "<summary>\\s*.*?\\s*</summary>",
    raw_qmd,
    perl = TRUE,
    ignore.case = TRUE
  )
  new_qmd <- if (has_summary) {
    sub(
      pattern = "<summary>\\s*.*?\\s*</summary>",
      replacement = paste0("<summary>\n\n", generated, "\n\n</summary>"),
      x = raw_qmd,
      perl = TRUE
    )
  } else {
    paste0("<summary>\n\n", generated, "\n\n</summary>\n\n", raw_qmd)
  }
  readr::write_file(new_qmd, qmd_path)
}

#' @title Hash Inputs for Caching
#' @description Creates a hash key from system prompt, user text, and dependencies.
#' @param system_prompt Character string.
#' @param user_text Character string.
#' @param deps Character vector of dependency paths.
#' @return Character string hash.
#' @export
hash_inputs <- function(system_prompt, user_text, deps) {
  # cache key changes if prompt, user text, or any dep content changes
  dep_txt <- paste0(
    vapply(deps, read_file_or_empty, ""),
    collapse = "\n<<FILE>>\n"
  )
  digest::digest(
    paste(system_prompt, user_text, dep_txt, sep = "\n---\n"),
    algo = "xxhash64"
  )
}

#' @title Call OpenAI Once
#' @description Makes a single call to OpenAI LLM and returns the response.
#' @param system_prompt System prompt.
#' @param user_text User message.
#' @param model Model name, default "gpt-5-mini-2025-08-07".
#' @param temperature Temperature parameter, default 1.
#' @param echo Echo parameter, default "none".
#' @return Character string response.
#' @export
call_openai_once <- function(
  system_prompt,
  user_text,
  model = "gpt-5-mini-2025-08-07",
  temperature = 1,
  echo = "none"
) {
  bot <- ellmer::chat_openai(
    system_prompt = system_prompt,
    model = model,
    params = ellmer::params(temperature = temperature),
    echo = echo
  )
  # Send the message via Chat object and coerce to plain text
  res <- bot$chat(user_text)
  out <- as.character(res)
  # Robust empty/NA guard: nzchar(NA_character_) is TRUE, so check NA explicitly
  if (length(out) == 0 || all(is.na(out))) {
    stop("LLM returned empty content.")
  }
  out <- paste(out, collapse = " ")
  out <- trimws(out)
  if (!nzchar(out)) {
    stop("LLM returned empty content.")
  }
  # Keep only one paragraph, guard against stray tags
  out <- stringr::str_squish(out)
  out
}

#' @title Generate Domain Summary from Master
#' @description Generates a summary for a domain using master prompts and injects into QMD.
#' @param master_json Path to master JSON.
#' @param domain_keyword Keyword for the domain.
#' @param model LLM model.
#' @param temperature Temperature.
#' @param base_dir Base directory.
#' @param echo Echo.
#' @return Invisible list with keyword, qmd, text.
#' @export
generate_domain_summary_from_master <- function(
  master_json,
  domain_keyword,
  model = Sys.getenv("LLM_MODEL", unset = "gpt-5-mini-2025-08-07"),
  temperature = 1,
  base_dir = ".",
  echo = "none"
) {
  prompts <- read_master_prompts(master_json)

  idx <- which(vapply(
    prompts,
    function(x) identical(x$keyword, domain_keyword),
    logical(1)
  ))
  if (length(idx) == 0) {
    stop(
      "No prompt found in master JSON for keyword: ",
      domain_keyword,
      "\nAvailable keywords: ",
      paste0(vapply(prompts, `[[`, "", "keyword"), collapse = ", ")
    )
  }
  p <- prompts[[idx]]
  ptx <- p$text

  # 1) Detect target qmd from first @line; default to first @file if present
  target_qmd <- detect_target_qmd(ptx)
  if (is.na(target_qmd)) {
    stop("Prompt lacks a target @_02-*.qmd line for keyword: ", domain_keyword)
  }
  target_path <- file.path(base_dir, target_qmd)

  # 2) Build system + user messages
  # System prompt: the instruction block (minus chain-of-thought directives)
  sys_prompt <- sanitize_system_prompt(ptx)

  # User content = resolved includes (e.g., {{@_02-01_iq_text.qmd}}) + the target file content
  inc <- expand_includes(ptx, base_dir = base_dir)
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

  # 3) Cache key
  key <- hash_inputs(sys_prompt, user_text, deps = c(target_path, inc$deps))
  path <- file.path(llm_cache_dir(), paste0(domain_keyword, "_", key, ".txt"))
  if (file.exists(path)) {
    generated <- readr::read_file(path)
  } else {
    generated <- call_openai_once(
      system_prompt = sys_prompt,
      user_text = user_text,
      model = model,
      temperature = temperature,
      echo = echo
    )
    readr::write_file(generated, path)
  }

  # 4) Inject into the domain QMD
  inject_summary_block(target_path, generated)
  invisible(list(keyword = domain_keyword, qmd = target_path, text = generated))
}

#' @title Run LLM for All Domains
#' @description Batch runs LLM generation for multiple domains.
#' @param master_json Path to master JSON.
#' @param domain_keywords Vector of domain keywords.
#' @param model LLM model.
#' @param temperature Temperature.
#' @param base_dir Base directory.
#' @param echo Echo.
#' @return List of results per domain.
#' @export
run_llm_for_all_domains <- function(
  master_json,
  domain_keywords = c(
    "priq",
    "pracad",
    "prverb",
    "prspt",
    "prmem",
    "prexe",
    "prmot",
    "prsoc",
    "pradhdchild",
    "pradhdadult",
    "premotchild",
    "premotadult",
    "pradapt",
    "prdaily",
    "prsirf"
  ),
  model = Sys.getenv("LLM_MODEL", unset = "gpt-5-mini-2025-08-07"),
  temperature = 1,
  base_dir = ".",
  echo = "none"
) {
  out <- lapply(domain_keywords, function(k) {
    try(
      {
        generate_domain_summary_from_master(
          master_json,
          k,
          model,
          temperature,
          base_dir,
          echo
        )
      },
      silent = TRUE
    )
  })
  names(out) <- domain_keywords
  out
}
