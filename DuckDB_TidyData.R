# Load necessary libraries

library(DBI)
library(duckdb)
library(dplyr)
library(glue)
library(purrr)
library(readr)
library(here)
library(arrow)

# Variables
source("R/duckdb_neuropsych_loader.R")
file_path <- here::here("data-raw", "csv")
output_dir <- here::here("data")
return_data <- FALSE # Set to FALSE to write files
use_duckdb <- TRUE

# Function to load data using DuckDB
df <- load_data_duckdb(
  file_path = file_path,
  output_dir = output_dir,
  return_data = return_data,
  use_duckdb = use_duckdb
)

# Arrow/Parquet

# Read CSV into Arrow
arrow_table <- read_csv_arrow("data-raw/csv/*.csv")

# Register Arrow table in DuckDB (zero-copy)
duckdb::duckdb_register_arrow(con, "neuropsych_arrow", arrow_table)

# Query with SQL
result <- DBI::dbGetQuery(
  con,
  "SELECT * FROM neuropsych_arrow WHERE percentile > 75"
)

## Parquet

# Variables
source("R/duckdb_neuropsych_loader.R")
file_path <- here::here("data-raw", "csv")
output_dir <- here::here("data")
return_data <- FALSE # Set to FALSE to write files
use_duckdb <- TRUE

# Write only Parquet files
df <- load_data_duckdb(
  file_path = file_path,
  output_format = "parquet",
  return_data = FALSE
)

# Write both CSV and Parquet
load_data_duckdb(
  file_path = file_path,
  output_format = "both",
  return_data = FALSE
)

# Return data in R (no file writing)
data <- load_data_duckdb(file_path = file_path, return_data = TRUE)
