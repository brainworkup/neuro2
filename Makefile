.PHONY: help deps test check docs report clean

help:
	@echo "Common targets:"
	@echo "  make deps   - install package dependencies"
	@echo "  make test   - run testthat tests"
	@echo "  make check  - R CMD check (no manual)"
	@echo "  make docs   - build website docs with altdoc"
	@echo "  make report - run unified report workflow (template)"
	@echo "  make clean  - remove build artifacts"

deps:
	Rscript -e "if (!requireNamespace('pak', quietly=TRUE)) install.packages('pak'); pak::pak('.')"

test:
	Rscript -e "if (!requireNamespace('testthat', quietly=TRUE)) install.packages('testthat'); testthat::test_local()"

check:
	R CMD build .
	R CMD check --no-manual --as-cran neuro2_*.tar.gz

docs:
	Rscript inst/scripts/build_docs.R

report:
	Rscript unified_workflow_runner.R config.yml || true

clean:
	rm -rf neuro2_*.tar.gz neuro2.Rcheck docs/ .quarto/ _freeze/ *_cache/ */*_cache/

