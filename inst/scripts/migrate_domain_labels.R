#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

message("\n== Migrating domain labels in parquet files ==\n")

pkg_root <- normalizePath(file.path(here::here(), ".", "."), mustWork = FALSE)
data_dir <- file.path(pkg_root, "data")

neurobehav_path <- file.path(data_dir, "neurobehav.parquet")
validity_path   <- file.path(data_dir, "validity.parquet")

backup_file <- function(path) {
  if (!file.exists(path)) return(invisible(FALSE))
  bdir <- file.path(dirname(path), "backup")
  if (!dir.exists(bdir)) dir.create(bdir, recursive = TRUE)
  bname <- paste0(basename(path), ".bak_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(path, file.path(bdir, bname), overwrite = TRUE)
}

recode_domain <- function(x) {
  dplyr::recode(
    x,
    # ADHD family → ADHD/Executive Function
    "ADHD" = "ADHD/Executive Function",
    "ADHD/EF" = "ADHD/Executive Function",
    "ADHD/Behavior" = "ADHD/Executive Function",
    # Emotion family → Emotional/Behavioral/Social/Personality
    "Behavioral/Emotional/Social" = "Emotional/Behavioral/Social/Personality",
    "Emotional/Behavioral/Personality" = "Emotional/Behavioral/Social/Personality",
    "Psychiatric Disorders" = "Emotional/Behavioral/Social/Personality",
    "Personality Disorders" = "Emotional/Behavioral/Social/Personality",
    "Psychosocial Problems" = "Emotional/Behavioral/Social/Personality",
    "Substance Use" = "Emotional/Behavioral/Social/Personality",
    "Substance Use Disorders" = "Emotional/Behavioral/Social/Personality",
    # Validity consolidation
    "Performance Validity" = "Validity",
    "Symptom Validity" = "Validity",
    "Effort/Validity" = "Validity",
    .default = x
  )
}

migrate_file <- function(path, filter_domains = NULL) {
  if (!file.exists(path)) {
    message("  - Skipping missing file: ", path)
    return(invisible(FALSE))
  }

  message("  - Backing up: ", path)
  backup_file(path)

  message("  - Loading: ", path)
  df <- read_parquet(path)
  if (!"domain" %in% names(df)) {
    message("    • No 'domain' column; skipping ", basename(path))
    return(invisible(FALSE))
  }

  before_tab <- sort(table(df$domain), decreasing = TRUE)

  if (!is.null(filter_domains)) {
    # Only recode rows whose domain is in the provided set
    idx <- df$domain %in% filter_domains
    df$domain[idx] <- recode_domain(df$domain[idx])
  } else {
    df$domain <- recode_domain(df$domain)
  }

  after_tab <- sort(table(df$domain), decreasing = TRUE)

  message("    • Domain distribution (before → after):")
  print(utils::head(before_tab, 10))
  print(utils::head(after_tab, 10))

  message("  - Writing updated parquet: ", path)
  write_parquet(df, path)
  TRUE
}

ok1 <- migrate_file(neurobehav_path)
ok2 <- migrate_file(validity_path, filter_domains = c(
  "Performance Validity", "Symptom Validity", "Effort/Validity", "Validity"
))

if (isTRUE(ok1) || isTRUE(ok2)) {
  message("\nMigration complete. Updated files:")
  if (isTRUE(ok1)) message("  • ", neurobehav_path)
  if (isTRUE(ok2)) message("  • ", validity_path)
} else {
  message("\nNo files updated (nothing to migrate or files missing).")
}

