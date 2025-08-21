# Remove the conflicting objects from the global environment
rm(list = c("%||%", "batch_process", "batch_process_domains", "cache_function",
  "calc_ci_95", "calc_percentile", "calc_predicted_score", "cat_neuropsych_results",
  "check_domain_raters", "concatenate_results", "create_domain_processor",
  "create_patient_workspace", "create_rbans_summary", "create_temp_dir", "dotplot",
  "drilldown", "extract_wisc5_data", "filter_data", "generate_assessment_report",
  "generate_neuropsych_report", "generate_neuropsych_report_system",
  "get_all_score_type_notes", "get_domain_info", "get_error_handler",
  "get_example_queries", "get_score_type_by_test_scale", "get_score_types_from_lookup",
  "get_source_note_by_score_type", "glue_neuropsych_results",
  "gpluck_compute_percentile_range", "gpluck_extract_tables", "gpluck_locate_areas",
  "gpluck_make_columns", "gpluck_make_score_ranges", "load_data", "load_data_duckdb",
  "load_neuropsych_packages", "make_shades", "neuro2_quick_start", "neuro2_workflow",
  "normalization", "parallel_map", "pegboard_dominant", "pegboard_nondominant",
  "plot_colors", "pluck_wiat4", "process_all_domains", "process_multi_rater_domain",
  "process_rbans_unified", "process_simple_domain", "process_with_duckdb",
  "query_neuropsych", "quick_package_check", "read_multiple_csv", "retry_with_backoff",
  "rocft_copy", "rocft_recall", "run_example_query", "safe_execute", "safe_path",
  "safe_read_csv", "safe_select", "save_as_markdown", "scico_palette",
  "setup_neuro2_packages", "standardization", "standardized_score", "time_it", "tmt_a",
  "tmt_b", "validate_and_load_data", "validate_data_structure",
  "validate_processor_inputs", "with_progress"))

# Now load the package properly
devtools::load_all(".")

# If you need to load the package in scripts, add this line at the top of your scripts:
# library(neuro2)
