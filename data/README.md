# Data Directory for Isabella

## Required Files

Place your assessment data files in this directory:

- `neurocog.parquet` - Neurocognitive test data
- `neurobehav.parquet` - Neurobehavioral/emotional data  
- `validity.parquet` - Performance/symptom validity data (optional)

## Data Format

Your Parquet/CSV files should have these columns:
- `test_name` - Name of the test battery
- `scale` - Specific subtest or scale name
- `score` - Standard score, scaled score, or T-score
- `percentile` - Percentile rank
- `range` - Descriptive range (e.g., "Average", "Below Average")
- `domain` - Cognitive/behavioral domain
- `subdomain` - More specific domain categorization

## Security Note

⚠️ **Patient data files are automatically excluded from git tracking**
Your patient data will remain local and private.

