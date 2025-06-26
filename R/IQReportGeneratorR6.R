#' IQReportGeneratorR6 Class
#'
#' An R6 class that encapsulates the entire workflow for generating IQ/cognitive ability reports.
#' This class handles data loading, processing, visualization, and report generation.
#'
#' @field patient_name Patient's name for the report.
#' @field input_file Path to the input CSV file (neurocog.csv).
#' @field output_dir Directory where output files will be saved (default: "data").
#' @field domains Cognitive domains to include (default: "General Cognitive Ability").
#' @field pheno Target phenotype identifier (default: "iq").
#' @field data The loaded and processed data.
#' @field scales List of scales to include in the report.
#' @field filtered_data Data filtered by domain and scales.
#' @field summary_text Text summary of the assessment.
#' @field output_files List of generated output files (tables, figures, etc.).
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new IQReportGeneratorR6 object with configuration parameters.}
#'   \item{load_data}{Load data from the specified input file.}
#'   \item{process_data}{Process and filter the data.}
#'   \item{generate_tables}{Generate tables for the report.}
#'   \item{generate_figures}{Generate figures for the report.}
#'   \item{generate_summary}{Generate or load the text summary.}
#'   \item{generate_report}{Generate the complete report.}
#'   \item{render_document}{Render the Quarto document with the generated components.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter select arrange desc distinct
#' @importFrom readr read_csv write_excel_csv
#' @importFrom here here
#' @export
IQReportGeneratorR6 <- R6::R6Class(
  classname = "IQReportGeneratorR6",
  public = list(
    patient_name = NULL,
    input_file = NULL,
    output_dir = "data",
    domains = "General Cognitive Ability",
    pheno = "iq",
    data = NULL,
    scales = NULL,
    filtered_data = NULL,
    summary_text = NULL,
    output_files = list(),

    #' @description
    #' Initialize a new IQReportGeneratorR6 object with configuration parameters.
    #'
    #' @param patient_name Patient's name for the report.
    #' @param input_file Path to the input CSV file (neurocog.csv).
    #' @param output_dir Directory where output files will be saved (default: "data").
    #' @param domains Cognitive domains to include (default: "General Cognitive Ability").
    #' @param pheno Target phenotype identifier (default: "iq").
    #'
    #' @return A new IQReportGeneratorR6 object
    initialize = function(
      patient_name,
      input_file = "data/neurocog.csv",
      output_dir = "data",
      domains = "General Cognitive Ability",
      pheno = "iq"
    ) {
      self$patient_name <- patient_name
      self$input_file <- input_file
      self$output_dir <- output_dir
      self$domains <- domains
      self$pheno <- pheno

      # Initialize the scales list with default values
      self$scales <- c(
        "Auditory Working Memory (AWMI)",
        "Cognitive Proficiency (CPI)",
        "Crystallized Knowledge",
        "Fluid Reasoning (FRI)",
        "Fluid Reasoning",
        "Full Scale (FSIQ)",
        "Full Scale IQ (FSIQ)",
        "General Ability (GAI)",
        "General Ability",
        "General Intelligence",
        "Global Neurocognitive Index (G)",
        "NAB Attention Index",
        "NAB Executive Functions Index",
        "NAB Language Index",
        "NAB Memory Index",
        "NAB Spatial Index",
        "NAB Total Index",
        "Nonverbal (NVI)",
        "Perceptual Reasoning (PRI)",
        "Perceptual Reasoning",
        "Processing Speed (PSI)",
        "Processing Speed",
        "RBANS Total Index",
        "Test of Premorbid Functioning",
        "TOPF Standard Score",
        "Total NAB Index (T-NAB)",
        "Verbal Comprehension (VCI)",
        "Verbal Comprehension",
        "Visual Perception/Construction",
        "Visual Spatial (VSI)",
        "Vocabulary Acquisition (VAI)",
        "Word Reading",
        "Working Memory (WMI)",
        "Working Memory",
        "Attention Index (ATT)",
        "Language Index (LAN)",
        "Spatial Index (SPT)",
        "Memory Index (MEM)",
        "Executive Functions Index (EXE)"
      )

      # Initialize output_files list
      self$output_files <- list(
        data_file = paste0(self$pheno, ".csv"),
        table_file = paste0("table_", self$pheno, ".png"),
        subdomain_figure = "fig_iq_subdomain.svg",
        narrow_figure = "fig_iq_narrow.svg",
        summary_file = "_02-01_iq_text.qmd"
      )
    },

    #' @description
    #' Load data from the specified input file.
    #'
    #' @return Invisibly returns self for method chaining.
    load_data = function() {
      self$data <- readr::read_csv(self$input_file)
      invisible(self)
    },

    #' @description
    #' Process and filter the data.
    #'
    #' @return Invisibly returns self for method chaining.
    process_data = function() {
      # Filter by domain
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)

      # Select specific columns from the data frame
      self$data <- self$data |>
        dplyr::select(
          test,
          test_name,
          scale,
          raw_score,
          score,
          ci_95,
          percentile,
          range,
          domain,
          subdomain,
          narrow,
          pass,
          verbal,
          timed,
          result,
          z,
          z_mean_domain,
          z_sd_domain,
          z_mean_subdomain,
          z_sd_subdomain,
          z_mean_narrow,
          z_sd_narrow,
          z_mean_pass,
          z_sd_pass,
          z_mean_verbal,
          z_sd_verbal,
          z_mean_timed,
          z_sd_timed
        )

      # Write the resulting data frame to a CSV file
      readr::write_excel_csv(
        self$data,
        here::here(self$output_dir, self$output_files$data_file),
        na = "",
        col_names = TRUE,
        append = FALSE
      )

      # Filter the data using the scales list
      self$filtered_data <- NeurotypR::filter_data(
        data = self$data,
        domain = self$domains,
        scale = self$scales
      )

      invisible(self)
    },

    #' @description
    #' Generate tables for the report.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_tables = function() {
      # Filter the data to include only the specified scales
      table_data <- dplyr::filter(self$filtered_data, scale %in% self$scales)

      # Define table parameters
      table_name <- paste0("table_", self$pheno)
      vertical_padding <- 0
      multiline <- TRUE

      # Define footnotes
      source_note <- gt::md(
        "Standard score: Mean = 100 [50th\u2030], SD ± 15 [16th\u2030, 84th\u2030]"
      )

      # Define the groups for the table
      grp_iq <- list(
        standard_score = c(
          "Composite Scores",
          "Test of Premorbid Functioning",
          "WAIS-5",
          "WAIS-IV",
          "WAIS-4",
          "WASI-2",
          "WISC-5",
          "WISC-V",
          "WRAT-5",
          "KTEA-3",
          "NAB",
          "NAB-S",
          "RBANS",
          "WPPSI-IV"
        )
      )

      # Create the table using the NeurotypR::tbl_gt function
      NeurotypR::tbl_gt(
        data = table_data,
        pheno = self$pheno,
        table_name = table_name,
        vertical_padding = vertical_padding,
        source_note = source_note,
        dynamic_grp = grp_iq,
        multiline = multiline
      )

      invisible(self)
    },

    #' @description
    #' Generate figures for the report.
    #'
    #' @return Invisibly returns self for method chaining.
    generate_figures = function() {
      # Generate subdomain figure
      x_subdomain <- self$filtered_data$z_mean_subdomain
      y_subdomain <- self$filtered_data$subdomain

      NeurotypR::dotplot2(
        data = self$filtered_data,
        x = x_subdomain,
        y = y_subdomain,
        colors = NULL,
        return_plot = TRUE,
        filename = self$output_files$subdomain_figure,
        na.rm = TRUE
      )

      # Generate narrow figure
      x_narrow <- self$filtered_data$z_mean_narrow
      y_narrow <- self$filtered_data$narrow

      NeurotypR::dotplot2(
        data = self$filtered_data,
        x = x_narrow,
        y = y_narrow,
        colors = NULL,
        return_plot = TRUE,
        filename = self$output_files$narrow_figure,
        na.rm = TRUE
      )

      invisible(self)
    },

    #' @description
    #' Generate or load the text summary.
    #'
    #' @param summary_text Optional text to use as summary (default: NULL, will try to load from file).
    #' @return Invisibly returns self for method chaining.
    generate_summary = function(summary_text = NULL) {
      if (!is.null(summary_text)) {
        # Use provided summary text
        self$summary_text <- summary_text

        # Write the summary to a file
        cat(
          paste0("<summary>\n\n", summary_text, "\n\n</summary>"),
          file = self$output_files$summary_file,
          append = FALSE
        )
      } else {
        # Try to read existing summary file
        if (file.exists(self$output_files$summary_file)) {
          self$summary_text <- readLines(
            self$output_files$summary_file,
            warn = FALSE
          )
          self$summary_text <- paste(self$summary_text, collapse = "\n")
        } else {
          # Generate a placeholder summary if file doesn't exist
          self$summary_text <- paste0(
            "<summary>\n\n",
            "Placeholder summary for ",
            self$patient_name,
            "'s cognitive assessment. ",
            "Please replace this with an actual clinical summary.\n\n",
            "</summary>"
          )

          # Write the placeholder to a file
          cat(
            self$summary_text,
            file = self$output_files$summary_file,
            append = FALSE
          )
        }
      }

      invisible(self)
    },

    #' @description
    #' Generate the complete report by running all processing steps.
    #'
    #' @param summary_text Optional text to use as summary (default: NULL).
    #' @return Invisibly returns self for method chaining.
    generate_report = function(summary_text = NULL) {
      self$load_data()
      self$process_data()
      self$generate_tables()
      self$generate_figures()
      self$generate_summary(summary_text)

      invisible(self)
    },

    #' @description
    #' Render the Quarto document with the generated components.
    #'
    #' @param output_file Output file path for the rendered document.
    #' @param template_file Template file to use (default: "_02-01_iq_template.qmd").
    #' @return Invisibly returns self for method chaining.
    render_document = function(
      output_file = "_02-01_iq.qmd",
      template_file = NULL
    ) {
      # If template file is not provided, create a default template
      if (is.null(template_file)) {
        template_content <- paste0(
          "## General Cognitive Ability {#sec-iq}\n\n",
          "{{< include ",
          self$output_files$summary_file,
          " >}}\n\n",
          "```{=typst}\n",
          "// Define a function to create a domain with a title, a table, and a figure\n",
          "#let domain(title: none, file_qtbl, file_fig) = {\n",
          "  let font = (font: \"Roboto Slab\", size: 0.7em)\n",
          "  set text(..font)\n",
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
          "        [#emph[_Premorbid Ability_] is an estimate of an individual's intellectual functioning prior to known or suspected onset of brain disease or dysfunction. Neurocognition is independent of intelligence and evaluates cognitive functioning across five domains\\: Attention (focus, concentration, and information processing), Language (verbal communication, naming, comprehension, and fluency), Memory (immediate and delayed verbal and visual recall), Spatial (visuospatial perception, construction, and orientation), and Executive Functions (planning, problem-solving, and mental flexibility). #footnote[All scores in these figures have been standardized as z-scores. In this system: A z-score of 0.0 represents average performance; Each unit represents one standard deviation from the average; Scores between -1.0 and +1.0 fall within the normal range; Scores below -1.0 indicate below-average performance and warrant attention; and Scores at or below -2.0 indicate significantly impaired performance and are clinically concerning.]\n",
          "        ],\n",
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
          "#let title = \"General Cognitive Ability\"\n\n",
          "// Define the file name of the table\n",
          "#let file_qtbl = \"",
          self$output_files$table_file,
          "\"\n\n",
          "// Define the file name of the figure\n",
          "#let file_fig = \"",
          self$output_files$subdomain_figure,
          "\"\n\n",
          "// The title is appended with ' Index Scores'\n",
          "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
          "```\n"
        )

        # Write the template to a temporary file
        temp_template_file <- "_02-01_iq_temp_template.qmd"
        cat(template_content, file = temp_template_file)
        template_file <- temp_template_file
      }

      # Copy the template to the output file
      file.copy(template_file, output_file, overwrite = TRUE)

      # If we created a temporary template, remove it
      if (exists("temp_template_file")) {
        unlink(temp_template_file)
      }

      # Optionally render the document with quarto
      # This would require the quarto R package
      # quarto::quarto_render(output_file)

      invisible(self)
    }
  )
)

#' Generate IQ/Cognitive Ability Report (Function Wrapper)
#'
#' This function encapsulates the entire workflow for generating IQ/cognitive ability reports.
#' It's a wrapper around the IQReportGeneratorR6 class.
#'
#' @param patient_name Patient's name for the report.
#' @param input_file Path to the input CSV file (neurocog.csv).
#' @param output_dir Directory where output files will be saved (default: "data").
#' @param domains Cognitive domains to include (default: "General Cognitive Ability").
#' @param pheno Target phenotype identifier (default: "iq").
#' @param summary_text Optional text to use as summary (default: NULL).
#' @param output_file Output file path for the rendered document (default: "_02-01_iq.qmd").
#'
#' @return Invisibly returns the IQReportGeneratorR6 object.
#' @export
#' @rdname generate_iq_report
generate_iq_report <- function(
  patient_name,
  input_file = "data/neurocog.csv",
  output_dir = "data",
  domains = "General Cognitive Ability",
  pheno = "iq",
  summary_text = NULL,
  output_file = "_02-01_iq.qmd"
) {
  # Create an IQReportGeneratorR6 object and generate the report
  generator <- IQReportGeneratorR6$new(
    patient_name = patient_name,
    input_file = input_file,
    output_dir = output_dir,
    domains = domains,
    pheno = pheno
  )

  # Generate all report components
  generator$generate_report(summary_text)

  # Render the final document
  generator$render_document(output_file)

  invisible(generator)
}
