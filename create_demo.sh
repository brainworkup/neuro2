#!/bin/bash

# Demo script to test file upload functionality
# This creates a sample scenario to demonstrate the file upload workflow

echo "🧠 neuro2 File Upload Demo"
echo "=========================="
echo

# Create demo directories
echo "📁 Setting up demo environment..."
mkdir -p demo_patient/{data-raw/csv,data,output}

# Create sample CSV file
cat > demo_patient/data-raw/csv/sample_test_data.csv << 'EOF'
test,test_name,scale,raw_score,score,percentile,range,domain,subdomain
wisc5,WISC-V,Similarities,25,12,75,High Average,General Cognitive Ability,Verbal Comprehension
wisc5,WISC-V,Block Design,45,11,63,Average,General Cognitive Ability,Visual Spatial
wisc5,WISC-V,Matrix Reasoning,23,13,84,High Average,General Cognitive Ability,Fluid Reasoning
wisc5,WISC-V,Digit Span,16,10,50,Average,General Cognitive Ability,Working Memory
wisc5,WISC-V,Coding,65,9,37,Average,General Cognitive Ability,Processing Speed
EOF

echo "✅ Created sample test data"

# Create demo config
cat > demo_patient/config.yml << 'EOF'
patient:
  name: "Demo Patient"
  age: 12
  doe: "2024-01-15"

data:
  input_dir: "data-raw/csv"
  output_dir: "data"
  format: "csv"

processing:
  use_duckdb: true
  
report:
  template: "template.qmd"
  format: "html"
EOF

echo "✅ Created demo configuration"

# Show directory structure
echo
echo "📁 Demo directory structure:"
find demo_patient -type f | sort

echo
echo "📄 Sample CSV content:"
head -3 demo_patient/data-raw/csv/sample_test_data.csv

echo
echo "🎯 Demo setup complete!"
echo
echo "To test file upload functionality:"
echo "1. cd demo_patient"
echo "2. Run: Rscript ../quick_upload.R 'Demo Patient' csv"
echo "3. Or use R: upload_files(method='csv', patient_name='Demo Patient')"
echo
echo "📚 See FILE_UPLOAD_GUIDE.md for complete instructions"