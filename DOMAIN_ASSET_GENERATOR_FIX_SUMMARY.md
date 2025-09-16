# Fixed: 04_generate_all_domain_assets.R

## Problem

The original `04_generate_all_domain_assets.R` script was using **basic gt() and ggplot()** calls to generate table and figure assets, which:

1. **Created inconsistent output** compared to the domain QMD files
2. **Didn't use your established R6 classes** (`TableGTR6` and `DotplotR6`)  
3. **Generated poor quality plots** with basic aesthetics
4. **Lacked proper data processing** (z-score calculations, aggregations)
5. **Missing multiple output formats** (PNG, PDF, SVG)

## Bad Code (Original)

```r
# Create a simple GT table
table_data <- data |>
  select(test, score, percentile) |>
  slice_head(n = 10)  # Limit for display

gt_table <- gt(table_data) |>
  tab_header(title = config$name) |>
  fmt_number(columns = c(score, percentile), decimals = 1)

# Save table
gtsave(gt_table, table_file)
```

```r
# Create a simple plot
p <- ggplot(data, aes(x = test, y = percentile)) +
  geom_point() +
  theme_minimal() +
  labs(title = paste(config$name, "- Narrow"))

ggsave(narrow_fig, p, width = 8, height = 6)
```

## Good Code (Fixed)

```r
# GENERATE TABLE USING PROPER TableGTR6 CLASS
if (exists("TableGTR6")) {
  table_processor <- TableGTR6$new(
    data = data,
    pheno = clean_domain,
    table_name = paste0("table_", clean_domain),
    vertical_padding = 0
  )
  tbl <- table_processor$build_table()
  table_processor$save_table(tbl, dir = FIGURE_DIR)
}
```

```r
# GENERATE SUBDOMAIN FIGURE USING PROPER DotplotR6 CLASS
if (exists("DotplotR6")) {
  fig_path <- file.path(FIGURE_DIR, paste0("fig_", clean_domain, "_subdomain"))
  dotplot_subdomain <- DotplotR6$new(
    data = data_subdomain,
    x = "z_mean_subdomain", 
    y = "subdomain"
  )
  
  # Create all format variants
  for (ext in c("png", "pdf", "svg")) {
    dotplot_subdomain$filename <- paste0(fig_path, ".", ext)
    dotplot_subdomain$create_plot()
  }
}
```

## Key Improvements

### 1. **Proper R6 Class Usage**
- ✅ Uses `TableGTR6$new()` instead of basic `gt()`
- ✅ Uses `DotplotR6$new()` instead of basic `ggplot()`
- ✅ Consistent with domain QMD file implementations

### 2. **Data Processing**
- ✅ Calculates z-scores if missing: `z = qnorm(percentile / 100)`
- ✅ Uses `calculate_z_stats()` function for aggregations
- ✅ Creates `z_mean_subdomain` and `z_mean_narrow` columns
- ✅ Handles missing data properly

### 3. **Multiple Output Formats**
- ✅ Creates PNG, PDF, and SVG versions of each figure
- ✅ Matches the format variety used in domain QMD files

### 4. **Better Error Handling**
- ✅ Checks if R6 classes exist before using them
- ✅ Provides fallback implementations if classes aren't loaded
- ✅ Comprehensive error reporting with context

### 5. **Improved Output Quality**
- ✅ Uses your established color scheme (`#E89606`)
- ✅ Professional formatting and themes
- ✅ Proper axis labels and titles
- ✅ Consistent styling across all outputs

## Fallback Strategy

The fixed version includes fallback implementations in case the R6 classes aren't available:

```r
if (exists("TableGTR6")) {
  # Use proper R6 class
} else {
  # Fallback: improved GT table with proper column selection
}

if (exists("DotplotR6")) {
  # Use proper R6 class  
} else {
  # Fallback: improved ggplot with proper aesthetics
}
```

## Usage

Replace your current `04_generate_all_domain_assets.R` with the fixed version:

```bash
# Backup original
mv 04_generate_all_domain_assets.R 04_generate_all_domain_assets_OLD.R

# Use fixed version
cp /mnt/user-data/outputs/04_generate_all_domain_assets_FIXED.R 04_generate_all_domain_assets.R

# Run it
Rscript 04_generate_all_domain_assets.R
```

## Benefits

1. **Consistent Output**: All assets now use the same R6 classes as domain QMD files
2. **Higher Quality**: Professional tables and plots with proper formatting
3. **Multiple Formats**: PNG/PDF/SVG variants for different use cases
4. **Better Integration**: Seamlessly works with your existing neuro2 package
5. **Robust**: Handles edge cases and missing data properly

## Validation

You can verify the fix is working by checking:

```r
# Check if generated files match domain QMD outputs
list.files("figs/", pattern = "table_.*\\.png")
list.files("figs/", pattern = "fig_.*_subdomain\\.(png|pdf|svg)")
list.files("figs/", pattern = "fig_.*_narrow\\.(png|pdf|svg)")
```

The outputs should now be **identical in quality and format** to what your domain QMD files generate! 🎯
