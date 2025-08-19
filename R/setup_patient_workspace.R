# Add to your DomainProcessorR6:
setup_patient_workspace <- function(patient_name, base_dir = ".") {
  # Create patient-specific directories
  dirs <- c("data", "figs", "output", "tmp")
  for (dir in dirs) {
    dir.create(file.path(base_dir, dir), recursive = TRUE)
  }

  # Copy template config
  file.copy(
    system.file("patient_template/config.yml", package = "neuro2"),
    file.path(base_dir, "config.yml")
  )
}
