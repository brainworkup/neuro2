#' DotplotR6 Class
#'
#' An R6 class that generates a dotplot for neurocognitive and neurobehavioral domains.
#' This is an R6 implementation of the dotplot function with identical functionality.
#'
#' @field data The dataset (data.frame/tibble) used to draw the plot.
#' @field x The column name for the x-axis (typically a percentile or z).
#' @field y The column name for the y-axis (typically the scale/domain label).
#' @field domain Optional domain label to keep alongside the object.
#' @field subdomain Optional subdomain label to keep alongside the object.
#' @field narrow Optional narrow label to keep alongside the object.
#' @field linewidth Line width for the segment “lollipop” stems. Default: 0.5.
#' @field fill A column name whose values determine the point fill (usually = x). Default: x.
#' @field shape Point shape. Default: 21.
#' @field point_size Point size. Default: 6.
#' @field line_color Line/point border color. Default: "black".
#' @field colors Optional vector of colors for a gradient fill. If NULL, uses internal palette.
#' @field plot_title Optional plot title.
#' @field theme One of "fivethirtyeight", "minimal", "classic". Default: "fivethirtyeight".
#' @field return_plot If TRUE, return the ggplot object; otherwise invisible(NULL).
#' @field filename Optional output filename; if given, the plot is saved.
#' @field width Width in inches when saving. Default: 10.
#' @field height Height in inches when saving. If NULL, calculated dynamically.
#' @field base_height Inches per item for dynamic height. Default: 0.4.
#' @field min_height Minimum figure height (in). Default: 4.
#' @field height_per_row Fallback inches per unique y when recomputing. Default: 0.7.
#' @field height_padding Extra inches added in fallback recompute. Default: 0.8.
#' @field plot The last ggplot object created by `create_plot()` (read-only convenience).
#'
#' @import ggplot2 ggthemes
#' @importFrom rlang .data
#' @importFrom stats reorder
#' @importFrom xfun file_ext
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
    width = 10,
    height = NULL,
    base_height = 0.4,
    min_height = 4,
    height_per_row = 0.7,
    height_padding = 0.8,
    plot = NULL,

    #' @description Initialize a new DotplotR6 object with configuration and data.
    #'
    #' @param data Data frame containing at least columns `x` and `y`.
    #' @param x Column name for x-axis (character). Default: "percentile".
    #' @param y Column name for y-axis (character). Default: "scale".
    #' @param colors Optional vector of colors for fill gradient.
    #' @param domain Optional domain label.
    #' @param plot_title Optional plot title.
    #' @param filename Optional filename to save the plot.
    #' @param fill Column name to use for point fill (default: same as x).
    #' @param height Figure height (in). If NULL, computed dynamically.
    #' @param width Figure width (in). Default: 10.
    #' @param base_height Inches per unique y item when computing height. Default: 0.4.
    #' @param min_height Minimum height (in). Default: 4.
    #' @param height_padding Extra inches in fallback recompute. Default: 0.8.
    #' @param height_per_row Fallback inches per row. Default: 0.7.
    #' @param line_color Line / border color. Default: "black".
    #' @param linewidth Line width. Default: 0.5.
    #' @param narrow Optional narrow label.
    #' @param point_size Point size. Default: 6.
    #' @param return_plot Return ggplot object? Default: TRUE.
    #' @param shape Point shape. Default: 21.
    #' @param subdomain Optional subdomain label.
    #' @param theme Theme string ("fivethirtyeight", "minimal", "classic"). Default: "fivethirtyeight".
    #' @param ... Ignored.
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
      width = 10,
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
      # Basic checks
      stopifnot(is.data.frame(data))
      if (!is.character(x) || length(x) != 1L) {
        stop("`x` must be a single column name (character).")
      }
      if (!is.character(y) || length(y) != 1L) {
        stop("`y` must be a single column name (character).")
      }
      if (!x %in% names(data)) {
        stop(sprintf("Column `%s` not found in `data`.", x))
      }
      if (!y %in% names(data)) {
        stop(sprintf("Column `%s` not found in `data`.", y))
      }
      if (!is.numeric(data[[x]]) && !is.integer(data[[x]])) {
        stop(sprintf("Column `%s` must be numeric.", x))
      }

      self$data <- data
      self$x <- x
      self$y <- y

      self$colors <- colors
      self$domain <- domain
      self$plot_title <- plot_title
      self$filename <- filename
      self$fill <- fill
      self$width <- width
      self$line_color <- line_color
      self$linewidth <- linewidth
      self$narrow <- narrow
      self$point_size <- point_size
      self$return_plot <- return_plot
      self$shape <- shape
      self$subdomain <- subdomain
      self$theme <- theme

      # Pre-compute a sensible height if not provided
      if (is.null(height)) {
        n_items <- tryCatch(
          {
            unique_y <- unique(self$data[[y]])
            unique_y <- unique_y[!is.na(unique_y)]
            n <- length(unique_y)
            if (is.na(n) || n < 1) 1L else n
          },
          error = function(e) 1L
        )

        calculated_height <- max(min_height, n_items * base_height + 2)
        self$height <- calculated_height

        if (getOption("dotplot.verbose", FALSE)) {
          message(sprintf(
            "DotplotR6: Calculated height of %.1f inches for %d items (%.2f per item + 2).",
            calculated_height,
            n_items,
            base_height
          ))
        }
      } else {
        self$height <- height
      }

      self$base_height <- base_height
      self$min_height <- min_height
      self$height_per_row <- height_per_row
      self$height_padding <- height_padding
    },

    #' @description Generate the dotplot based on the object's configuration.
    #' @return If `return_plot` is TRUE, a ggplot object; otherwise invisible(NULL).
    create_plot = function() {
      # palette (overridden if self$colors is non-NULL)
      default_palette <- c(
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
        "#1951A5",
        "#12429E",
        "#0C3496",
        "#05258F",
        "#023198"
      )
      color_palette <- if (is.null(self$colors)) {
        default_palette
      } else {
        self$colors
      }

      fill_var <- if (identical(self$fill, self$x)) self$x else self$fill
      if (!fill_var %in% names(self$data)) {
        fill_var <- self$x
      } # fail-safe

      p <- ggplot2::ggplot() +
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
            fill = .data[[fill_var]]
          ),
          shape = self$shape,
          size = self$point_size,
          color = self$line_color
        ) +
        ggplot2::scale_fill_gradientn(colors = color_palette, guide = "none") +
        ggplot2::labs(title = self$plot_title, x = NULL, y = NULL)

      # theme switch
      p <- p +
        switch(
          self$theme,
          "fivethirtyeight" = ggthemes::theme_fivethirtyeight(),
          "minimal" = ggplot2::theme_minimal(),
          "classic" = ggplot2::theme_classic(),
          ggplot2::theme_minimal()
        )

      # layout/margins/clipping
      p <- p +
        ggplot2::coord_cartesian(clip = "off") +
        ggplot2::theme(
          panel.background = ggplot2::element_rect(fill = "white", colour = NA),
          plot.background = ggplot2::element_rect(fill = "white", colour = NA),
          panel.border = ggplot2::element_rect(colour = "white", fill = NA),
          plot.margin = ggplot2::margin(t = 5, r = 5, b = 5, l = 12)
        ) +
        ggplot2::scale_x_continuous(
          expand = ggplot2::expansion(mult = c(0.2, 0.1))
        )

      # return early if not saving
      if (is.null(self$filename)) {
        self$plot <- p
        return(if (self$return_plot) p else invisible(NULL))
      }

      # caching option
      if (
        isTRUE(getOption("neuro2.skip_if_exists", TRUE)) &&
          file.exists(self$filename)
      ) {
        if (isTRUE(getOption("neuro2.verbose", TRUE))) {
          message("  ✓ ", basename(self$filename), " (cached)")
        }
        self$plot <- p
        return(if (self$return_plot) p else invisible(NULL))
      }

      # dimensions (fallback recompute if height went NULL)
      plot_width <- if (!is.null(self$width)) self$width else 10
      plot_height <- self$height
      if (is.null(plot_height)) {
        uniq_y <- tryCatch(unique(self$data[[self$y]]), error = function(e) {
          character(0)
        })
        n_rows <- length(uniq_y[!is.na(uniq_y)])
        if (is.na(n_rows) || n_rows < 1) {
          n_rows <- 1L
        }
        plot_height <- max(
          self$min_height,
          (n_rows * self$height_per_row) + self$height_padding
        )
      }

      ext <- tools::file_ext(self$filename)
      if (identical(ext, "pdf")) {
        ggplot2::ggsave(
          self$filename,
          p,
          device = "pdf",
          width = plot_width,
          height = plot_height,
          dpi = 300
        )
      } else if (identical(ext, "png")) {
        ggplot2::ggsave(
          self$filename,
          p,
          device = "png",
          width = plot_width,
          height = plot_height,
          dpi = 300
        )
      } else if (identical(ext, "svg")) {
        ggplot2::ggsave(
          self$filename,
          p,
          device = "svg",
          width = plot_width,
          height = plot_height,
          dpi = 300
        )
      } else {
        warning("Unknown extension `.", ext, "`. Saving as PNG.")
        ggplot2::ggsave(
          paste0(self$filename, ".png"),
          p,
          device = "png",
          width = plot_width,
          height = plot_height,
          dpi = 300
        )
      }

      self$plot <- p
      if (self$return_plot) p else invisible(NULL)
    }
  )
)

#' dotplot (convenience wrapper)
#'
#' @description A functional wrapper around DotplotR6 for quick plots.
#' @param data,x,y See DotplotR6 fields.
#' @inheritParams DotplotR6
#' @param ... Ignored.
#' @return A ggplot object (invisibly NULL if `return_plot = FALSE`).
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
  plot_title = NULL,
  domain = NULL,
  subdomain = NULL,
  narrow = NULL,
  ...
) {
  obj <- DotplotR6$new(
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
    height_padding = height_padding,
    plot_title = plot_title,
    domain = domain,
    subdomain = subdomain,
    narrow = narrow
  )
  obj$create_plot()
}
