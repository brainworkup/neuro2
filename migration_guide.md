# Migration Guide: Simplified DomainProcessorR6

## Key Problems with the Original Code

1. **Hardcoded Logic**: Specific logic for "emotion" and "adhd" domains
2. **Complex Rater Detection**: Hardcoded assumptions about child vs adult
3. **Duplicated Code**: Separate methods for different rater combinations
4. **Inflexible**: Can't easily add new domains or rater combinations
5. **Hard to Maintain**: Changes require modifying multiple hardcoded sections

## Key Improvements in New Version

1. **Data-Driven**: Uses your CSV lookup table as the source of truth
2. **Systematic**: Automatically detects raters and age groups for any domain
3. **DRY (Don't Repeat Yourself)**: Single logic path handles all cases
4. **Flexible**: Easy to add new domains/tests by updating the CSV
5. **Maintainable**: Changes only require updating the lookup table

## Comparison: Old vs New Approach

### OLD WAY (Complex and Hardcoded)
```r
# Hardcoded domain detection
has_multiple_raters = function() {
  tolower(self$pheno) %in% c("emotion", "adhd")  # Hardcoded!
}

detect_emotion_type = function() {
  if (tolower(self$pheno) != "emotion") return(NULL)
  
  # Hardcoded domain name checks
  if (any(grepl("Behavioral/Emotional/Social", self$domains, ignore.case = TRUE))) {
    return("child")
  } else if (any(grepl("Emotional/Behavioral/Personality", self$domains, ignore.case = TRUE))) {
    return("adult")
  }
  
  # Hardcoded file checks
  if (file.exists("basc3_prs_child.csv")) return("child")
  if (file.exists("pai_adol.csv")) return("adult")
  
  return("child")  # Hardcoded default
}

get_rater_types = function() {
  if (tolower(self$pheno) == "adhd") {
    return(c("self", "observer"))  # Hardcoded!
  }
  
  if (tolower(self$pheno) == "emotion") {
    emotion_type <- self$detect_emotion_type()
    if (emotion_type == "child") {
      return(c("self", "parent", "teacher"))  # Hardcoded!
    } else {
      return(c("self"))  # Hardcoded!
    }
  }
  
  return(NULL)
}
```

### NEW WAY (Data-Driven and Systematic)
```r
# Data-driven rater detection
get_available_raters = function() {
  domain_tests <- self$test_lookup %>%
    dplyr::filter(
      domain %in% self$domains,
      age_group %in% c(self$age_group, "child/adult")
    )
  
  unique(domain_tests$rater)  # Automatically determined from data!
}

has_multiple_raters = function() {
  length(self$get_available_raters()) > 1  # Simple and universal
}

get_tests_for_rater = function(rater) {
  self$test_lookup %>%
    dplyr::filter(
      domain %in% self$domains,
      rater == !!rater,
      age_group %in% c(self$age_group, "child/adult")
    ) %>%
    dplyr::pull(test)  # Tests determined from lookup table
}
```

## Migration Steps

### Step 1: Create the Test Lookup File
Ensure your `test_testname_rater.csv` file is in the project root or specify its location.

### Step 2: Replace the Old Class
Replace your old `DomainProcessorR6.R` file with the new simplified version.

### Step 3: Update Your Usage

**OLD USAGE:**
```r
# Complex instantiation with hardcoded assumptions
processor <- DomainProcessorR6$new(
  domains = c("Behavioral/Emotional/Social"),
  pheno = "emotion",
  input_file = "neurobehav.csv"
)

# Had to manually detect child vs adult, rater types, etc.
processor$process(generate_domain_files = TRUE)
```

**NEW USAGE:**
```r
# Simple, explicit instantiation
processor <- DomainProcessorR6$new(
  domains = "Behavioral/Emotional/Social",
  pheno = "emotion",
  input_file = "neurobehav.csv", 
  age_group = "child"  # Explicit, not guessed
)

# Or use the helper function
processor <- create_domain_processor(
  domain_name = "Behavioral/Emotional/Social",
  data_file = "neurobehav.csv",
  age_group = "child"
)

processor$process(generate_qmd = TRUE)
```

### Step 4: Use the New Helper Functions

**For Simple Domains (single rater):**
```r
# Personality disorders, substance use, etc.
process_simple_domain("Personality Disorders", "neurobehav.csv", "adult")
```

**For Multi-Rater Domains:**
```r  
# ADHD, Behavioral/Emotional/Social, etc.
process_multi_rater_domain("ADHD", "neurobehav.csv", "adult")
```

**Explore Available Options:**
```r
# See what domains are available
get_domain_info()

# Check what raters are available for a specific domain
check_domain_raters("ADHD", "adult")
check_domain_raters("Behavioral/Emotional/Social", "child")
```

## Benefits of the New Approach

### 1. Easier to Add New Tests
**OLD:** Had to modify multiple functions and add hardcoded logic
**NEW:** Just add a row to the CSV file

### 2. Clearer Age Group Handling  
**OLD:** Complex detection logic that could fail
**NEW:** Explicit age_group parameter

### 3. Universal Logic
**OLD:** Different code paths for different domains
**NEW:** Same logic works for all domains

### 4. Better Error Messages
**OLD:** Cryptic failures when detection logic failed
**NEW:** Clear messages about what's available

### 5. Easier Testing
**OLD:** Had to mock file existence and domain names
**NEW:** Just provide different CSV data

## Common Patterns

### Pattern 1: Adult Self-Report Only
```r
# Domains: Personality Disorders, Psychiatric Disorders, Substance Use, etc.
processor <- process_simple_domain("Personality Disorders", "data.csv", "adult")
```

### Pattern 2: Child Multi-Rater  
```r
# Domains: Behavioral/Emotional/Social, ADHD (child)
processor <- process_multi_rater_domain("Behavioral/Emotional/Social", "data.csv", "child")
# Automatically includes: self, parent, teacher (as available)
```

### Pattern 3: Adult Multi-Rater
```r
# Domains: ADHD (adult), Adaptive Functioning
processor <- process_multi_rater_domain("ADHD", "data.csv", "adult") 
# Automatically includes: self, observer (as available)
```

### Pattern 4: Batch Processing
```r
adult_domains <- c("Personality Disorders", "ADHD", "Substance Use")
results <- batch_process_domains(adult_domains, "data.csv", "adult")
```

## Troubleshooting

### "Test lookup file not found"
Make sure `test_testname_rater.csv` is in your project root, or specify the full path:
```r
processor <- DomainProcessorR6$new(..., test_lookup_file = "path/to/file.csv")
```

### "No tests found for domain"
Check the exact domain name in your CSV file:
```r
get_domain_info()  # See all available domains
```

### "No tests found for rater"
Check what raters are available:
```r
check_domain_raters("Your Domain", "adult")
```

This new approach is much simpler, more maintainable, and easier to extend!
