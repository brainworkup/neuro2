# .Rprofile for neuro2 package development

if (interactive()) {
  suppressMessages(require(devtools))
  suppressMessages(require(usethis))

  # Automatically load the package when starting R in this project
  cat("Loading neuro2 package for development...\n")
  devtools::load_all(quiet = TRUE)

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

# Or use the conflicted package
library(conflicted)
conflict_prefer_all("neuro2", quiet = TRUE)
