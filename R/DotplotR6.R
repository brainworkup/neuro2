#' DotplotR6 Class
#'
#' An R6 class that generates a dotplot for neurocognitive and neurobehavioral domains.
#' This is an R6 implementation of the dotplot function with identical functionality.
#'
#' @field data The dataset or df containing the data for the dotplot.
#' @field x The column name in the data frame for the x-axis variable, typically
#'   the mean z-score for a cognitive domain.
#' @field y The column name in the data frame for the y-axis variable, typically
#'   the cognitive domain to plot.
#' @field linewidth The width of the line, Default: 0.5
#' @field fill The fill color for the points, Default: x-axis variable
#' @field shape The shape of the points, Default: 21
#' @field point_size The size of the points, Default: 6
#' @field line_color The color of the lines, Default: 'black'
#' @field colors A vector of colors for fill gradient, Default: NULL (uses
#'   pre-defined color palette)
#' @field theme The ggplot theme to be used, Default: 'fivethirtyeight'
#' @field width The width, in inches, to use when saving the figure, Default: 10
#' @field height Optional explicit height (in inches) when saving the figure.
#'   If NULL, the height is calculated dynamically.
#' @field base_height Inches allocated per item when computing height dynamically,
#'   Default: 0.4
#' @field min_height Minimum allowable height when saving the figure, Default: 4
#' @field height_per_row Inches allocated per row when computing height dynamically,
#'   Default: 0.7
#' @field height_padding Additional inches added to the dynamic height calculation,
#'   Default: 0.8
#' @field return_plot Whether to return the plot object, Default: TRUE
#' @field filename The filename to save the plot to, Default: NULL
#' @field domain The domain
#' @field subdomain The subdomain
#' @field narrow The narrow subdomain
#' @field plot_title Title of plot
#' @field plot NOt sure
#'
#' @section Methods:
#' \describe{
#'   \item{initialize}{Initialize a new DotplotR6 object with configuration and data.}
#'   \item{create_plot}{Generate the dotplot based on the object's configuration.}
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom stats reorder
#' @importFrom ggplot2 ggplot geom_segment aes geom_point scale_fill_gradientn theme element_rect ggsave
#' @importFrom ggthemes theme_fivethirtyeight
#' @importFrom ggtext element_markdown
#' @importFrom tibble tibble
#' @importFrom highcharter list_parse
#' @export
DotplotR6 <- R6::R6Class(
  classname = "DotplotR6",
  public = list(
    data = NULL,
    x = NULL,
    y = NULL,
    domain = NULL,
    subdomain = NULL,
    narrow = NULL,
    linewidth = 0.5,
    fill = NULL,
    shape = 21,
    point_size = 6,
    line_color = "black",
    colors = NULL,
    plot_title = NULL,
    theme = "fivethirtyeight",
    return_plot = TRUE,
    filename = NULL,
    width = NULL,
    height = NULL,
    base_height = NULL,
    min_height = NULL,
    height_per_row = 0.7,
    height_padding = 0.8,
    plot = NULL,

    #' @description
    #' Initialize a new DotplotR6 object with configuration and data.
    #'
    #' @param data The dataset or df containing the data for the dotplot.
    #' @param x The column name in the data frame for the x-axis variable, typically
    #'   the mean z-score for a cognitive domain.
    #' @param y The column name in the data frame for the y-axis variable, typically
    #'   the cognitive domain to plot.
    #' @param linewidth The width of the line, Default: 0.5
    #' @param fill The fill color for the points, Default: x-axis variable
    #' @param shape The shape of the points, Default: 21
    #' @param point_size The size of the points, Default: 6
    #' @param line_color The color of the lines, Default: 'black'
    #' @param colors A vector of colors for fill gradient, Default: NULL (uses
    #'   pre-defined color palette)
    #' @param theme The ggplot theme to be used, Default: 'fivethirtyeight'
    #' @param return_plot Whether to return the plot object, Default: TRUE
    #' @param filename The filename to save the plot to, Default: NULL
    #' @param width The width, in inches, to use when saving the figure. Default: 8
    #' @param height Optional explicit height (in inches) when saving the figure.
    #'   If NULL, the height is calculated dynamically based on the number of items.
    #' @param base_height Inches to allocate per item when computing height dynamically. Default: 0.4
    #' @param min_height Minimum height for the saved figure in inches. Default: 4
    #' @param height_per_row Inches to allocate per row for fallback calculation. Default: 0.7
    #' @param height_padding Additional inches added to fallback calculation. Default: 0.8
    #' @param domain The domain
    #' @param subdomain The subdomain
    #' @param narrow The narrow subdomain
    #' @param plot_title Title of plot
    #' @param plot NOt sure
    #' @param ... Additional arguments (ignored).
    #'
    #' @return A new DotplotR6 object
    initialize = function(
      data,
      x = "percentile",
      y = "scale",
      colors = NULL,
      domain = NULL,
      plot_title = NULL,
      filename = NULL,
      fill = x,
      height = NULL,
      width = 8,
      base_height = 0.4,
      min_height = 4,
      height_padding = 0.8,
      height_per_row = 0.7,
      line_color = "black",
      linewidth = 0.5,
      narrow = NULL,
      point_size = 6,
      return_plot = TRUE,
      shape = 21,
      subdomain = NULL,
      theme = "fivethirtyeight",
      ...
    ) {
      self$data <- data
      self$x <- x
      self$y <- y
      self$linewidth <- linewidth
      self$fill <- fill
      self$shape <- shape
      self$point_size <- point_size
      self$line_color <- line_color
      self$colors <- colors
      self$theme <- theme
      self$return_plot <- return_plot
      self$filename <- filename
      self$width <- width
      self$height_per_row <- height_per_row
      self$height_padding <- height_padding
      self$domain <- domain
      self$subdomain <- subdomain
      self$narrow <- narrow
      self$plot_title <- plot_title

      # Store the dynamic height parameters
      self$base_height <- base_height
      self$min_height <- min_height

      # Calculate dynamic height based on actual items that will be plotted
      # Count unique values in the y-axis column (what will actually display)
      if (!is.null(data) && !is.null(y) && y %in% names(data)) {
        y_data <- data[[y]]
        n_items <- length(unique(y_data[!is.na(y_data)]))

        # Handle edge case: no valid data
        if (n_items == 0) {
          warning(
            "DotplotR6: No valid data points found for y-axis variable '",
            y,
            "'"
          )
          n_items <- 1 # Prevent invalid dimensions
        }
      } else {
        # Fallback if data structure is unexpected
        n_items <- nrow(data)
        if (is.null(n_items) || n_items == 0) {
          n_items <- 1
        }
      }

      # Calculate height if not explicitly provided
      if (is.null(height)) {
        # Dynamic height: each item needs base_height space, plus room for margins/title
        calculated_height <- max(min_height, n_items * base_height + 2)
        self$height <- calculated_height

        # Optional: provide feedback during development
        if (getOption("dotplot.verbose", FALSE)) {
          message(sprintf(
            "DotplotR6: Calculated height of %.1f inches for %d items (%.2f per item + 2)",
            calculated_height,
            n_items,
            base_height
          ))
        }
      } else {
        self$height <- height
      }
    },

    #' @description
    #' Generate the dotplot based on the object's configuration.
    #'
    #' @return If return_plot is TRUE, returns an object of class 'ggplot' representing the dotplot.
    #'   Otherwise returns invisible(NULL).
    create_plot = function() {
      # Define the color palette
      color_palette <- if (is.null(self$colors)) {
        c(
          "#7E1700",
          "#8E3B0B",
          "#9C5717",
          "#A86F22",
          "#B58A30",
          "#C2A647",
          "#CEC56C",
          "#D2D78A",
          "#CBE7B3",
          "#A7E6D2",
          "#80D6D7",
          "#59BDD2",
          "#3DA3C8",
          "#2E8ABF",
          "#2471B4",
          "#1F60AD",
          "#184EA4",
          "#0C3B9C",
          "#023198"
        )
      } else {
        self$colors
      }

      # Make sure fill is set correctly
      fill_var <- if (identical(self$fill, self$x)) self$x else self$fill

      # Make the plot
      plot_object <- ggplot2::ggplot() +
        ggplot2::geom_segment(
          data = self$data,
          ggplot2::aes(
            x = .data[[self$x]],
            y = stats::reorder(.data[[self$y]], .data[[self$x]]),
            xend = 0,
            yend = .data[[self$y]]
          ),
          color = self$line_color,
          linewidth = self$linewidth
        ) +
        ggplot2::geom_point(
          data = self$data,
          ggplot2::aes(
            x = .data[[self$x]],
            y = stats::reorder(.data[[self$y]], .data[[self$x]]),
            fill = .data[[self$x]]
          ),
          shape = self$shape,
          size = self$point_size,
          color = self$line_color
        ) +
        ggplot2::scale_fill_gradientn(colors = color_palette, guide = "none")

      # Apply theme
      plot_object <- plot_object +
        switch(
          self$theme,
          "fivethirtyeight" = ggthemes::theme_fivethirtyeight(),
          "minimal" = ggplot2::theme_minimal(),
          "classic" = ggplot2::theme_classic(),
          ggplot2::theme_minimal()
        )

      # Add margins and turn off clipping
      plot_object <- plot_object +
        ggplot2::coord_cartesian(clip = "off") +
        ggplot2::theme(
          panel.background = ggplot2::element_rect(fill = "white"),
          plot.background = ggplot2::element_rect(fill = "white"),
          panel.border = ggplot2::element_rect(color = "white"),
          # Add this line to increase the left margin
          plot.margin = ggplot2::margin(t = 5, r = 5, b = 5, l = 10)
        )

      # Add this after creating your plot object
      plot_object <- plot_object +
        ggplot2::scale_x_continuous(
          expand = ggplot2::expansion(mult = c(0.2, 0.1))
        )

      # Save the plot to a file if filename is provided
      if (!is.null(self$filename)) {
        # Skip saving if target exists and skipping is enabled
        skip_if_exists <- getOption("neuro2.skip_if_exists", TRUE)
        if (skip_if_exists && file.exists(self$filename)) {
          if (getOption("neuro2.verbose", TRUE)) {
            message("  ✓ ", basename(self$filename), " (cached)")
          }
          return(if (self$return_plot) plot_object else invisible(NULL))
        }

        # Determine file extension to save accordingly
        ext <- tools::file_ext(self$filename)
        plot_width <- if (!is.null(self$width)) self$width else 10

        # Use the height that was calculated in initialize
        # But allow for dynamic recalculation as fallback if somehow height is still NULL
        plot_height <- self$height
        if (is.null(plot_height)) {
          y_values <- self$data[[self$y]]
          if (is.null(y_values)) {
            n_rows <- 1
          } else {
            n_rows <- length(unique(y_values[!is.na(y_values)]))
            if (is.na(n_rows) || n_rows < 1) {
              n_rows <- 1
            }
          }
          computed_height <- (n_rows * self$height_per_row) +
            self$height_padding
          plot_height <- max(self$min_height, computed_height)
        }

        if (ext == "pdf") {
          ggplot2::ggsave(
            filename = self$filename,
            plot = plot_object,
            device = "pdf",
            width = plot_width,
            height = plot_height,
            dpi = 300
          )
        } else if (ext == "png") {
          ggplot2::ggsave(
            filename = self$filename,
            plot = plot_object,
            device = "png",
            width = plot_width,
            height = plot_height,
            dpi = 300
          )
        } else if (ext == "svg") {
          ggplot2::ggsave(
            filename = self$filename,
            plot = plot_object,
            device = "svg",
            width = plot_width,
            height = plot_height,
            dpi = 300
          )
        } else {
          warning(
            "File extension not recognized.
                  Supported extensions are 'pdf', 'png', and 'svg'."
          )
        }
      }

      # Return the plot if return_plot is TRUE
      if (self$return_plot) {
        return(plot_object)
      } else {
        return(invisible(NULL))
      }
    }
  )
)

#' Create Dotplot for Neurocognitive Domains, Version 2 (Function Wrapper)
#'
#' This function generates a dotplot for neurocognitive and neurobehavioral
#' domains. It's a wrapper around the DotplotR6 class.
#'
#' @param data The dataset or df containing the data for the dotplot.
#' @param x The column name in the data frame for the x-axis variable, typically
#'   the mean z-score for a cognitive domain.
#' @param y The column name in the data frame for the y-axis variable, typically
#'   the cognitive domain to plot.
#' @param linewidth The width of the line, Default: 0.5
#' @param fill The fill color for the points, Default: x-axis variable
#' @param shape The shape of the points, Default: 21
#' @param point_size The size of the points, Default: 6
#' @param line_color The color of the lines, Default: 'black'
#' @param colors A vector of colors for fill gradient, Default: NULL (uses
#'   pre-defined color palette)
#' @param theme The ggplot theme to be used, Default: 'fivethirtyeight'. Other
#'   options include 'minimal' and 'classic'
#' @param return_plot Whether to return the plot object, Default: TRUE
#' @param filename The filename to save the plot to, Default: NULL
#' @param width The width, in inches, to use when saving the figure. Default: 10
#' @param height Optional explicit height (in inches). If NULL, calculated dynamically.
#' @param base_height Inches per item for dynamic height calculation. Default: 0.4
#' @param min_height Minimum height in inches. Default: 4
#' @param height_per_row Fallback: inches per row. Default: 0.7
#' @param height_padding Fallback: additional inches. Default: 0.8
#' @param ... Additional arguments to be passed to the function.
#'
#' @return An object of class 'ggplot' representing the dotplot.
#' @rdname dotplot
#' @export
dotplot <- function(
  data,
  x,
  y,
  linewidth = 0.5,
  fill = x,
  shape = 21,
  point_size = 6,
  line_color = "black",
  colors = NULL,
  theme = "fivethirtyeight",
  return_plot = TRUE,
  filename = NULL,
  width = 10,
  height = NULL,
  base_height = 0.4,
  min_height = 4,
  height_per_row = 0.7,
  height_padding = 0.8,
  ...
) {
  # Create a DotplotR6 object and generate the plot
  dot_plot_obj <- DotplotR6$new(
    data = data,
    x = x,
    y = y,
    linewidth = linewidth,
    fill = fill,
    shape = shape,
    point_size = point_size,
    line_color = line_color,
    colors = colors,
    theme = theme,
    return_plot = return_plot,
    filename = filename,
    width = width,
    height = height,
    base_height = base_height,
    min_height = min_height,
    height_per_row = height_per_row,
    height_padding = height_padding
  )

  return(dot_plot_obj$create_plot())
}
