--- R/DomainProcessorR6.R
+++ R/DomainProcessorR6.R
@@ 1068,1075c1068,1080
-      # Write to file
-      cat(qmd_content, file = output_file)
+      # Write QMD to file
+      cat(qmd_content, file = output_file)
+      # Immediately render this domain file for side-effects (tables, plots, text)
+      message(paste0("[DOMAINS] Rendering ", output_file, " to typst..."))
+      system(paste("quarto render", output_file, "--to typst"), intern = TRUE)
@@ 2000,2005c2005,2008
-      # Write to file
-      cat(qmd_content, file = output_file)
+      # Write QMD to file
+      cat(qmd_content, file = output_file)
+      # Immediately render this domain file
+      message(paste0("[DOMAINS] Rendering ", output_file, " to typst..."))
+      system(paste("quarto render", output_file, "--to typst"), intern = TRUE)
@@ 2350,2355c2355,2358
-      cat(qmd_content, file = output_file)
+      # Write QMD to file
+      cat(qmd_content, file = output_file)
+      # Immediately render this domain file
+      message(paste0("[DOMAINS] Rendering ", output_file, " to typst..."))
+      system(paste("quarto render", output_file, "--to typst"), intern = TRUE)
```  
```diff
--- unified_workflow_runner.R
+++ unified_workflow_runner.R
@@ 1230,1240d1229
-      # Final check: render any generated domain files to create required figures
-      final_domain_files <- list.files(".", pattern = "_02-.*\\.qmd$")
-      if (length(final_domain_files) > 0) {
-        log_message("Final step: Rendering all domain files to generate figures...", "DOMAINS")
-        for (domain_file in final_domain_files) {
-          tryCatch({
-            log_message(paste0("Rendering ", domain_file, " to typst..."), "DOMAINS")
-            render_cmd <- paste("quarto render", domain_file, "--to typst")
-            result <- system(render_cmd, intern = TRUE, ignore.stdout = FALSE, ignore.stderr = FALSE)
-            log_message(paste0("Successfully rendered ", domain_file), "DOMAINS")
-          }, error = function(e) {
-            log_message(paste0("Warning: Could not render ", domain_file, " - ", e$message), "WARNING")
-          })
-        }
-      }
```  
*Remove the redundant batch render in your runner; the per-file renders in `DomainProcessorR6` will ensure all QMDs are processed before the final `template.qmd` run.*
