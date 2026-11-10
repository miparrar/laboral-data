#!/usr/bin/env Rscript
# Fuente única del calendario: repositorio laborales.
# Un cron diario es solo un disparador; el calendario decide si corresponde actualizar.
calendar_base <- "https://raw.githubusercontent.com/miparrar/laborales/main/src_data/calendario_ene"
now <- as.POSIXct(Sys.time(), tz = "America/Santiago")
year <- as.integer(format(now, "%Y", tz = "America/Santiago"))
today <- as.Date(format(now, "%Y-%m-%d", tz = "America/Santiago"))
clock <- format(now, "%H:%M", tz = "America/Santiago")

read_year <- function(year) {
  url <- sprintf("%s/%d.yaml", calendar_base, year)
  tmp <- tempfile(fileext = ".yaml")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch({
    suppressWarnings(utils::download.file(url, tmp, mode = "wb", quiet = TRUE))
    TRUE
  }, error = function(e) FALSE)
  if (!ok) return(NULL)
  yaml::read_yaml(tmp)
}

calendars <- Filter(Negate(is.null), lapply(unique(c(year - 1L, year)), read_year))
if (!length(calendars)) stop("No se pudo obtener ningún calendario ENE desde laborales.")

rows <- do.call(rbind, lapply(calendars, function(calendar) {
  do.call(rbind, lapply(calendar$publicaciones, function(p) {
    data.frame(fecha = as.Date(p$fecha), hora = p$hora, periodo = p$periodo)
  }))
}))
eligible <- rows[rows$fecha < today | (rows$fecha == today & rows$hora <= clock), , drop = FALSE]
if (!nrow(eligible)) stop("No existe una publicación ENE anterior a la fecha actual.")

expected <- max(eligible$periodo)
sources <- names(yaml::read_yaml("config/fuentes.yml")$sources)
manifest_path <- "api/v1/manifest.json"
entries <- if (file.exists(manifest_path)) {
  jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)$datasets
} else {
  list()
}
due_by_source <- vapply(sources, function(id) {
  entry <- purrr::detect(entries, ~ identical(.x$id, id))
  is.null(entry) ||
    is.null(entry$last_period) ||
    entry$last_period < expected ||
    !file.exists(file.path("api/v1/series", paste0(id, ".json")))
}, logical(1))
due <- any(due_by_source)
out <- Sys.getenv("GITHUB_OUTPUT")
if (nzchar(out)) cat(sprintf("due=%s\n", tolower(as.character(due))), file = out, append = TRUE)
message(sprintf(
  "Calendario ENE: período esperado=%s; pendientes=%s; actualizar=%s",
  expected,
  if (due) paste(names(due_by_source)[due_by_source], collapse = ", ") else "ninguno",
  due
))
