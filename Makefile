RSCRIPT ?= Rscript

.PHONY: deps update test

deps:
	$(RSCRIPT) -e 'install.packages(c("readxl","dplyr","tidyr","purrr","stringr","tibble","jsonlite","yaml","digest"), repos="https://cloud.r-project.org")'

update:
	$(RSCRIPT) scripts/update_data.R

test:
	$(RSCRIPT) tests/test_indicadores_principales.R
