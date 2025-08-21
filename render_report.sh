#!/bin/bash

# Render neuropsychological report with Typst format
# Usage: ./render_report.sh [format]
# Where format can be: adult, forensic, pediatric (default: adult)

FORMAT=${1:-adult}

case $FORMAT in
  forensic)
    # For forensic format, use the base typst format
    # The specific settings are in _quarto.yml
    echo "Rendering with forensic format settings..."
    quarto render template.qmd --to neurotyp-forensic-typst
    ;;
  pediatric)
    echo "Rendering with pediatric format settings..."
    quarto render template.qmd --to neurotyp-pediatric-typst
    ;;
  adult|*)
    echo "Rendering with adult format settings..."
    quarto render template.qmd --to neurotyp-adult-typst
    ;;
esac

echo "Rendering complete!"
