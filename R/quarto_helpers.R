# Helper functions for Quarto processing
# Safe readLines function that suppresses incomplete final line warnings
.safe_readLines <- function(
  con,
  n = -1L,
  ok = TRUE,
  warn = FALSE,
  encoding = "unknown",
  skipNul = FALSE
) {
  old_warn <- getOption("warn")
  options(warn = -1)
  on.exit(options(warn = old_warn))

  readLines(
    con = con,
    n = n,
    ok = ok,
    warn = warn,
    encoding = encoding,
    skipNul = skipNul
  )
}

if (exists("QUARTO_PROJECT_DIR", envir = .GlobalEnv)) {
  assign("readLines", .safe_readLines, envir = .GlobalEnv)
}

.neuro2_preferred_quarto_format <- function(render_format = NULL) {
  fmt <- render_format

  if (is.null(fmt) || is.na(fmt) || !nzchar(fmt)) {
    option_fmt <- getOption("neuro2.quarto_output_format")
    if (!is.null(option_fmt) && nzchar(option_fmt)) {
      fmt <- option_fmt
    }
  }

  if (is.null(fmt) || is.na(fmt) || !nzchar(fmt)) {
    env_fmt <- Sys.getenv("NEURO2_QUARTO_FORMAT", unset = "")
    if (nzchar(env_fmt)) {
      fmt <- env_fmt
    }
  }

  if (is.null(fmt) || is.na(fmt) || !nzchar(fmt)) {
    fmt <- "typst"
  }

  fmt
}

.neuro2_render_quarto <- function(
  input,
  profile = NULL,
  render_format = NULL,
  render_all_formats = FALSE,
  quiet = FALSE,
  ...
) {
  render_call <- function(fmt = NULL) {
    args <- list(input = input, quiet = quiet, ...)

    if (!is.null(profile)) {
      args$profile <- profile
    }

    if (!is.null(fmt)) {
      args$output_format <- fmt
    }

    do.call(quarto::quarto_render, args)
  }

  if (isTRUE(render_all_formats)) {
    return(render_call(NULL))
  }

  fmt <- .neuro2_preferred_quarto_format(render_format)

  tryCatch(
    render_call(fmt),
    error = function(err) {
      warning(
        sprintf(
          "Quarto render with format '%s' failed for '%s': %s. Retrying with all configured formats.",
          fmt,
          basename(input),
          err$message
        ),
        call. = FALSE
      )
      render_call(NULL)
    }
  )
}
