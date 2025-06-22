# No Remotes ----
# Attachments ----
to_install <- c("dplyr", "fs", "ggplot2", "ggtext", "ggthemes", "glue", "gt", "gtExtras", "here", "highcharter", "janitor", "kableExtra", "purrr", "quarto", "R6", "readr", "readxl", "stringr", "tibble", "tidyr", "tidyselect")
  for (i in to_install) {
    message(paste("looking for ", i))
    if (!requireNamespace(i, quietly = TRUE)) {
      message(paste("     installing", i))
      install.packages(i)
    }
  }

