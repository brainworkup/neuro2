#!/bin/bash  
# cleanup_redundant_files.sh  
  
# Move core files to archive or remove  
mkdir -p archive  
mv core_*.R archive/  
mv run_*.R archive/  
mv generate_*.R archive/  
mv domain_generator_module.R archive/  
mv report_generator_module.R archive/  
  
echo "Redundant files moved to archive/"  
echo "Main workflow: ./unified_neuropsych_workflow.sh"
