---
title: "Cognitive Assessment Report"
author: "Dr. Neuropsychologist"
---

```{r setup, include=FALSE}
# Create the report generator for a specific patient
report_generator <- IQReportGeneratorR6$new(
  patient_name = "John Doe",
  input_file = "data/neurocog.csv"
)

# Generate all report components in one step
report_generator$generate_report()

# The document will be rendered using the generated components
```
