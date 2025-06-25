#!/bin/bash
# This script renders domain files to typst format based on _include_domains.rmd

# Create output directory if it doesn't exist
mkdir -p output/domains

# Extract file paths from _include_domains.rmd
domain_files=$(grep -o "{{< include .*\.qmd >}}" _include_domains.qmd | sed 's/{{< include \(.*\) >}}/\1/')

# Process each domain file
for qmd_file in $domain_files; do
  echo "Processing domain: $qmd_file"

  # Get the file path (assuming files are in sections/ directory)
  domain_file="$qmd_file"

  # Get the filename without path and extension
  filename=$(basename "$qmd_file" .qmd)

  # Render the domain using quarto
  quarto render "$domain_file" --to neurotyp-adult-typst

  # Move the resulting files to output/domains
  if [ -f "sections/$filename.typ" ]; then
    mv "sections/$filename.typ" "output/domains/"
    echo "  Moved $filename.typ to output/domains/"
  fi

  if [ -f "sections/$filename.pdf" ]; then
    mv "sections/$filename.pdf" "output/domains/"
    echo "  Moved $filename.pdf to output/domains/"
  fi
done

echo "Domain processing complete."
