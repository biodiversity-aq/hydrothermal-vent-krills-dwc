.PHONY: data restore status
.DEFAULT_GOAL := data

data:
	Rscript src/transform-data.R

restore:
	Rscript -e 'renv::restore(prompt = FALSE)'

status:
	Rscript -e 'renv::status()'
