# Improved detect_emotion_type method for DomainProcessorR6
detect_emotion_type = function() {
  if (tolower(self$pheno) != "emotion") {
    return(NULL)
  }

  # Check domains first (most reliable method)
  child_domain_patterns <- c(
    "Behavioral/Emotional/Social",
    "Personality Disorders", 
    "Psychiatric Disorders",
    "Psychosocial Problems",
    "Substance Use"
  )

  adult_domain_patterns <- c(
    "Emotional/Behavioral/Personality"
  )

  # Check if any child-specific domains are present
  child_domain_match <- any(sapply(child_domain_patterns, function(pattern) {
    any(grepl(pattern, self$domains, ignore.case = TRUE, fixed = TRUE))
  }))
  
  # Check if any adult-specific domains are present  
  adult_domain_match <- any(sapply(adult_domain_patterns, function(pattern) {
    any(grepl(pattern, self$domains, ignore.case = TRUE, fixed = TRUE))
  }))
  
  # If we have clear domain matches, use those
  if (child_domain_match && !adult_domain_match) {
    return("child")
  } else if (adult_domain_match && !child_domain_match) {
    return("adult")
  }
  
  # If domains are ambiguous, check the data if available
  if (!is.null(self$data) && nrow(self$data) > 0) {
    
    # Check for child-specific test patterns
    child_test_patterns <- c(
      "BASC-3.*Child", "BASC.*Child", "CBCL", "TRF", "YSR",
      "Child.*Behavior", "Adolescent", "Youth", "Student"
    )
    
    adult_test_patterns <- c(
      "BASC-3.*Adult", "BASC.*Adult", "Adult.*Self", "ASR", 
      "MMPI", "PAI", "Beck.*Adult", "Adult.*Behavior"
    )
    
    # Check test names for age indicators
    if ("test_name" %in% names(self$data)) {
      test_names <- unique(self$data$test_name)
      
      child_test_match <- any(sapply(child_test_patterns, function(pattern) {
        any(grepl(pattern, test_names, ignore.case = TRUE))
      }))
      
      adult_test_match <- any(sapply(adult_test_patterns, function(pattern) {
        any(grepl(pattern, test_names, ignore.case = TRUE))
      }))
      
      if (child_test_match && !adult_test_match) {
        return("child")
      } else if (adult_test_match && !child_test_match) {
        return("adult")
      }
    }
    
    # Check for rater types (children typically have parent/teacher raters)
    if ("rater" %in% names(self$data)) {
      raters <- unique(self$data$rater)
      has_parent_teacher <- any(c("parent", "teacher") %in% tolower(raters))
      has_only_self <- length(raters) == 1 && "self" %in% tolower(raters)
      
      if (has_parent_teacher) {
        return("child")
      } else if (has_only_self) {
        return("adult")
      }
    }
  }
  
  # If we have both child and adult domain patterns, or can't determine from data,
  # prefer child as default (more common in neuropsych practice)
  if (child_domain_match || length(self$domains) > 1) {
    return("child")
  }
  
  # Final fallback
  return("child")
}