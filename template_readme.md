# neuro2: Neuropsychological Assessment Report Generator

An R-based template for generating comprehensive neuropsychological assessment reports using Quarto and Typst.

## 🚀 Quick Start

### For Each New Patient Assessment

1. **Create a new repository from this template:**
   ```bash
   # Using GitHub CLI
   gh repo create PATIENT-NAME-neuro --template brainworkup/neuro2 --private
   cd PATIENT-NAME-neuro
   
   # Or use GitHub web interface:
   # Go to: https://github.com/brainworkup/neuro2
   # Click "Use this template" → "Create a new repository"
   ```

2. **Set up the patient workspace:**
   ```r
   # In R console
   source("inst/patient_template/setup_patient.R")
   setup_patient_workspace("PATIENT_NAME", age = 12)
   ```

3. **Add your data files:**
   ```bash
   # Copy your CSV files to the data/ directory
   cp /path/to/your/neurocog.csv data/
   cp /path/to/your/neurobehav.csv data/
   ```

4. **Generate the assessment report:**
   ```r
   source("run_analysis.R")
   main_analysis()
   ```

## 📁 Patient Workspace Structure

After setup, your patient workspace will look like:

```
PATIENT-NAME-neuro/
├── data/                   # Your patient data (git-ignored)
│   ├── neurocog.csv       # Cognitive test data
│   ├── neurobehav.csv     # Behavioral/emotional data
│   └── README.md          # Data format instructions
├── figs/                  # Generated plots and tables (git-ignored)
├── output/                # Final reports (git-ignored)
├── R/                     # Core neuro2 functions (from template)
├── config.yml             # Patient-specific configuration
└── run_analysis.R         # Main analysis script
```

## 📊 Data Format

Your CSV files should include these essential columns:

- `test_name` - Test battery name (e.g., "WISC-V", "BASC-3")
- `scale` - Subtest/scale name (e.g., "Block Design", "Attention Problems")
- `score` - Numerical score (standard, scaled, or T-score)
- `percentile` - Percentile rank (0-100)
- `range` - Descriptive range (e.g., "Average", "Below Average")
- `domain` - Primary domain (e.g., "Memory", "ADHD")

## 🔄 Updating the Template

When the core neuro2 functionality is updated:

```bash
# In your patient repository
git remote add upstream https://github.com/brainworkup/neuro2
git fetch upstream main
git checkout upstream/main -- R/ inst/

# Resolve any conflicts in your patient-specific files
```

## 🛠️ Development Workflow

### For Template Developers

1. Make improvements to core functionality in the main `neuro2` repository
2. Test with sample data
3. Update version and commit changes
4. Patient repositories can pull updates as needed

### Core Components

- **R6 Classes**: Domain processors, table generators, plot creators
- **Templates**: Quarto/Typst templates for report generation  
- **Utilities**: Data validation, file I/O, configuration management
- **Workflows**: Automated processing pipelines

## 📋 Configuration Options

Edit `config.yml` to customize:

```yaml
patient:
  name: "Patient Name"
  age: 12
  assessment_date: "2024-01-15"

data:
  format: "parquet"  # or "csv"
  input_dir: "data"
  output_dir: "output"

processing:
  age_group: "child"  # or "adult", "auto"
  verbose: true
  parallel: false

output:
  output_format: "typst"  # or "pdf", "html"
  generate_plots: true
  generate_tables: true
```

## 🔒 Privacy & Security

- **Patient data is automatically git-ignored** - your data stays local
- **Each patient gets a separate private repository**
- **No patient information is committed to version control**
- **HIPAA-compliant when used with private repositories**

## 🆘 Troubleshooting

### Common Issues

1. **Missing packages**: Run `source("R/setup_neuro2.R")` to install dependencies
2. **Data format errors**: Check your CSV column names match the expected format
3. **Permission errors**: Ensure your data files are readable by R

### Getting Help

1. Check the generated `data/README.md` for data format requirements
2. Review the `config.yml` file for configuration options
3. Open an issue in the main neuro2 repository for bugs/feature requests

## 📄 License

This template is provided for neuropsychological assessment purposes. Ensure compliance with your institutional requirements and applicable privacy laws when handling patient data.

---

**Created by Dr. Joey Trampush, BrainWorkup Neuropsychology**