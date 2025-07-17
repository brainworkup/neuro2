# Load necessary libraries

library(DBI)
library(duckdb)
library(dplyr)
library(glue)
library(purrr)
library(readr)
library(here)

# Variables
source("R/duckdb_data_loader.R")
file_path <- here::here("data-raw", "csv")
output_dir <- here::here("data")
return_data <- FALSE  # Set to FALSE to write files
use_duckdb <- TRUE

# Function to load data using DuckDB
df <- load_data_duckdb(
  file_path = file_path,
  output_dir = output_dir,
  return_data = return_data,
  use_duckdb = use_duckdb
)
