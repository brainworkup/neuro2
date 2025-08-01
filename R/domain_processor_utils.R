#' Create a domain processor with smart defaults
#'
#' @param domain_name The domain name (e.g., "ADHD", "Behavioral/Emotional/Social")
#' @param data_file Path to your neurobehavioral data file
#' @param age_group Either "adult" or "child"
#' @param test_lookup_file Path to the test lookup CSV (default: "test_testname_rater.csv")
#' @return A DomainProcessorR6 object
#' @export
create_domain_processor <- function(
  domain_name,
  data_file,
  age_group = "adult",
  test_lookup_file = "test_testname_rater.csv"
) {
  # Create a clean phenotype name from domain name
  pheno <- tolower(gsub("[^A-Za-z0-9]", "_", domain_name))
  pheno <- gsub("_+", "_", pheno) # Remove multiple underscores
  pheno <- gsub("^_|_$", "", pheno) # Remove leading/trailing underscores

  DomainProcessorR6$new(
    domains = domain_name,
    pheno = pheno,
    input_file = data_file,
    age_group = age_group,
    test_lookup_file = test_lookup_file
  )
}

#' Process a simple domain (single rater)
#'
#' @param domain_name Domain name
#' @param data_file Path to data file
#' @param age_group Age group ("adult" or "child")
#' @return A DomainProcessorR6 object
#' @export
process_simple_domain <- function(domain_name, data_file, age_group = "adult") {
  processor <- create_domain_processor(domain_name, data_file, age_group)

  # Check if it's actually simple
  if (processor$has_multiple_raters()) {
    warning(
      "Domain '",
      domain_name,
      "' has multiple raters. Consider using process_multi_rater_domain()"
    )
  }

  processor$process(generate_qmd = TRUE)

  message("Generated files for ", domain_name, " (", age_group, ")")
  return(processor)
}

#' Process a multi-rater domain
#'
#' @param domain_name Domain name
#' @param data_file Path to data file
#' @param age_group Age group ("adult" or "child")
#' @return A DomainProcessorR6 object
#' @export
process_multi_rater_domain <- function(
  domain_name,
  data_file,
  age_group = "adult"
) {
  processor <- create_domain_processor(domain_name, data_file, age_group)

  raters <- processor$get_available_raters()
  message(
    "Available raters for ",
    domain_name,
    " (",
    age_group,
    "): ",
    paste(raters, collapse = ", ")
  )

  processor$process(generate_qmd = TRUE)

  message("Generated multi-rater files for ", domain_name, " (", age_group, ")")
  return(processor)
}

#' Get domain information from the lookup table
#'
#' @param test_lookup_file Path to test lookup file
#' @return A data frame with domain summary information
#' @export
get_domain_info <- function(test_lookup_file = "test_testname_rater.csv") {
  lookup <- readr::read_csv(test_lookup_file, show_col_types = FALSE)

  # Summarize by domain
  domain_summary <- lookup %>%
    dplyr::group_by(domain) %>%
    dplyr::summarise(
      raters = paste(unique(rater), collapse = ", "),
      age_groups = paste(unique(age_group), collapse = ", "),
      test_count = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::arrange(domain)

  return(domain_summary)
}

#' Check what raters are available for a specific domain and age group
#'
#' @param domain_name Domain name
#' @param age_group Age group
#' @param test_lookup_file Path to test lookup file
#' @return A data frame with rater summary information
#' @export
check_domain_raters <- function(
  domain_name,
  age_group = "adult",
  test_lookup_file = "test_testname_rater.csv"
) {
  lookup <- readr::read_csv(test_lookup_file, show_col_types = FALSE)

  available_tests <- lookup %>%
    dplyr::filter(
      domain == domain_name,
      age_group %in% c(!!age_group, "child/adult")
    )

  if (nrow(available_tests) == 0) {
    message(
      "No tests found for domain '",
      domain_name,
      "' and age group '",
      age_group,
      "'"
    )
    return(data.frame())
  }

  rater_summary <- available_tests %>%
    dplyr::group_by(rater) %>%
    dplyr::summarise(
      tests = paste(test, collapse = ", "),
      test_count = dplyr::n(),
      .groups = "drop"
    )

  message("Available raters for '", domain_name, "' (", age_group, "):")
  print(rater_summary)

  return(rater_summary)
}

#' Batch process multiple domains
#'
#' @param domains Vector of domain names
#' @param data_file Path to data file
#' @param age_group Age group
#' @return A list of DomainProcessorR6 objects
#' @export
batch_process_domains <- function(domains, data_file, age_group = "adult") {
  results <- list()

  for (domain in domains) {
    message("\nProcessing domain: ", domain)

    tryCatch(
      {
        processor <- create_domain_processor(domain, data_file, age_group)

        if (processor$has_multiple_raters()) {
          results[[domain]] <- process_multi_rater_domain(
            domain,
            data_file,
            age_group
          )
        } else {
          results[[domain]] <- process_simple_domain(
            domain,
            data_file,
            age_group
          )
        }
      },
      error = function(e) {
        message("Error processing ", domain, ": ", e$message)
        results[[domain]] <- NULL
      }
    )
  }

  return(results)
}
