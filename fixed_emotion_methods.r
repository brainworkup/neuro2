# Add this method to check if a specific rater has data
check_rater_data_exists = function(rater) {
  if (is.null(self$data) || nrow(self$data) == 0) {
    return(FALSE)
  }
  
  # Check if there's a column that indicates rater type
  rater_columns <- c("rater", "informant", "reporter")
  rater_col <- NULL
  
  for (col in rater_columns) {
    if (col %in% names(self$data)) {
      rater_col <- col
      break
    }
  }
  
  if (is.null(rater_col)) {
    # If no rater column, assume data exists for all raters
    return(TRUE)
  }
  
  # Check if this rater has any data
  rater_data <- self$data[self$data[[rater_col]] == rater, ]
  return(nrow(rater_data) > 0)
},

# Fixed emotion child QMD generation
generate_emotion_child_qmd = function(domain_name, output_file) {
  # Fix the output filename to include "_child"
  if (is.null(output_file)) {
    output_file <- paste0("_02-", self$number, "_emotion_child.qmd")
  } else {
    # Ensure the filename includes "_child"
    if (!grepl("_child", output_file)) {
      output_file <- gsub("_emotion", "_emotion_child", output_file)
    }
  }
  
  # Use correct header for child emotion domain
  correct_domain_name <- "Behavioral/Emotional/Social"
  
  # Create text files for different raters
  self_text <- paste0("_02-", self$number, "_emotion_child_text_self.qmd")
  parent_text <- paste0("_02-", self$number, "_emotion_child_text_parent.qmd")
  teacher_text <- paste0("_02-", self$number, "_emotion_child_text_teacher.qmd")

  # Start building QMD content
  qmd_content <- paste0(
    "```{=typst}\n",
    "== ", correct_domain_name, "\n",  # Use correct domain name for child
    "<sec-emotion-child>\n",
    "```\n\n"
  )
  
  # Check data availability for each rater and include conditionally
  if (self$check_rater_data_exists("self")) {
    qmd_content <- paste0(
      qmd_content,
      "### SELF-REPORT\n\n",
      "{{< include ", self_text, " >}}\n\n"
    )
  }
  
  if (self$check_rater_data_exists("parent")) {
    qmd_content <- paste0(
      qmd_content,
      "### PARENT RATINGS\n\n",
      "{{< include ", parent_text, " >}}\n\n"
    )
  }
  
  if (self$check_rater_data_exists("teacher")) {
    qmd_content <- paste0(
      qmd_content,
      "### TEACHER RATINGS\n\n",
      "{{< include ", teacher_text, " >}}\n\n"
    )
  }

  writeLines(qmd_content, output_file)
  message(paste("Generated emotion child QMD file:", output_file))
  return(output_file)
},

# Fixed emotion adult QMD generation  
generate_emotion_adult_qmd = function(domain_name, output_file) {
  # Fix the output filename to include "_adult"
  if (is.null(output_file)) {
    output_file <- paste0("_02-", self$number, "_emotion_adult.qmd")
  } else {
    # Ensure the filename includes "_adult"
    if (!grepl("_adult", output_file)) {
      output_file <- gsub("_emotion", "_emotion_adult", output_file)
    }
  }
  
  # Use correct header for adult emotion domain
  correct_domain_name <- "Emotional/Behavioral/Personality"
  
  # Create text file for self-report (adults typically only have self-report)
  text_file <- paste0("_02-", self$number, "_emotion_adult_text.qmd")

  qmd_content <- paste0(
    "```{=typst}\n",
    "== ", correct_domain_name, "\n",  # Use correct domain name for adult
    "<sec-emotion-adult>\n",
    "```\n\n",
    "{{< include ", text_file, " >}}\n\n"
  )

  writeLines(qmd_content, output_file)
  message(paste("Generated emotion adult QMD file:", output_file))
  return(output_file)
},

# Enhanced ADHD methods with similar fixes
generate_adhd_child_qmd = function(domain_name, output_file) {
  # Fix the output filename to include "_child"
  if (is.null(output_file)) {
    output_file <- paste0("_02-", self$number, "_adhd_child.qmd")
  } else {
    if (!grepl("_child", output_file)) {
      output_file <- gsub("_adhd", "_adhd_child", output_file)
    }
  }
  
  # Create text files for different raters
  self_text <- paste0("_02-", self$number, "_adhd_child_text_self.qmd")
  parent_text <- paste0("_02-", self$number, "_adhd_child_text_parent.qmd")
  teacher_text <- paste0("_02-", self$number, "_adhd_child_text_teacher.qmd")

  qmd_content <- paste0(
    "```{=typst}\n",
    "== ", domain_name, "\n",
    "<sec-adhd-child>\n",
    "```\n\n"
  )
  
  # Check data availability for each rater and include conditionally
  if (self$check_rater_data_exists("self")) {
    qmd_content <- paste0(
      qmd_content,
      "### SELF-REPORT\n\n",
      "{{< include ", self_text, " >}}\n\n"
    )
  }
  
  if (self$check_rater_data_exists("parent")) {
    qmd_content <- paste0(
      qmd_content,
      "### PARENT RATINGS\n\n",
      "{{< include ", parent_text, " >}}\n\n"
    )
  }
  
  if (self$check_rater_data_exists("teacher")) {
    qmd_content <- paste0(
      qmd_content,
      "### TEACHER RATINGS\n\n",
      "{{< include ", teacher_text, " >}}\n\n"
    )
  }

  writeLines(qmd_content, output_file)
  message(paste("Generated ADHD child QMD file:", output_file))
  return(output_file)
},

generate_adhd_adult_qmd = function(domain_name, output_file) {
  # Fix the output filename to include "_adult"
  if (is.null(output_file)) {
    output_file <- paste0("_02-", self$number, "_adhd_adult.qmd")
  } else {
    if (!grepl("_adult", output_file)) {
      output_file <- gsub("_adhd", "_adhd_adult", output_file)
    }
  }
  
  # Create text files for different raters
  self_text <- paste0("_02-", self$number, "_adhd_adult_text_self.qmd")
  observer_text <- paste0("_02-", self$number, "_adhd_adult_text_observer.qmd")

  qmd_content <- paste0(
    "```{=typst}\n",
    "== ", domain_name, "\n",
    "<sec-adhd-adult>\n",
    "```\n\n"
  )
  
  # Check data availability for each rater and include conditionally
  if (self$check_rater_data_exists("self")) {
    qmd_content <- paste0(
      qmd_content,
      "### SELF-REPORT\n\n",
      "{{< include ", self_text, " >}}\n\n"
    )
  }
  
  if (self$check_rater_data_exists("observer")) {
    qmd_content <- paste0(
      qmd_content,
      "### OBSERVER RATINGS\n\n",
      "{{< include ", observer_text, " >}}\n\n"
    )
  }

  writeLines(qmd_content, output_file)
  message(paste("Generated ADHD adult QMD file:", output_file))
  return(output_file)
},

# Also need to fix the main generate_domain_qmd method to pass the correct output_file
generate_domain_qmd = function(domain_name = NULL, output_file = NULL) {
  if (is.null(domain_name)) {
    domain_name <- self$domains[1]
  }

  # Handle special cases for multi-rater domains
  if (self$has_multiple_raters()) {
    if (tolower(self$pheno) == "emotion") {
      emotion_type <- self$detect_emotion_type()
      
      # Fix output filename for emotion
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_emotion_", emotion_type, ".qmd")
      }
      
      if (emotion_type == "child") {
        return(self$generate_emotion_child_qmd(domain_name, output_file))
      } else {
        return(self$generate_emotion_adult_qmd(domain_name, output_file))
      }
    } else if (tolower(self$pheno) == "adhd") {
      is_child <- any(grepl("child", tolower(self$domains))) ||
        (!is.null(self$data) &&
          any(grepl("child|adolescent", self$data$test_name, ignore.case = TRUE)))
      
      # Fix output filename for ADHD
      age_type <- if (is_child) "child" else "adult"
      if (is.null(output_file)) {
        output_file <- paste0("_02-", self$number, "_adhd_", age_type, ".qmd")
      }

      if (is_child) {
        return(self$generate_adhd_child_qmd(domain_name, output_file))
      } else {
        return(self$generate_adhd_adult_qmd(domain_name, output_file))
      }
    }
  }

  # For standard domains, use original logic
  if (is.null(output_file)) {
    output_file <- paste0("_02-", self$number, "_", tolower(self$pheno), ".qmd")
  }

  # Generate standard domain QMD following memory template exactly
  return(self$generate_standard_qmd(domain_name, output_file))
}