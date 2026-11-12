#!/usr/bin/env Rscript
# El YAML anual es la fuente única; se publica una versión JSON para consumidores.
base <- "config/calendario_ene"
destino <- "api/v1/calendario"
archivos <- list.files(base, pattern = "^[0-9]{4}\\.yaml$", full.names = TRUE)
if (!length(archivos)) stop("No hay calendarios ENE para publicar.", call. = FALSE)

dir.create(destino, recursive = TRUE, showWarnings = FALSE)
anios <- integer()

for (archivo in archivos) {
  calendario <- yaml::read_yaml(archivo)
  anio <- as.integer(sub("\\.yaml$", "", basename(archivo)))
  if (!identical(calendario$anio, anio) ||
      !identical(calendario$zona_horaria, "America/Santiago") ||
      !identical(calendario$producto, "EMPLEO NACIONAL") ||
      length(calendario$publicaciones) != 12L ||
      !startsWith(calendario$fuente, "https://www.ine.gob.cl/")) {
    stop("Calendario ENE inválido en: ", archivo, call. = FALSE)
  }
  anios <- c(anios, anio)
  jsonlite::write_json(
    c(list(schema_version = 1L), calendario),
    file.path(destino, paste0(anio, ".json")),
    pretty = TRUE, auto_unbox = TRUE, na = "null"
  )
}

jsonlite::write_json(
  list(schema_version = 1L, anios = as.list(sort(anios))),
  file.path(destino, "index.json"),
  pretty = TRUE, auto_unbox = TRUE
)
message("Calendarios ENE publicados: ", paste(sort(anios), collapse = ", "))
