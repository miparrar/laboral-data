#!/usr/bin/env Rscript
# Inspección estructural de un tabulado antes de registrarlo como fuente.
# No genera datos ni modifica la API publicada.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !file.exists(args[[1]])) {
  stop("Uso: Rscript scripts/inspect_tabulado.R /ruta/al/archivo.xlsx", call. = FALSE)
}
path <- args[[1]]
sheets <- readxl::excel_sheets(path)
cat("Archivo:", basename(path), "\nHojas:", length(sheets), "\n")
purrr::walk(seq_along(sheets), function(i) {
  sheet <- sheets[[i]]
  if (i == 1L) {
    cat(sprintf("%-24s ÍNDICE (omitir)\n", sheet))
    return(invisible(NULL))
  }
  x <- readxl::read_excel(path, sheet = sheet, skip = 5L, col_names = FALSE,
                          col_types = "text", n_max = 4L, .name_repair = "minimal")
  row <- function(n) if (nrow(x) >= n) unlist(x[n, ], use.names = FALSE) else character()
  headers <- row(1L)
  units <- row(2L)
  col <- seq.int(3L, length(headers) - 1L, by = 2L)
  vals <- headers[col]
  quality <- units[col]
  measures <- units[col + 1L]
  cat(sprintf("%-24s %2d pares, %d encabezados, notas=%s, unidades=%s\n",
              sheet, length(col), sum(!is.na(vals) & nzchar(vals)),
              paste(unique(stats::na.omit(quality)), collapse = "/"),
              paste(unique(stats::na.omit(measures)), collapse = "/")))
  cat(" Indicadores:", paste(vals, collapse = " | "), "\n")
})
