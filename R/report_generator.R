## ReportGenerator.R
#' @title ReportGenerator R6 Class
#' @name ReportGenerator
#' @description
#' An R6 class to orchestrate import and processing of neuropsychological data,
#' creation of tables, plots, and text summaries, and rendering reports via Quarto+Typst.
#'
#' @field params Named list of template parameters passed to the Quarto engine
#' @field output_dir Filepath where tables, plots, text, and final report are saved
#' @field data A tibble/data.frame of combined and processed neuropsychological data
#'
#' @import R6
#' @importFrom quarto quarto_render
#' @importFrom glue glue
#' @importFrom fs dir_create file_copy
#' @importFrom dplyr group_by mutate ungroup across filter
#' @importFrom readr read_csv write_excel_csv read_lines
#' @importFrom stats sd
#' @importFrom gt gt cols_label tab_header tab_footnote
#' @importFrom stringr str_match_all str_squish
#' @export
ReportGenerator <- R6::R6Class(
  "ReportGenerator",
  private = list(
    template_qmd = NULL,
    extensions_dir = NULL
  ),
  public = list(
    params = list(),
    output_dir = NULL,
    data = NULL,

    #' @description
    #' Initialize a ReportGenerator.
    #' @param params Named list of execute parameters for the Quarto template
    #' @param output_dir Directory to save outputs (defaults to working directory)
    initialize = function(params = list(), output_dir = getwd()) {
      private$template_qmd <- system.file(
        "quarto",
        "templates",
        "typst-report",
        "template.qmd",
        package = "yourpkg"
      )
      private$extensions_dir <- system.file(
        "quarto",
        "extensions",
        "typst",
        package = "yourpkg"
      )
      self$params <- params
      self$output_dir <- output_dir
      fs::dir_create(self$output_dir)
    },

    #' @description
    #' Load and combine CSV data files into the internal data object.
    #' @param files Character vector of file paths to CSVs
    load_data = function(files = NULL) {
      if (is.null(files)) {
        # load all example data
        self$data <- dplyr::bind_rows(
          caars2_self,
          cvlt3_brief,
          nabs,
          wais5_index,
          wais5_subtest,
          wiat4
        )
      } else {
        self$data <- read_and_combine_files(files)
      }
      invisible(self)
    },

    #' @description
    #' Filter data by domain and/or scale values.
    #' @param domains Character vector of domain names to include (NULL for all)
    #' @param scales Character vector of scale names to include (NULL for all)
    filter_data = function(domains = NULL, scales = NULL) {
      self$data <- filter_data(self$data, domains, scales)
      invisible(self)
    },

    #' @description
    #' Calculate z-score statistics grouped by specified variables.
    #' @param group_vars Character vector of column names for grouping
    calculate_stats = function(group_vars) {
      self$data <- calculate_z_stats(self$data, group_vars)
      invisible(self)
    },

    #' @description
    #' Generate and save GT tables to the output directory.
    #' @param ... Additional arguments passed to table functions
    generate_tables = function(...) {
      tbl1 <- tbl_kbl(self$data)
      gt::gtsave(tbl1, file.path(self$output_dir, "domain_table.png"))
      invisible(self)
    },

    #' @description
    #' Generate and save plots (e.g., dotplots) to the output directory.
    #' @param ... Additional arguments passed to plotting functions
    generate_plots = function(...) {
      p1 <- dotplot(self$data)
      ggplot2::ggsave(file.path(self$output_dir, "dotplot.png"), p1)
      invisible(self)
    },

    #' @description
    #' Process raw transcript and save as cleaned Markdown.
    #' @param input Raw transcript file path
    #' @param output Desired output file path
    #' @param begin Pattern marking start of text to keep
    #' @param end Pattern marking end of text to keep
    generate_text = function(input, output, begin, end) {
      read_write_transcript_otterai(input, output, begin, end)
      invisible(self)
    },

    #' @description
    #' Assemble multiple section QMD files into a master document and render in one step.
    #' @param sections_dir Directory containing section .qmd files
    #' @param placeholder Placeholder tag in the master template to replace (e.g., "{{sections}}")
    #' @param output_file Name of the rendered report file (e.g., "report.pdf")
    render_sections = function(
      sections_dir,
      placeholder = "{{sections}}",
      output_file = "report.pdf"
    ) {
      # Discover and sort section files
      section_files <- list.files(
        sections_dir,
        pattern = "\\.qmd$",
        full.names = TRUE
      )
      section_files <- sort(section_files)
      # Read the base template
      template_lines <- readr::read_lines(private$template_qmd)
      # Build include directives
      include_lines <- paste0("{{< include ", basename(section_files), " >}}")
      # Replace placeholder with includes
      master_lines <- gsub(
        placeholder,
        paste(include_lines, collapse = "\n"),
        template_lines,
        fixed = TRUE
      )
      # Write master QMD
      master_path <- file.path(self$output_dir, "master_report.qmd")
      writeLines(master_lines, master_path)
      # Copy section files alongside
      fs::file_copy(
        section_files,
        file.path(self$output_dir, basename(section_files)),
        overwrite = TRUE
      )

      # Render master report
      quarto::quarto_render(
        input = master_path,
        output_file = file.path(self$output_dir, output_file),
        execute_params = self$params,
        format = "typst",
        extensions = private$extensions_dir
      )
      invisible(file.path(self$output_dir, output_file))
    },

    #' @description
    #' Render the final report using Quarto+Typst.
    #' @param output_file Filename for the rendered report (e.g., "report.pdf")
    render = function(output_file = "report.pdf") {
      out_path <- file.path(self$output_dir, output_file)
      quarto::quarto_render(
        input = private$template_qmd,
        output_file = out_path,
        execute_params = self$params,
        format = "typst",
        extensions = private$extensions_dir
      )
      message("Report written to: ", out_path)
      invisible(out_path)
    }
  )
)

# Ensure helper scripts (data_tidy.R, plots.R, tables.R, text.R) reside in R/ so functions are available.
