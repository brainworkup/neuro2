
# First load conflicted
if (!requireNamespace("conflicted", quietly = TRUE)) {
  install.packages("conflicted")
}
library(conflicted)

# Then load your package
devtools::load_all(".")
