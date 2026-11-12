#!/usr/bin/env Rscript
# Fuente única: archivos YAML versionados en laboral-data.
# Cron diario sólo dispara la verificación; la fecha y hora oficial mandan.
calendar_base <- "config/calendario_ene"
now <- as.POSIXct(Sys.time(), tz = "America/Santiago")
year <- as.integer(format(now, "%Y", tz = "America/Santiago"))
today <- as.Date(format(now, "%Y-%m-%d", tz = "America/Santiago"))
clock <- format(now, "%H:%M", tz = "America/Santiago")

read_year <- function(year) {
  path <- file.path(calendar_base, sprintf("%d.yaml", year))
  if (!file.exists(path)) return(NULL)
  result <- yaml::read_yaml(path)
  if (!identical(result$anio, as.integer(year)) ||
      !identical(result$zona_horaria, "America/Santiago") ||
      !identical(result$producto, "EMPLEO NACIONAL") ||
      length(result$publicaciones) != 12L) {
    stop("Calendario ENE inválido: ", path, call. = FALSE)
  }
  result
}

current <- read_year(year)
if (is.null(current)) {
  stop("Falta el calendario ENE del año vigente: ",
       file.path(calendar_base, paste0(year, ".yaml")), call. = FALSE)
}
previous <- read_year(year - 1L)
calendars <- Filter(Negate(is.null), list(previous, current))

rows <- do.call(rbind, lapply(calendars, function(calendar) {
  do.call(rbind, lapply(calendar$publicaciones, function(p) {
    data.frame(fecha = as.Date(p$fecha), hora = p$hora, periodo = p$periodo)
  }))
}))
eligible <- rows[rows$fecha < today | (rows$fecha == today & rows$hora <= clock), , drop = FALSE]
if (!nrow(eligible)) stop("No existe una publicación ENE anterior a la fecha actual.")

expected <- max(eligible$periodo)
sources <- names(yaml::read_yaml("config/fuentes.yml")$sources)
catalog_path <- "api/v1/catalog.json"
entries <- if (file.exists(catalog_path)) {
  jsonlite::fromJSON(catalog_path, simplifyVector = FALSE)$datasets
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
