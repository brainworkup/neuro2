## data-raw/import-pdf-tables.R

library(readr)
library(usethis)

ext <- system.file("extdata", package = "neuro2")

caars2_self <- read_csv(file.path(ext, "caars2_self.csv"))
cvlt3_brief <- read_csv(file.path(ext, "cvlt3_brief.csv"))
nabs <- read_csv(file.path(ext, "nabs.csv"))
wais5 <- read_csv(file.path(ext, "wais5.csv"))
wiat4 <- read_csv(file.path(ext, "wiat4.csv"))

# save as internal data
use_data(caars2_self, overwrite = TRUE)
use_data(cvlt3_brief, overwrite = TRUE)
use_data(nabs, overwrite = TRUE)
use_data(wais5, overwrite = TRUE)
use_data(wais5_subtest, overwrite = TRUE)
use_data(wiat4, overwrite = TRUE)
