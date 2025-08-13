neuro2 main

❯ quarto render template.qmd --to neurotyp-forensic-typst 
NULL
Using libraries at paths:
- /Users/joey/.R
- /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
NULL
Using libraries at paths:
- /Users/joey/.R
- /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
here() starts at /Users/joey/neuro2
Generating domain files using R6 classes...

Generating files for General Cognitive Ability (iq)...
No data available for table generation for General Cognitive Ability
[DOMAINS] Generated _02-01_iq.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-01_iq.qmd
Generating files for Academic Skills (academics)...
No data available for table generation for Academic Skills
[DOMAINS] Generated _02-02_academics.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-02_academics.qmd
Generating files for Verbal/Language (verbal)...
No data available for table generation for Verbal/Language
[DOMAINS] Generated _02-03_verbal.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-03_verbal.qmd
Generating files for Visual Perception/Construction (spatial)...
No data available for table generation for Visual Perception/Construction
[DOMAINS] Generated _02-04_spatial.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-04_spatial.qmd
Generating files for Memory (memory)...
No data available for table generation for Memory
[DOMAINS] Generated _02-05_memory.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-05_memory.qmd
Generating files for Attention/Executive (executive)...
No data available for table generation for Attention/Executive
[DOMAINS] Generated _02-06_executive.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-06_executive.qmd
Generating files for Motor (motor)...
No data available for table generation for Motor
[DOMAINS] Generated _02-07_motor.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-07_motor.qmd
Generating files for Social Cognition (social)...
No data available for table generation for Social Cognition
[DOMAINS] Generated _02-08_social.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-08_social.qmd
Generating files for ADHD (adhd)...
[DOMAINS] Generated _02-09_adhd_adult.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-09_adhd_adult.qmd
Generating files for Behavioral/Emotional/Social (emotion)...
No data available for emotion child table generation
[DOMAINS] Generated _02-10_emotion_child.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-10_emotion_child.qmd
Generating files for Emotional/Behavioral/Personality (emotion)...
  ✗ Error: argument is missing, with no default

Generating adult/child variant files...
[DOMAINS] Generated _02-09_adhd_adult.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-09_adhd_adult.qmd
[DOMAINS] Generated _02-09_adhd_adult.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-09_adhd_child.qmd
  ✗ Error: argument is missing, with no default
No data available for emotion child table generation
[DOMAINS] Generated _02-10_emotion_child.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-10_emotion_child.qmd
No data available for table generation for Adaptive Functioning
[DOMAINS] Generated _02-11_adaptive.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-11_adaptive.qmd
No data available for table generation for Daily Living
[DOMAINS] Generated _02-12_daily_living.qmd (rendering deferred to workflow runner)
  ✓ Generated _02-12_daily_living.qmd

Domain file generation complete!
NULL
Using libraries at paths:
- /Users/joey/.R
- /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
here() starts at /Users/joey/neuro2

Attaching package: 'dplyr'

The following objects are masked from 'package:stats':

    filter, lag

The following objects are masked from 'package:base':

    intersect, setdiff, setequal, union

Generating all domain table and figure files...

Processing iq domain...
Registered S3 method overwritten by 'quantmod':
  method            from
  as.zoo.data.frame zoo 
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: RBANS, WISC-V
  scaled_score: RBANS, WISC-V
  percentile: RBANS
  raw_score: WISC-V
Found test batteries with multiple score types: RBANS, WISC-V
Applying special handling for RBANS subtests vs indices/composites
  Using battery-specific patterns for RBANS
  Special handling for RBANS scales
  RBANS standard score scales: RBANS Total Index
  RBANS scaled score scales: 
Applying special handling for WISC-V subtests vs indices/composites
  WISC-V standard score scales: Full Scale IQ (FSIQ)
  WISC-V scaled score scales: Verbal Comprehension (VCI), Visual Spatial (VSI), Fluid Reasoning (FRI), Working Memory (
WMI), Processing Speed (PSI), Nonverbal (NVI), General Ability (GAI), Cognitive Proficiency (CPI)                      Applying rbans_standard footnote to battery: RBANS
Applying wisc-v_standard footnote to battery: WISC-V
Applying wisc-v_scaled footnote to battery: WISC-V
Found 6 tests in the data that need score type fixing
Processing tests for scaled_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for standard_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
  Skipping RBANS - handled separately
Processing tests for raw_score score type
  Skipping WISC-V - handled separately
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: 
  scaled_score: 
  percentile: RBANS
  raw_score: WISC-V
  t_score: 
  z_score: 
  base_rate: 
  percent_mastery: 
  rbans_standard: RBANS
  wisc-v_standard: WISC-V
  wisc-v_scaled: WISC-V
Skipping battery-specific group: rbans_standard
Skipping battery-specific group: wisc-v_standard
Skipping battery-specific group: wisc-v_scaled
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc61259899.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc4e2ceeb8.html screenshot completed
  ✓ table_iq.png generated
Saving 7 x 7 in image
  ✓ fig_iq_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_iq_narrow.svg generated

Processing academics domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: WIAT-4
Found 1 tests in the data that need score type fixing
Processing tests for scaled_score score type
Processing tests for standard_score score type
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
Processing tests for raw_score score type
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: WIAT-4
  scaled_score: 
  t_score: 
  z_score: 
  percentile: 
  raw_score: 
  base_rate: 
  percent_mastery: 
Adding standard_score footnote to groups: WIAT-4
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc67ec9a20.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc5e7ae02d.html screenshot completed
  ✓ table_academics.png generated
Saving 7 x 7 in image
  ✓ fig_academics_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_academics_narrow.svg generated

Processing verbal domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: RBANS, WISC-V
  scaled_score: RBANS, WISC-V
  percentile: RBANS
  raw_score: WISC-V
Found test batteries with multiple score types: RBANS, WISC-V
Applying special handling for RBANS subtests vs indices/composites
  Using battery-specific patterns for RBANS
  Special handling for RBANS scales
  RBANS standard score scales: Language Index
  RBANS scaled score scales: Picture Naming, Semantic Fluency
Applying special handling for WISC-V subtests vs indices/composites
  WISC-V standard score scales: 
  WISC-V scaled score scales: Similarities, Vocabulary, Comprehension
Applying rbans_standard footnote to battery: RBANS
Applying rbans_scaled footnote to battery: RBANS
Applying wisc-v_scaled footnote to battery: WISC-V
Found 6 tests in the data that need score type fixing
Processing tests for scaled_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for standard_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
  Skipping RBANS - handled separately
Processing tests for raw_score score type
  Skipping WISC-V - handled separately
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: 
  scaled_score: 
  percentile: RBANS
  raw_score: WISC-V
  t_score: 
  z_score: 
  base_rate: 
  percent_mastery: 
  rbans_standard: RBANS
  rbans_scaled: RBANS
  wisc-v_scaled: WISC-V
Skipping battery-specific group: rbans_standard
Skipping battery-specific group: rbans_scaled
Skipping battery-specific group: wisc-v_scaled
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc5513dad0.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cca82b953.html screenshot completed
  ✓ table_verbal.png generated
Saving 7 x 7 in image
  ✓ fig_verbal_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_verbal_narrow.svg generated

Processing spatial domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: RBANS, WISC-V
  scaled_score: RBANS, WISC-V
  percentile: RBANS
  raw_score: WISC-V
Found test batteries with multiple score types: RBANS, WISC-V
Applying special handling for RBANS subtests vs indices/composites
  Using battery-specific patterns for RBANS
  Special handling for RBANS scales
  RBANS standard score scales: Visuospatial/Constructional Index
  RBANS scaled score scales: Figure Copy, Line Orientation
Applying special handling for WISC-V subtests vs indices/composites
  WISC-V standard score scales: 
  WISC-V scaled score scales: Block Design, Visual Puzzles, Matrix Reasoning, Figure Weights, Picture Concepts, Block D
esign No Time Bonus                                                                                                    Applying rbans_standard footnote to battery: RBANS
Applying rbans_scaled footnote to battery: RBANS
Applying wisc-v_scaled footnote to battery: WISC-V
Found 6 tests in the data that need score type fixing
Processing tests for scaled_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for standard_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
  Skipping RBANS - handled separately
Processing tests for raw_score score type
  Skipping WISC-V - handled separately
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: 
  scaled_score: 
  percentile: RBANS
  raw_score: WISC-V
  t_score: 
  z_score: 
  base_rate: 
  percent_mastery: 
  rbans_standard: RBANS
  rbans_scaled: RBANS
  wisc-v_scaled: WISC-V
Skipping battery-specific group: rbans_standard
Skipping battery-specific group: rbans_scaled
Skipping battery-specific group: wisc-v_scaled
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97ccc54fd89.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc1fd133b2.html screenshot completed
  ✓ table_spatial.png generated
Saving 7 x 7 in image
  ✓ fig_spatial_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_spatial_narrow.svg generated

Processing memory domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: RBANS
  scaled_score: RBANS
  percentile: RBANS
Found test batteries with multiple score types: RBANS
Applying special handling for RBANS subtests vs indices/composites
  Using battery-specific patterns for RBANS
  Special handling for RBANS scales
  RBANS standard score scales: 
  RBANS scaled score scales: Story Memory, List Recall, List Recognition, Story Recall
Applying rbans_scaled footnote to battery: RBANS
Found 3 tests in the data that need score type fixing
Processing tests for scaled_score score type
  Skipping RBANS - handled separately
Processing tests for standard_score score type
  Skipping RBANS - handled separately
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
  Skipping RBANS - handled separately
Processing tests for raw_score score type
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: 
  scaled_score: 
  percentile: RBANS
  t_score: 
  z_score: 
  raw_score: 
  base_rate: 
  percent_mastery: 
  rbans_scaled: RBANS
Skipping battery-specific group: rbans_scaled
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc5f98fb6f.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc34a36571.html screenshot completed
  ✓ table_memory.png generated
Saving 7 x 7 in image
  ✓ fig_memory_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_memory_narrow.svg generated

Processing executive domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  standard_score: RBANS, WISC-V
  scaled_score: RBANS, WISC-V
  percentile: RBANS
  t_score: Trail Making Test
  raw_score: WISC-V
Found test batteries with multiple score types: RBANS, WISC-V
Applying special handling for RBANS subtests vs indices/composites
  Using battery-specific patterns for RBANS
  Special handling for RBANS scales
  RBANS standard score scales: RBANS Digit Span, RBANS Coding, Attention Index
  RBANS scaled score scales: 
Applying special handling for WISC-V subtests vs indices/composites
  WISC-V standard score scales: 
  WISC-V scaled score scales: Digit Span, Picture Span, Coding, Symbol Search, Cancellation, Digit Span Forward, Digit 
Span Backward, Digit Span Sequencing, Cancellation Random, Cancellation Structured                                     Applying rbans_standard footnote to battery: RBANS
Applying wisc-v_scaled footnote to battery: WISC-V
Found 7 tests in the data that need score type fixing
Processing tests for scaled_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for standard_score score type
  Skipping RBANS - handled separately
  Skipping WISC-V - handled separately
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
  Skipping RBANS - handled separately
Processing tests for raw_score score type
  Skipping WISC-V - handled separately
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  standard_score: 
  scaled_score: 
  percentile: RBANS
  t_score: Trail Making Test
  raw_score: WISC-V
  z_score: 
  base_rate: 
  percent_mastery: 
  rbans_standard: RBANS
  wisc-v_scaled: WISC-V
Adding t_score footnote to groups: Trail Making Test
Skipping battery-specific group: rbans_standard
Skipping battery-specific group: wisc-v_scaled
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc5358f8b6.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc76309f79.html screenshot completed
  ✓ table_executive.png generated
Saving 7 x 7 in image
  ✓ fig_executive_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_executive_narrow.svg generated

Processing motor domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  t_score: Grooved Pegboard
Found 1 tests in the data that need score type fixing
Processing tests for scaled_score score type
Processing tests for standard_score score type
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
Processing tests for raw_score score type
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  t_score: Grooved Pegboard
  scaled_score: 
  standard_score: 
  z_score: 
  percentile: 
  raw_score: 
  base_rate: 
  percent_mastery: 
Adding t_score footnote to groups: Grooved Pegboard
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc7235fd8d.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc36996e8f.html screenshot completed
  ✓ table_motor.png generated
Saving 7 x 7 in image
  ✓ fig_motor_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_motor_narrow.svg generated

Processing adhd domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc13298a4a.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97ccc360a1a.html screenshot completed
  ✓ table_adhd.png generated
Saving 7 x 7 in image
  ✓ fig_adhd_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_adhd_narrow.svg generated

Processing adhd domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc2fd13739.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc508097b5.html screenshot completed
  ✓ table_adhd.png generated
Saving 7 x 7 in image
  ✓ fig_adhd_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_adhd_narrow.svg generated

Processing emotion domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  t_score: PAI Adolescent
Found 1 tests in the data that need score type fixing
Processing tests for scaled_score score type
Processing tests for standard_score score type
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
Processing tests for raw_score score type
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  t_score: PAI Adolescent
  scaled_score: 
  standard_score: 
  z_score: 
  percentile: 
  raw_score: 
  base_rate: 
  percent_mastery: 
Adding t_score footnote to groups: PAI Adolescent
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc2a68155d.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc1752a26b.html screenshot completed
  ✓ table_emotion.png generated
Saving 7 x 7 in image
  ✓ fig_emotion_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_emotion_narrow.svg generated

Processing emotion domain (self)...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc32252ac3.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc261a81ed.html screenshot completed
  ✓ table_emotion_child_self.png generated
Saving 7 x 7 in image
  ✓ fig_emotion_subdomain_self.svg generated

Processing emotion domain (parent)...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
  t_score: BASC-3 PRS Adolescent
Found 1 tests in the data that need score type fixing
Processing tests for scaled_score score type
Processing tests for standard_score score type
Processing tests for t_score score type
Processing tests for z_score score type
Processing tests for percentile score type
Processing tests for raw_score score type
Processing tests for base_rate score type
Processing tests for percent_mastery score type
Fixed score type groups:
  t_score: BASC-3 PRS Adolescent
  scaled_score: 
  standard_score: 
  z_score: 
  percentile: 
  raw_score: 
  base_rate: 
  percent_mastery: 
Adding t_score footnote to groups: BASC-3 PRS Adolescent
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc16480226.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc51851837.html screenshot completed
  ✓ table_emotion_child_parent.png generated
Saving 7 x 7 in image
  ✓ fig_emotion_subdomain_parent.svg generated

Processing social domain...
Using lookup_neuropsych_scales from sysdata.rda for score type mapping
Found score types: standard_score, scaled_score, t_score, percent_mastery, raw_score, z_score, percentile, base_rate
Added 147 tests/scales to standard_score mapping
Added 153 tests/scales to scaled_score mapping
Added 296 tests/scales to t_score mapping
Added 8 tests/scales to percent_mastery mapping
Added 59 tests/scales to raw_score mapping
Added 24 tests/scales to z_score mapping
Added 26 tests/scales to percentile mapping
Added 11 tests/scales to base_rate mapping
Original score type groups:
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc78f8ecb0.html screenshot completed
file:////var/folders/jg/994m6px53vn1p22x98l98jfm0000gn/T//RtmpVCUEJT/file97cc1e7b54dc.html screenshot completed
  ✓ table_social.png generated
Saving 7 x 7 in image
  ✓ fig_social_subdomain.svg generated
Saving 7 x 7 in image
  ✓ fig_social_narrow.svg generated

Checking SIRF figure...
  ⚠ fig_sirf_overall.svg missing, but this may be generated elsewhere

Done! All domain assets generation complete.

Generated files:

Table PNG files:
  - table_academics.png
  - table_adhd.png
  - table_emotion_child_parent.png
  - table_emotion_child_self.png
  - table_emotion.png
  - table_executive.png
  - table_iq.png
  - table_memory.png
  - table_motor.png
  - table_social.png
  - table_spatial.png
  - table_validity.png
  - table_verbal.png

Table PDF files:
  - table_academics.pdf
  - table_adhd.pdf
  - table_emotion_child_parent.pdf
  - table_emotion_child_self.pdf
  - table_emotion.pdf
  - table_executive.pdf
  - table_iq.pdf
  - table_memory.pdf
  - table_motor.pdf
  - table_social.pdf
  - table_spatial.pdf
  - table_validity.pdf
  - table_verbal.pdf

Figure SVG files:
  - fig_academics_narrow.svg
  - fig_academics_subdomain.svg
  - fig_adhd_narrow.svg
  - fig_adhd_subdomain.svg
  - fig_emotion_narrow.svg
  - fig_emotion_subdomain_parent.svg
  - fig_emotion_subdomain_self.svg
  - fig_emotion_subdomain.svg
  - fig_executive_narrow.svg
  - fig_executive_subdomain.svg
  - fig_iq_narrow.svg
  - fig_iq_subdomain.svg
  - fig_memory_narrow.svg
  - fig_memory_subdomain.svg
  - fig_motor_narrow.svg
  - fig_motor_subdomain.svg
  - fig_social_narrow.svg
  - fig_social_subdomain.svg
  - fig_spatial_narrow.svg
  - fig_spatial_subdomain.svg
  - fig_validity_subdomain.svg
  - fig_verbal_narrow.svg
  - fig_verbal_subdomain.svg
NULL
Using libraries at paths:
- /Users/joey/.R
- /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
here() starts at /Users/joey/neuro2
Processing _02-01_iq.qmd ...
Warning in readLines(file) :
  incomplete final line found on '_02-01_iq.qmd'
  Using plot title for iq from sysdata.rda
  Created: _02-01_iq_output.qmd 
Processing _02-02_academics.qmd ...
  Using plot title for academics from sysdata.rda
  Created: _02-02_academics_output.qmd 
Processing _02-03_verbal.qmd ...
  Using plot title for verbal from sysdata.rda
  Created: _02-03_verbal_output.qmd 
Processing _02-04_spatial.qmd ...
  Using plot title for spatial from sysdata.rda
  Created: _02-04_spatial_output.qmd 
Processing _02-05_memory.qmd ...
  Using plot title for memory from sysdata.rda
  Created: _02-05_memory_output.qmd 
Processing _02-06_executive.qmd ...
  Using plot title for executive from sysdata.rda
  Created: _02-06_executive_output.qmd 
Processing _02-07_motor.qmd ...
  Using plot title for motor from sysdata.rda
  Created: _02-07_motor_output.qmd 
Processing _02-08_social.qmd ...
  Using plot title for social from sysdata.rda
  Created: _02-08_social_output.qmd 
Processing _02-09_adhd_adult.qmd ...
  Using plot title for adhd_adult from sysdata.rda
  Created: _02-09_adhd_adult_output.qmd 
Processing _02-10_emotion_child.qmd ...
  Using plot title for emotion_child from sysdata.rda
  Created: _02-10_emotion_child_output.qmd 
Processing _02-11_adaptive.qmd ...
  Using plot title for adaptive from sysdata.rda
  Created: _02-11_adaptive_output.qmd 
Processing _02-12_daily_living.qmd ...
  Using plot title for daily_living from sysdata.rda
  Created: _02-12_daily_living_output.qmd 
Domain output processing complete.

NULL
Using libraries at paths:
- /Users/joey/.R
- /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library


processing file: template.qmd
1/11                   
2/11 [setup]           
3/11                   
4/11 [include-domains] 
5/11                   
6/11 [setup-sirf]      
7/11                   
8/11 [fig-sirf-overall]
9/11                   
10/11 [signature]       
11/11                   
output file: template.knit.md

ERROR: Include directive failed.
  in file /Users/joey/neuro2/template.qmd, 
  in file _02-10_emotion_child_output.qmd, 
  could not find file /Users/joey/neuro2/_02-10_emotion_child_text_self.qmd.

Stack trace:
    at retrieveInclude (file:///Applications/quarto/bin/quarto.js:69284:13)
    at retrieveInclude (file:///Applications/quarto/bin/quarto.js:69303:15)
    at standaloneInclude (file:///Applications/quarto/bin/quarto.js:69317:9)
    at processMarkdownIncludes (file:///Applications/quarto/bin/quarto.js:69555:30)
    at eventLoopTick (ext:core/01_core.js:178:7)
    at async handleLanguageCells (file:///Applications/quarto/bin/quarto.js:69671:3)
    at async file:///Applications/quarto/bin/quarto.js:123815:41
    at async withTimingAsync (file:///Applications/quarto/bin/quarto.js:18979:21)
    at async renderFileInternal (file:///Applications/quarto/bin/quarto.js:123814:9)
    at async renderFiles (file:///Applications/quarto/bin/quarto.js:123578:9)
