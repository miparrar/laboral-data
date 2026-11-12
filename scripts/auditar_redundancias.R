#!/usr/bin/env Rscript
source("R/redundancias.R")
resumen <- laboral_auditar_publicadas()
if (nrow(resumen)) {
  print(resumen, n = Inf)
  stop("Persisten observaciones redundantes en la API JSON.", call. = FALSE)
}
message("Sin observaciones redundantes entre series publicadas.")
