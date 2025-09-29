#' @title Locate PDF Areas
#' @description This is a function to pluck and locate areas from file.
#' @importFrom tabulapdf locate_areas
#' @param file The File name of the input PDF.
#' @param pages A vector of character strings specifying which pages to analyse, Default: NULL
#' @param ... Additional arguments passed to locate_areas() in the tabulapdf package.
#' @return A list containing all areas found by area extraction algorithem.
#' @details Use this function with caution when handling sensitive PDFs as it involves rasterizing those documents. Also use this function if your PDF contains tables and you want to access those tables programmatically.
#' @seealso
#'  \code{\link[tabulapdf]{locate_areas}}
#' @rdname gpluck_locate_areas
#' @export
gpluck_locate_areas <- function(file, pages = NULL, ...) {
  tabulapdf::locate_areas(file = file, pages = pages, ...)
}


#' @title Extract Tables from a PDF
#' @description This function returns the tables in a PDF file as parsed by the tabulapdf package.
#' @importFrom tabulapdf extract_tables
#' @param file The path to the PDF file.
#' @param pages A single page number or vector of page numbers, Default: NULL
#' @param area An area on the page given as c(x0, y0, x1, y1). Default: NULL
#' @param guess Whether to attempt to detect tables when the coordinates are not given. Default: FALSE
#' @param method Method to use for parsing. Default: c("decide", "lattice", "stream")
#' @param output Output format (see \code{\link[tabulapdf]{extract_tables}} for more details). Default: c("matrix", "data.frame", "character", "asis", "csv", "tsv", "json")
#' @param ... Other arguments to \code{\link[tabulapdf]{extract_tables}}
#' @return A parsed table in either matrix, data frame, character, asis, csv, tsv or json format.
#' @details This is a wrapper around the \code{\link[tabulapdf]{extract_tables}} function that allows for easier access to the tables in a PDF document.
#' @seealso
#'  \code{\link[tabulapdf]{extract_tables}}
#' @rdname gpluck_extract_tables
#' @export
gpluck_extract_tables <- function(
  file,
  pages = NULL,
  area = NULL,
  guess = FALSE,
  method = c("decide", "lattice", "stream"),
  output = c("matrix", "data.frame", "character", "asis", "csv", "tsv", "json"),
  ...
) {
  tabulapdf::extract_tables(
    file = file,
    pages = pages,
    area = area,
    guess = match.arg(guess),
    method = match.arg(method),
    output = match.arg(output)
  )
}

# maybe depracte this?
#' @title Insert Variables and Data from Tables into DF.
#' @description This function takes a data frame containing text data from PDF tables, and makes additional columns of binary, range or score values for the specified domain, subdomains, test types, etc.
#' @importFrom dplyr mutate
#' @param data Data frame to convert to table and then csv.
#' @param test Name of test that information will be extracted from.
#' @param test_name Test name as provided in test field.
#' @param scale Name of subscale from neuropsych test or battery. Default: NULL
#' @param raw_score Raw score if available. Default: NULL
#' @param score Standardized Score for the given test. Default: NULL
#' @param range Range of performance e.g., Below Average, Average, Above
#' Average, etc the given test or subscale. Default: NULL
#' @param percentile Percentile the patient's performance falls at for the given test. Default: NULL
#' @param ci_95 Confidence interval level (95%) for the given test. Default: NULL
#' @param domain Domain of the test, e.g. Academic Skills. Default: c("General
#' Cognitive Ability", "Academic Skills", "Verbal/Language", "Visual
#' Perception/Construction", "Attention/Executive", "Memory", "Motor", "Social
#' Cognition", "Emotional/Behavioral/Social/Personality", "ADHD/Executive Function", "Adaptive Function", "Validity")
#' @param subdomain Cognitive subdomain of the scale. Default: NULL
#' @param narrow Narrow cognitive domain of the scale. Default: NULL
#' @param pass PASS Cognitive Model. Default: c("Planning", "Attention", "Sequential", "Simultaneous", "Knowledge",
#'    NA)
#' @param verbal Type of verbal ability tested, e.g. Verbal, Nonverbal. Default: c("Verbal", "Nonverbal", NA)
#' @param timed Indicates if the test is timed or not. Default: c("Timed", "Untimed", NA)
#' @param test_type Type of test, e.g. npsych_test, rating_scale,
#' validity_indicator, item. Default: c("npsych_test", "rating_scale",
#' "validity_indicator", "basc3", "item", NA)
#' @param score_type Type of score reported, e.g. raw_score, scaled_score, t_score, standard_score, z_score, percentile, base_rate, beta_coefficient. Default: c("raw_score", "scaled_score", "t_score", "standard_score", "z_score",
#'    "percentile", "base_rate", "beta_coefficient", NA)
#' @param absort Default order of scales to use for sorting. Default: NULL
#' @param description Description of the test or task. Default: NULL
#' @param result Concatenate the results to include details of test performance. Default: NULL
#' @param ... Other parameters.
#' @return A modified data frame with additional columns.
#' @details This function adds new columns to a data frame by extracting numerical values from PDF tables.
#' @rdname gpluck_make_columns
#' @export
gpluck_make_columns <- function(
  data,
  test,
  test_name,
  scale = NULL,
  raw_score = NULL,
  score = NULL,
  ci_95 = NULL,
  percentile = NULL,
  range = NULL,
  domain = c(
    "General Cognitive Ability",
    "Intelligence/General Ability",
    "Academic Skills",
    "Verbal/Language",
    "Visual Perception/Construction",
    "Attention/Executive",
    "Memory",
    "Motor",
    "Social Cognition",
    "Emotional/Behavioral/Social/Personality",
    "ADHD/Executive Function",
    "Adaptive Functioning",
    "Validity"
  ),
  subdomain = NULL,
  narrow = NULL,
  pass = c(
    "Planning",
    "Attention",
    "Sequential",
    "Simultaneous",
    "Knowledge",
    NA_character_
  ),
  verbal = c("Verbal", "Nonverbal", NA_character_),
  timed = c("Timed", "Untimed", NA_character_),
  test_type = c(
    "npsych_test",
    "rating_scale",
    "validity_indicator",
    "item",
    "basc3",
    NA_character_
  ),
  score_type = c(
    "raw_score",
    "scaled_score",
    "t_score",
    "standard_score",
    "z_score",
    "percentile",
    "base_rate",
    "beta_coefficient",
    NA_real_
  ),
  # absort = NULL,
  description = NULL,
  result = NULL,
  ...
) {
  table <- data |>
    dplyr::mutate(
      test = test,
      test_name = test_name,
      scale = scale,
      raw_score = raw_score,
      score = score,
      ci_95 = ci_95,
      percentile = percentile,
      range = range,
      domain = domain,
      subdomain = subdomain,
      narrow = narrow,
      pass = pass,
      verbal = verbal,
      timed = timed,
      score_type = score_type,
      test_type = test_type,
      # absort = paste0(tolower(test), "_", seq_len(nrow(data))),
      description = description,
      result = result,
      ...
    )
  return(table)
}


#' @title Make Score Ranges
#' @description This function takes a text table of score ranges for each percentile, and returns an object that matches the input but with the ability to get score ranges for any given test type
#' @importFrom dplyr mutate case_when
#' @param table The table containing the lower bound and upper bound score columns
#' @param score Optional lower bound or upper bound score column name. If omitted, use `Score`
#' @param percentile Option percentiles column name. if omitted, use `Percentile`
#' @param range Score performance range. if omitted, use `Range`
#' @param test_type A vector of test types to consider. Default: c("npsych_test", "rating_scale", "validity_indicator", "basc3")
#' @param subdomain Which subdomain.
#' @param ... Other arguments passed on to `dplyr::filter`
#' @return An object that matches the input but with the ability to get score ranges for any given test type
#' @details This function takes a text table of score ranges for each percentile, and returns an object that matches the input but with the ability to get score ranges for any given test type
#' @rdname gpluck_make_score_ranges
#' @export
gpluck_make_score_ranges <- function(
  table,
  score,
  percentile,
  range,
  test_type = c(
    "npsych_test",
    "rating_scale",
    "validity_indicator",
    "performance_validity",
    "symptom_validity",
    "rating_scale_basc3",
    "basc3"
  ),
  ...
) {
  if (test_type == "npsych_test") {
    table <- table |>
      dplyr::mutate(
        range = dplyr::case_when(
          percentile >= 98 ~ "Exceptionally High",
          percentile %in% 91:97 ~ "Above Average",
          percentile %in% 75:90 ~ "High Average",
          percentile %in% 25:74 ~ "Average",
          percentile %in% 9:24 ~ "Low Average",
          percentile %in% 2:8 ~ "Below Average",
          percentile < 2 ~ "Exceptionally Low",
          TRUE ~ as.character(range)
        )
      )
  } else if (
    identical(test_type, "rating_scale") && !startsWith(test, "basc3_")
  ) {
    table <- table |>
      dplyr::mutate(
        range = dplyr::case_when(
          percentile >= 98 ~ "Exceptionally High",
          percentile %in% 91:97 ~ "Above Average",
          percentile %in% 75:90 ~ "High Average",
          percentile %in% 25:74 ~ "Average",
          percentile %in% 9:24 ~ "Low Average",
          percentile %in% 2:8 ~ "Below Average",
          percentile < 2 ~ "Exceptionally Low",
          TRUE ~ as.character(range)
        )
      )
  } else if (test_type == "validity_indicator") {
    table <- table |>
      dplyr::mutate(
        range = dplyr::case_when(
          percentile >= 25 ~ "WNL Score",
          percentile %in% 9:24 ~ "Low Average Score",
          percentile %in% 2:8 ~ "Below Average Score",
          percentile < 2 ~ "Exceptionally Low Score",
          TRUE ~ as.character(range)
        )
      )
  } else if (startsWith(test, "basc3_")) {
    table <- table |>
      dplyr::mutate(
        range = dplyr::case_when(
          score >= 60 &
            subdomain %in% c("Adaptive Skills", "Personal Adjustment") ~
            "Normative Strength",
          score %in%
            40:59 &
            subdomain %in% c("Adaptive Skills", "Personal Adjustment") ~
            "Average",
          score %in%
            30:39 &
            subdomain %in% c("Adaptive Skills", "Personal Adjustment") ~
            "At-Risk",
          score %in%
            20:29 &
            subdomain %in% c("Adaptive Skills", "Personal Adjustment") ~
            "Clinically Significant",
          score <= 20 &
            subdomain %in% c("Adaptive Skills", "Personal Adjustment") ~
            "Markedly Impaired",
          score >= 80 &
            subdomain != c("Adaptive Skills", "Personal Adjustment") ~
            "Markedly Elevated",
          score %in%
            70:79 &
            subdomain != c("Adaptive Skills", "Personal Adjustment") ~
            "Clinically Significant",
          score %in%
            60:69 &
            subdomain != c("Adaptive Skills", "Personal Adjustment") ~
            "At-Risk",
          score %in%
            40:59 &
            subdomain != c("Adaptive Skills", "Personal Adjustment") ~
            "Average",
          score <= 39 &
            subdomain != c("Adaptive Skills", "Personal Adjustment") ~
            "Normative Strength",
          TRUE ~ as.character(range)
        )
      )
  }
  return(table)
}

#' Compute Percentile & Performance Range
#'
#' @param .data A data.frame/tibble.
#' @param score_col Unquoted name of the score column in `.data`.
#' @param score_type One of "z_score", "scaled_score", "t_score", "standard_score".
#' @param keep_intermediate Keep pct1/pct2/pct3 columns? Default FALSE.
#' @return `.data` with added columns: z, percentile, range.
#' @export
gpluck_compute_percentile_range <- function(
  .data,
  score_col,
  score_type = c("z_score", "scaled_score", "t_score", "standard_score"),
  keep_intermediate = FALSE
) {
  score_type <- match.arg(score_type)

  params <- list(
    z_score = list(mu = 0, sd = 1),
    scaled_score = list(mu = 10, sd = 3),
    t_score = list(mu = 50, sd = 10),
    standard_score = list(mu = 100, sd = 15)
  )

  mu <- params[[score_type]]$mu
  sd <- params[[score_type]]$sd

  out <- .data |>
    dplyr::mutate(
      z = (({{ score_col }}) - mu) / sd,
      pct1 = round(stats::pnorm(z) * 100, 1),
      pct2 = dplyr::case_when(
        pct1 < 1 ~ ceiling(pct1),
        pct1 > 99 ~ floor(pct1),
        TRUE ~ round(pct1)
      ),
      pct3 = pct2,
      range = dplyr::case_when(
        pct3 >= 98 ~ "Exceptionally High",
        pct3 %in% 91:97 ~ "Above Average",
        pct3 %in% 75:90 ~ "High Average",
        pct3 %in% 25:74 ~ "Average",
        pct3 %in% 9:24 ~ "Low Average",
        pct3 %in% 2:8 ~ "Below Average",
        pct3 < 2 ~ "Exceptionally Low",
        TRUE ~ NA_character_
      ),
      percentile = pct1
    )

  if (!keep_intermediate) {
    out <- dplyr::select(out, -c(pct1, pct2, pct3))
  }

  out
}
