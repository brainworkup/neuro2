#' DomainProcessorR6 - Integrated Working Version
#'
#' A clean, working implementation that generates QMD files correctly
#' following the exact structure of the working Academic Skills example.
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
DomainProcessorR6Combo <- R6::R6Class(
  classname = "DomainProcessorR6Combo",
  public = list(
    domains = NULL,
    pheno = NULL,
    input_file = NULL,
    output_dir = "data",
    number = NULL,
    data = NULL,

    #' @description
    #' Initialize a new DomainProcessorR6Combo object
    #'
    #' @param domains Character vector of domain names to process
    #' @param pheno Target phenotype identifier string
    #' @param input_file Path to the input data file
    #' @param output_dir Directory where output files will be saved
    #' @param number Domain number for file naming (optional)
    #' @return A new DomainProcessorR6Combo object
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      number = NULL
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir
      
      # Set the number field
      if (!is.null(number)) {
        self$number <- sprintf("%02d", as.numeric(number))
      } else {
        self$number <- private$get_domain_number()
      }
    },

    #' @description
    #' Load data from the specified input file
    #' @return Invisibly returns self for method chaining
    load_data = function() {
      if (!is.null(self$data)) {
        message("Data already loaded, skipping file read.")
        return(invisible(self))
      }

      if (is.null(self$input_file)) {
        stop("No input file specified and no data pre-loaded.")
      }

      # Determine file extension and read appropriately
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
    #' @return Invisibly returns self for method chaining
    filter_by_domain = function() {
      self$data <- self$data |> dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Select relevant columns from the data
    #' @return Invisibly returns self for method chaining
    select_columns = function() {
      desired_columns <- c(
        "test", "test_name", "scale", "raw_score", "score",
        "ci_95", "percentile", "range", "domain", "subdomain",
        "narrow", "pass", "verbal", "timed", "result", "z"
      )

      existing_columns <- intersect(desired_columns, names(self$data))

      # Calculate z-score if missing but percentile exists
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
    #' @param filename Optional custom filename
    #' @param format Output format
    #' @return Invisibly returns self for method chaining
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
    #' @return Logical indicating if domain has multiple raters
    has_multiple_raters = function() {
      tolower(self$pheno) %in% c("emotion", "adhd")
    },

    #' @description
    #' Detect emotion type (child/adult)
    #' @return Character string: "child", "adult", or NULL
    detect_emotion_type = function() {
      if (tolower(self$pheno) != "emotion") {
        return(NULL)
      }

      # Check domain names for clues
      child_patterns <- c(
        "Behavioral/Emotional/Social",
        "Personality Disorders", 
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      )
      
      adult_patterns <- c(
        "Emotional/Behavioral/Personality"
      )

      if (any(sapply(child_patterns, function(p) any(grepl(p, self$domains, ignore.case = TRUE))))) {
        return("child")
      } else if (any(sapply(adult_patterns, function(p) any(grepl(p, self$domains, ignore.case = TRUE))))) {
        return("adult")
      }

      # Default to child if unclear
      return("child")
    },

    #' @description
    #' Generate text file for the domain
    #' @param report_type Type of report ("self", "parent", "teacher", "observer")
    #' @return Path to generated text file
    generate_text_file = function(report_type = NULL) {
      if (!is.null(report_type)) {
        text_file <- paste0("_02-", self$number, "_", self$pheno, "_text_", report_type, ".qmd")
      } else {
        text_file <- paste0("_02-", self$number, "_", self$pheno, "_text.qmd")
      }

      # Create minimal placeholder text for now
      # This will be replaced by actual NeuropsychResultsR6 processing
      domain_name <- self$domains[1]
      
      text_content <- if (!is.null(report_type)) {
        paste0(
          "<!-- Text content for ", domain_name, " - ", report_type, " report -->\n",
          "Results from ", tolower(report_type), " ratings for ", domain_name, " are summarized below.\n"
        )
      } else {
        paste0(
          "<!-- Text content for ", domain_name, " -->\n",
          "Results from ", domain_name, " assessment are summarized below.\n"
        )
      }

      writeLines(text_content, text_file)
      message(paste("Generated text file:", text_file))
      return(text_file)
    },

    #' @description
    #' Generate domain QMD file following the working Academic Skills pattern
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_domain_qmd = function(domain_name = NULL, output_file = NULL) {
      if (is.null(domain_name)) {
        domain_name <- self$domains[1]
      }

      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_", tolower(self$pheno), ".qmd")
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
          # Determine if child or adult ADHD
          is_child <- any(grepl("child", tolower(self$domains))) ||
                     (!is.null(self$data) && any(grepl("child|adolescent", self$data$test_name, ignore.case = TRUE)))
          
          if (is_child) {
            return(self$generate_adhd_child_qmd(domain_name, output_file))
          } else {
            return(self$generate_adhd_adult_qmd(domain_name, output_file))
          }
        }
      }

      # Generate standard single-rater domain QMD
      return(self$generate_standard_qmd(domain_name, output_file))
    },

    #' @description
    #' Generate standard (single-rater) domain QMD file
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_standard_qmd = function(domain_name, output_file) {
      # Generate text file first
      text_file <- self$generate_text_file()
      
      # Get input file info
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Build QMD content following the exact Academic Skills pattern
      qmd_content <- paste0(
        "## ", domain_name, " {#sec-", tolower(self$pheno), "}\n\n",
        "{{< include ", basename(text_file), " >}}\n\n",
        
        "```{r}\n",
        "#| label: setup-", tolower(self$pheno), "\n",
        "#| include: false\n\n",
        
        "# Load packages\n",
        "suppressPackageStartupMessages({\n",
        "  library(tidyverse)\n",
        "  library(gt)\n",
        "  library(gtExtras)\n",
        "  library(glue)\n",
        "})\n\n",
        
        "# Source R6 classes\n",
        "source(here::here(\"R\", \"DomainProcessorR6.R\"))\n",
        "source(here::here(\"R\", \"NeuropsychResultsR6.R\"))\n",
        "source(here::here(\"R\", \"DotplotR6.R\"))\n",
        "source(here::here(\"R\", \"TableGTR6.R\"))\n",
        "source(here::here(\"R\", \"score_type_utils.R\"))\n",
        "source(here::here(\"R\", \"tidy_data.R\"))\n\n",
        
        "# Set domain parameters\n",
        "domains <- \"", domain_name, "\"\n",
        "pheno <- \"", tolower(self$pheno), "\"\n",
        "```\n\n",
        
        "```{r}\n",
        "#| label: data-", tolower(self$pheno), "\n",
        "#| include: false\n\n",
        
        "# Read and process data\n",
        "data <- readr::read_csv(\n",
        "  here::here(\"", input_path, "\"),\n",
        "  show_col_types = FALSE\n",
        ") |>\n",
        "  dplyr::filter(domain %in% domains) |>\n",
        "  dplyr::filter(!is.na(percentile))\n\n",
        
        "# Calculate z-scores if needed\n",
        "if (!\"z\" %in% names(data)) {\n",
        "  data <- data |>\n",
        "    dplyr::mutate(\n",
        "      z = qnorm(percentile / 100),\n",
        "      z = round(z, 2)\n",
        "    )\n",
        "}\n\n",
        
        "# Select relevant columns\n",
        "data <- data |>\n",
        "  dplyr::select(\n",
        "    test, test_name, scale, raw_score, score,\n",
        "    ci_95, percentile, range, domain, subdomain,\n",
        "    narrow, pass, verbal, timed, result, z\n",
        "  ) |>\n",
        "  dplyr::arrange(desc(percentile))\n",
        "```\n\n",
        
        "```{r}\n",
        "#| label: qtbl-", tolower(self$pheno), "\n",
        "#| include: false\n",
        "#| eval: true\n\n",
        
        "# Define score type footnotes\n",
        "fn_list <- list(\n",
        "  standard_score = \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\",\n",
        "  scaled_score = \"Scaled score: Mean = 10 [50th‰], SD ± 3 [16th‰, 84th‰]\",\n",
        "  t_score = \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\",\n",
        "  z_score = \"z-score: Mean = 0 [50th‰], SD ± 1 [16th‰, 84th‰]\",\n",
        "  raw_score = \"Raw score: Untransformed test score\",\n",
        "  base_rate = \"Base rate: Percentage of the normative sample at or below this score\"\n",
        ")\n\n",
        
        "# Determine score type groups based on test batteries\n",
        "test_names <- unique(data$test_name)\n",
        "grp_list <- list()\n",
        "source_note <- \"\"\n\n",
        
        "# Check for different score types\n",
        "if (any(grepl(\"WAIS|WISC|WPPSI|WJ|WIAT|KTEA\", test_names))) {\n",
        "  grp_list$standard_score <- test_names[grepl(\"WAIS|WISC|WPPSI|WJ|WIAT|KTEA\", test_names)]\n",
        "  source_note <- fn_list$standard_score\n",
        "}\n\n",
        
        "if (any(grepl(\"RBANS\", test_names))) {\n",
        "  # RBANS has both standard scores (indices) and scaled scores (subtests)\n",
        "  rbans_indices <- test_names[grepl(\"Index|Total\", test_names)]\n",
        "  rbans_subtests <- setdiff(test_names[grepl(\"RBANS\", test_names)], rbans_indices)\n",
        "  \n",
        "  if (length(rbans_indices) > 0) {\n",
        "    grp_list$standard_score <- c(grp_list$standard_score, rbans_indices)\n",
        "  }\n",
        "  if (length(rbans_subtests) > 0) {\n",
        "    grp_list$scaled_score <- rbans_subtests\n",
        "  }\n",
        "  \n",
        "  if (nchar(source_note) == 0) source_note <- fn_list$standard_score\n",
        "}\n\n",
        
        "# Create table\n",
        "table <- TableGTR6$new(\n",
        "  data = data,\n",
        "  pheno = pheno,\n",
        "  table_name = paste0(\"table_\", pheno),\n",
        "  source_note = source_note,\n",
        "  title = NULL,\n",
        "  fn_list = fn_list,\n",
        "  grp_list = grp_list,\n",
        "  vertical_padding = 0.0,\n",
        "  multiline = FALSE\n",
        ")\n\n",
        
        "# Build the table\n",
        "qtbl <- table$build_table()\n\n",
        
        "# Save as PNG and PDF\n",
        "gt::gtsave(\n",
        "  qtbl,\n",
        "  filename = here::here(\"figs\", paste0(\"_qtbl_\", pheno, \".png\")),\n",
        "  expand = 10\n",
        ")\n",
        "gt::gtsave(\n",
        "  qtbl,\n",
        "  filename = here::here(\"figs\", paste0(\"_qtbl_\", pheno, \".pdf\")),\n",
        "  expand = 10\n",
        ")\n",
        "```\n\n",
        
        "```{r}\n",
        "#| label: fig-", tolower(self$pheno), "\n",
        "#| include: false\n",
        "#| eval: true\n\n",
        
        "# Get plot title\n",
        "plot_title <- \"", private$get_default_plot_title(), "\"\n\n",
        
        "# Define colors\n",
        "colors <- list(\n",
        "  domain = \"#E89606\",\n",
        "  test = \"grey50\"\n",
        ")\n\n",
        
        "# Create dotplot\n",
        "dotplot <- DotplotR6$new(\n",
        "  data = data,\n",
        "  x_var = \"percentile\",\n",
        "  y_var = \"scale\",\n",
        "  domain = domains,\n",
        "  pheno = pheno,\n",
        "  colors = colors,\n",
        "  plot_title = plot_title,\n",
        "  width = 8,\n",
        "  height = 6\n",
        ")\n\n",
        
        "# Generate the plot\n",
        "fig <- dotplot$generate_plot()\n\n",
        
        "# Save the plot\n",
        "ggplot2::ggsave(\n",
        "  filename = here::here(\"figs\", paste0(\"_fig_\", pheno, \".png\")),\n",
        "  plot = fig,\n",
        "  width = 8,\n",
        "  height = 6,\n",
        "  dpi = 300,\n",
        "  bg = \"white\"\n",
        ")\n\n",
        
        "ggplot2::ggsave(\n",
        "  filename = here::here(\"figs\", paste0(\"_fig_\", pheno, \".pdf\")),\n",
        "  plot = fig,\n",
        "  width = 8,\n",
        "  height = 6,\n",
        "  bg = \"white\"\n",
        ")\n",
        "```\n\n",
        
        "```{=typst}\n",
        "#let domain(title: \"\", file_qtbl, file_fig) = [\n",
        "  == #title\n",
        "  #figure(\n",
        "    image(file_qtbl, width: 100%),\n",
        "    caption: figure.caption(\n",
        "      position: top,\n",
        "      [\n",
        "        #title\n",
        "      ],\n",
        "    ),\n",
        "    kind: \"qtbl\",\n",
        "    supplement: [Table],\n",
        "  )\n",
        "  #figure(\n",
        "    image(file_fig, width: 100%),\n",
        "    caption: figure.caption(\n",
        "      position: bottom,\n",
        "      [\n",
        "        #title\n",
        "      ],\n",
        "    ),\n",
        "    kind: \"image\",\n",
        "    supplement: [Figure],\n",
        "  )\n",
        "]\n\n",
        
        "#domain(\n",
        "  title: [", domain_name, "],\n",
        "  file_qtbl: \"figs/_qtbl_", tolower(self$pheno), ".png\",\n",
        "  file_fig: \"figs/_fig_", tolower(self$pheno), ".png\"\n",
        ")\n",
        "```\n"
      )

      # Write the QMD file
      writeLines(qmd_content, output_file)
      message(paste("Generated standard QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD adult QMD file
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_adhd_adult_qmd = function(domain_name, output_file) {
      # Generate text files for different raters
      self_text <- self$generate_text_file("self")
      observer_text <- self$generate_text_file("observer")

      qmd_content <- paste0(
        "## ", domain_name, " {#sec-adhd-adult}\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ", basename(self_text), " >}}\n\n",
        "### OBSERVER RATINGS\n\n",
        "{{< include ", basename(observer_text), " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated ADHD adult QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate ADHD child QMD file
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_adhd_child_qmd = function(domain_name, output_file) {
      # Generate text files for different raters
      self_text <- self$generate_text_file("self")
      parent_text <- self$generate_text_file("parent")
      teacher_text <- self$generate_text_file("teacher")

      qmd_content <- paste0(
        "```{=typst}\n== ", domain_name, "```\n\n",
        " {#sec-adhd-child}\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ", basename(self_text), " >}}\n\n",
        "### PARENT RATINGS\n\n",
        "{{< include ", basename(parent_text), " >}}\n\n",
        "### TEACHER RATINGS\n\n",
        "{{< include ", basename(teacher_text), " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated ADHD child QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion child QMD file
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_emotion_child_qmd = function(domain_name, output_file) {
      # Generate text files for different raters
      self_text <- self$generate_text_file("self")
      parent_text <- self$generate_text_file("parent")
      teacher_text <- self$generate_text_file("teacher")

      qmd_content <- paste0(
        "## ", domain_name, " {#sec-emotion-child}\n\n",
        "### SELF-REPORT\n\n",
        "{{< include ", basename(self_text), " >}}\n\n",
        "### PARENT RATINGS\n\n",
        "{{< include ", basename(parent_text), " >}}\n\n",
        "### TEACHER RATINGS\n\n",
        "{{< include ", basename(teacher_text), " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated emotion child QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Generate emotion adult QMD file
    #' @param domain_name Name of the domain
    #' @param output_file Output file path
    #' @return Path to generated QMD file
    generate_emotion_adult_qmd = function(domain_name, output_file) {
      # Generate text file
      text_file <- self$generate_text_file()

      qmd_content <- paste0(
        "## ", domain_name, " {#sec-emotion-adult}\n\n",
        "{{< include ", basename(text_file), " >}}\n\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated emotion adult QMD file:", output_file))
      return(output_file)
    },

    #' @description
    #' Run the complete processing pipeline
    #' @param generate_domain_files Whether to generate domain QMD files
    #' @return Invisibly returns self for method chaining
    process = function(generate_domain_files = TRUE) {
      # Run the complete pipeline
      self$load_data()
      self$filter_by_domain()
      self$select_columns()
      self$save_data()

      # Generate domain files if requested
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
        iq = "01", academics = "02", verbal = "03", spatial = "04",
        memory = "05", executive = "06", motor = "07", social = "08",
        adhd = "09", emotion = "10", adaptive = "11", daily_living = "12",
        validity = "13"
      )

      num <- domain_numbers[tolower(self$pheno)]
      if (is.na(num) || is.null(num)) "99" else num
    },

    # Get default plot title
    get_default_plot_title = function() {
      titles <- list(
        iq = "Intellectual and cognitive abilities represent an individual's capacity to think, reason, and solve problems.",
        academics = "Academic skills reflect the application of cognitive abilities to educational tasks.",
        verbal = "Verbal and language functioning refers to the ability to access and apply acquired word knowledge.",
        spatial = "Visuospatial abilities involve perceiving, analyzing, and mentally manipulating visual information.",
        memory = "Memory functions are crucial for learning, daily functioning, and cognitive processing.",
        executive = "Attentional and executive functions underlie most domains of cognitive performance.",
        motor = "Motor functions involve the planning and execution of voluntary movements.",
        social = "Social cognition encompasses the mental processes involved in perceiving, interpreting, and responding to social information.",
        adhd = "ADHD assessment evaluates attention, hyperactivity, and impulsivity patterns.",
        emotion = "Emotional and behavioral functioning assessment provides insights into psychological well-being."
      )

      result <- titles[[tolower(self$pheno)]]
      if (is.null(result)) {
        paste("This section presents results from the", self$domains[1], "domain assessment.")
      } else {
        result
      }
    }
  )
)