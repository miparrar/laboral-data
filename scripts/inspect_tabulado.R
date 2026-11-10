#!/usr/bin/env Rscript
# Inspección genérica con readxl (sin alterar los datos publicados).
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || !file.exists(args[[1L]])) {
  stop("Uso: Rscript scripts/inspect_tabulado.R archivo.xlsx [reporte.json]")
}
path <- args[[1L]]
sheets <- readxl::excel_sheets(path)
result <- purrr::map(sheets, function(sheet) {
  x <- readxl::read_excel(path, sheet = sheet, col_names = FALSE,
                          n_max = 12L, col_types = "text",
                          .name_repair = "minimal")
  row <- function(i) if (i <= nrow(x)) unname(unlist(x[i, ], use.names = FALSE)) else character()
  list(
    sheet = sheet, columns = ncol(x),
    rows = purrr::map(seq_len(min(12L, nrow(x))), function(i) {
      values <- row(i)
      which(!is.na(values) & nzchar(trimws(values))) |>
        purrr::map(function(j) list(column = j, text = values[[j]]))
    })
  )
})
for (entry in result) {
  cat(entry$sheet, ": ", entry$columns, " columnas\n", sep = "")
  for (i in seq_along(entry$rows)) {
    cat("  fila ", i, ": ",
        paste(vapply(entry$rows[[i]], function(y) paste0(y$column, "=", y$text),
                     character(1)), collapse = " | "), "\n", sep = "")
  }
}
if (length(args) >= 2L) {
  jsonlite::write_json(
    list(source = basename(path), sheets = result), args[[2L]],
    pretty = TRUE, auto_unbox = TRUE
  )
}
