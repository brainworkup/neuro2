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
#' @field return_plot Whether to return the plot object, Default: TRUE
#' @field filename The filename to save the plot to, Default: NULL
#' @field width Plot width in inches, Default: 10
#' @field height Plot height in inches, Default: 6
#' @field dpi Resolution for raster outputs, Default: 300
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
    linewidth = 0.5,
    fill = NULL,
    shape = 21,
    point_size = 6,
    line_color = "black",
    colors = NULL,
    theme = "fivethirtyeight",
    return_plot = TRUE,
    filename = NULL,
    width = 10,
    height = 6,
    dpi = 300,

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
    #' @param width Plot width in inches, Default: 10
    #' @param height Plot height in inches, Default: 6
    #' @param dpi Resolution for raster outputs, Default: 300
    #' @param ... Additional arguments (ignored).
    #'
    #' @return A new DotplotR6 object
    initialize = function(
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
      height = 6,
      dpi = 300,
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
      self$height <- height
      self$dpi <- dpi
    },

    #' @description
    #' Generate the dotplot based on the object's configuration.
    #'
    #' @return If return_plot is TRUE, returns an object of class 'ggplot' representing the dotplot.
    #'   Otherwise returns invisible(NULL).
    create_plot = function() {
      # Remove NA values if they exist
      if (any(is.na(self$data[[self$x]]) | is.na(self$data[[self$y]]))) {
        message("Removing rows with NA values in x or y columns")
        self$data <- self$data[
          !is.na(self$data[[self$x]]) & !is.na(self$data[[self$y]]),
        ]
      }

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
          plot.margin = ggplot2::margin(t = 5, r = 5, b = 5, l = 10),
          axis.text.y = ggplot2::element_text(size = 10, hjust = 1)
        )

      # Add x-axis expansion
      plot_object <- plot_object +
        ggplot2::scale_x_continuous(
          expand = ggplot2::expansion(mult = c(0.2, 0.1))
        )

      # Save the plot to a file if filename is provided
      if (!is.null(self$filename)) {
        # Determine file extension to save accordingly
        ext <- tools::file_ext(self$filename)

        if (ext == "pdf") {
          ggplot2::ggsave(
            filename = self$filename,
            plot = plot_object,
            device = "pdf",
            width = self$width,
            height = self$height,
            dpi = self$dpi
          )
        } else if (ext == "png") {
          ggplot2::ggsave(
            filename = self$filename,
            plot = plot_object,
            device = "png",
            width = self$width,
            height = self$height,
            dpi = self$dpi
          )
        } else if (ext == "svg") {
          # SVG requires the svglite package or built-in svg device
          if (requireNamespace("svglite", quietly = TRUE)) {
            ggplot2::ggsave(
              filename = self$filename,
              plot = plot_object,
              device = svglite::svglite,
              width = self$width,
              height = self$height
            )
          } else {
            # Fall back to base R svg device
            ggplot2::ggsave(
              filename = self$filename,
              plot = plot_object,
              device = "svg",
              width = self$width,
              height = self$height
            )
          }
        } else {
          warning(
            "File extension not recognized. ",
            "Supported extensions are 'pdf', 'png', and 'svg'."
          )
        }

        message(paste("Plot saved to:", self$filename))
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
#' @param width Plot width in inches, Default: 10
#' @param height Plot height in inches, Default: 6
#' @param dpi Resolution for raster outputs, Default: 300
#' @param na.rm Whether to remove NA values, Default: FALSE
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
  height = 6,
  dpi = 300,
  na.rm = FALSE,
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
    dpi = dpi
  )

  return(dot_plot_obj$create_plot())
}
