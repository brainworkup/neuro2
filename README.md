# Neuro Report R6

yourpkg/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   └── ReportGenerator.R
└── inst/
    └── quarto/
        ├── extensions/
        │   └── typst/
        │       └── _extension.yml
        └── templates/
            └── typst-report/
                ├── template.qmd             # your main QMD “shell”
                ├── _quarto.yml              # the template’s quarto project config
                ├── _variables.yml           # default parameters for template
                └── _include_domains.qmd     # your include-snippet for sections
