#!/bin/bash
# Clean run script - no triple execution

echo "================================"
echo "NEURO2 WORKFLOW - CLEAN VERSION"
echo "================================"

# Clear any locks
rm -f .BATCH_DONE .COMPONENTS_LOADED 2>/dev/null

# Run the clean workflow
Rscript clean_workflow.R

echo "================================"
echo "COMPLETE - No triple execution!"
echo "================================"

