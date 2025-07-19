library(shiny)
library(dplyr)

# Normative data for Grooved Pegboard (time in seconds)
norm_data <- tibble::tribble(
  ~AgeMin, ~AgeMax, ~DOM_M, ~DOM_SD, ~NONDOM_M, ~NONDOM_SD,
  4, 4, 65.21, 28.90, 82.9, 38.9,
  8, 8, 36.00, 8.00, 39.0, 10.0,
  9, 9, 74.00, 15.00, 80.0, 15.1,
  8, 9, 81.96, 13.79, 93.6, 17.7,
  10, 10, 72.00, 10.00, 78.0, 10.0,
  11, 11, 70.00, 8.00, 76.0, 8.3,
  12, 12, 68.00, 7.50, 74.0, 7.8,
  13, 13, 64.61, 10.80, 70.0, 10.9,
  14, 14, 63.50, 8.80, 69.1, 9.4,
  20, 24, 57.95, 8.32, 63.64, 9.40,
  25, 29, 60.12, 10.31, 65.95, 11.53,
  30, 34, 62.29, 11.91, 68.25, 13.23,
  35, 39, 64.46, 13.13, 70.56, 14.49,
  40, 44, 66.63, 13.95, 72.86, 15.33,
  45, 49, 68.79, 14.39, 75.16, 15.74,
  50, 54, 70.96, 14.44, 77.47, 15.72,
  55, 59, 73.13, 14.10, 79.77, 15.26,
  60, 64, 75.30, 13.38, 82.08, 14.38
)

ui <- fluidPage(
  titlePanel("Grooved Pegboard Normative Calculator"),
  sidebarLayout(
    sidebarPanel(
      numericInput("age", "Age (years):", value = NA, min = 4, max = 100, step = 1),
      numericInput("raw_dom", "Raw Time Dominant Hand (sec):", value = NA, min = 0),
      numericInput("raw_nondom", "Raw Time Non-Dominant Hand (sec):", value = NA, min = 0),
      actionButton("calc", "Calculate")
    ),
    mainPanel(
      tableOutput("results")
    )
  )
)

server <- function(input, output, session) {
  calc_vals <- eventReactive(input$calc, {
    req(input$age, input$raw_dom, input$raw_nondom)
    age <- input$age

    # Select normative row: exact match first, else range
    norm_row <- norm_data %>%
      filter((AgeMin == AgeMax & AgeMin == age) |
               (AgeMin < AgeMax & age >= AgeMin & age <= AgeMax)) %>%
      arrange((AgeMax - AgeMin)) %>%
      slice(1)
    req(nrow(norm_row) == 1)

    # Compute reversed stats: higher raw = slower = worse
    compute_rev <- function(raw, m, sd) {
      z <- (m - raw) / sd
      t <- 50 + 10 * z
      pctl <- pnorm(z) * 100
      list(z = z, t = t, p = pctl)
    }

    dom_stats    <- compute_rev(input$raw_dom,    norm_row$DOM_M,    norm_row$DOM_SD)
    nondom_stats <- compute_rev(input$raw_nondom, norm_row$NONDOM_M, norm_row$NONDOM_SD)

    # Prepare output table
    tibble::tibble(
      Hand       = c("Dominant", "Non-Dominant"),
      Raw_Time   = c(input$raw_dom, input$raw_nondom),
      Mean       = c(norm_row$DOM_M, norm_row$NONDOM_M),
      SD         = c(norm_row$DOM_SD, norm_row$NONDOM_SD),
      Z_score    = c(dom_stats$z, nondom_stats$z),
      T_score    = c(dom_stats$t, nondom_stats$t),
      Percentile = c(dom_stats$p, nondom_stats$p)
    )
  })

  output$results <- renderTable({
    calc_vals()
  }, digits = c(NA, 2, 2, 2, 2, 1, 1),
  caption = "Grooved Pegboard Scores vs Norms (Reversed: higher = worse)")
}

shinyApp(ui, server)
