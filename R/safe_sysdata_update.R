#' Safely update internal package data without overwriting existing variables
#'
#' @param ... Named objects to save
#' @param file Path to the .rda file (default: "R/sysdata.rda")
#' @param overwrite Character vector of object names that should be overwritten
#' @param add_only Logical, if TRUE only add new objects, never overwrite
.safe_use_data_internal <- function(
  ...,
  file = "R/sysdata.rda",
  overwrite = NULL,
  add_only = FALSE
) {
  # Get the new objects to save
  new_objects <- list(...)
  new_names <- names(new_objects)

  if (is.null(new_names) || any(new_names == "")) {
    # Get names from the call if not provided
    dots <- match.call(expand.dots = FALSE)$...
    new_names <- as.character(dots)
  }

  # Check if the file exists
  if (file.exists(file)) {
    # Load existing objects into a new environment
    existing_env <- new.env()
    load(file, envir = existing_env)
    existing_names <- ls(envir = existing_env)

    cat("Existing objects in", file, ":\n")
    cat("  ", paste(existing_names, collapse = ", "), "\n\n")

    # Check for conflicts
    conflicts <- intersect(new_names, existing_names)

    if (length(conflicts) > 0) {
      cat("Found conflicts with existing objects:\n")
      cat("  ", paste(conflicts, collapse = ", "), "\n")

      if (add_only) {
        # Remove conflicting objects from new list
        keep_idx <- !new_names %in% conflicts
        new_objects <- new_objects[keep_idx]
        new_names <- new_names[keep_idx]
        cat("  -> Skipping all conflicts (add_only = TRUE)\n")
      } else if (!is.null(overwrite)) {
        # Only overwrite specified objects
        allowed_overwrites <- intersect(conflicts, overwrite)
        forbidden_overwrites <- setdiff(conflicts, overwrite)

        if (length(allowed_overwrites) > 0) {
          cat(
            "  -> Will overwrite:",
            paste(allowed_overwrites, collapse = ", "),
            "\n"
          )
        }
        if (length(forbidden_overwrites) > 0) {
          cat(
            "  -> Will skip:",
            paste(forbidden_overwrites, collapse = ", "),
            "\n"
          )
          # Remove forbidden overwrites from new list
          keep_idx <- !new_names %in% forbidden_overwrites
          new_objects <- new_objects[keep_idx]
          new_names <- new_names[keep_idx]
        }
      } else {
        # Ask user what to do
        cat("\nWhat would you like to do?\n")
        cat("1. Overwrite all conflicts\n")
        cat("2. Skip all conflicts\n")
        cat("3. Cancel operation\n")

        choice <- readline("Enter choice (1-3): ")

        if (choice == "1") {
          cat("  -> Overwriting all conflicts\n")
        } else if (choice == "2") {
          # Remove conflicting objects from new list
          keep_idx <- !new_names %in% conflicts
          new_objects <- new_objects[keep_idx]
          new_names <- new_names[keep_idx]
          cat("  -> Skipping all conflicts\n")
        } else {
          stop("Operation cancelled")
        }
      }
    }

    # Merge objects
    final_env <- new.env()

    # First, copy all existing objects
    for (name in existing_names) {
      assign(name, get(name, envir = existing_env), envir = final_env)
    }

    # Then, add/overwrite with new objects
    for (i in seq_along(new_names)) {
      assign(new_names[i], new_objects[[i]], envir = final_env)
    }

    # Save all objects
    all_names <- ls(envir = final_env)
    save(list = all_names, file = file, envir = final_env)

    cat("\nSaved", length(all_names), "objects to", file, "\n")
    cat("Final objects:", paste(sort(all_names), collapse = ", "), "\n")
  } else {
    # File doesn't exist, create it normally
    cat("Creating new file:", file, "\n")

    # Create environment with new objects
    final_env <- new.env()
    for (i in seq_along(new_names)) {
      assign(new_names[i], new_objects[[i]], envir = final_env)
    }

    save(list = new_names, file = file, envir = final_env)
    cat("Saved", length(new_names), "objects to", file, "\n")
  }
}
