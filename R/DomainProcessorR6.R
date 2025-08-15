#' DomainProcessorR6 - Following Memory Template Exactly
#'
#' A working implementation that generates QMD files following the exact
#' structure of the memory template file.
#'
#' @field domains Character vector of domain names to process.
#' @field pheno Target phenotype identifier string.
#' @field input_file Path to the input data file.
#' @field output_dir Directory where output files will be saved.
#' @field number Domain number for file naming.
#' @field data The loaded and processed data.
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter select arrange desc distinct all_of
#' @importFrom readr read_csv write_excel_csv
#' @importFrom here here
#' @export
DomainProcessorR6 <- R6::R6Class(
  classname = "DomainProcessorR6",
  public = list(
    domains = NULL,
    pheno = NULL,
    input_file = NULL,
    output_dir = "data",
    number = NULL,
    data = NULL,

    #' @description
    #' Initialize a new DomainProcessorR6 object
    #' @description Create a new instance.
    #' @param domains Character scalar or vector of domain names.
    #' @param pheno A data.frame or tibble.
    #' @param input_file Path to a file.
    #' @param output_dir Path to an output directory.
    #' @param number Numeric index or identifier.
    #' @return A new \code{DomainProcessorR6} object.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$initialize(domains=..., pheno=..., input_file=..., output_dir=..., number=...)
    #' }
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      number = NULL,
      output_base = "."
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir

      if (!is.null(number)) {
        self$number <- sprintf("%02d", as.numeric(number))
      } else {
        self$number <- private$get_domain_number()
      }
      # Ensure output directories exist
      self$dirs <- list(
        figs = file.path(output_base, "figs"),
        output = file.path(output_base, "output"),
        tmp = file.path(output_base, "tmp")
      )

      lapply(self$dirs, function(d) {
        if (!dir.exists(d)) dir.create(d, recursive = TRUE)
      })
    },

    # Update your save functions
    save_plot = function(plot, filename) {
      png_file <- file.path(self$dirs$figs, paste0(filename, ".png"))
      pdf_file <- file.path(self$dirs$figs, paste0(filename, ".pdf"))

      ggplot2::ggsave(png_file, plot, width = 8, height = 6, dpi = 300)
      ggplot2::ggsave(pdf_file, plot, width = 8, height = 6)

      return(list(png = png_file, pdf = pdf_file))
    },

    #' @description
    #' Load data from the specified input file
    #' @description Load and normalize input data into the processor.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$load_data()
    #' }
    load_data = function() {
      if (!is.null(self$data)) {
        message("Data already loaded, skipping file read.")
        return(invisible(self))
      }

      if (is.null(self$input_file)) {
        stop("No input file specified and no data pre-loaded.")
      }

      file_ext <- tools::file_ext(self$input_file)

      if (file_ext == "parquet") {
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop("The 'arrow' package is required to read Parquet files.")
        }
        self$data <- arrow::read_parquet(self$input_file)
      } else if (file_ext == "feather") {
        if (!requireNamespace("arrow", quietly = TRUE)) {
          stop("The 'arrow' package is required to read Feather files.")
        }
        self$data <- arrow::read_feather(self$input_file)
      } else {
        self$data <- readr::read_csv(self$input_file, show_col_types = FALSE)
      }

      invisible(self)
    },

    #' @description
    #' Filter data to include only the specified domains
    #' @description Filter the internal data to a specific domain or set of domains.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$filter_by_domain()
    #' }
    filter_by_domain = function() {
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data
    #' @description Select and rename columns needed for downstream processing.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$select_columns()
    #' }
    select_columns = function() {
      desired_columns <- c(
        "test",
        "test_name",
        "scale",
        "raw_score",
        "score",
        "ci_95",
        "percentile",
        "range",
        "domain",
        "subdomain",
        "narrow",
        "pass",
        "verbal",
        "timed",
        "result",
        "z",
        "z_mean_domain",
        "z_sd_domain",
        "z_mean_subdomain",
        "z_sd_subdomain",
        "z_mean_narrow",
        "z_sd_narrow",
        "z_mean_pass",
        "z_sd_pass",
        "z_mean_verbal",
        "z_sd_verbal",
        "z_mean_timed",
        "z_sd_timed"
      )

      existing_columns <- intersect(desired_columns, names(self$data))

      # Only warn about missing z-score columns if verbose mode
      missing_columns <- setdiff(desired_columns, existing_columns)
      missing_z_columns <- grep("^z", missing_columns, value = TRUE)
      missing_other_columns <- setdiff(missing_columns, missing_z_columns)

      if (length(missing_other_columns) > 0) {
        message(
          "Note: The following columns were not found in the data: ",
          paste(missing_other_columns, collapse = ", ")
        )
      }

      # Calculate basic z-score if missing but percentile exists
      if ("percentile" %in% names(self$data) && !"z" %in% names(self$data)) {
        self$data$z <- qnorm(self$data$percentile / 100)
        self$data$z <- round(self$data$z, 2)
        existing_columns <- c(existing_columns, "z")
      }

      self$data <- self$data |> dplyr::select(all_of(existing_columns))
      invisible(self)
    },

    #' @description
    #' Save the processed data to a file
    #' @description Persist the current data to disk in the requested format.
    #' @param filename Path to a file.
    #' @param format File format (e.g., 'csv', 'rds', 'qmd').
    #' @return Invisibly returns the output file path on success.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$save_data(filename=..., format=...)
    #' }
    save_data = function(filename = NULL, format = "parquet") {
      if (is.null(filename)) {
        filename <- paste0(self$pheno, ".", format)
      }

      output_path <- here::here(self$output_dir, filename)

      if (format == "parquet" && requireNamespace("arrow", quietly = TRUE)) {
        arrow::write_parquet(self$data, output_path)
      } else {
        readr::write_excel_csv(
          self$data,
          gsub("\\.parquet$", ".csv", output_path),
          na = "",
          col_names = TRUE,
          append = FALSE
        )
      }

      invisible(self)
    },

    #' @description
    #' Check if domain has multiple raters
    #' @description Check whether multiple raters are present for a given measure or dataset.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$has_multiple_raters()
    #' }
    has_multiple_raters = function() {
      tolower(self$pheno) %in% c("emotion", "adhd")
    },

    #' @description
    #' Detect emotion type (child/adult)
    #' @description Infer whether the dataset represents child or adult emotion measures.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$detect_emotion_type()
    #' }
    detect_emotion_type = function() {
      if (tolower(self$pheno) != "emotion") {
        return(NULL)
      }

      child_patterns <- c(
        "Behavioral/Emotional/Social",
        "Personality Disorders",
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      )

      adult_patterns <- c("Emotional/Behavioral/Personality")

      if (
        any(sapply(child_patterns, function(p) {
          any(grepl(p, self$domains, ignore.case = TRUE))
        }))
      ) {
        return("child")
      } else if (
        any(sapply(adult_patterns, function(p) {
          any(grepl(p, self$domains, ignore.case = TRUE))
        }))
      ) {
        return("adult")
      }

      return("child")
    },

    #' @description
    #' Generate domain QMD file following the memory template exactly
    #' @description Generate a Quarto (.qmd) file for the given domain.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_domain_qmd(domain_name=..., output_file=...)
    #' }
    generate_domain_qmd = function(domain_name = NULL, output_file = NULL) {
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      if (is.null(output_file)) {
        output_file <- paste0(
          "_02-",
          self$number,
          "_",
          tolower(self$pheno),
          ".qmd"
        )
      }

      # Handle special cases for multi-rater domains
      if (self$has_multiple_raters()) {
        if (tolower(self$pheno) == "emotion") {
          emotion_type <- self$detect_emotion_type()
          if (emotion_type == "child") {
            return(self$generate_emotion_child_qmd(domain_name, output_file))
          } else {
            return(self$generate_emotion_adult_qmd(domain_name, output_file))
          }
        } else if (tolower(self$pheno) == "adhd") {
          is_child <- any(grepl("child", tolower(self$domains))) ||
            (!is.null(self$data) &&
              any(grepl(
                "child|adolescent",
                self$data$test_name,
                ignore.case = TRUE
              )))

          if (is_child) {
            return(self$generate_adhd_child_qmd(domain_name, output_file))
          } else {
            return(self$generate_adhd_adult_qmd(domain_name, output_file))
          }
        }
      }

      # Generate standard domain QMD following memory template exactly
      return(self$generate_standard_qmd(domain_name, output_file))
    },

    #' @description
    #' Generate standard domain QMD following the memory template structure exactly
    #' @description Generate a standard Quarto (.qmd) file for general domains.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_standard_qmd(domain_name=..., output_file=...)
    #' }
    generate_standard_qmd = function(domain_name, output_file) {
      # First generate the text file that will be included
      text_file <- paste0(
        "_02-",
        self$number,
        "_",
        tolower(self$pheno),
        "_text.qmd"
      )

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Build QMD content following the exact memory template structure
      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-",
        tolower(self$pheno),
        ">\n",
        "```\n\n",

        "{{< include ",
        text_file,
        " >}}\n\n",

        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",

        "# Source R6 classes\n",
        "source(\"R/DomainProcessorR6.R\")\n",
        "source(\"R/NeuropsychResultsR6.R\")\n",
        "source(\"R/DotplotR6.R\")\n",
        "source(\"R/TableGTR6.R\")\n",
        "source(\"R/score_type_utils.R\")\n\n",

        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",

        "# Target phenotype\n",
        "pheno <- \"",
        tolower(self$pheno),
        "\"\n\n",

        "# Create R6 processor\n",
        "processor_",
        tolower(self$pheno),
        " <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "# Load and process data\n",
        "processor_",
        tolower(self$pheno),
        "$load_data()\n",
        "processor_",
        tolower(self$pheno),
        "$filter_by_domain()\n\n",

        "# Create the data object with original name for compatibility\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",

        "# Process and export data using R6\n",
        "processor_",
        tolower(self$pheno),
        "$select_columns()\n",
        "processor_",
        tolower(self$pheno),
        "$save_data()\n\n",

        "# Update the original object\n",
        tolower(self$pheno),
        " <- processor_",
        tolower(self$pheno),
        "$data\n\n",

        "# Load internal data to get standardized scale names\n",
        "scale_var_name <- paste0(\"scales_\", tolower(pheno))\n",
        "if (!exists(scale_var_name)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path, envir = .GlobalEnv)\n",
        "  }\n",
        "}\n",
        "if (exists(scale_var_name)) {\n",
        "  scales <- get(scale_var_name)\n",
        "} else {\n",
        "  warning(paste0(\n",
        "    \"Scale variable '\",\n",
        "    scale_var_name,\n",
        "    \"' not found. Using empty vector.\"\n",
        "  ))\n",
        "  scales <- character(0)\n",
        "}\n\n",

        "# Filter the data directly without using NeurotypR\n",
        "filter_data <- function(data, domain, scale) {\n",
        "  # Filter by domain if provided\n",
        "  if (!is.null(domain)) {\n",
        "    data <- data[data$domain %in% domain, ]\n",
        "  }\n\n",
        "  # Filter by scale if provided\n",
        "  if (!is.null(scale)) {\n",
        "    data <- data[data$scale %in% scale, ]\n",
        "  }\n\n",
        "  return(data)\n",
        "}\n\n",

        "# Apply the filter function\n",
        "data_",
        tolower(self$pheno),
        " <- filter_data(data = ",
        tolower(self$pheno),
        ", domain = domains, scale = scales)\n",
        "```\n\n",

        "```{r}\n",
        "#| label: text-",
        tolower(self$pheno),
        "\n",
        "#| cache: true\n",
        "#| include: true\n",
        "#| echo: false\n",
        "#| results: asis\n\n",

        "# Generate text using R6 class\n",
        "results_processor <- NeuropsychResultsR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  file = \"",
        text_file,
        "\"\n",
        ")\n",
        "results_processor$process()\n",
        "```\n\n",

        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_",
        tolower(self$pheno),
        "\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_",
        tolower(self$pheno),
        ")\n\n",

        "# Create a list of test names grouped by score type\n",
        "score_types_list <- list()\n\n",

        "# Process the score type map to group tests by score type\n",
        "for (test_name in names(score_type_map)) {\n",
        "  types <- score_type_map[[test_name]]\n",
        "  for (type in types) {\n",
        "    if (!type %in% names(score_types_list)) {\n",
        "      score_types_list[[type]] <- character(0)\n",
        "    }\n",
        "    score_types_list[[type]] <- unique(c(score_types_list[[type]], test_name))\n",
        "  }\n",
        "}\n\n",

        "# Get unique score types present\n",
        "unique_score_types <- names(score_types_list)\n\n",

        "# Define the score type footnotes\n",
        "fn_list <- list()\n",
        "if (\"t_score\" %in% unique_score_types) {\n",
        "  fn_list$t_score <- \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\"\n",
        "}\n",
        "if (\"scaled_score\" %in% unique_score_types) {\n",
        "  fn_list$scaled_score <- \"Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]\"\n",
        "}\n",
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "}\n\n",

        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",

        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",

        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  # Determine default based on pheno\n",
        "  source_note <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_",
        tolower(self$pheno),
        ",\n",
        "  pheno = pheno,\n",
        "  table_name = table_name,\n",
        "  vertical_padding = vertical_padding,\n",
        "  source_note = source_note,\n",
        "  multiline = multiline,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  dynamic_grp = dynamic_grp\n",
        ")\n\n",

        "# Get the table object without automatic saving\n",
        "tbl <- table_gt$build_table()\n\n",

        "# Save the table using our save_table method\n",
        "table_gt$save_table(tbl, dir = here::here())\n",
        "```\n\n",

        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\"z_mean_subdomain\" %in% names(data_",
        tolower(self$pheno),
        ") && \"subdomain\" %in% names(data_",
        tolower(self$pheno),
        ")) {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_",
        tolower(self$pheno),
        ",\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- \"",
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "-narrow\n",
        "#| include: false\n\n",

        "# Create narrow plot using R6 DotplotR6\n",
        "if (\"z_mean_narrow\" %in% names(data_",
        tolower(self$pheno),
        ") && \"narrow\" %in% names(data_",
        tolower(self$pheno),
        ")) {\n",
        "  dotplot_narrow <- DotplotR6$new(\n",
        "    data = data_",
        tolower(self$pheno),
        ",\n",
        "    x = \"z_mean_narrow\",\n",
        "    y = \"narrow\",\n",
        "    filename = here::here(\"fig_",
        tolower(self$pheno),
        "_narrow.svg\")\n",
        "  )\n",
        "  dotplot_narrow$create_plot()\n",
        "} else {\n",
        "  warning(\"Narrow plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_",
        tolower(self$pheno),
        "\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- \"",
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define a function to create a domain with a title, a table, and a figure\n",
        "#let domain(title: none, file_qtbl, file_fig) = {\n",
        "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
        "  set text(..font)\n\n",
        "  // Make all figure labels (Table X:, Figure X:) bold\n",
        "  show figure.caption: it => {\n",
        "    context {\n",
        "      let supplement = it.supplement\n",
        "      let counter = it.counter.display(it.numbering)\n",
        "      block[*#supplement #counter:* #it.body]\n",
        "    }\n",
        "  }\n\n",
        "  pad(top: 0.5em)[]\n",
        "  grid(\n",
        "    columns: (50%, 50%),\n",
        "    gutter: 8pt,\n",
        "    figure(\n",
        "      [#image(file_qtbl)],\n",
        "      caption: figure.caption(position: top, [#title]),\n",
        "      kind: \"qtbl\",\n",
        "      supplement: [*Table*],\n",
        "    ),\n",
        "    figure(\n",
        "      [#image(file_fig, width: auto)],\n",
        "      caption: figure.caption(\n",
        "        position: bottom,\n",
        "        [`{r} plot_title_",
        tolower(self$pheno),
        "`],\n",
        "      ),\n",
        "      placement: none,\n",
        "      kind: \"image\",\n",
        "      supplement: [*Figure*],\n",
        "      gap: 0.5em,\n",
        "    ),\n",
        "  )\n",
        "}\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_",
        tolower(self$pheno),
        ".png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_subdomain.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_",
        tolower(self$pheno),
        ".png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_narrow.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n"
      )

      # Write the QMD file
      writeLines(qmd_content, output_file)
      message(paste(
        "Generated standard QMD file following memory template:",
        output_file
      ))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult QMD file
    #' @description Generate a Quarto (.qmd) file tailored for adult ADHD measures.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_adhd_adult_qmd(domain_name=..., output_file=...)
    #' }
    generate_adhd_adult_qmd = function(domain_name, output_file) {
      # Create text files for different raters
      self_text <- paste0("_02-", self$number, "_adhd_adult_text_self.qmd")
      observer_text <- paste0(
        "_02-",
        self$number,
        "_adhd_adult_text_observer.qmd"
      )

      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-adhd-adult>\n",
        "```\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ",
        self_text,
        " >}}\n\n",
        "### OBSERVER RATINGS\n\n",
        "{{< include ",
        observer_text,
        " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated ADHD adult QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD child QMD file
    #' @description Generate a Quarto (.qmd) file tailored for child ADHD measures.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_adhd_child_qmd(domain_name=..., output_file=...)
    #' }
    generate_adhd_child_qmd = function(domain_name, output_file) {
      # Create text files for different raters
      self_text <- paste0("_02-", self$number, "_adhd_child_text_self.qmd")
      parent_text <- paste0("_02-", self$number, "_adhd_child_text_parent.qmd")
      teacher_text <- paste0(
        "_02-",
        self$number,
        "_adhd_child_text_teacher.qmd"
      )

      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-adhd-child>\n",
        "```\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ",
        self_text,
        " >}}\n\n",
        "### PARENT RATINGS\n\n",
        "{{< include ",
        parent_text,
        " >}}\n\n",
        "### TEACHER RATINGS\n\n",
        "{{< include ",
        teacher_text,
        " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated ADHD child QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion child QMD file
    #' @description Generate a Quarto (.qmd) file tailored for child emotion/affect measures.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_emotion_child_qmd(domain_name=..., output_file=...)
    #' }
    generate_emotion_child_qmd = function(domain_name, output_file) {
      # Create text files for different raters
      self_text <- paste0("_02-", self$number, "_emotion_child_text_self.qmd")
      parent_text <- paste0(
        "_02-",
        self$number,
        "_emotion_child_text_parent.qmd"
      )
      teacher_text <- paste0(
        "_02-",
        self$number,
        "_emotion_child_text_teacher.qmd"
      )

      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-emotion-child>\n",
        "```\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ",
        self_text,
        " >}}\n\n",
        "### PARENT RATINGS\n\n",
        "{{< include ",
        parent_text,
        " >}}\n\n",
        "### TEACHER RATINGS\n\n",
        "{{< include ",
        teacher_text,
        " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated emotion child QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion adult QMD file
    #' @description Generate a Quarto (.qmd) file tailored for adult emotion/affect measures.
    #' @param domain_name Character scalar or vector of domain names.
    #' @param output_file Path to a file.
    #' @return Invisibly returns the path to the generated file.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$generate_emotion_adult_qmd(domain_name=..., output_file=...)
    #' }
    generate_emotion_adult_qmd = function(domain_name, output_file) {
      # Create text file
      text_file <- paste0("_02-", self$number, "_emotion_adult_text.qmd")

      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-emotion-adult>\n",
        "```\n\n",
        "{{< include ",
        text_file,
        " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated emotion adult QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Run the complete processing pipeline
    #' @description Run the full processing pipeline and (optionally) generate domain files.
    #' @param generate_domain_files Character scalar or vector of domain names.
    #' @return Invisibly returns \code{self} for method chaining.
    #' @examples
    #' \dontrun{
    #'   obj <- DomainProcessorR6$new()
    #'   obj$process(generate_domain_files=...)
    #' }
    process = function(generate_domain_files = TRUE) {
      self$load_data()
      self$filter_by_domain()
      self$select_columns()
      self$save_data()

      if (generate_domain_files) {
        self$generate_domain_qmd()
      }

      invisible(self)
    }
  ),

  # Private methods
  private = list(
    # Get domain number from phenotype
    get_domain_number = function() {
      domain_numbers <- c(
        iq = "01",
        academics = "02",
        verbal = "03",
        spatial = "04",
        memory = "05",
        executive = "06",
        motor = "07",
        social = "08",
        adhd = "09",
        emotion = "10",
        adaptive = "11",
        daily_living = "12",
        validity = "13"
      )

      num <- domain_numbers[tolower(self$pheno)]
      if (is.na(num) || is.null(num)) "99" else num
    }
  )
)
