#' FlexibleDrilldownR6 Class
#'
#' An enhanced R6 class that creates interactive `highcharter` drilldown plots
#' with configurable hierarchies for neuropsychological data analysis.
#' Supports multiple organizational schemes including clinical domains,
#' PASS model, test modality, and timing constraints.
#'
#' @field data Dataset to use
#' @field patient Name of patient
#' @field neuro_domain Name of neuropsych domain to add to HC series
#' @field theme The highcharter theme to use
#' @field hierarchy Vector of column names defining the drill-down hierarchy
#' @field hierarchy_labels Named vector of display labels for hierarchy levels
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new FlexibleDrilldownR6 object with
#'     configuration and data}
#'   \item{create_plot}{Generate the interactive `highcharter` drilldown plot
#'     based on the object's configuration}
#'   \item{validate_hierarchy}{Validate that the specified hierarchy exists
#'     in the data}
#'   \item{get_hierarchy_preset}{Get a predefined hierarchy configuration}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom dplyr group_by summarize mutate ungroup arrange desc filter
#' @importFrom highcharter highchart hc_title hc_add_series hcaes hc_xAxis
#'   hc_yAxis hc_tooltip hc_plotOptions hc_drilldown hc_colorAxis
#'   hc_add_theme hc_chart hc_theme_merge hc_theme_monokai
#'   hc_theme_darkunica tooltip_table list_parse
#' @importFrom tibble tibble
#' @export
FlexibleDrilldownR6 <- R6::R6Class(
  classname = "FlexibleDrilldownR6",
  public = list(
    data = NULL,
    patient = NULL,
    neuro_domain = NULL,
    theme = NULL,
    hierarchy = NULL,
    hierarchy_labels = NULL,

    #' @description
    #' Initialize a new FlexibleDrilldownR6 object
    #'
    #' @param data Dataset to use
    #' @param patient Name of patient
    #' @param neuro_domain Name of neuropsych domain for HC series
    #' @param hierarchy Vector of column names for drill-down levels.
    #'   Default is c("domain", "subdomain", "narrow", "scale")
    #' @param hierarchy_labels Named vector of display labels for each level
    #' @param preset Character string for preset hierarchy: "clinical",
    #'   "pass_model", "modality", "timing", "pass_clinical", "modality_clinical"
    #' @param theme Highcharter theme to use
    #'
    #' @return A new FlexibleDrilldownR6 object
    initialize = function(
      data,
      patient,
      neuro_domain = c(
        "Neuropsychological Test Scores",
        "Behavioral Rating Scales",
        "Validity Test Scores"
      ),
      hierarchy = NULL,
      hierarchy_labels = NULL,
      preset = "clinical",
      theme = NULL
    ) {
      # Check required packages
      required_pkgs <- c("dplyr", "highcharter", "tibble")
      for (pkg in required_pkgs) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
          stop(sprintf(
            "Package '%s' must be installed to use this class.",
            pkg
          ))
        }
      }

      self$data <- data
      self$patient <- patient
      self$neuro_domain <- neuro_domain[1]
      self$theme <- theme

      # Set hierarchy (use preset if specified, otherwise use provided hierarchy)
      if (!is.null(preset) && preset != "custom") {
        preset_config <- self$get_hierarchy_preset(preset)
        self$hierarchy <- preset_config$hierarchy
        self$hierarchy_labels <- preset_config$labels
      } else if (!is.null(hierarchy)) {
        self$hierarchy <- hierarchy
        if (is.null(hierarchy_labels)) {
          self$hierarchy_labels <- setNames(hierarchy, hierarchy)
        } else {
          self$hierarchy_labels <- hierarchy_labels
        }
      } else {
        # Default to clinical hierarchy
        self$hierarchy <- c("domain", "subdomain", "narrow", "scale")
        self$hierarchy_labels <- c(
          domain = "Domain",
          subdomain = "Subdomain",
          narrow = "Narrow Ability",
          scale = "Test Score"
        )
      }

      # Validate hierarchy exists in data
      self$validate_hierarchy()
    },

    #' @description
    #' Get a preset hierarchy configuration
    #'
    #' @param preset_name Name of the preset
    #'
    #' @return List with hierarchy and labels
    get_hierarchy_preset = function(preset_name = "clinical") {
      presets <- list(
        clinical = list(
          hierarchy = c("domain", "subdomain", "narrow", "scale"),
          labels = c(
            domain = "Clinical Domain",
            subdomain = "Subdomain",
            narrow = "Narrow Ability",
            scale = "Test Score"
          )
        ),

        pass_model = list(
          hierarchy = c("pass", "domain", "subdomain", "scale"),
          labels = c(
            pass = "PASS Process",
            domain = "Clinical Domain",
            subdomain = "Subdomain",
            scale = "Test Score"
          )
        ),

        pass_clinical = list(
          hierarchy = c("pass", "verbal", "domain", "subdomain"),
          labels = c(
            pass = "PASS Process",
            verbal = "Modality",
            domain = "Clinical Domain",
            subdomain = "Subdomain"
          )
        ),

        modality = list(
          hierarchy = c("verbal", "timed", "domain", "subdomain"),
          labels = c(
            verbal = "Test Modality",
            timed = "Timing Constraint",
            domain = "Clinical Domain",
            subdomain = "Subdomain"
          )
        ),

        modality_clinical = list(
          hierarchy = c("verbal", "domain", "subdomain", "scale"),
          labels = c(
            verbal = "Test Modality",
            domain = "Clinical Domain",
            subdomain = "Subdomain",
            scale = "Test Score"
          )
        ),

        timing = list(
          hierarchy = c("timed", "domain", "subdomain", "scale"),
          labels = c(
            timed = "Timing Constraint",
            domain = "Clinical Domain",
            subdomain = "Subdomain",
            scale = "Test Score"
          )
        ),

        pass_modality = list(
          hierarchy = c("pass", "verbal", "timed", "domain"),
          labels = c(
            pass = "PASS Process",
            verbal = "Test Modality",
            timed = "Timing Constraint",
            domain = "Clinical Domain"
          )
        )
      )

      if (!preset_name %in% names(presets)) {
        stop(sprintf(
          "Unknown preset: %s. Available presets: %s",
          preset_name,
          paste(names(presets), collapse = ", ")
        ))
      }

      return(presets[[preset_name]])
    },

    #' @description
    #' Validate that hierarchy columns exist in data
    validate_hierarchy = function() {
      missing_cols <- setdiff(self$hierarchy, names(self$data))

      if (length(missing_cols) > 0) {
        stop(sprintf(
          "Hierarchy columns not found in data: %s\nAvailable columns: %s",
          paste(missing_cols, collapse = ", "),
          paste(names(self$data), collapse = ", ")
        ))
      }

      # Check for required scoring columns
      required_cols <- c("z", "percentile")
      missing_required <- setdiff(required_cols, names(self$data))

      if (length(missing_required) > 0) {
        stop(sprintf(
          "Required columns not found in data: %s",
          paste(missing_required, collapse = ", ")
        ))
      }

      invisible(TRUE)
    },

    #' @description
    #' Generate the interactive highcharter drilldown plot
    #'
    #' @return A highcharter object representing the interactive drilldown plot
    create_plot = function() {
      # Helper function to classify range
      classify_range <- function(pct) {
        dplyr::case_when(
          pct >= 98 ~ "Exceptionally High",
          pct %in% 91:97 ~ "Above Average",
          pct %in% 75:90 ~ "High Average",
          pct %in% 25:74 ~ "Average",
          pct %in% 9:24 ~ "Low Average",
          pct %in% 2:8 ~ "Below Average",
          pct < 2 ~ "Exceptionally Low",
          TRUE ~ NA_character_
        )
      }

      # Recursive function to create drilldown data for each level
      create_level_data <- function(df, level_idx, parent_id = NULL) {
        if (level_idx > length(self$hierarchy)) {
          return(NULL)
        }

        current_col <- self$hierarchy[level_idx]
        is_last_level <- level_idx == length(self$hierarchy)

        # Filter out NA values for the current grouping variable
        df_filtered <- df |> dplyr::filter(!is.na(.data[[current_col]]))

        if (nrow(df_filtered) == 0) {
          return(NULL)
        }

        # Create summary for current level
        df_summary <- df_filtered |>
          dplyr::group_by(.data[[current_col]]) |>
          dplyr::summarize(
            zMean = mean(z, na.rm = TRUE),
            zPct = mean(percentile, na.rm = TRUE),
            .groups = "drop"
          ) |>
          dplyr::mutate(
            zMean = round(zMean, 2),
            zPct = round(zPct, 0),
            range = classify_range(zPct)
          ) |>
          dplyr::arrange(dplyr::desc(zPct))

        # Create tibble with drilldown structure
        level_tibble <- tibble::tibble(
          name = df_summary[[current_col]],
          y = df_summary$zMean,
          y2 = df_summary$zPct,
          range = df_summary$range
        )

        # Add drilldown IDs if not last level
        if (!is_last_level) {
          if (is.null(parent_id)) {
            level_tibble$drilldown <- tolower(gsub(" ", "_", level_tibble$name))
          } else {
            level_tibble$drilldown <- tolower(paste(
              parent_id,
              gsub(" ", "_", level_tibble$name),
              sep = "_"
            ))
          }
        }

        # Create list for highcharter
        result <- list(
          id = parent_id,
          type = "column",
          data = highcharter::list_parse(level_tibble)
        )

        # If not last level, recurse for next level
        if (!is_last_level) {
          next_level_data <- lapply(
            unique(df_filtered[[current_col]]),
            function(value) {
              df_subset <- df_filtered |>
                dplyr::filter(.data[[current_col]] == value)

              new_parent_id <- if (is.null(parent_id)) {
                tolower(gsub(" ", "_", value))
              } else {
                tolower(paste(parent_id, gsub(" ", "_", value), sep = "_"))
              }

              create_level_data(df_subset, level_idx + 1, new_parent_id)
            }
          )

          # Flatten list and remove NULLs
          next_level_data <- Filter(Negate(is.null), next_level_data)

          return(list(
            current = if (is.null(parent_id)) NULL else result,
            children = next_level_data
          ))
        }

        return(if (is.null(parent_id)) NULL else result)
      }

      # Create all levels
      all_levels <- create_level_data(self$data, 1, NULL)

      # Flatten the nested structure
      flatten_levels <- function(level_data) {
        if (is.null(level_data)) {
          return(list())
        }

        result <- list()
        if (!is.null(level_data$current)) {
          result <- c(result, list(level_data$current))
        }
        if (!is.null(level_data$children)) {
          for (child in level_data$children) {
            result <- c(result, flatten_levels(child))
          }
        }
        return(result)
      }

      drilldown_series <- flatten_levels(all_levels)

      # Create Level 1 data (top level)
      level1_col <- self$hierarchy[1]
      df_level1 <- self$data |>
        dplyr::filter(!is.na(.data[[level1_col]])) |>
        dplyr::group_by(.data[[level1_col]]) |>
        dplyr::summarize(
          zMean = mean(z, na.rm = TRUE),
          zPct = mean(percentile, na.rm = TRUE),
          .groups = "drop"
        ) |>
        dplyr::mutate(
          zMean = round(zMean, 2),
          zPct = round(zPct, 0),
          range = classify_range(zPct)
        ) |>
        dplyr::arrange(dplyr::desc(zPct))

      df_level1_status <- tibble::tibble(
        name = df_level1[[level1_col]],
        y = df_level1$zMean,
        y2 = df_level1$zPct,
        range = df_level1$range,
        drilldown = tolower(gsub(" ", "_", name))
      )

      # Create theme
      chart_theme <- highcharter::hc_theme_merge(
        highcharter::hc_theme_monokai(),
        highcharter::hc_theme_darkunica()
      )

      # Create tooltip
      x <- c("Name", "Score", "Percentile", "Range")
      y <- c("{point.name}", "{point.y}", "{point.y2}", "{point.range}")
      tt <- highcharter::tooltip_table(x, y)

      # Create plot
      plot <- highcharter::highchart() |>
        highcharter::hc_title(
          text = self$patient,
          style = list(fontSize = "15px")
        ) |>
        highcharter::hc_add_series(
          df_level1_status,
          type = "bar",
          name = self$neuro_domain,
          highcharter::hcaes(x = name, y = y)
        ) |>
        highcharter::hc_xAxis(
          type = "category",
          title = list(text = self$hierarchy_labels[level1_col])
        ) |>
        highcharter::hc_yAxis(
          title = list(text = "z-Score (Mean = 0, SD = 1)"),
          labels = list(format = "{value}")
        ) |>
        highcharter::hc_tooltip(
          pointFormat = tt,
          useHTML = TRUE,
          valueDecimals = 1
        ) |>
        highcharter::hc_plotOptions(
          series = list(
            colorByPoint = TRUE,
            allowPointSelect = TRUE,
            dataLabels = TRUE
          )
        ) |>
        highcharter::hc_drilldown(
          allowPointDrilldown = TRUE,
          series = drilldown_series
        ) |>
        highcharter::hc_colorAxis(minColor = "red", maxColor = "blue") |>
        highcharter::hc_add_theme(chart_theme) |>
        highcharter::hc_chart(
          style = list(fontFamily = "Cabin"),
          backgroundColor = list("gray")
        )

      return(plot)
    }
  )
)

#' Create Flexible Drilldown Plot (Function Wrapper)
#'
#' Wrapper function for FlexibleDrilldownR6 class that creates interactive
#' highcharter drilldown plots with configurable hierarchies.
#'
#' @param data Dataset to use
#' @param patient Name of patient
#' @param neuro_domain Name of neuropsych domain to add to HC series
#' @param hierarchy Vector of column names for drill-down levels
#' @param hierarchy_labels Named vector of display labels
#' @param preset Preset hierarchy: "clinical", "pass_model", "modality",
#'   "timing", "pass_clinical", "modality_clinical", "pass_modality"
#' @param theme Highcharter theme to use
#'
#' @return A drilldown plot
#' @export
#'
#' @examples
#' \dontrun{
#' # Use clinical hierarchy (default)
#' plot1 <- drilldown_flexible(neurocog_data, "Patient A")
#'
#' # Use PASS model hierarchy
#' plot2 <- drilldown_flexible(
#'   neurocog_data,
#'   "Patient A",
#'   preset = "pass_model"
#' )
#'
#' # Use modality-based hierarchy
#' plot3 <- drilldown_flexible(
#'   neurocog_data,
#'   "Patient A",
#'   preset = "modality"
#' )
#'
#' # Custom hierarchy
#' plot4 <- drilldown_flexible(
#'   neurocog_data,
#'   "Patient A",
#'   hierarchy = c("pass", "verbal", "domain"),
#'   hierarchy_labels = c(
#'     pass = "PASS Model",
#'     verbal = "Modality",
#'     domain = "Domain"
#'   )
#' )
#' }
