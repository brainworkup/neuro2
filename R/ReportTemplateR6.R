#' ReportTemplateR6 Class
#'
#' An R6 class that encapsulates the Quarto-Typst template system for neuropsychological reports.
#' This class handles template variables, section inclusion, and report generation.
#'
#' @field variables List of variables used in the report template.
#' @field template_dir Directory containing the template files (default: "inst/quarto/templates/typst-report").
#' @field output_dir Directory where generated reports will be saved (default: ".").
#' @field sections List of sections to include in the report.
#' @field data_paths List of paths to data files.
#' @field packages List of R packages required for the report.
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new ReportTemplateR6 object with configuration parameters.}
#'   \item{load_variables}{Load variables from a YAML file or list.}
#'   \item{set_variable}{Set a specific variable value.}
#'   \item{get_variable}{Get a specific variable value.}
#'   \item{set_sections}{Set the sections to include in the report.}
#'   \item{add_section}{Add a section to the report.}
#'   \item{remove_section}{Remove a section from the report.}
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
    sections = NULL,
    data_paths = NULL,
    packages = NULL,

    #' @description
    #' Initialize a new ReportTemplateR6 object with configuration parameters.
    #'
    #' @param variables List of variables or path to a YAML file containing variables.
    #' @param template_dir Directory containing the template files (default: "inst/quarto/templates/typst-report").
    #' @param output_dir Directory where generated reports will be saved (default: ".").
    #' @param sections List of sections to include in the report (default: NULL, will use all sections).
    #' @param data_paths List of paths to data files (default: NULL).
    #' @param packages List of R packages required for the report (default: NULL, will use defaults).
    #'
    #' @return A new ReportTemplateR6 object
    initialize = function(
      variables = NULL,
      template_dir = "inst/quarto/templates/typst-report",
      output_dir = ".",
      sections = NULL,
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
            patient = "Patient Name",
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

      # Set default sections if not provided
      if (is.null(sections)) {
        self$sections <- list(
          "_00-00_tests.qmd",
          "_01-00_nse_adult.qmd",
          "_02-00_behav_obs.qmd",
          "_03-00_sirf.qmd",
          "_03-00_sirf_text.qmd",
          "_03-01_recommendations.qmd",
          "_03-02_signature.qmd",
          "_03-03_appendix.qmd"
        )
      } else {
        self$sections <- sections
      }

      # Set default data paths if not provided
      if (is.null(data_paths)) {
        self$data_paths <- list(
          neurocog = "data-raw/neurocog.csv",
          neurobehav = "data-raw/neurobehav.csv",
          neuropsych = "data-raw/neuropsych.csv"
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
          "xfun",
          "NeurotypR",
          "NeurotypR"
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
    #' Set the sections to include in the report.
    #'
    #' @param sections List of section file names.
    #' @return Invisibly returns self for method chaining.
    set_sections = function(sections) {
      self$sections <- sections

      invisible(self)
    },

    #' @description
    #' Add a section to the report.
    #'
    #' @param section Section file name.
    #' @param position Position to insert the section (default: end of list).
    #' @return Invisibly returns self for method chaining.
    add_section = function(section, position = NULL) {
      if (is.null(position) || position > length(self$sections)) {
        self$sections <- c(self$sections, section)
      } else {
        self$sections <- append(self$sections, section, after = position - 1)
      }

      invisible(self)
    },

    #' @description
    #' Remove a section from the report.
    #'
    #' @param section Section file name or position.
    #' @return Invisibly returns self for method chaining.
    remove_section = function(section) {
      if (is.numeric(section)) {
        if (section > 0 && section <= length(self$sections)) {
          self$sections <- self$sections[-section]
        }
      } else if (section %in% self$sections) {
        self$sections <- self$sections[self$sections != section]
      }

      invisible(self)
    },

    #' @description
    #' Generate the Quarto template file.
    #'
    #' @param output_file Output file path (default: "report_template.qmd").
    #' @return Invisibly returns self for method chaining.
    generate_template = function(output_file = "report_template.qmd") {
      # Create the YAML frontmatter
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
        "format:\n",
        "  neurotyp-adult-typst:\n",
        "    keep-typ: true\n",
        "    keep-md: true\n",
        "    papersize: \"a4\"\n",
        "    fontsize: 11pt\n",
        "    bodyfont: \"Source Serif 4\"\n",
        "    sansfont: \"Source Sans 3\"\n",
        "    number-sections: false\n",
        "    number-offset: 1\n",
        "    shift-heading-level-by: 0\n",
        "    fig-width: 6\n",
        "    fig-height: 4\n",
        "    fig-format: svg\n",
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
        "bibliography:\n",
        "  - bib/refs.bib\n",
        "citeproc: true\n",
        "csl: bib/apa.csl\n",
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

      # Create the data load chunk
      data_load_chunk <- paste0(
        "```{r}\n",
        "#| label: data-load\n",
        "#| include: false\n",
        "\n",
        "path_data <- here::here(\"data\")\n",
        "path_csv <- here::here(\"inst\", \"extdata\")\n",
        "NeurotypR::load_data(here::here(path_csv))\n"
      )

      # Add data loading for each data path
      for (name in names(self$data_paths)) {
        data_load_chunk <- paste0(
          data_load_chunk,
          name,
          " <- readr::read_csv(\"",
          self$data_paths[[name]],
          "\")\n"
        )
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
        "// #v(2em, weak: true)\n",
        "// #show block: set par(leading: 0.65em)\n",
        "#block[\n",
        "*PATIENT NAME:* #name \\\n",
        "*DATE OF BIRTH:* ",
        self$variables$dob,
        ", Age ",
        self$variables$age,
        " \\\n",
        "*DATES OF EXAM:* ",
        self$variables$doe,
        ", ",
        self$variables$doe2,
        ", and ",
        self$variables$doe3,
        " \\\n",
        "*DATE OF REPORT*: ",
        self$variables$date_of_report,
        " \\\n",
        "]\n",
        "```\n\n"
      )

      # Create the section includes
      section_includes <- ""
      for (section in self$sections) {
        section_includes <- paste0(
          section_includes,
          "{{< include sections/",
          section,
          " >}}\n\n"
        )
      }

      # Add the "NEUROCOGNITIVE FINDINGS" heading
      section_includes <- paste0(
        section_includes,
        "# NEUROCOGNITIVE FINDINGS\n\n"
      )

      # Combine all parts
      template_content <- paste0(
        yaml_header,
        setup_chunk,
        data_load_chunk,
        typst_block,
        section_includes
      )

      # Write to file
      cat(template_content, file = file.path(self$output_dir, output_file))

      invisible(self)
    },

    #' @description
    #' Render the report using Quarto.
    #'
    #' @param input_file Input Quarto file path.
    #' @param output_format Output format (default: "neurotyp-adult-typst").
    #' @param output_file Output file path (default: NULL, will use Quarto default).
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

      # Render the report
      args <- list(input = input_file, output_format = output_format)

      if (!is.null(output_file)) {
        args$output_file <- output_file
      }

      do.call(quarto::quarto_render, args)

      invisible(self)
    }
  )
)

#' Generate Neuropsychological Report (Function Wrapper)
#'
#' This function encapsulates the entire workflow for generating neuropsychological reports.
#' It's a wrapper around the ReportTemplateR6 class.
#'
#' @param variables List of variables or path to a YAML file containing variables.
#' @param template_dir Directory containing the template files (default: "inst/quarto/templates/typst-report").
#' @param output_dir Directory where generated reports will be saved (default: ".").
#' @param sections List of sections to include in the report (default: NULL, will use all sections).
#' @param data_paths List of paths to data files (default: NULL).
#' @param output_file Output file path for the generated template (default: "report_template.qmd").
#' @param render Whether to render the report after generating the template (default: TRUE).
#' @param output_format Output format for rendering (default: "neurotyp-adult-typst").
#'
#' @return Invisibly returns the ReportTemplateR6 object.
#' @export
#' @rdname generate_neuropsych_report
generate_neuropsych_report <- function(
  variables = NULL,
  template_dir = "inst/quarto/templates/typst-report",
  output_dir = ".",
  sections = NULL,
  data_paths = NULL,
  output_file = "report_template.qmd",
  render = TRUE,
  output_format = "neurotyp-adult-typst"
) {
  # Create a ReportTemplateR6 object
  report_generator <- ReportTemplateR6$new(
    variables = variables,
    template_dir = template_dir,
    output_dir = output_dir,
    sections = sections,
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
