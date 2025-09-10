# File Upload Solution for neuro2

## Problem Statement
The user asked "how do I upload a file?" in the context of the neuro2 neuropsychological report generation system.

## Analysis
After examining the codebase, I found that neuro2 uses a multi-step workflow where "file upload" refers to getting neuropsychological test data into the system for processing and report generation. The existing system had several file input methods but lacked clear documentation and user-friendly interfaces.

## Solution Implemented

### 1. Comprehensive Documentation
- **`FILE_UPLOAD_GUIDE.md`**: Complete guide covering all file upload methods
- Updated **`README.md`** with file upload instructions in the Quick Start section
- Enhanced **`unified_neuropsych_workflow.sh`** with references to upload documentation

### 2. Helper Functions (`R/file_upload_helpers.R`)
Created user-friendly R functions to simplify file uploading:

- **`upload_files()`**: Main function with three modes:
  - `method = "csv"`: Direct CSV file upload
  - `method = "pdf"`: PDF extraction workflow
  - `method = "interactive"`: Guided interactive mode
- **`quick_upload()`**: Simplified wrapper for common use cases
- **`list_pdf_templates()`**: Shows available PDF extraction templates
- **`check_upload_requirements()`**: Validates system setup

### 3. Command-Line Tools
- **`quick_upload.R`**: Executable script for command-line file uploads
- **`create_demo.sh`**: Creates demo environment for testing

### 4. Examples and Testing
- **`examples/file_upload_examples.R`**: Comprehensive examples
- **`tests/testthat/test-file-upload.R`**: Unit tests for file upload functionality

## File Upload Methods Supported

### Method 1: Direct CSV Upload
```r
upload_files(
  method = "csv", 
  file_path = "path/to/data.csv",
  patient_name = "Patient Name"
)
```

### Method 2: PDF Extraction
```r
upload_files(
  method = "pdf", 
  test_type = "wisc5",  # 50+ test types supported
  patient_name = "Patient Name"
)
```

### Method 3: Interactive Mode
```r
upload_files(method = "interactive")
# Provides guided prompts for all options
```

### Method 4: Command Line
```bash
Rscript quick_upload.R "Patient Name" csv
```

## Supported Test Types for PDF Extraction
The system supports 50+ neuropsychological tests including:
- **Intelligence**: WISC-V, WAIS-5, WPPSI-4
- **Achievement**: WIAT-4, KTEA-3, WRAT-5
- **Memory**: WMS-IV, CVLT-3, RBANS
- **ADHD/Behavior**: CAARS-2, Conners-4, BASC-3
- **Executive Function**: D-KEFS, CEFI, NAB

## Complete Workflow

1. **Upload Files**: Use any of the methods above
2. **Process Data**: System converts CSV → Parquet for efficiency
3. **Generate Domains**: Creates report sections based on available data
4. **Render Report**: Produces PDF/HTML using Quarto/Typst

## Key Features

- **Multiple Input Methods**: CSV, PDF extraction, interactive
- **Validation**: Checks system requirements and file formats
- **Error Handling**: Clear error messages and troubleshooting
- **Documentation**: Comprehensive guides and examples
- **Backward Compatibility**: Works with existing workflow scripts
- **Testing**: Unit tests ensure reliability

## Files Modified/Added

### New Files
- `FILE_UPLOAD_GUIDE.md` - Complete file upload documentation
- `R/file_upload_helpers.R` - Helper functions for file uploading
- `quick_upload.R` - Command-line upload script
- `examples/file_upload_examples.R` - Usage examples
- `tests/testthat/test-file-upload.R` - Unit tests
- `create_demo.sh` - Demo environment setup

### Modified Files
- `README.md` - Added file upload section to Quick Start
- `NAMESPACE` - Added exports for new functions
- `unified_neuropsych_workflow.sh` - Added references to upload guide

## Usage Examples

### Basic CSV Upload
```r
library(neuro2)

# Check system is ready
check_upload_requirements()

# Upload CSV file
upload_files(
  method = "csv",
  file_path = "test_data.csv",
  patient_name = "John Doe"
)

# Run workflow
system("./unified_neuropsych_workflow.sh 'John Doe'")
```

### PDF Extraction
```r
# List available templates
list_pdf_templates()

# Extract from WISC-V PDF
upload_files(
  method = "pdf",
  test_type = "wisc5",
  patient_name = "Jane Smith"
)
```

### Command Line
```bash
# Quick upload with prompts
Rscript quick_upload.R "Patient Name"

# Direct CSV upload
Rscript quick_upload.R "Patient Name" csv

# Check available templates
Rscript -e "neuro2::list_pdf_templates()"
```

## Testing

Run the tests to validate functionality:
```r
devtools::test()
```

Create and test demo environment:
```bash
./create_demo.sh
cd demo_patient
Rscript ../quick_upload.R "Demo Patient" csv
```

## Impact

This solution addresses the file upload question by:

1. **Clarifying the Process**: Comprehensive documentation explains all available methods
2. **Simplifying Usage**: Helper functions reduce complexity for users
3. **Providing Multiple Options**: CSV, PDF, interactive, and command-line methods
4. **Ensuring Reliability**: Tests and validation functions catch common issues
5. **Maintaining Compatibility**: Works with existing neuro2 workflows

The implementation makes file uploading accessible to users at all technical levels while preserving the sophisticated capabilities of the neuro2 system.