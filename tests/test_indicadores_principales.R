source("R/indicadores_principales.R")
stopifnot(
  identical(ip_period(c("2010", "2010", "2011", "2026"), c("Ene - Mar", "Nov - Ene", "Dic - Feb", "Jul - Sep")),
            c("2010-02", "2010-12", "2011-01", "2026-08")),
  length(ip_sheet_map(ip_config())) == 19L,
  length(ip_config()$indicators) == 13L,
  !anyDuplicated(vapply(ip_config()$indicators, function(x) x$id, character(1)))
)
# El test de integración usa el archivo descargado en la ejecución actual.
path <- "data_raw/indicadores_principales.xlsx"
if (file.exists(path)) {
  data <- ip_process(path)
  stopifnot(
    nrow(data) == 19L * 13L * dplyr::n_distinct(data$period),
    all(data$quality %in% c("sin_advertencia", "poco_fiable", "no_fiable")),
    all(data$region != "nacional" | data$sex %in% c("total", "hombre", "mujer")),
    all(data$region == "nacional" | data$sex == "total"),
    max(data$period) >= "2026-08",
    min(data$period) == "2010-02",
    !anyDuplicated(data[c("period", "region", "sex", "indicator")]),
    setequal(unique(data$source_sheet), names(ip_sheet_map(ip_config()))),
    all(data$source_sheet[data$region == "nacional" &
                            data$sex == "mujer"] == "M")
  )
}
message("Pruebas completadas.")

# Complementarios reutiliza el mismo parser para 15 indicadores y 19 coberturas.
comp_cfg <- yaml::read_yaml("config/complementarios.yml")
stopifnot(
  length(ip_sheet_map(comp_cfg)) == 19L,
  length(comp_cfg$indicators) == 15L,
  isTRUE(comp_cfg$allow_missing_values),
  !anyDuplicated(vapply(comp_cfg$indicators, function(x) x$id, character(1)))
)
comp_path <- "data_raw/complementarios.xlsx"
if (file.exists(comp_path)) {
  comp <- ip_process(comp_path, comp_cfg)
  stopifnot(
    nrow(comp) == 19L * 15L * dplyr::n_distinct(comp$period),
    dplyr::n_distinct(comp$indicator) == 15L,
    dplyr::n_distinct(paste(comp$region, comp$sex)) == 19L,
    all(comp$quality %in% c("sin_advertencia", "poco_fiable", "no_fiable", "sin_dato")),
    all(is.na(comp$value) == (comp$quality == "sin_dato")),
    min(comp$period) == "2010-02",
    !anyDuplicated(comp[c("period", "region", "sex", "indicator")])
  )
}


# Horas: sólo tres hojas nacionales (AS, H y M); 13 indicadores, 3 en horas.
horas_cfg <- yaml::read_yaml("config/horas.yml")
stopifnot(
  identical(names(ip_sheet_map(horas_cfg)), c("AS", "H", "M")),
  length(horas_cfg$indicators) == 13L,
  sum(vapply(horas_cfg$indicators, function(x) identical(x$unit, "hours"), logical(1))) == 3L,
  isTRUE(horas_cfg$allow_missing_values)
)
horas_path <- "data_raw/horas.xlsx"
if (file.exists(horas_path)) {
  horas <- ip_process(horas_path, horas_cfg)
  stopifnot(
    nrow(horas) == 3L * 13L * dplyr::n_distinct(horas$period),
    dplyr::n_distinct(paste(horas$region, horas$sex)) == 3L,
    all(horas$region == "nacional"),
    setequal(unique(horas$sex), c("total", "hombre", "mujer")),
    all(is.na(horas$value) == (horas$quality == "sin_dato")),
    !anyDuplicated(horas[c("period", "region", "sex", "indicator")])
  )
}

# Principales por edad: seis tramos nacionales, ambos sexos, 13 indicadores.
edad_cfg <- yaml::read_yaml("config/indicadores_principales_edad.yml")
tramos <- c("15-24", "25-34", "35-44", "45-54", "55-64", "65+")
stopifnot(
  identical(names(ip_sheet_map(edad_cfg)),
            c("15-24", "25-34", "35-44", "45-54", "55-64", "65-Más")),
  identical(vapply(edad_cfg$sheet_dimensions, function(x) x$age_group, character(1)),
            stats::setNames(tramos, names(edad_cfg$sheet_dimensions))),
  length(edad_cfg$indicators) == 13L,
  isTRUE(edad_cfg$allow_missing_values),
  !anyDuplicated(vapply(edad_cfg$indicators, function(x) x$id, character(1)))
)
edad_path <- "data_raw/indicadores_principales_edad.xlsx"
if (file.exists(edad_path)) {
  edad <- ip_process(edad_path, edad_cfg)
  periodos <- dplyr::n_distinct(edad$period)
  stopifnot(
    nrow(edad) == 6L * 13L * periodos,
    dplyr::n_distinct(edad$indicator) == 13L,
    setequal(unique(edad$age_group), tramos),
    all(edad$region == "nacional"),
    all(edad$sex == "total"),
    all(edad$quality %in% c("sin_advertencia", "poco_fiable", "no_fiable", "sin_dato")),
    all(is.na(edad$value) == (edad$quality == "sin_dato")),
    min(edad$period) == "2010-02",
    !anyDuplicated(edad[c("period", "region", "sex", "age_group", "indicator")])
  )
}

# Rama de actividad: 23 categorías (total + 22), 19 coberturas geográficas/sexo.
rama_cfg <- yaml::read_yaml("config/rama.yml")
stopifnot(
  length(rama_cfg$indicators) == 23L,
  length(rama_cfg$public_indicators) == 1L,
  identical(rama_cfg$public_indicators[[1L]]$id, "ocupados"),
  identical(rama_cfg$dimension_from_indicator, "branch"),
  identical(rama_cfg$indicators[[1L]]$id, "total"),
  identical(rama_cfg$indicators[[23L]]$id, "no_sabe_no_responde"),
  length(ip_sheet_map(rama_cfg)) == 19L,
  isTRUE(rama_cfg$allow_missing_values),
  !anyDuplicated(vapply(rama_cfg$indicators, function(x) x$id, character(1)))
)
rama_path <- "data_raw/rama.xlsx"
if (file.exists(rama_path)) {
  rama <- ip_process(rama_path, rama_cfg)
  stopifnot(
    min(rama$period) == "2013-02",
    nrow(rama) == 19L * 23L * dplyr::n_distinct(rama$period),
    setequal(unique(rama$indicator), "ocupados"),
    dplyr::n_distinct(rama$branch) == 23L,
    dplyr::n_distinct(rama$region) == 17L,
    setequal(unique(rama$sex), c("total", "hombre", "mujer")),
    all(rama$region == "nacional" | rama$sex == "total"),
    all(rama$quality %in% c("sin_advertencia", "poco_fiable", "no_fiable", "sin_dato")),
    all(is.na(rama$value) == (rama$quality == "sin_dato")),
    !anyDuplicated(rama[c("period", "region", "sex", "branch", "indicator")])
  )
  # El total y las categorías permanecen separados: nunca sumar el total
  # a las ramas, ni interpretar NS/NR como una actividad productiva.
}

# Contrato de publicación: un catálogo con inventario por serie.
catalog <- jsonlite::fromJSON("api/v1/catalog.json", simplifyVector = FALSE)
sources <- names(yaml::read_yaml("config/fuentes.yml")$sources)
catalog_ids <- vapply(catalog$datasets, function(x) x$id, character(1))
stopifnot(identical(catalog$schema_version, 2L), setequal(catalog_ids, sources))
for (id in sources) {
  entry <- purrr::detect(catalog$datasets, ~ identical(.x$id, id))
  config <- yaml::read_yaml(paste0("config/", id, ".yml"))
  file <- file.path("api/v1", entry$path)
  stopifnot(file.exists(file), identical(entry$status, "ok"))
  observations <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  specs <- vapply(config$indicators, function(x) x$id, character(1))
  series_index <- dplyr::bind_rows(entry$series)
  original <- if ("branch" %in% names(series_index)) {
    series_index$branch
  } else series_index$indicator
  indice <- match(original, specs)
  stopifnot(
    identical(observations$id, id),
    identical(entry$parser_version, 6L),
    identical(observations$source_file,
              yaml::read_yaml("config/fuentes.yml")$sources[[id]]$file),
    identical(observations$source_file, entry$source_file),
    identical(observations$source_url, entry$source_url),
    identical(observations$source_sha256, entry$source_sha256),
    setequal(unlist(entry$source_sheets), names(ip_sheet_map(config))),
    all(series_index$source_sheet %in% names(ip_sheet_map(config))),
    !anyNA(indice),
    identical(series_index$note_column, ip_col_excel(3L + 2L * (indice - 1L))),
    identical(series_index$value_column, ip_col_excel(4L + 2L * (indice - 1L))),
    nrow(series_index) == dplyr::n_distinct(series_index$series_key),
    all(series_index$first_period <= series_index$last_period),
    all(is.na(series_index$first_valid_period) |
          series_index$first_valid_period >= series_index$first_period),
    all(is.na(series_index$last_valid_period) |
          series_index$last_valid_period <= series_index$last_period),
    sum(series_index$observations) == entry$observations,
    sum(series_index$valid_observations) <= entry$observations,
    length(observations$observations) == entry$observations,
    min(series_index$first_period) == entry$first_period,
    max(series_index$last_period) == entry$last_period,
    setequal(vapply(entry$indicators, function(x) x$id, character(1)),
             unique(vapply(observations$observations,
                           function(x) x$indicator, character(1)))),
    all(vapply(entry$indicators, function(x)
      !is.null(x$analysis$measurement_type) &&
      length(x$analysis$allowed) >= 1L, logical(1))),
    nzchar(entry$build_sha256)
  )
}
message("Catálogo por serie, trazabilidad Excel y ausencia de manifiesto validados.")

# Tras la depuración, el total de ramas sólo se consulta en principales.
source("R/redundancias.R")
stopifnot(nrow(laboral_auditar_publicadas()) == 0L)
message("Catálogo analítico y ausencia de redundancias validados.")
