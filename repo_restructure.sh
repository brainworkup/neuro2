# Run this in your neuro2 repository root
#!/bin/bash

# Create new directory structure
mkdir -p inst/templates
mkdir -p inst/scripts  
mkdir -p inst/patient_template/{data,figs,output,config}
mkdir -p man
mkdir -p tests/testthat

# Move existing R files to proper locations
# (Assuming you have R files in root or various locations)
if [ ! -d "R" ]; then
    mkdir R
fi

# Move your R6 classes and utilities to R/ directory
# You'll need to adjust these paths based on your current structure
find . -name "*.R" -not -path "./R/*" -not -path "./inst/*" -exec mv {} R/ \;

# Create patient template structure
cat > inst/patient_template/.gitignore << 'EOF'
# Patient-specific data (never commit)
data/*.csv
data/*.xlsx
data/*.parquet
data/*.feather
figs/
output/
tmp/

# Generated QMD files (patient-specific)
_02-*.qmd
*_text.qmd

# Reports
*.pdf
*.docx
*.html
*.typ

# Keep directory structure
!data/.gitkeep
!figs/.gitkeep
!output/.gitkeep
!config/
EOF

# Create .gitkeep files to maintain directory structure
touch inst/patient_template/{data,figs,output}/.gitkeep

echo "Repository restructured for template use!"
echo "Next: Run the R setup script to create template files"