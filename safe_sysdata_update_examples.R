# Safe way to update sysdata.rda without overwriting existing variables
# This addresses the issue mentioned about create_sysdata.R overwriting the entire file

library(usethis)

# Example usage for your create_sysdata.R script:
# Instead of using usethis::use_data(..., internal = TRUE, overwrite = TRUE)
# You would use:

# Example 1: Only add new objects, never overwrite existing ones
safe_use_data_internal(
  scales_iq = scales_iq,
  scales_academics = scales_academics,
  add_only = TRUE
)

# Example 2: Only overwrite specific objects
safe_use_data_internal(
  scales_iq = scales_iq,
  scales_academics = scales_academics,
  dots = dots,  # This exists in the file
  overwrite = c("dots")  # Only allow overwriting 'dots'
)

# Example 3: Update create_sysdata.R to use this function
# At the end of your create_sysdata.R, replace the usethis::use_data() calls with:
#
# source("safe_sysdata_update_fixed.R")  # Note: Use the fixed version
#
# For the scales data
safe_use_data_internal(
  scales_iq = scales_iq,
  scales_academics = scales_academics,
  scales_verbal = scales_verbal,
  scales_spatial = scales_spatial,
  scales_memory = scales_memory,
  scales_memory_order = scales_memory_order,
  scales_executive = scales_executive,
  scales_motor = scales_motor,
  scales_social = scales_social,
  scales_adhd_adult = scales_adhd_adult,
  scales_adhd_child = scales_adhd_child,
  scales_emotion_adult = scales_emotion_adult,
  scales_emotion_child = scales_emotion_child,
  scales_adaptive = scales_adaptive,
  scales_daily_living = scales_daily_living,
  scales_all = scales_all,
  overwrite = c(
    "scales_iq",
    "scales_academics",
    "scales_verbal",
    "scales_spatial",
    "scales_memory",
    "scales_memory_order",
    "scales_executive",
    "scales_motor",
    "scales_social",
    "scales_adhd_adult",
    "scales_adhd_child",
    "scales_emotion_adult",
    "scales_emotion_child",
    "scales_adaptive",
    "scales_daily_living",
    "scales_all"
  )
)

# # For the plot titles
# safe_use_data_internal(
#   plot_title_neurocognition = plot_title_neurocognition,
#   plot_title_iq = plot_title_iq,
#   plot_title_academics = plot_title_academics,
#   plot_title_verbal = plot_title_verbal,
#   plot_title_spatial = plot_title_spatial,
#   plot_title_memory = plot_title_memory,
#   plot_title_executive = plot_title_executive,
#   plot_title_motor = plot_title_motor,
#   plot_title_social = plot_title_social,
#   plot_title_adhd_adult = plot_title_adhd_adult,
#   plot_title_emotion_adult = plot_title_emotion_adult,
#   plot_title_adaptive = plot_title_adaptive,
#   plot_title_daily_living = plot_title_daily_living,
#   overwrite = c(
#     "plot_title_neurocognition",
#     "plot_title_iq",
#     "plot_title_academics",
#     "plot_title_verbal",
#     "plot_title_spatial",
#     "plot_title_memory",
#     "plot_title_executive",
#     "plot_title_motor",
#     "plot_title_social",
#     "plot_title_adhd_adult",
#     "plot_title_emotion_adult",
#     "plot_title_adaptive",
#     "plot_title_daily_living"
#   )
# )
#
# # For other data
# safe_use_data_internal(
#   lookup_table = lookup_table,
#   dots = dots,
#   overwrite = c("lookup_table", "dots")
# )
