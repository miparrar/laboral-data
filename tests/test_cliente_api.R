# Pruebas del cliente R sin conexiones de red.
source("R/cliente_api.R")

fuente <- "https://www.ine.gob.cl/indicadores_principales.xlsx"
catalogo <- list(datasets = list(
  list(
    id = "indicadores_principales",
    title = "Indicadores principales ENE",
    indicators = list(
      list(id = "tasa_desocupacion", label = "Tasa de desocupación",
           unit = "percent"),
      list(id = "ocupados", label = "Personas ocupadas",
           unit = "thousand_persons")
    ),
    series = list(
      list(series_key = "indicadores_principales/tasa_desocupacion/nacional/total",
           indicator = "tasa_desocupacion", region = "nacional", sex = "total",
           source_sheet = "AS", note_column = "I", value_column = "J",
           first_period = "2026-07", last_period = "2026-08",
           observations = 2L, unit = "percent"),
      list(series_key = "indicadores_principales/ocupados/metropolitana/total",
           indicator = "ocupados", region = "metropolitana", sex = "total",
           source_sheet = "RM", note_column = "G", value_column = "H",
           first_period = "2026-08", last_period = "2026-08",
           observations = 1L, unit = "thousand_persons")
    ),
    source_file = "indicadores_principales.xlsx",
    source_url = fuente,
    source_sheets = c("AS", "H", "M")
  ),
  list(
    id = "rama",
    title = "Ocupación por rama",
    indicators = list(
      list(id = "ocupados", label = "Personas ocupadas", unit = "thousand_persons")
    ),
    series = list(list(
      series_key = "rama/ocupados/nacional/total/construccion",
      indicator = "ocupados", region = "nacional", sex = "total",
      branch = "construccion", source_sheet = "AS",
      note_column = "I", value_column = "J",
      first_period = "2026-08", last_period = "2026-08",
      observations = 1L, unit = "thousand_persons"
    )),
    dimension_labels = list(
      branch = list(list(id = "construccion", label = "Construcción"))
    ),
    source_file = "rama.xlsx",
    source_url = "https://www.ine.gob.cl/rama.xlsx",
    source_sheets = c("AS", "H", "M")
  )
))
assign("raw:catalog.json", catalogo, envir = .laboral_cache)

ejemplo <- tibble::tibble(
  period = c("2026-07", "2026-08", "2026-08", "2026-08"),
  region = c("nacional", "nacional", "nacional", "metropolitana"),
  sex = c("total", "total", "mujer", "total"),
  source_sheet = c("AS", "AS", "M", "RM"),
  indicator = c("tasa_desocupacion", "tasa_desocupacion",
                "tasa_desocupacion", "ocupados"),
  value = c(8.7, 8.5, 9.0, 4000)
)
assign("table:series/indicadores_principales.json", list(
  id = "indicadores_principales",
  source_file = "indicadores_principales.xlsx",
  source_url = fuente,
  source_sha256 = "sha256-prueba",
  observations = ejemplo
), envir = .laboral_cache)
assign("table:series/rama.json", list(
  id = "rama",
  source_file = "rama.xlsx",
  source_url = "https://www.ine.gob.cl/rama.xlsx",
  source_sha256 = "sha256-rama",
  observations = tibble::tibble(
    period = "2026-08", region = "nacional", sex = "total",
    indicator = "ocupados", branch = "construccion",
    source_sheet = "AS", value = 700
  )
), envir = .laboral_cache)

stopifnot(
  nrow(laboral_catalogo()) == 2L,
  nrow(laboral_metadata()) == 3L,
  nrow(laboral_series()) == 3L,
  identical(
    laboral_series() |>
      dplyr::filter(.data$indicator == "tasa_desocupacion") |>
      dplyr::pull(.data$value_column),
    "J"
  ),
  identical(laboral_describir("indicadores_principales/tasa_desocupacion")$archivo,
            "indicadores_principales.xlsx"),
  identical(laboral_describir("indicadores_principales/tasa_desocupacion")$hojas,
            "AS, H, M"),
  nrow(laboral_buscar("desocupación")) == 1L,
  nrow(laboral_buscar("construccion")) == 1L
)

seleccion <- laboral_obtener(
  "indicadores_principales/tasa_desocupacion",
  desde = "2026-08", region = "nacional", sexo = "total"
)
stopifnot(
  inherits(seleccion, "tbl_df"),
  nrow(seleccion) == 1L,
  seleccion$period == "2026-08",
  seleccion$source_file == "indicadores_principales.xlsx",
  seleccion$source_sheet == "AS",
  seleccion$source_url == fuente,
  seleccion$source_sha256 == "sha256-prueba",
  seleccion$series_id == "indicadores_principales/tasa_desocupacion"
)

varias <- laboral_obtener(c("indicadores_principales/tasa_desocupacion",
                             "rama/ocupados"), desde = "2026-07")
stopifnot(nrow(varias) == 4L, setequal(varias$source_file,
                                       c("indicadores_principales.xlsx", "rama.xlsx")))

ocupacion <- laboral_leer(
  "rama", rama = "construccion", region = "nacional"
)
stopifnot(nrow(ocupacion) == 1L, ocupacion$source_sheet == "AS")
stopifnot(nrow(laboral_leer(region = c("nacional", "metropolitana"))) == 4L)

da_error <- function(expresion) inherits(
  tryCatch(force(expresion), error = identity), "error"
)
stopifnot(
  da_error(laboral_leer("inexistente")),
  da_error(laboral_leer(edad = "15-24")),
  da_error(laboral_leer(actualizar = NA)),
  da_error(laboral_leer(indicador = 1)),
  da_error(laboral_obtener("serie/inexistente")),
  da_error(laboral_obtener("rama/ocupados", desde = "2026-09", hasta = "2026-07")),
  da_error(laboral_obtener("rama/ocupados", desde = "2026-99"))
)
# Una coincidencia en el título del TABULADO no hace relevante
# a cada uno de sus indicadores para la consulta del agente.
catalogo$datasets[[3L]] <- list(
  id = "complementarios",
  title = "Indicadores complementarios a la tasa de desocupación ENE",
  indicators = list(list(id = "su3",
                         label = "Tasa combinada de desocupación y fuerza potencial",
                         unit = "percent")),
  coverage = list(list(region = "nacional", sex = "total")),
  source_file = "complementarios.xlsx",
  source_url = "https://www.ine.gob.cl/complementarios.xlsx",
  source_sheets = c("AS", "H", "M")
)
assign("raw:catalog.json", catalogo, envir = .laboral_cache)
stopifnot(
  identical(laboral_buscar("tasa de desocupación")$indicador,
            "tasa_desocupacion"),
  !any(laboral_buscar("tasa de desocupación")$tabulado == "complementarios")
)

message("Pruebas del cliente API y trazabilidad completadas.")
