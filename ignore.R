usethis::use_build_ignore(c(".history/", ".Rhistory", ".Rproj.user", ".RData", ".Ruserdata", ".DS_Store",
                            "data-raw/", "data/", "docs/", "vignettes/", "tests/testthat/",
                            "tests/testthat.Rout", "tests/testthat.Rout.save", "tests/testthat.Rout.fail",
                            "tests/testthat.Rout.fail.save", "tests/testthat.Rcheck.log",
                            "tests/testthat.Rcheck/", "README.md", "LICENSE", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", ".roo/","air.toml"))

library(quarto)
# Basic span usage in table cells
quarto::tbl_qmd_span("**bold text**")
tbl_qmd_span("$\\alpha + \\beta$", display = "Greek formula")

# Basic div usage in table cells
tbl_qmd_div("## Section Title\n\nContent here")
tbl_qmd_div("{{< video https://example.com >}}", display = "[Video content]")

# Explicit encoding choices
tbl_qmd_span_base64("Complex $\\LaTeX$ content")
tbl_qmd_span_raw("Simple text")

# Use with different HTML table packages
if (FALSE) { # \dontrun{
  # With kableExtra
  library(kableExtra)
  df <- data.frame(
    math = c(tbl_qmd_span("$x^2$"), tbl_qmd_span("$\\sum_{i=1}^n x_i$")),
    text = c(tbl_qmd_span("**Important**", "bold"), tbl_qmd_span("`code`", "code"))
  )
  kbl(df, format = "html", escape = FALSE) |> kable_styling()
} # }
