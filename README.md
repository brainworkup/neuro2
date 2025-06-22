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

yourpkg/
└── inst/
    └── quarto/
        └── templates/
            └── typst-report/
                ├── template.qmd          # your master skeleton
                ├── _quarto.yml           # project‐level settings
                ├── _variables.yml        # default params
                ├── _include_domains.qmd  # previously added snippet
                └── sections/             # new folder for all your section files
                    ├── _00-00_tests.qmd
                    ├── _01-00_nse_adult.qmd
                    ├── _01-00_nse_forensic.qmd
                    ├── _01-00_nse_pediatric.qmd
                    ├── _01-00_nse_referral.qmd
                    ├── _02-00_behav_obs.qmd
                    ├── _03-00_dsm5_icd10_dx.qmd
                    ├── _03-00_sirf.qmd
                    ├── _03-00_sirf_text.qmd
                    └── _03-01_recommendations.qmd
