#' Simplified DomainProcessorR6 Class
#'
#' A streamlined R6 class for processing neuropsychological domain data.
#' Uses a systematic lookup table approach instead of hardcoded logic.
#'
#' @field domains Character vector of domain names to process.
#' @field pheno Target phenotype identifier string.
#' @field input_file Path to the input data file.
#' @field output_dir Directory where output files will be saved.
#' @field data The loaded and processed data.
#' @field test_lookup Lookup table for tests, raters, and age groups.
#' @field age_group Age group for processing ("adult" or "child").
#'
#' @section Methods:
#' \describe{
#'   \item{\code{initialize(domains, pheno, input_file, output_dir, age_group, test_lookup_file)}}{Initialize the processor.}
#'   \item{\code{load_test_lookup(file)}}{Load the test lookup table from CSV.}
#'   \item{\code{get_available_raters()}}{Get available raters for the configured domains.}
#'   \item{\code{get_tests_for_rater(rater)}}{Get tests for a specific rater.}
#'   \item{\code{has_multiple_raters()}}{Check if domain has multiple raters.}
#'   \item{\code{load_data()}}{Load and filter data from file.}
#'   \item{\code{filter_by_domain()}}{Filter data by configured domains.}
#'   \item{\code{filter_by_rater(rater)}}{Filter data by specific rater.}
#'   \item{\code{select_columns()}}{Select relevant columns from data.}
#'   \item{\code{save_data(filename, format)}}{Save processed data to file.}
#'   \item{\code{generate_simple_domain_qmd(output_file)}}{Generate QMD file for single-rater domain.}
#'   \item{\code{generate_multi_rater_domain_qmd(output_file)}}{Generate QMD file for multi-rater domain.}
#'   \item{\code{get_domain_number()}}{Get domain number for file naming.}
#'   \item{\code{process(generate_qmd)}}{Main processing pipeline.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr filter select arrange desc distinct all_of group_by
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
    data = NULL,
    test_lookup = NULL,
    age_group = "adult",

    #' @description
    #' Initialize the processor
    #'
    #' @param domains Character vector of domain names to process.
    #' @param pheno Target phenotype identifier string.
    #' @param input_file Path to the input data file.
    #' @param output_dir Directory where output files will be saved.
    #' @param age_group Age group for processing ("adult" or "child").
    #' @param test_lookup_file Path to the test lookup CSV file.
    #' @return A new DomainProcessorR6 object
    initialize = function(
      domains,
      pheno,
      input_file,
      output_dir = "data",
      age_group = "adult",
      test_lookup_file = "test_testname_rater.csv"
    ) {
      self$domains <- domains
      self$pheno <- pheno
      self$input_file <- input_file
      self$output_dir <- output_dir
      self$age_group <- age_group

      # Load the test lookup table
      self$load_test_lookup(test_lookup_file)
    },

    #' @description
    #' Load the test lookup table from CSV
    #'
    #' @param file Path to the test lookup CSV file.
    #' @return invisible(self)
    load_test_lookup = function(file = "test_testname_rater.csv") {
      lookup_path <- here::here(file)
      if (!file.exists(lookup_path)) {
        # Try alternative locations
        alt_paths <- c(
          here::here("data-raw", file),
          here::here("inst", "extdata", file),
          file.path(system.file(package = "neuro2"), "extdata", file)
        )

        lookup_path <- NULL
        for (path in alt_paths) {
          if (file.exists(path)) {
            lookup_path <- path
            break
          }
        }

        if (is.null(lookup_path)) {
          stop("Test lookup file not found: ", file)
        }
      }

      self$test_lookup <- readr::read_csv(lookup_path, show_col_types = FALSE)
      message("Loaded test lookup with ", nrow(self$test_lookup), " tests")
    },

    #' @description
    #' Get available raters for this domain
    #' @return Character vector of available raters
    get_available_raters = function() {
      if (is.null(self$test_lookup)) {
        stop("Test lookup not loaded")
      }

      # Filter by domain and age group compatibility
      domain_tests <- self$test_lookup %>%
        dplyr::filter(
          domain %in% self$domains,
          age_group %in% c(self$age_group, "child/adult")
        )

      if (nrow(domain_tests) == 0) {
        warning(
          "No tests found for domain(s): ",
          paste(self$domains, collapse = ", "),
          " and age group: ",
          self$age_group
        )
        return(character(0))
      }

      # Return unique raters
      unique(domain_tests$rater)
    },

    #' @description
    #' Get tests for a specific rater
    #'
    #' @param rater The rater type (e.g., "self", "parent", "teacher", "observer").
    #' @return Character vector of test names
    get_tests_for_rater = function(rater) {
      self$test_lookup %>%
        dplyr::filter(
          domain %in% self$domains,
          rater == !!rater,
          age_group %in% c(self$age_group, "child/adult")
        ) %>%
        dplyr::pull(test)
    },

    #' @description
    #' Check if domain has multiple raters
    #' @return Logical value indicating if multiple raters exist
    has_multiple_raters = function() {
      raters <- self$get_available_raters()
      length(raters) > 1
    },

    #' @description
    #' Load and filter data
    #' @return invisible(self)
    load_data = function() {
      if (!is.null(self$data)) {
        message("Data already loaded, skipping file read.")
        return(invisible(self))
      }

      if (is.null(self$input_file)) {
        stop("No input file specified and no data pre-loaded.")
      }

      # Determine file type and load accordingly
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
    #' Filter data by domain
    #' @return invisible(self)
    filter_by_domain = function() {
      self$data <- self$data %>% dplyr::filter(domain %in% self$domains)
      invisible(self)
    },

    #' @description
    #' Filter data by rater (using test lookup)
    #'
    #' @param rater The rater type to filter by.
    #' @return Filtered data frame
    filter_by_rater = function(rater) {
      rater_tests <- self$get_tests_for_rater(rater)

      if (length(rater_tests) == 0) {
        warning("No tests found for rater: ", rater)
        return(self$data[0, ]) # Return empty dataframe with same structure
      }

      self$data %>% dplyr::filter(test %in% rater_tests)
    },

    #' @description
    #' Select relevant columns
    #' @return invisible(self)
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
        # Z-score columns (optional)
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

      # Calculate basic z-score if missing but percentile exists
      if ("percentile" %in% names(self$data) && !"z" %in% names(self$data)) {
        self$data$z <- qnorm(self$data$percentile / 100)
        existing_columns <- c(existing_columns, "z")
      }

      self$data <- self$data %>% dplyr::select(all_of(existing_columns))
      invisible(self)
    },

    #' @description
    #' Save processed data
    #'
    #' @param filename Optional filename for output.
    #' @param format Output format ("csv" or "parquet").
    #' @return invisible(self)
    save_data = function(filename = NULL, format = "csv") {
      if (is.null(filename)) {
        filename <- paste0(self$pheno, ".", format)
      }

      output_path <- here::here(self$output_dir, filename)
      dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

      if (format == "parquet") {
        if (requireNamespace("arrow", quietly = TRUE)) {
          arrow::write_parquet(self$data, output_path)
        } else {
          warning("Arrow package not available, falling back to CSV")
          format <- "csv"
        }
      }

      if (format == "csv") {
        readr::write_excel_csv(
          self$data,
          output_path,
          na = "",
          col_names = TRUE
        )
      }

      invisible(self)
    },

    #' @description
    #' Generate QMD file for single-rater domain
    #'
    #' @param output_file Optional output file path.
    #' @return The path to the generated file
    generate_simple_domain_qmd = function(output_file = NULL) {
      if (is.null(output_file)) {
        domain_num <- self$get_domain_number()
        output_file <- paste0(
          "_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          ".qmd"
        )
      }

      # Template for simple (single-rater) domain
      template <- '
## {{DOMAIN_NAME}} {#sec-{{PHENO}}}

{{< include _02-{{DOMAIN_NUM}}_{{PHENO}}_text.qmd >}}

```{r}
#| label: setup-{{PHENO}}
#| include: false

source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT_Modified.R")

# Create processor
processor <- DomainProcessorR6$new(
  domains = c("{{DOMAIN_NAME}}"),
  pheno = "{{PHENO}}",
  input_file = "{{INPUT_FILE}}",
  age_group = "{{AGE_GROUP}}"
)

# Process data
processor$load_data()$filter_by_domain()$select_columns()$save_data()
data_{{PHENO}} <- processor$data
```

```{r}
#| label: text-{{PHENO}}
#| include: false

# Generate text report
results_processor <- NeuropsychResultsR6$new(
  data = data_{{PHENO}},
  file = "_02-{{DOMAIN_NUM}}_{{PHENO}}_text.qmd"
)
results_processor$process()
```
'

      # Replace placeholders
      content <- template
      content <- gsub("{{DOMAIN_NAME}}", self$domains[1], content)
      content <- gsub("{{PHENO}}", tolower(self$pheno), content)
      content <- gsub("{{DOMAIN_NUM}}", self$get_domain_number(), content)
      content <- gsub("{{INPUT_FILE}}", self$input_file, content)
      content <- gsub("{{AGE_GROUP}}", self$age_group, content)

      writeLines(content, output_file)
      return(output_file)
    },

    #' @description
    #' Generate QMD file for multi-rater domain
    #'
    #' @param output_file Optional output file path.
    #' @return The path to the generated file
    generate_multi_rater_domain_qmd = function(output_file = NULL) {
      raters <- self$get_available_raters()

      if (is.null(output_file)) {
        domain_num <- self$get_domain_number()
        age_suffix <- if (self$age_group == "child") "_child" else ""
        output_file <- paste0(
          "_02-",
          domain_num,
          "_",
          tolower(self$pheno),
          age_suffix,
          ".qmd"
        )
      }

      # Start with header
      content <- paste0(
        "## ",
        self$domains[1],
        " {#sec-",
        tolower(self$pheno),
        "}\n\n"
      )

      # Add setup block
      content <- paste0(
        content,
        '
```{r}
#| label: setup-',
        tolower(self$pheno),
        '
#| include: false

source("R/DomainProcessorR6.R")
source("R/NeuropsychResultsR6.R")
source("R/DotplotR6.R")
source("R/TableGT_Modified.R")

# Create processor
processor <- DomainProcessorR6$new(
  domains = c("',
        self$domains[1],
        '"),
  pheno = "',
        tolower(self$pheno),
        '",
  input_file = "',
        self$input_file,
        '",
  age_group = "',
        self$age_group,
        '"
)

# Process data
processor$load_data()$filter_by_domain()$select_columns()
```

'
      )

      # Add sections for each rater
      for (rater in raters) {
        rater_section <- paste0(
          "### ",
          toupper(rater),
          if (rater == "self") " REPORT" else " RATINGS",
          "\n\n",
          "```{r}\n",
          "#| label: data-",
          tolower(self$pheno),
          "-",
          rater,
          "\n",
          "#| include: false\n\n",
          "data_",
          tolower(self$pheno),
          "_",
          rater,
          " <- processor$filter_by_rater('",
          rater,
          "')\n",
          "```\n\n",

          "```{r}\n",
          "#| label: text-",
          tolower(self$pheno),
          "-",
          rater,
          "\n",
          "#| include: false\n\n",
          "# Generate text report\n",
          "results_processor <- NeuropsychResultsR6$new(\n",
          "  data = data_",
          tolower(self$pheno),
          "_",
          rater,
          ",\n",
          "  file = \"_02-",
          self$get_domain_number(),
          "_",
          tolower(self$pheno),
          "_",
          rater,
          "_text.qmd\"\n",
          ")\n",
          "results_processor$process()\n",
          "```\n\n",

          "{{< include _02-",
          self$get_domain_number(),
          "_",
          tolower(self$pheno),
          "_",
          rater,
          "_text.qmd >}}\n\n"
        )

        content <- paste0(content, rater_section)
      }

      writeLines(content, output_file)
      return(output_file)
    },

    #' @description
    #' Get domain number for file naming
    #' @return Character string with domain number
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
        # Add mappings for your actual domains
        "behavioral/emotional/social" = "10",
        "psychiatric disorders" = "13",
        "personality disorders" = "14",
        "substance use" = "15",
        "symptom validity" = "16",
        "psychosocial problems" = "17",
        "adaptive functioning" = "11"
      )

      # Try exact match first, then try lowercase
      key <- tolower(self$pheno)
      num <- domain_numbers[key]
      if (is.na(num) || is.null(num)) {
        # Try matching with domain names
        key <- tolower(self$domains[1])
        num <- domain_numbers[key]
      }
      if (is.na(num) || is.null(num)) "99" else num
    },

    #' @description
    #' Main processing pipeline
    #'
    #' @param generate_qmd Whether to generate QMD files.
    #' @return invisible(self)
    process = function(generate_qmd = FALSE) {
      # Basic processing pipeline
      self$load_data()
      self$filter_by_domain()
      self$select_columns()
      self$save_data()

      # Generate QMD file if requested
      if (generate_qmd) {
        if (self$has_multiple_raters()) {
          self$generate_multi_rater_domain_qmd()
        } else {
          self$generate_simple_domain_qmd()
        }
      }

      invisible(self)
    }
  )
)
