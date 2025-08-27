#' @title DomainProcessorR6
#' @description R6 class for processing neuropsychological domain data
#' @field domains Character vector of domain names to process
#' @field pheno The phenotype identifier (e.g., "emotion", "adhd")
#' @field input_file Path to the input data file
#' @field output_dir Directory path for output files (default: "data")
#' @field number Numeric identifier for domain ordering
#' @field data Data frame containing the processed neuropsychological data
#' @field dirs List containing directory paths for output organization
#' @export
DomainProcessorR6 <- R6::R6Class(
  "DomainProcessorR6",
  public = list(
    domains = NULL,
    pheno = NULL,
    input_file = NULL,
    output_dir = "data",
    number = NULL,
    data = NULL,
    dirs = NULL,

    #' @description
    #' Initialize a new DomainProcessorR6 object
    #' @param domains Character scalar or vector of domain names.
    #' @param pheno A data.frame or tibble.
    #' @param input_file Path to a file.
    #' @param output_dir Path to an output directory.
    #' @param number Numeric index or identifier.
    #' @param output_base Base directory path for output files
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

    #' @description Save a plot to file
    #' @param plot The plot object to save
    #' @param filename The filename to save the plot as
    #' @return List with paths to saved PNG and PDF files
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
        "test_type",
        "score_type",
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
    #' Check if a specific rater has data
    #' @param rater The rater type to check for ("self", "parent", "teacher", "observer")
    #' @return Logical indicating if the rater has data
    check_rater_data_exists = function(rater) {
      if (is.null(self$data) || nrow(self$data) == 0) {
        return(FALSE)
      }

      # For self-report data, check test variable for specific tests
      if (rater == "self") {
        self_report_tests <- c(
          "basc3_srp_child",
          "basc3_srp_adolescent",
          "basc3_srp_college",
          "brown_efa_self",
          "caars_self",
          "caars2_self",
          "cefi_self_12-18",
          "cefi_self",
          "conners4_self",
          "pai_adol_clinical",
          "pai_adol_validity",
          "pai_adol",
          "pai_clinical",
          "pai_inatt",
          "pai_validity",
          "pai",
          "mmpi3"
        )
        return(any(self$data$test %in% self_report_tests))
      }

      # For parent report data, check test variable for specific tests
      if (rater == "parent") {
        parent_report_tests <- c(
          "basc3_prs_preschool",
          "basc3_prs_child",
          "basc3_prs_adolescent",
          "basc3_prs_college",
          "cefi_parent_5-18",
          "brown_efa_parent",
          "conners4_parent"
        )
        return(any(self$data$test %in% parent_report_tests))
      }

      # For teacher report data, check test variable for specific tests
      if (rater == "teacher") {
        teacher_report_tests <- c(
          "basc3_trs_preschool",
          "basc3_trs_child",
          "basc3_trs_adolescent",
          "basc3_trs_college",
          "cefi_teacher_5-18",
          "brown_efa_teacher",
          "conners4_teacher"
        )
        return(any(self$data$test %in% teacher_report_tests))
      }

      # For other raters (observer), check test variable for specific tests
      if (rater == "observer") {
        observer_tests <- c(
          "caars_observer",
          "cefi_observer",
          "caars2_observer",
          "brown_efa_observer"
        )
        return(any(self$data$test %in% observer_tests))
      }

      # Default case
      return(FALSE)
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

      # Check domains first (most reliable method)
      child_domain_patterns <- c(
        "Behavioral/Emotional/Social",
        "Personality Disorders",
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      )

      adult_domain_patterns <- c(
        "Emotional/Behavioral/Personality",
        "Personality Disorders",
        "Psychiatric Disorders",
        "Psychosocial Problems",
        "Substance Use"
      )

      # Check if any child-specific domains are present
      child_domain_match <- any(sapply(
        child_domain_patterns,
        function(pattern) {
          any(grepl(pattern, self$domains, fixed = TRUE))
        }
      ))

      # Check if any adult-specific domains are present
      adult_domain_match <- any(sapply(
        adult_domain_patterns,
        function(pattern) {
          any(grepl(pattern, self$domains, fixed = TRUE))
        }
      ))

      # If we have clear domain matches, use those
      if (child_domain_match && !adult_domain_match) {
        return("child")
      } else if (adult_domain_match && !child_domain_match) {
        return("adult")
      }

      # If domains are ambiguous, check the data if available
      if (!is.null(self$data) && nrow(self$data) > 0) {
        # Check for child-specific test patterns
        child_test_patterns <- c(
          "BAI",
          "BASC-3 PRS Adolescent",
          "BASC-3 PRS Child",
          "BASC-3 PRS Preschool",
          "BASC-3 SRP Adolescent",
          "BASC-3 SRP Child",
          "BASC-3 TRS Child",
          "BASC-3 TRS Preschool",
          "BASC-3 TRS Adolescent",
          "BDI-2",
          "Rating Scale of Impairment",
          "PAI Adolescent",
          "MMPI-A"
        )

        adult_test_patterns <- c("BAI", "BDI-2", "MMPI-3", "PAI")

        # Check test names for age indicators
        if ("test_name" %in% names(self$data)) {
          test_names <- unique(self$data$test_name)

          child_test_match <- any(sapply(
            child_test_patterns,
            function(pattern) {
              any(grepl(pattern, test_names, ignore.case = TRUE))
            }
          ))

          adult_test_match <- any(sapply(
            adult_test_patterns,
            function(pattern) {
              any(grepl(pattern, test_names, ignore.case = TRUE))
            }
          ))

          if (child_test_match && !adult_test_match) {
            return("child")
          } else if (adult_test_match && !child_test_match) {
            return("adult")
          }
        }

        # Check for rater types (children typically have parent/teacher raters)
        if ("rater" %in% names(self$data)) {
          raters <- unique(self$data$rater)
          has_parent_teacher <- any(c("parent", "teacher") %in% tolower(raters))
          has_only_self <- length(raters) == 1 && "self" %in% tolower(raters)

          if (has_parent_teacher) {
            return("child")
          } else if (has_only_self) {
            return("adult")
          }
        }
      }

      # If we have both child and adult domain patterns, or can't determine from data,
      # prefer child as default (more common in neuropsych practice)
      if (child_domain_match || length(self$domains) > 1) {
        return("child")
      }

      # Final fallback
      return("child")
    },

    #' @description
    #' Generate domain QMD file (unified method)
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

      # Determine output file
      if (is.null(output_file)) {
        # Handle special cases
        if (tolower(self$pheno) == "emotion") {
          emotion_type <- self$detect_emotion_type()
          output_file <- paste0(
            "_02-",
            self$number,
            "_emotion_",
            emotion_type,
            ".qmd"
          )
        } else if (tolower(self$pheno) == "adhd") {
          age_type <- if (self$detect_age_group() == "child") {
            "child"
          } else {
            "adult"
          }
          output_file <- paste0("_02-", self$number, "_adhd_", age_type, ".qmd")
        } else {
          output_file <- paste0(
            "_02-",
            self$number,
            "_",
            tolower(self$pheno),
            ".qmd"
          )
        }
      }

      # Generate text files first
      text_files <- self$generate_domain_text_qmd()

      # Build QMD content using template
      qmd_content <- private$build_unified_qmd_template(domain_name, text_files)

      # Write file
      writeLines(qmd_content, output_file)
      message(paste("Generated domain file:", output_file))

      return(output_file)
    },

    #' @description
    #' Generate the paired narrative text .qmd file(s) for this domain.
    #' @details Creates minimal placeholder file(s) containing:
    #'
    #' <summary>
    #'
    #' </summary>
    #'
    #' If a file already exists, it is left unchanged. For multi-rater child
    #' emotion/ADHD domains, creates one file per available rater.
    #' @return Invisibly returns a character vector of the path(s) created or found.
    generate_domain_text_qmd = function() {
      create_if_missing <- function(f) {
        if (!file.exists(f)) {
          writeLines(
            c("<summary>", "", "</summary>", ""),
            con = f,
            useBytes = TRUE
          )
        }
        f
      }

      ph <- tolower(self$pheno)
      created <- character()

      if (ph == "emotion") {
        etype <- tryCatch(self$detect_emotion_type(), error = function(e) NULL)
        if (is.null(etype)) {
          etype <- "adult"
        }
        if (etype == "child") {
          raters <- c("self", "parent", "teacher")
          for (r in raters) {
            if (self$check_rater_data_exists(r)) {
              f <- paste0(
                "_02-",
                self$number,
                "_emotion_child_text_",
                r,
                ".qmd"
              )
              created <- c(created, create_if_missing(f))
            }
          }
        } else {
          f <- paste0("_02-", self$number, "_emotion_adult_text.qmd")
          created <- c(created, create_if_missing(f))
        }
        return(invisible(created))
      }

      if (ph == "adhd") {
        is_child <- any(grepl("child", tolower(self$domains))) ||
          (!is.null(self$data) &&
            any(grepl(
              "child|adolescent",
              self$data$test_name,
              ignore.case = TRUE
            )))

        if (is_child) {
          raters <- c("self", "parent", "teacher")
          for (r in raters) {
            if (self$check_rater_data_exists(r)) {
              f <- paste0("_02-", self$number, "_adhd_child_text_", r, ".qmd")
              created <- c(created, create_if_missing(f))
            }
          }
        } else {
          raters <- c("self", "observer")
          for (r in raters) {
            if (self$check_rater_data_exists(r)) {
              f <- paste0("_02-", self$number, "_adhd_adult_text_", r, ".qmd")
              created <- c(created, create_if_missing(f))
            }
          }
        }
        return(invisible(created))
      }

      # Standard/other domains: single text file
      f <- paste0("_02-", self$number, "_", ph, "_text.qmd")
      created <- c(created, create_if_missing(f))
      invisible(created)
    },

    #' @description
    #' Generate standard domain QMD
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
      # Ensure text files exist
      self$generate_domain_text_qmd()

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

        "# R6 classes are available through the neuro2 package\n",
        "# which is already loaded in the parent template\n\n",

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

        # Replace the entire scale variable section (around lines 575-595) with:

        "# Load internal data to get standardized scale names\n",
        if (tolower(self$pheno) == "emotion") {
          emotion_type <- self$detect_emotion_type()
          paste0(
            "scale_var_name <- \"scales_",
            tolower(self$pheno),
            "_",
            emotion_type,
            "\"\n",
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
            "}\n\n"
          )
        } else {
          paste0(
            "scale_var_name <- \"scales_",
            tolower(self$pheno),
            "\"\n",
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
            "}\n\n"
          )
        },

        "# Filter the data directly\n",
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

        # Replace this section in generate_standard_qmd method:

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

        "# Load plot title from sysdata.rda or use default\n",
        "plot_title_var_name <- paste0(\"plot_title_\", \"",
        tolower(self$pheno),
        "\")\n",
        "sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "if (file.exists(sysdata_path)) {\n",
        "  load(sysdata_path)\n",
        "}\n\n",

        "# Always create the plot title variable\n",
        "if (exists(plot_title_var_name)) {\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- get(plot_title_var_name)\n",
        "} else {\n",
        "  # Use a sensible default based on the domain\n",
        "  plot_title_",
        tolower(self$pheno),
        " <- \"",
        domain_name,
        " scores reflect performance across multiple cognitive and behavioral measures.\"\n",
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
        "// #let file_qtbl = \"table_",
        tolower(self$pheno),
        ".png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_subdomain.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
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
      message(paste("Generated standard QMD file:", output_file))
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
      # Fix the output filename to include "_adult"
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_adhd_adult.qmd")
      } else {
        if (!grepl("_adult", output_file)) {
          output_file <- gsub("_adhd", "_adhd_adult", output_file)
        }
      }

      # Create text files for different raters
      self_text <- paste0("_02-", self$number, "_adhd_adult_text_self.qmd")
      observer_text <- paste0(
        "_02-",
        self$number,
        "_adhd_adult_text_observer.qmd"
      )

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Build complete QMD content with all R processing blocks
      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-adhd-adult>\n",
        "```\n\n",

        # Setup R code block
        "```{r}\n",
        "#| label: setup-adhd-adult\n",
        "#| include: false\n\n",

        "# R6 classes are available through the neuro2 package\n",
        "# which is already loaded in the parent template\n\n",

        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",

        "# Target phenotype\n",
        "pheno <- \"adhd\"\n\n",

        "# Create R6 processor\n",
        "processor_adhd <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "# Load and process data\n",
        "processor_adhd$load_data()\n",
        "processor_adhd$filter_by_domain()\n\n",

        "# Create the data object with original name for compatibility\n",
        "adhd <- processor_adhd$data\n\n",

        "# Process and export data using R6\n",
        "processor_adhd$select_columns()\n",
        "processor_adhd$save_data()\n\n",

        "# Update the original object\n",
        "adhd <- processor_adhd$data\n\n",

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

        "# Filter the data directly\n",
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
        "data_adhd <- filter_data(data = adhd, domain = domains, scale = scales)\n",
        "```\n\n"
      )

      # Add text processing sections for each available rater
      raters <- c("self", "observer")
      text_files <- c(self_text, observer_text)
      rater_names <- c("SELF-REPORT", "OBSERVER RATINGS")

      for (i in seq_along(raters)) {
        rater <- raters[i]
        text_file <- text_files[i]
        section_name <- rater_names[i]

        if (self$check_rater_data_exists(rater)) {
          qmd_content <- paste0(
            qmd_content,
            "### ",
            section_name,
            "\n\n",
            "{{< include ",
            text_file,
            " >}}\n\n",

            "```{r}\n",
            "#| label: text-adhd-adult-",
            rater,
            "\n",
            "#| cache: true\n",
            "#| include: false\n",
            "#| results: asis\n\n",

            "# Filter data for this rater\n",
            "data_adhd_",
            rater,
            " <- data_adhd\n",
            "if (\"rater\" %in% names(data_adhd_",
            rater,
            ")) {\n",
            "  data_adhd_",
            rater,
            " <- data_adhd_",
            rater,
            "[data_adhd_",
            rater,
            "$rater == \"",
            rater,
            "\", ]\n",
            "}\n\n",

            "# Generate text using R6 class\n",
            "if (nrow(data_adhd_",
            rater,
            ") > 0) {\n",
            "  results_processor_",
            rater,
            " <- NeuropsychResultsR6$new(\n",
            "    data = data_adhd_",
            rater,
            ",\n",
            "    file = \"",
            text_file,
            "\"\n",
            "  )\n",
            "  results_processor_",
            rater,
            "$process()\n",
            "}\n",
            "```\n\n"
          )
        }
      }

      # Add table generation and plot code
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-adhd-adult\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_adhd_adult\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_adhd)\n\n",

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
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "}\n\n",

        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",

        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",

        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_adhd,\n",
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
        "#| label: fig-adhd-adult-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\"z_mean_subdomain\" %in% names(data_adhd) && \"subdomain\" %in% names(data_adhd)) {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_adhd,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_adhd_adult_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_adhd\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_adhd <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_adhd <- \"",
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        "```{r}\n",
        "#| label: fig-adhd-adult-narrow\n",
        "#| include: false\n\n",

        "# Create narrow plot using R6 DotplotR6\n",
        "if (\"z_mean_narrow\" %in% names(data_adhd) && \"narrow\" %in% names(data_adhd)) {\n",
        "  dotplot_narrow <- DotplotR6$new(\n",
        "    data = data_adhd,\n",
        "    x = \"z_mean_narrow\",\n",
        "    y = \"narrow\",\n",
        "    filename = here::here(\"fig_adhd_adult_narrow.svg\")\n",
        "  )\n",
        "  dotplot_narrow$create_plot()\n",
        "} else {\n",
        "  warning(\"Narrow plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_adhd\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_adhd <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_adhd <- \"",
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
        "        [`{r} plot_title_adhd`],\n",
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
        "// #let file_qtbl = \"table_adhd_adult.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_adhd_adult_subdomain.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_adhd_adult.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_adhd_adult_narrow.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated complete ADHD adult QMD file:", output_file))
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
      # Fix the output filename to include "_child"
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_adhd_child.qmd")
      } else {
        if (!grepl("_child", output_file)) {
          output_file <- gsub("_adhd", "_adhd_child", output_file)
        }
      }

      # Create text files for different raters
      self_text <- paste0("_02-", self$number, "_adhd_child_text_self.qmd")
      parent_text <- paste0("_02-", self$number, "_adhd_child_text_parent.qmd")
      teacher_text <- paste0(
        "_02-",
        self$number,
        "_adhd_child_text_teacher.qmd"
      )

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Build complete QMD content with all R processing blocks
      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        domain_name,
        "\n",
        "<sec-adhd-child>\n",
        "```\n\n",

        # Setup R code block
        "```{r}\n",
        "#| label: setup-adhd-child\n",
        "#| include: false\n\n",

        "# R6 classes are available through the neuro2 package\n",
        "# which is already loaded in the parent template\n\n",

        "# Filter by domain\n",
        "domains <- c(\"",
        domain_name,
        "\")\n\n",

        "# Target phenotype\n",
        "pheno <- \"adhd\"\n\n",

        "# Create R6 processor\n",
        "processor_adhd <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "# Load and process data\n",
        "processor_adhd$load_data()\n",
        "processor_adhd$filter_by_domain()\n\n",

        "# Create the data object with original name for compatibility\n",
        "adhd <- processor_adhd$data\n\n",

        "# Process and export data using R6\n",
        "processor_adhd$select_columns()\n",
        "processor_adhd$save_data()\n\n",

        "# Update the original object\n",
        "adhd <- processor_adhd$data\n\n",

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

        "# Filter the data directly\n",
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
        "data_adhd <- filter_data(data = adhd, domain = domains, scale = scales)\n",
        "```\n\n"
      )

      # Add text processing sections for each available rater
      raters <- c("self", "parent", "teacher")
      text_files <- c(self_text, parent_text, teacher_text)
      rater_names <- c("SELF-REPORT", "PARENT RATINGS", "TEACHER RATINGS")

      for (i in seq_along(raters)) {
        rater <- raters[i]
        text_file <- text_files[i]
        section_name <- rater_names[i]

        if (self$check_rater_data_exists(rater)) {
          qmd_content <- paste0(
            qmd_content,
            "### ",
            section_name,
            "\n\n",
            "{{< include ",
            text_file,
            " >}}\n\n",

            "```{r}\n",
            "#| label: text-adhd-child-",
            rater,
            "\n",
            "#| cache: true\n",
            "#| include: false\n",
            "#| results: asis\n\n",

            "# Filter data for this rater\n",
            "data_adhd_",
            rater,
            " <- data_adhd\n",
            "if (\"rater\" %in% names(data_adhd_",
            rater,
            ")) {\n",
            "  data_adhd_",
            rater,
            " <- data_adhd_",
            rater,
            "[data_adhd_",
            rater,
            "$rater == \"",
            rater,
            "\", ]\n",
            "}\n\n",

            "# Generate text using R6 class\n",
            "if (nrow(data_adhd_",
            rater,
            ") > 0) {\n",
            "  results_processor_",
            rater,
            " <- NeuropsychResultsR6$new(\n",
            "    data = data_adhd_",
            rater,
            ",\n",
            "    file = \"",
            text_file,
            "\"\n",
            "  )\n",
            "  results_processor_",
            rater,
            "$process()\n",
            "}\n",
            "```\n\n"
          )
        }
      }

      # Add table generation and plot code (same structure as emotion domain)
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-adhd-child\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_adhd_child\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_adhd)\n\n",

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
        "if (\"standard_score\" %in% unique_score_types) {\n",
        "  fn_list$standard_score <- \"Standard score: Mean = 100 [50th‰], SD ± 15 [16th‰, 84th‰]\"\n",
        "}\n\n",

        "# Create groups based on test names that use each score type\n",
        "grp_list <- score_types_list\n\n",

        "# Define which groups support which score types (for dynamic footnotes)\n",
        "dynamic_grp <- score_types_list\n\n",

        "# Default source note if no score types are found\n",
        "if (length(fn_list) == 0) {\n",
        "  source_note <- \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_adhd,\n",
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
        "#| label: fig-adhd-child-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\"z_mean_subdomain\" %in% names(data_adhd) && \"subdomain\" %in% names(data_adhd)) {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_adhd,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_adhd_child_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_adhd\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_adhd <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_adhd <- \"",
        domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        "```{r}\n",
        "#| label: fig-adhd-child-narrow\n",
        "#| include: false\n\n",

        "# Create narrow plot using R6 DotplotR6\n",
        "if (\"z_mean_narrow\" %in% names(data_adhd) && \"narrow\" %in% names(data_adhd)) {\n",
        "  dotplot_narrow <- DotplotR6$new(\n",
        "    data = data_adhd,\n",
        "    x = \"z_mean_narrow\",\n",
        "    y = \"narrow\",\n",
        "    filename = here::here(\"fig_adhd_child_narrow.svg\")\n",
        "  )\n",
        "  dotplot_narrow$create_plot()\n",
        "} else {\n",
        "  warning(\"Narrow plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_adhd\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_adhd <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_adhd <- \"",
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
        "        [`{r} plot_title_adhd`],\n",
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
        "// #let file_qtbl = \"table_adhd_child.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_adhd_child_subdomain.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "#let file_qtbl = \"table_adhd_child.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_adhd_child_narrow.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated complete ADHD child QMD file:", output_file))
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
      # Fix the output filename to include "_child"
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_emotion_child.qmd")
      } else {
        # Ensure the filename includes "_child"
        if (!grepl("_child", output_file)) {
          output_file <- gsub("_emotion", "_emotion_child", output_file)
        }
      }

      # Use correct header for child emotion domain
      correct_domain_name <- "Behavioral/Emotional/Social"

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

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Multiple domains for emotion (based on master template)
      multiple_domains <- c(
        "Behavioral/Emotional/Social",
        "Emotional/Behavioral/Personality",
        "Psychiatric Symptoms",
        "Substance Use",
        "Personality Disorders",
        "Psychosocial Problems"
      )

      # Start building QMD content with complete R processing blocks
      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        correct_domain_name,
        "\n",
        "<sec-emotion-child>\n",
        "```\n\n",

        # Setup R code block
        "```{r}\n",
        "#| label: setup-emotion-child\n",
        "#| include: false\n\n",

        "# R6 classes are available through the neuro2 package\n",
        "# which is already loaded in the parent template\n\n",

        "# Filter by domain\n",
        "domains <- c(\n",
        paste0("  \"", multiple_domains, "\"", collapse = ",\n"),
        "\n)\n\n",

        "# Target phenotype\n",
        "pheno <- \"emotion\"\n\n",

        "# Create R6 processor\n",
        "processor_emotion <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "# Load and process data\n",
        "processor_emotion$load_data()\n",
        "processor_emotion$filter_by_domain()\n\n",

        "# Create the data object with original name for compatibility\n",
        "emotion <- processor_emotion$data\n\n",

        "# Process and export data using R6\n",
        "processor_emotion$select_columns()\n",
        "processor_emotion$save_data()\n\n",

        "# Update the original object\n",
        "emotion <- processor_emotion$data\n\n",

        "# Load internal data to get standardized scale names\n",
        "scale_var_name <- paste0(\"scales_\", tolower(pheno), \"_child\")\n",
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

        "# Filter the data directly\n",
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
        "data_emotion <- filter_data(data = emotion, domain = domains, scale = scales)\n",
        "```\n\n"
      )

      # Add separate R code blocks for each rater following the master template
      # SELF-REPORT TEXT PROCESSING
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: text-emotion-child-self\n",
        "#| cache: true\n",
        "#| include: false\n",
        "#| results: asis\n\n",

        "# Filter data for this rater\n",
        "data_emotion_self <- data_emotion\n",
        "if (\"rater\" %in% names(data_emotion_self)) {\n",
        "  data_emotion_self <- data_emotion_self[data_emotion_self$rater == \"self\", ]\n",
        "}\n\n",

        "# Generate text using R6 class\n",
        "if (nrow(data_emotion_self) > 0) {\n",
        "  results_processor_self <- NeuropsychResultsR6$new(\n",
        "    data = data_emotion_self,\n",
        "    file = \"",
        self_text,
        "\"\n",
        "  )\n",
        "  results_processor_self$process()\n",
        "}\n",
        "```\n\n",

        # PARENT TEXT PROCESSING
        "```{r}\n",
        "#| label: text-emotion-child-parent\n",
        "#| cache: true\n",
        "#| include: false\n",
        "#| results: asis\n\n",

        "# Filter data for this rater\n",
        "data_emotion_parent <- data_emotion\n",
        "if (\"rater\" %in% names(data_emotion_parent)) {\n",
        "  data_emotion_parent <- data_emotion_parent[\n",
        "    data_emotion_parent$rater == \"parent\",\n",
        "  ]\n",
        "}\n\n",

        "# Generate text using R6 class\n",
        "if (nrow(data_emotion_parent) > 0) {\n",
        "  results_processor_parent <- NeuropsychResultsR6$new(\n",
        "    data = data_emotion_parent,\n",
        "    file = \"",
        parent_text,
        "\"\n",
        "  )\n",
        "  results_processor_parent$process()\n",
        "}\n",
        "```\n\n",

        # TEACHER TEXT PROCESSING (with eval: false)
        "```{r}\n",
        "#| label: text-emotion-child-teacher\n",
        "#| cache: true\n",
        "#| include: false\n",
        "#| results: asis\n",
        "#| eval: false\n\n",

        "# Filter data for this rater\n",
        "data_emotion_teacher <- data_emotion\n",
        "if (\"rater\" %in% names(data_emotion_teacher)) {\n",
        "  data_emotion_teacher <- data_emotion_teacher[\n",
        "    data_emotion_teacher$rater == \"teacher\",\n",
        "  ]\n",
        "}\n\n",

        "# Generate text using R6 class\n",
        "if (nrow(data_emotion_teacher) > 0) {\n",
        "  results_processor_teacher <- NeuropsychResultsR6$new(\n",
        "    data = data_emotion_teacher,\n",
        "    file = \"",
        teacher_text,
        "\"\n",
        "  )\n",
        "  results_processor_teacher$process()\n",
        "}\n",
        "```\n\n"
      )

      # Add separate table generation for each rater
      # SELF TABLE
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-emotion-child-self\n",
        "#| dev: tikz\n",
        "#| fig-process: pdf2png\n",
        "#| include: false\n",
        "#| eval: true\n",
        "options(tikzDefaultEngine = \"xetex\")\n\n",

        "# Table parameters\n",
        "table_name <- \"table_emotion_child_self\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_emotion)\n\n",

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
        "  source_note <- \"T score: Mean = 50 [50th], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_emotion_self,\n",
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
        "```\n\n"
      )

      # PARENT TABLE
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-emotion-child-parent\n",
        "#| dev: tikz\n",
        "#| fig-process: pdf2png\n",
        "#| include: false\n",
        "#| eval: true\n",
        "options(tikzDefaultEngine = \"xetex\")\n\n",

        "# Table parameters\n",
        "table_name <- \"table_emotion_child_parent\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_emotion)\n\n",

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
        "  source_note <- \"T score: Mean = 50 [50th], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_emotion_parent,\n",
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
        "```\n\n"
      )

      # TEACHER TABLE (with eval: false)
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: qtbl-emotion-child-teacher\n",
        "#| dev: tikz\n",
        "#| fig-process: pdf2png\n",
        "#| include: false\n",
        "#| eval: false\n",
        "options(tikzDefaultEngine = \"xetex\")\n\n",

        "# Table parameters\n",
        "table_name <- \"table_emotion_child_teacher\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_emotion)\n\n",

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
        "  source_note <- \"T score: Mean = 50 [50th], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_emotion_teacher,\n",
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
        "```\n\n"
      )

      # Add separate figure generation for each rater
      # SELF FIGURE
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-emotion-child-self-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\n",
        "  \"z_mean_subdomain\" %in%\n",
        "    names(data_emotion_self) &&\n",
        "    \"subdomain\" %in% names(data_emotion_self)\n",
        ") {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_emotion_self,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_emotion_child_self_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_emotion_child_self\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_emotion <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_emotion <- \"Behavioral/Emotional/Social self-report scores ... \"\n",
        "}\n",
        "```\n\n"
      )

      # PARENT FIGURE
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-emotion-child-parent-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\n",
        "  \"z_mean_subdomain\" %in%\n",
        "    names(data_emotion_parent) &&\n",
        "    \"subdomain\" %in% names(data_emotion_parent)\n",
        ") {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_emotion_parent,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_emotion_child_parent_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_emotion_child_parent\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_emotion <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_emotion <- \"Behavioral/Emotional/Social parent-report scores ... \"\n",
        "}\n",
        "```\n\n"
      )

      # TEACHER FIGURE (with eval: false)
      qmd_content <- paste0(
        qmd_content,
        "```{r}\n",
        "#| label: fig-emotion-child-teacher-subdomain\n",
        "#| include: false\n",
        "#| eval: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\n",
        "  \"z_mean_subdomain\" %in%\n",
        "    names(data_emotion_teacher) &&\n",
        "    \"subdomain\" %in% names(data_emotion_teacher)\n",
        ") {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_emotion_teacher,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_emotion_child_teacher_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_emotion_child_teacher\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_emotion <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_emotion <- \"Behavioral/Emotional/Social teacher-report scores ... \"\n",
        "}\n",
        "```\n\n"
      )

      # Add the section structure with text includes and Typst code matching the master
      qmd_content <- paste0(
        qmd_content,
        "### SELF-REPORT\n\n",
        "{{< include ",
        self_text,
        " >}}\n\n",

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
        "        [`{r} plot_title_emotion_child_self`],\n",
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
        "#let title = \"Behavioral/Emotional/Social\"\n\n",
        "// Define the file name of the table\n",
        "// #let file_qtbl = \"table_emotion_child_self.png\"\n\n",
        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_emotion_child_self_subdomain.svg\"\n\n",
        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "### PARENT RATINGS\n\n",
        "{{< include ",
        parent_text,
        " >}}\n\n",

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
        "        [`{r} plot_title_emotion_child_parent`],\n",
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
        "#let title = \"Behavioral/Emotional/Social\"\n\n",
        "// Define the file name of the table\n",
        "// #let file_qtbl = \"table_emotion_child_parent.png\"\n\n",
        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_emotion_child_parent_subdomain.svg\"\n\n",
        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "<!-- ### TEACHER RATINGS-->\n\n",
        "<!-- {{< include ",
        teacher_text,
        " >}} -->\n\n",

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
        "        [`{r} plot_title_emotion_child_teacher`],\n",
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
        "#let title = \"Behavioral/Emotional/Social\"\n\n",
        "// Define the file name of the table\n",
        "// #let file_qtbl = \"table_emotion_child_teacher.png\"\n\n",
        "// Define the file name of the figure\n",
        "// #let file_fig = \"fig_emotion_child_teacher_subdomain.svg\"\n\n",
        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated complete emotion child QMD file:", output_file))
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
      # Fix the output filename to include "_adult"
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_emotion_adult.qmd")
      } else {
        # Ensure the filename includes "_adult"
        if (!grepl("_adult", output_file)) {
          output_file <- gsub("_emotion", "_emotion_adult", output_file)
        }
      }

      # Use correct header for adult emotion domain
      correct_domain_name <- "Emotional/Behavioral/Personality"

      # Create text file for self-report (adults typically only have self-report)
      text_file <- paste0("_02-", self$number, "_emotion_adult_text.qmd")

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      # Build complete QMD content with all R processing blocks
      qmd_content <- paste0(
        "```{=typst}\n",
        "== ",
        correct_domain_name,
        "\n", # Use correct domain name for adult
        "<sec-emotion-adult>\n",
        "```\n\n",

        "{{< include ",
        text_file,
        " >}}\n\n",

        # Setup R code block
        "```{r}\n",
        "#| label: setup-emotion-adult\n",
        "#| include: false\n\n",

        "# R6 classes are available through the neuro2 package\n",
        "# which is already loaded in the parent template\n\n",

        "# Filter by domain\n",
        "domains <- c(\"",
        correct_domain_name,
        "\")\n\n",

        "# Target phenotype\n",
        "pheno <- \"emotion\"\n\n",

        "# Create R6 processor\n",
        "processor_emotion <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = pheno,\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "# Load and process data\n",
        "processor_emotion$load_data()\n",
        "processor_emotion$filter_by_domain()\n\n",

        "# Create the data object with original name for compatibility\n",
        "emotion <- processor_emotion$data\n\n",

        "# Process and export data using R6\n",
        "processor_emotion$select_columns()\n",
        "processor_emotion$save_data()\n\n",

        "# Update the original object\n",
        "emotion <- processor_emotion$data\n\n",

        "# Load internal data to get standardized scale names\n",
        "scale_var_name <- paste0(\"scales_\", tolower(pheno), \"_adult\")\n",
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

        "# Filter the data directly\n",
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
        "data_emotion <- filter_data(data = emotion, domain = domains, scale = scales)\n",
        "```\n\n",

        "```{r}\n",
        "#| label: text-emotion-adult\n",
        "#| cache: true\n",
        "#| include: true\n",
        "#| echo: false\n",
        "#| results: asis\n\n",

        "# Generate text using R6 class\n",
        "results_processor <- NeuropsychResultsR6$new(\n",
        "  data = data_emotion,\n",
        "  file = \"",
        text_file,
        "\"\n",
        ")\n",
        "results_processor$process()\n",
        "```\n\n",

        "```{r}\n",
        "#| label: qtbl-emotion-adult\n",
        "#| include: false\n\n",

        "# Table parameters\n",
        "table_name <- \"table_emotion_adult\"\n",
        "vertical_padding <- 0\n",
        "multiline <- TRUE\n\n",

        "# Get score types from the lookup table\n",
        "score_type_map <- get_score_types_from_lookup(data_emotion)\n\n",

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
        "  source_note <- \"T score: Mean = 50 [50th‰], SD ± 10 [16th‰, 84th‰]\"\n",
        "} else {\n",
        "  source_note <- NULL # No general source note when using footnotes\n",
        "}\n\n",

        "# Create table using our modified TableGTR6 R6 class\n",
        "table_gt <- TableGTR6$new(\n",
        "  data = data_emotion,\n",
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
        "#| label: fig-emotion-adult-subdomain\n",
        "#| include: false\n\n",

        "# Create subdomain plot using R6 DotplotR6\n",
        "if (\"z_mean_subdomain\" %in% names(data_emotion) && \"subdomain\" %in% names(data_emotion)) {\n",
        "  dotplot_subdomain <- DotplotR6$new(\n",
        "    data = data_emotion,\n",
        "    x = \"z_mean_subdomain\",\n",
        "    y = \"subdomain\",\n",
        "    filename = here::here(\"fig_emotion_adult_subdomain.svg\")\n",
        "  )\n",
        "  dotplot_subdomain$create_plot()\n",
        "} else {\n",
        "  warning(\"Subdomain plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_emotion\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_emotion <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_emotion <- \"",
        correct_domain_name,
        " scores ... \"\n",
        "}\n",
        "```\n\n",

        "```{r}\n",
        "#| label: fig-emotion-adult-narrow\n",
        "#| include: false\n\n",

        "# Create narrow plot using R6 DotplotR6\n",
        "if (\"z_mean_narrow\" %in% names(data_emotion) && \"narrow\" %in% names(data_emotion)) {\n",
        "  dotplot_narrow <- DotplotR6$new(\n",
        "    data = data_emotion,\n",
        "    x = \"z_mean_narrow\",\n",
        "    y = \"narrow\",\n",
        "    filename = here::here(\"fig_emotion_adult_narrow.svg\")\n",
        "  )\n",
        "  dotplot_narrow$create_plot()\n",
        "} else {\n",
        "  warning(\"Narrow plot cannot be created: missing required columns\")\n",
        "}\n\n",

        "# Load plot title from sysdata.rda\n",
        "plot_title_var <- \"plot_title_emotion\"\n",
        "if (!exists(plot_title_var)) {\n",
        "  sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "  if (file.exists(sysdata_path)) {\n",
        "    load(sysdata_path)\n",
        "  }\n",
        "}\n\n",

        "# Get the plot title or use default\n",
        "if (exists(plot_title_var)) {\n",
        "  plot_title_emotion <- get(plot_title_var)\n",
        "} else {\n",
        "  plot_title_emotion <- \"",
        correct_domain_name,
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
        "        [`{r} plot_title_emotion`],\n",
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
        correct_domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "// #let file_qtbl = \"table_emotion_adult.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_emotion_adult_subdomain.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        "```{=typst}\n",
        "// Define the title of the domain\n",
        "#let title = \"",
        correct_domain_name,
        "\"\n\n",

        "// Define the file name of the table\n",
        "// #let file_qtbl = \"table_emotion_adult.png\"\n\n",

        "// Define the file name of the figure\n",
        "#let file_fig = \"fig_emotion_adult_narrow.svg\"\n\n",

        "// The title is appended with ' Scores'\n",
        "// #domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n"
      )

      writeLines(qmd_content, output_file)
      message(paste("Generated complete emotion adult QMD file:", output_file))
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
    },

    build_unified_qmd_template = function(domain_name, text_files) {
      # Create the basic structure
      header <- paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "}\n\n"
      )

      # Handle multi-rater domains
      if (self$has_multiple_raters()) {
        return(private$build_multi_rater_template(domain_name, text_files))
      } else {
        return(private$build_single_rater_template(domain_name, text_files[1]))
      }
    },

    build_single_rater_template = function(domain_name, text_file) {
      paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "}\n\n",
        "{{< include ",
        text_file,
        " >}}\n\n",
        private$build_r_processing_block(),
        private$build_typst_display_block()
      )
    },

    build_multi_rater_template = function(domain_name, text_files) {
      # Build sections for each rater
      content <- paste0(
        "## ",
        domain_name,
        " {#sec-",
        tolower(self$pheno),
        "}\n\n"
      )

      rater_names <- c(
        "SELF-REPORT" = "self",
        "PARENT RATINGS" = "parent",
        "TEACHER RATINGS" = "teacher",
        "OBSERVER RATINGS" = "observer"
      )

      for (section_name in names(rater_names)) {
        rater <- rater_names[section_name]
        text_file <- grep(
          paste0("_", rater, "\\.qmd$"),
          text_files,
          value = TRUE
        )

        if (length(text_file) > 0 && self$check_rater_data_exists(rater)) {
          content <- paste0(
            content,
            "### ",
            section_name,
            "\n\n",
            "{{< include ",
            text_file,
            " >}}\n\n"
          )
        }
      }

      content <- paste0(
        content,
        private$build_r_processing_block(),
        private$build_typst_display_block()
      )

      return(content)
    },

    build_r_processing_block = function() {
      # Format domains properly as a vector if multiple
      domains_arg <- if (length(self$domains) == 1) {
        paste0("\"", self$domains, "\"")
      } else {
        paste0(
          "c(\n  ",
          paste0("\"", self$domains, "\"", collapse = ",\n  "),
          "\n)"
        )
      }

      # Get input file path
      input_path <- if (grepl("^data/", self$input_file)) {
        self$input_file
      } else {
        paste0("data/", basename(self$input_file))
      }

      paste0(
        # Setup block
        "```{r}\n",
        "#| label: setup-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n\n",

        "# Load required packages\n",
        "suppressPackageStartupMessages({\n",
        "  library(here)\n",
        "  library(tidyverse)\n",
        "  library(gt)\n",
        "  library(gtExtras)\n",
        "  library(neuro2)\n",
        "})\n\n",

        "# Define domains\n",
        "domains <- ",
        domains_arg,
        "\n\n",

        "# Load and process data\n",
        "processor <- DomainProcessorR6$new(\n",
        "  domains = domains,\n",
        "  pheno = \"",
        self$pheno,
        "\",\n",
        "  input_file = \"",
        input_path,
        "\"\n",
        ")\n\n",

        "processor$load_data()\n",
        "processor$filter_by_domain()\n",
        "processor$select_columns()\n\n",

        "# Main data object\n",
        tolower(self$pheno),
        "_data <- processor$data\n",
        "```\n\n",

        # Text generation block
        "```{r}\n",
        "#| label: text-",
        tolower(self$pheno),
        "\n",
        "#| cache: true\n",
        "#| include: false\n",
        "#| results: asis\n\n",

        "# Generate text using R6 class\n",
        "if (nrow(",
        tolower(self$pheno),
        "_data) > 0) {\n",
        "  results_processor <- NeuropsychResultsR6$new(\n",
        "    data = ",
        tolower(self$pheno),
        "_data,\n",
        "    file = \"_02-",
        self$number,
        "_",
        tolower(self$pheno),
        "_text.qmd\"\n",
        "  )\n",
        "  results_processor$process()\n",
        "}\n",
        "```\n\n",

        # Table generation block
        "```{r}\n",
        "#| label: qtbl-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n",
        "#| eval: true\n\n",

        "if (nrow(",
        tolower(self$pheno),
        "_data) > 0) {\n",
        "  # Generate table\n",
        "  table_",
        tolower(self$pheno),
        " <- TableGTR6$new(\n",
        "    data = ",
        tolower(self$pheno),
        "_data,\n",
        "    pheno = \"",
        self$pheno,
        "\",\n",
        "    table_name = \"table_",
        tolower(self$pheno),
        "\",\n",
        "    vertical_padding = 0\n",
        "  )\n",
        "  tbl <- table_",
        tolower(self$pheno),
        "$build_table()\n",
        "  table_",
        tolower(self$pheno),
        "$save_table(tbl, dir = here::here())\n",
        "}\n",
        "```\n\n",

        # Figure generation block
        "```{r}\n",
        "#| label: fig-",
        tolower(self$pheno),
        "\n",
        "#| include: false\n",
        "#| eval: true\n\n",

        "if (nrow(",
        tolower(self$pheno),
        "_data) > 0) {\n",
        "  # Generate figure\n",
        "  if (all(c(\"z_mean_subdomain\", \"subdomain\") %in% names(",
        tolower(self$pheno),
        "_data))) {\n",
        "    dotplot_",
        tolower(self$pheno),
        " <- DotplotR6$new(\n",
        "      data = ",
        tolower(self$pheno),
        "_data,\n",
        "      x = \"z_mean_subdomain\",\n",
        "      y = \"subdomain\",\n",
        "      filename = here::here(\"fig_",
        tolower(self$pheno),
        "_subdomain.svg\")\n",
        "    )\n",
        "    dotplot_",
        tolower(self$pheno),
        "$create_plot()\n",
        "  }\n",
        "}\n\n",

        private$get_plot_title_block(self$domains[1]),
        "```\n\n"
      )
    },

    # Replace the build_typst_display_block method in the private section with this:
    build_typst_display_block = function() {
      # Build complete Typst blocks with function definition and two figure displays
      paste0(
        # First block - subdomain figure
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
        "#let title = \"",
        self$domains[1],
        "\"\n\n",
        "#let file_qtbl = \"table_",
        tolower(self$pheno),
        ".png\"\n\n",
        "#let file_fig = \"fig_",
        tolower(self$pheno),
        "_subdomain.svg\"\n\n",
        "#domain(title: [#title Scores], file_qtbl, file_fig)\n",
        "```\n\n",

        # Second block - narrow figure (if applicable)
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
        self$domains[1],
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
    },
    # Add this to the private section of DomainProcessorR6:

    get_plot_title_block = function(domain_name) {
      pheno_lower <- tolower(self$pheno)

      # Default plot titles for each domain
      default_titles <- list(
        iq = "General cognitive ability reflects overall intellectual functioning across verbal and nonverbal domains.",
        academics = "Academic skills reflect the application of cognitive abilities to educational tasks.",
        verbal = "Verbal and language abilities support communication and verbal reasoning.",
        spatial = "Visual-spatial processing enables understanding of visual information and spatial relationships.",
        memory = "Memory functions support encoding, storage, and retrieval of information.",
        executive = "Executive functions coordinate attention, planning, and cognitive control.",
        motor = "Motor skills encompass fine and gross motor coordination and speed.",
        social = "Social cognition supports understanding of social situations and interpersonal interactions.",
        adhd = "ADHD symptoms impact attention, hyperactivity, and impulsivity across settings.",
        emotion = "Emotional and behavioral functioning reflects psychological adjustment and regulation.",
        adaptive = "Adaptive functioning encompasses practical skills for daily living.",
        daily_living = "Daily living skills support independence in everyday activities.",
        validity = "Performance and symptom validity indicators assess test engagement and response patterns."
      )

      default_title <- default_titles[[pheno_lower]] %||%
        paste0(
          domain_name,
          " scores reflect performance across multiple measures."
        )

      paste0(
        "# Ensure plot title exists\n",
        "plot_title_",
        pheno_lower,
        " <- \"",
        default_title,
        "\"\n",
        "\n",
        "# Try to load custom title from sysdata.rda\n",
        "sysdata_path <- here::here(\"R\", \"sysdata.rda\")\n",
        "if (file.exists(sysdata_path)) {\n",
        "  sysdata_env <- new.env()\n",
        "  load(sysdata_path, envir = sysdata_env)\n",
        "  custom_title_name <- paste0(\"plot_title_\", \"",
        pheno_lower,
        "\")\n",
        "  if (exists(custom_title_name, envir = sysdata_env)) {\n",
        "    plot_title_",
        pheno_lower,
        " <- get(custom_title_name, envir = sysdata_env)\n",
        "  }\n",
        "}\n"
      )
    }
  )
)
