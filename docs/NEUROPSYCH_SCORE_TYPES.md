# Neuropsychological Test Score Type Mapping

This document explains the standardized system for mapping neuropsychological tests to their correct score types in the neuro2 package.

## Overview

Neuropsychological tests use different standardized scoring systems:

- **Scaled Scores**: Mean = 10, SD = 3 (16th-84th percentile range)
- **Standard Scores**: Mean = 100, SD = 15 (16th-84th percentile range)
- **T-Scores**: Mean = 50, SD = 10 (16th-84th percentile range)
- **z-Scores**: Mean = 0, SD = 1 (16th-84th percentile range)

It's critical that each test is associated with the correct score type in report tables to ensure accurate interpretation of the scores. This mapping system ensures that tests are consistently assigned to the correct score type across all domains.

## Implementation

The score type mapping is implemented in the `TableGT_Modified` class in `R/TableGT_Modified.R`. The class uses two complementary approaches to ensure correct score type assignments:

1. **Test-level mapping**: A comprehensive mapping of test names to their correct score types, which is used to preprocess the groupings before footnotes are added. This works well for tests that have a single score type.

2. **Scale-level mapping**: A special handling mechanism for test batteries that have multiple score types (e.g., both subtests and indices/composites). This examines the scale names within each test to determine the appropriate score type.

The system intelligently:
1. Identifies test batteries with multiple score types (WISC-V, WAIS-IV, RBANS, etc.)
2. Examines scale names to determine if they are subtests or indices/composites
3. Applies the appropriate footnotes based on scale-level categorization
4. Ensures consistent score type assignments across all domains

## Current Mappings

The current test-to-score-type mappings are:

### Scaled Score Tests (Mean=10, SD=3)

#### WISC-V / WAIS-IV / WPPSI-IV Subtests
- WISC-V, Similarities, Vocabulary, Comprehension
- Block Design, Visual Puzzles, Matrix Reasoning
- Figure Weights, Picture Concepts, Digit Span
- Letter-Number Sequencing, Coding, Symbol Search
- Cancellation

#### WMS Subtests
- WMS-IV, Logical Memory, Verbal Paired Associates
- Designs, Visual Reproduction, Spatial Addition
- Symbol Span, Logical Memory II, Verbal Paired Associates II
- Designs II, Visual Reproduction II

#### D-KEFS Subtests
- D-KEFS, Trail Making, Verbal Fluency, Design Fluency
- Color-Word Interference, Tower, Word Context
- Proverb, Twenty Questions

### Standard Score Tests (Mean=100, SD=15)

#### IQ and Index Scores
- Full Scale (FSIQ), Verbal Comprehension (VCI), Perceptual Reasoning (PRI)
- Working Memory (WMI), Processing Speed (PSI), General Ability (GAI)
- Cognitive Proficiency (CPI), Visual Spatial (VSI), Fluid Reasoning (FRI)
- Quantitative Reasoning (QRI)

#### Academic Achievement Tests
- WIAT-III, Oral Reading Fluency, Reading Comprehension
- Math Problem Solving, Numerical Operations, Word Reading
- Pseudoword Decoding, Oral Expression, Listening Comprehension
- Written Expression, Spelling, Essay Composition
- Alphabet Writing Fluency, Sentence Composition

## Test Batteries with Multiple Score Types

Several neuropsychological test batteries contain both subtests and composite/index scores that use different standardized score systems. The system automatically detects and handles these special cases:

### WISC-V / WAIS-IV / WAIS-5
- **Indices/Composites (Standard Scores)**: Full Scale IQ, Verbal Comprehension Index, Perceptual Reasoning Index, Working Memory Index, Processing Speed Index, etc.
- **Subtests (Scaled Scores)**: Similarities, Vocabulary, Comprehension, Block Design, Digit Span, Coding, etc.

### RBANS
- **Indices (Standard Scores)**: Total Index, Immediate Memory Index, Visuospatial Index, Language Index, Attention Index, Delayed Memory Index
- **Subtests (Scaled Scores)**: Digit Span, Coding, Picture Naming, Semantic Fluency, List Learning, Story Memory, Figure Copy, Line Orientation, List Recall, List Recognition, Story Recall, Figure Recall

### NAB / NAB-S
- **Indices/Composites (Standard Scores)**: Total NAB Index, Attention Index, Language Index, Memory Index, Spatial Index, Executive Functions Index
- **Subtests (Scaled Scores)**: Digits Forward, Digits Backward, Numbers & Letters, Shape Learning, Story Learning, etc.

### WMS-IV
- **Indices (Standard Scores)**: Auditory Memory Index, Visual Memory Index, Immediate Memory Index, Delayed Memory Index
- **Subtests (Scaled Scores)**: Logical Memory, Verbal Paired Associates, Designs, Visual Reproduction, Spatial Addition, Symbol Span

### T-Score Tests (Mean=50, SD=10)

#### Behavior Ratings
- BRIEF, BASC, Conners, CBCL, SCL-90-R
- Beck Depression Inventory, Beck Anxiety Inventory
- Global Severity Index, Positive Symptom Total
- Positive Symptom Distress Index, Somatization, Obsessive-Compulsive
- Interpersonal Sensitivity, Depression, Anxiety, Hostility
- Phobic Anxiety, Paranoid Ideation, Psychoticism

#### Executive Function Measures
- WCST, Perseverative Errors, Nonperseverative Errors
- Categories Completed, Trials to First Category
- Failure to Maintain Set, Learning to Learn
- Trail Making Test, TMT Part A, TMT Part B

## How to Add New Tests

When adding new neuropsychological tests to the system:

1. Identify the correct standardized score type for the test (scaled, standard, T-score, or z-score)
2. Open `R/TableGT_Modified.R` and locate the `test_score_type_map` list in the `build_table` method
3. Add the test name to the appropriate score type category in the mapping
4. Follow the existing naming patterns and group related tests together
5. Keep the mapping alphabetized within each category for readability

Example:

```r
test_score_type_map <- list(
  # Scaled score tests (mean=10, SD=3)
  "scaled_score" = c(
    # Existing tests...
    
    # Add your new scaled score tests here
    "NEW-TEST-NAME", "New Subtest 1", "New Subtest 2"
  ),
  
  # Standard score tests (mean=100, SD=15)
  "standard_score" = c(
    # Existing tests...
    
    # Add your new standard score tests here
    "NEW-STANDARD-TEST", "New Standard Subtest 1"
  ),
  
  # Other score types...
)
```

## Verifying Correct Mapping

After adding new tests:

1. Run a test rendering of the relevant domain QMD file:
   ```r
   library(quarto)
   quarto_render('_02-XX_domain.qmd', output_format = 'typst')
   ```

2. Check the output PDF file to verify that the tests have the correct footnote references
3. If there are issues, verify that the test names in your mapping exactly match the test names in the data

## Troubleshooting

If you encounter issues with score type assignments:

1. Check for exact name matches - the mapping is case-sensitive
2. Ensure the test is only listed in one score type category in the `test_score_type_map`
3. Verify that the test name matches exactly what appears in the data
4. For test batteries with multiple score types:
   - Check if the battery is listed in the `multi_score_batteries` array
   - Verify that the pattern detection is correctly identifying indices vs. subtests
   - Examine the scale names to ensure they match the expected patterns
5. Add detailed debug logging with `message()` calls
6. Check the console output for diagnostic messages:
   - "Original score type groups"
   - "Fixed score type groups"
   - "Found test batteries with multiple score types"
   - "Applying special handling for [battery] subtests vs indices/composites"

### Adding a New Test Battery with Multiple Score Types

If you need to add support for a new test battery that has both standard scores and scaled scores:

1. Add the test battery name to the `multi_score_batteries` array in the `build_table` method
2. Ensure the `standard_score_patterns` array contains patterns that can identify index/composite scores for this battery
3. Test the implementation with a domain that includes this test battery
4. Examine the console output to verify correct detection of standard vs. scaled score scales

## References

For detailed information about neuropsychological test scoring systems, refer to:

- Lezak, M. D., Howieson, D. B., Bigler, E. D., & Tranel, D. (2012). Neuropsychological assessment (5th ed.). Oxford University Press.
- Strauss, E., Sherman, E. M. S., & Spreen, O. (2006). A compendium of neuropsychological tests: Administration, norms, and commentary (3rd ed.). Oxford University Press.