# .Rprofile for neuro2 package development

if (interactive()) {
  suppressMessages(require(devtools))
  suppressMessages(require(usethis))

  # Note: Removed automatic devtools::load_all() to prevent UI comm errors
  # You can manually run devtools::load_all() when needed
  cat(
    "Development tools loaded. Run devtools::load_all() to load neuro2 package.\n"
  )

  # Set options
  options(
    usethis.full_name = "Joey Trampush",
    usethis.protocol = "https",
    usethis.description = list(
      `Authors@R` = 'person("Joey", "Trampush", 
                           email = "j.trampush@gmail.com", 
                           role = c("aut", "cre"))'
    )
  )
}

# Set option to convert conflict warnings to messages
options(conflicts.policy = list(warn = FALSE))

# Load conflicted package but don't auto-prefer neuro2 functions
# library(conflicted)
# Removed: conflict_prefer_all("neuro2", quiet = TRUE)
