#' ReportTemplateR6 Class
#'
#' An R6 class that encapsulates the Quarto-Typst template system
#'  for neuropsychological reports.
#' This class handles template variables,
#'  section inclusion, and report generation.
#'
#' @field variables List of variables used in the report template.
#' @field template_dir Directory containing the template files
#'  (default: "inst/quarto/_extensions/brainworkup").
#' @field output_dir Directory where generated reports will be saved
#'  (default: ".").
#' @field domains List of domains to include in the report.
#' @field data_paths List of paths to data files.
#' @field packages List of R packages required for the report.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new ReportTemplateR6
#'  object with configuration parameters.}
#'   \item{load_variables}{Load variables from a YAML file or list.}
#'   \item{set_variable}{Set a specific variable value.}
#'   \item{get_variable}{Get a specific variable value.}
#'   \item{set_domains}{Set the domains to include in the report.}
#'   \item{add_domain}{Add a domain to the report.}
#'   \item{remove_domain}{Remove a domain from the report.}
#'   \item{generate_template}{Generate the Quarto template file.}
#'   \item{render_report}{Render the report using Quarto.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom yaml read_yaml write_yaml
#' @importFrom here here
#' @importFrom quarto quarto_render
#' @export
ReportTemplateR6 <- R6::R6Class(
  classname = "ReportTemplateR6",
  public = list(
    variables = NULL,
    template_dir = NULL,
    output_dir = NULL,
    domains = NULL,
    data_paths = NULL,
    packages = NULL,

    #' @description
    #' Initialize a new ReportTemplateR6 object
    #'  with configuration parameters.
    #'
    #' @param variables List of variables or path to
    #'  a YAML file containing variables.
    #' @param template_dir Directory containing the template files
    #'  (default: "inst/quarto/_extensions/brainworkup").
    #' @param output_dir Directory where generated reports
    #'  will be saved (default: ".").
    #' @param domains List of domains to include in the report
    #'  (default: NULL, will use all domains).
    #' @param data_paths List of paths to data files (default: NULL).
    #' @param packages List of R packages required for the report
    #'  (default: NULL, will use defaults).
    #'
    #' @return A new ReportTemplateR6 object
    initialize = function(
      variables = NULL,
      template_dir = "inst/quarto/_extensions/brainworkup",
      output_dir = ".",
      domains = NULL,
      data_paths = NULL,
      packages = NULL
    ) {
      self$template_dir <- template_dir
      self$output_dir <- output_dir

      # Load variables
      if (is.null(variables)) {
        # Default variables file
        variables_file <- file.path(template_dir, "_variables.yml")
        if (file.exists(variables_file)) {
          self$load_variables(variables_file)
        } else {
          self$variables <- list(
            version = "0.1.0",
            patient = "Biggie",
            first_name = "First",
            last_name = "Last",
            dob = format(Sys.Date() - 365 * 30, "%Y-%m-%d"), # 30 years ago
            doe = format(Sys.Date(), "%Y-%m-%d"),
            date_of_report = format(Sys.Date(), "%Y-%m-%d")
          )
        }
      } else if (
        is.character(variables) &&
          length(variables) == 1 &&
          file.exists(variables)
      ) {
        # Variables file path
        self$load_variables(variables)
      } else if (is.list(variables)) {
        # Variables list
        self$variables <- variables
      }

      # Set default domains if not provided
      if (is.null(domains)) {
        self$domains <- list(
          "_00-00_tests.qmd",
          "_01-00_nse_adult.qmd",
          "_01-00_nse_forensic.qmd",
          "_01-00_nse_pediatric.qmd",
          "_01-01_behav_obs.qmd",
          "_03-00_sirf.qmd",
          "_03-00_sirf_text.qmd",
          "_03-01_recs.qmd",
          "_03-02_signature.qmd",
          "_03-03_appendix.qmd"
        )
      } else {
        self$domains <- domains
      }

      # Set default data paths if not provided
      if (is.null(data_paths)) {
        self$data_paths <- list(
          neurocog = "data/neurocog.parquet",
          neurobehav = "data/neurobehav.parquet",
          neuropsych = "data/neuropsych.parquet",
          validity = "data/validity.parquet"
        )
      } else {
        self$data_paths <- data_paths
      }

      # Set default packages if not provided
      if (is.null(packages)) {
        self$packages <- c(
          "dplyr",
          "glue",
          "gt",
          "here",
          "janitor",
          "knitr",
          "purrr",
          "quarto",
          "readr",
          "readxl",
          "rmarkdown",
          "snakecase",
          "stringr",
          "tidytable",
          "vroom",
          "xfun"
        )
      } else {
        self$packages <- packages
      }
    },

    #' @description
    #' Load variables from a YAML file.
    #'
    #' @param file_path Path to the YAML file containing variables.
    #' @return Invisibly returns self for method chaining.
    load_variables = function(file_path) {
      if (!file.exists(file_path)) {
        stop("Variables file not found: ", file_path)
      }

      self$variables <- yaml::read_yaml(file_path)

      invisible(self)
    },

    #' @description
    #' Set a specific variable value.
    #'
    #' @param name Name of the variable.
    #' @param value Value to set.
    #' @return Invisibly returns self for method chaining.
    set_variable = function(name, value) {
      self$variables[[name]] <- value

      invisible(self)
    },

    #' @description
    #' Get a specific variable value.
    #'
    #' @param name Name of the variable.
    #' @return The value of the variable.
    get_variable = function(name) {
      return(self$variables[[name]])
    },

    #' @description
    #' Set the domains to include in the report.
    #'
    #' @param domains List of domain file names.
    #' @return Invisibly returns self for method chaining.
    set_domains = function(domains) {
      self$domains <- domains

      invisible(self)
    },

    #' @description
    #' Add a domain to the report.
    #'
    #' @param domain Domain file name.
    #' @param position Position to insert the domain (default: end of list).
    #' @return Invisibly returns self for method chaining.
    add_domain = function(domain, position = NULL) {
      if (is.null(position) || position > length(self$domains)) {
        self$domains <- c(self$domains, domain)
      } else {
        self$domains <- append(self$domains, domain, after = position - 1)
      }

      invisible(self)
    },

    #' @description
    #' Remove a domain from the report.
    #'
    #' @param domain Domain file name or position.
    #' @return Invisibly returns self for method chaining.
    remove_domain = function(domain) {
      if (is.numeric(domain)) {
        if (domain > 0 && domain <= length(self$domains)) {
          self$domains <- self$domains[-domain]
        }
      } else if (domain %in% self$domains) {
        self$domains <- self$domains[self$domains != domain]
      }

      invisible(self)
    },

    #' @description
    #' Generate the Quarto template file.
    #'
    #' @param output_file Output file path (default: "report_template.qmd").
    #' @return Invisibly returns self for method chaining.
    generate_template = function(output_file = "report_template.qmd") {
      # Create the YAML frontmatter with all necessary fields
      yaml_header <- paste0(
        "---\n",
        "title: NEUROCOGNITIVE EXAMINATION\n",
        "patient: ",
        self$variables$patient,
        "\n",
        "name: ",
        self$variables$last_name,
        ", ",
        self$variables$first_name,
        "\n",
        "doe: ",
        self$variables$doe,
        "\n",
        "date_of_report: ",
        self$variables$date_of_report,
        "\n",
        "format: neurotyp-adult-typst\n",
        "\n",
        "execute:\n",
        "  warning: false\n",
        "  echo: false\n",
        "  message: false\n",
        "  freeze: auto\n",
        "  cache: true\n",
        "  engine: knitr\n",
        "  tools:\n",
        "    r: \"/usr/local/bin/R\"\n",
        "\n",
        "editor:\n",
        "  markdown:\n",
        "    wrap: sentence\n",
        "    canonical: true\n",
        "fig-width: 6\n",
        "fig-asp: 0.618\n",
        "out-width: 70%\n",
        "fig-align: center\n",
        "fig-format: svg\n",
        "fig-dpi: 270\n",
        "df-print: kable\n",
        "reference-location: document\n",
        "---\n\n"
      )

      # Create the setup chunk
      setup_chunk <- paste0(
        "```{r}\n",
        "#| label: setup\n",
        "#| include: false\n",
        "#| cache: false\n",
        "\n",
        "# Suppress xfun::attr() deprecation warnings\n",
        "options(warn = -1)\n",
        "\n",
        "packages <- c(\n",
        "  ",
        paste0("\"", self$packages, "\"", collapse = ",\n  "),
        "\n",
        ")\n",
        "\n",
        "# Function to load packages one by one\n",
        "load_packages <- function(packages) {\n",
        "  for (pkg in packages) {\n",
        "    if (!require(pkg, character.only = TRUE)) {\n",
        "      install.packages(pkg)\n",
        "      library(pkg, character.only = TRUE)\n",
        "    }\n",
        "    message(paste(\"Loaded package:\", pkg))\n",
        "  }\n",
        "}\n",
        "\n",
        "# Call the function to load packages\n",
        "load_packages(packages)\n",
        "\n",
        "# Apply xfun::attr() deprecation fix after loading xfun\n",
        "if (requireNamespace(\"xfun\", quietly = TRUE)) {\n",
        "  # Check if attr function exists and patch it\n",
        "  if (exists(\"attr\", envir = asNamespace(\"xfun\"))) {\n",
        "    tryCatch(\n",
        "      {\n",
        "        # Temporarily unlock the binding\n",
        "        unlockBinding(\"attr\", asNamespace(\"xfun\"))\n",
        "        # Replace with attr2\n",
        "        assign(\"attr\", xfun::attr2, envir = asNamespace(\"xfun\"))\n",
        "        # Lock it back\n",
        "        lockBinding(\"attr\", asNamespace(\"xfun\"))\n",
        "        message(\"Applied xfun::attr() deprecation fix\")\n",
        "      },\n",
        "      error = function(e) {\n",
        "        message(\n",
        "          \"Could not patch xfun::attr(), continuing with warnings suppressed\"\n",
        "        )\n",
        "      }\n",
        "    )\n",
        "  }\n",
        "}\n",
        "\n",
        "# Set knitr options\n",
        "knitr::opts_knit$set(\n",
        "  width = 80,\n",
        "  digits = 2,\n",
        "  warnPartialMatchArgs = FALSE,\n",
        "  crop = knitr::hook_pdfcrop,\n",
        "  optipng = knitr::hook_optipng\n",
        ")\n",
        "\n",
        "# Keep warnings suppressed for the rest of the document\n",
        "options(warn = -1)\n",
        "\n",
        "# Set environment variables with default values\n",
        "Sys.setenv(PATIENT = \"",
        self$variables$patient,
        "\")\n",
        "patient <- Sys.getenv(\"PATIENT\")\n",
        "```\n\n"
      )

      # Create the data load chunk - fix to use arrow for Parquet files
      data_load_chunk <- paste0(
        "```{r}\n",
        "#| label: data-load\n",
        "#| include: false\n",
        "\n",
        "path_data <- here::here(\"data\")\n",
        "# Use arrow to read Parquet files\n"
      )

      # Add data loading for each data path - fix to use correct reader
      for (name in names(self$data_paths)) {
        file_path <- self$data_paths[[name]]
        if (grepl("\\.parquet$", file_path)) {
          data_load_chunk <- paste0(
            data_load_chunk,
            name,
            " <- arrow::read_parquet(here::here(\"",
            file_path,
            "\"))\n"
          )
        } else if (grepl("\\.csv$", file_path)) {
          data_load_chunk <- paste0(
            data_load_chunk,
            name,
            " <- readr::read_csv(here::here(\"",
            file_path,
            "\"))\n"
          )
        }
      }

      data_load_chunk <- paste0(data_load_chunk, "```\n\n")

      # Create the Typst block for patient information
      typst_block <- paste0(
        "```{=typst}\n",
        "#let name = [",
        self$variables$last_name,
        ", ",
        self$variables$first_name,
        "]\n",
        "#let doe = [",
        self$variables$date_of_report,
        "]\n",
        "#let patient = [",
        self$variables$patient,
        "]\n",
        "#v(2em, weak: true)\n",
        "#show block: set par(leading: 0.65em)\n",
        "#block[\n",
        "*PATIENT NAME:* #name \\\\\n",
        "*DATE OF BIRTH:* ",
        if (!is.null(self$variables$dob)) self$variables$dob else "YYYY-MM-DD",
        ", Age ",
        if (!is.null(self$variables$age)) self$variables$age else "XX",
        " \\\\\n",
        "*DATES OF EXAM:* ",
        self$variables$doe,
        if (!is.null(self$variables$doe2)) {
          paste0(", ", self$variables$doe2)
        } else {
          ""
        },
        if (!is.null(self$variables$doe3)) {
          paste0(", and ", self$variables$doe3)
        } else {
          ""
        },
        " \\\\\n",
        "*DATE OF REPORT*: ",
        self$variables$date_of_report,
        " \\\\\n",
        "]\n",
        "```\n\n"
      )

      # Create the domain includes
      domain_includes <- ""
      for (domain in self$domains) {
        domain_includes <- paste0(
          domain_includes,
          "{{< include ",
          domain,
          " >}}\n\n"
        )

        # Add text companion for cognitive/behavioral domains (_02-XX_ pattern)
        if (grepl("^_02-", domain)) {
          domain_text <- sub("\\.qmd$", "_text.qmd", domain)
          domain_includes <- paste0(
            domain_includes,
            "{{< include ",
            domain_text,
            " >}}\n\n"
          )
        }
      }

      # Add the "NEUROCOGNITIVE FINDINGS" heading
      domain_includes <- paste0(
        "# NEUROCOGNITIVE FINDINGS\n\n",
        domain_includes
      )

      # Combine all parts
      template_content <- paste0(
        yaml_header,
        setup_chunk,
        data_load_chunk,
        typst_block,
        domain_includes
      )

      # Write to file
      cat(template_content, file = file.path(self$output_dir, output_file))

      invisible(self)
    },

    #' @description
    #' Render the report using Quarto.
    #'
    #' @param input_file Input Quarto file path.
    #' @param output_format Output format
    #'  (default: "neurotyp-adult-typst",
    #'  other options: "neurotyp-forensic-typst", "neurotyp-pediatric-typst").
    #' @param output_file Output file path
    #'  (default: NULL, will use Quarto default).
    #' @return Invisibly returns self for method chaining.
    render_report = function(
      input_file,
      output_format = "neurotyp-adult-typst",
      output_file = NULL
    ) {
      if (!file.exists(input_file)) {
        stop("Input file not found: ", input_file)
      }

      # Check if quarto package is available
      if (!requireNamespace("quarto", quietly = TRUE)) {
        stop("The 'quarto' package is required to render reports.")
      }

      # Render the report - call function directly instead of using do.call
      if (!is.null(output_file)) {
        quarto::quarto_render(
          input = input_file,
          output_format = output_format,
          output_file = output_file
        )
      } else {
        quarto::quarto_render(input = input_file, output_format = output_format)
      }

      invisible(self)
    }
  )
)

#' Generate Neuropsychological Report (Function Wrapper)
#'
#' This function encapsulates the entire workflow
#'  for generating neuropsychological reports.
#' It's a wrapper around the ReportTemplateR6 class.
#'
#' @param variables List of variables or
#'  path to a YAML file containing variables.
#' @param template_dir Directory containing the template files
#'  (default: "inst/quarto/_extensions/brainworkup").
#' @param output_dir Directory where generated reports will be saved
#'  (default: ".").
#' @param domains List of domains to include in the report
#'  (default: NULL, will use all domains).
#' @param data_paths List of paths to data files (default: NULL).
#' @param output_file Output file path for the generated template
#'  (default: "report_template.qmd").
#' @param render Whether to render the report after generating
#'  the template (default: TRUE).
#' @param output_format Output format for rendering
#'  (default: "neurotyp-adult-typst", other options: "neurotyp-forensic-typst", "neurotyp-pediatric-typst").
#'
#' @return Invisibly returns the ReportTemplateR6 object.
#' @export
#' @rdname generate_neuropsych_report
generate_neuropsych_report <- function(
  variables = NULL,
  template_dir = "inst/quarto/_extensions/brainworkup",
  output_dir = "output",
  domains = NULL,
  data_paths = NULL,
  output_file = "template.qmd",
  render = TRUE,
  output_format = "neurotyp-adult-typst"
) {
  # Create a ReportTemplateR6 object
  report_generator <- ReportTemplateR6$new(
    variables = variables,
    template_dir = template_dir,
    output_dir = output_dir,
    domains = domains,
    data_paths = data_paths
  )

  # Generate the template
  report_generator$generate_template(output_file)

  # Render the report if requested
  if (render) {
    report_generator$render_report(
      input_file = file.path(output_dir, output_file),
      output_format = output_format
    )
  }

  invisible(report_generator)
}
