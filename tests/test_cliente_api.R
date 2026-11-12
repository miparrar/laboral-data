# Pruebas del cliente R sin conexiones de red.
source("R/cliente_api.R")

ejemplo <- tibble::tibble(
  period = c("2026-07", "2026-08", "2026-08", "2026-08"),
  region = c("nacional", "nacional", "nacional", "metropolitana"),
  sex = c("total", "total", "mujer", "total"),
  indicator = c("tasa_desocupacion", "tasa_desocupacion",
                "tasa_desocupacion", "ocupados"),
  value = c(8.7, 8.5, 9.0, 4000)
)
assign("indicadores_principales", ejemplo, envir = .laboral_cache)

seleccion <- laboral_leer(
  "indicadores_principales",
  indicador = "tasa_desocupacion",
  region = "nacional",
  sexo = "total"
)
stopifnot(
  inherits(seleccion, "tbl_df"),
  nrow(seleccion) == 2L,
  identical(seleccion$period, c("2026-07", "2026-08")),
  nrow(laboral_leer(region = c("nacional", "metropolitana"))) == 4L
)

da_error <- function(expresion) inherits(
  tryCatch(force(expresion), error = identity), "error"
)
stopifnot(
  da_error(laboral_leer("inexistente")),
  da_error(laboral_leer(edad = "15-24")),
  da_error(laboral_leer(actualizar = NA)),
  da_error(laboral_leer(indicador = 1))
)
message("Pruebas del cliente API completadas.")
