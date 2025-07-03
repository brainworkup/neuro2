## code to prepare `neurobehav` dataset goes here

neurobehav <- readr::read_csv("data-raw/neurobehav.csv")
usethis::use_data(neurobehav, overwrite = TRUE, internal = TRUE)
