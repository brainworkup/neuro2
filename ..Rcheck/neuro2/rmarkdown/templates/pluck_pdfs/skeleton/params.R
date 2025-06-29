# Parameters

patient <- "Biggie"

test <- "wais5"
test_name <- "WAIS-5"
pages <- c(5, 5)
extract_columns <- c(1, 3, 4, 5)

test <- "wrat5"
test_name <- "WRAT-5"
pages <- c(2)
extract_columns <- c(1, 2, 3, 4, 5)
score_type <- "standard_score"

pdf <- file.path(file.choose(""))
file <- pdf

params <-
  list(
    patient = patient,
    test = test,
    test_name = test_name,
    file = file,
    pages = pages
  )

# Extracted areas
extracted_areas <- tabulapdf::extract_areas(
  file = file,
  pages = pages,
  method = "decide",
  output = "matrix",
  copy = TRUE
)

# Loop over the list and write each matrix to a CSV file
for (i in seq_along(extracted_areas)) {
  write.csv(extracted_areas[[i]], file = paste0(test, "_", i, ".csv"), row.names = FALSE)
}

# Save the entire list to an R data file
save(extracted_areas, file = paste0(test, "_extracted_areas.RData"))

# Check the extracted areas
str(extracted_areas)
