# Verifica el calendario oficial versionado y el contrato JSON publicado.
calendarios <- list.files(
  "config/calendario_ene", pattern = "^[0-9]{4}\\.yaml$", full.names = TRUE
)
stopifnot(length(calendarios) > 0L)
for (archivo in calendarios) {
  fuente <- yaml::read_yaml(archivo)
  anio <- as.integer(sub("\\.yaml$", "", basename(archivo)))
  salida <- file.path("api/v1/calendario", paste0(anio, ".json"))
  stopifnot(
    file.exists(salida),
    identical(fuente$anio, anio),
    identical(fuente$zona_horaria, "America/Santiago"),
    identical(fuente$producto, "EMPLEO NACIONAL"),
    startsWith(fuente$fuente, "https://www.ine.gob.cl/"),
    length(fuente$publicaciones) == 12L
  )
  publicada <- jsonlite::fromJSON(salida, simplifyVector = FALSE)
  stopifnot(
    identical(publicada$schema_version, 1L),
    identical(publicada$anio, fuente$anio),
    identical(publicada$fuente, fuente$fuente),
    identical(publicada$actualizacion_fuente, fuente$actualizacion_fuente),
    identical(publicada$zona_horaria, fuente$zona_horaria),
    identical(publicada$producto, fuente$producto),
    length(publicada$publicaciones) == length(fuente$publicaciones)
  )
  claves <- c("fecha", "hora", "trimestre", "anio_trimestre", "periodo")
  for (i in seq_along(fuente$publicaciones)) {
    stopifnot(identical(publicada$publicaciones[[i]][claves],
                        fuente$publicaciones[[i]][claves]))
  }
}
index <- jsonlite::fromJSON("api/v1/calendario/index.json",
                             simplifyVector = FALSE)
stopifnot(identical(unlist(index$anios),
                    as.integer(sub("\\.yaml$", "", basename(calendarios)))))
message("Calendario ENE oficial y JSON validados.")
