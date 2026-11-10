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
    !anyDuplicated(data[c("period", "region", "sex", "indicator")])
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

# Contrato de publicación: todas las fuentes y series deben estar presentes.
manifest <- jsonlite::fromJSON("api/v1/manifest.json", simplifyVector = FALSE)
catalog <- jsonlite::fromJSON("api/v1/catalog.json", simplifyVector = FALSE)
sources <- names(yaml::read_yaml("config/fuentes.yml")$sources)
manifest_ids <- vapply(manifest$datasets, function(x) x$id, character(1))
catalog_ids <- vapply(catalog$datasets, function(x) x$id, character(1))
stopifnot(setequal(manifest_ids, sources), setequal(catalog_ids, sources))
for (id in sources) {
  entry <- purrr::detect(manifest$datasets, ~ identical(.x$id, id))
  description <- purrr::detect(catalog$datasets, ~ identical(.x$id, id))
  file <- file.path("api/v1", entry$path)
  stopifnot(file.exists(file), identical(entry$status, "ok"))
  series <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  stopifnot(
    identical(series$id, id),
    length(series$observations) == entry$observations,
    length(description$coverage) == length(ip_sheet_map(yaml::read_yaml(paste0("config/", id, ".yml")))),
    length(description$indicators) == length(yaml::read_yaml(paste0("config/", id, ".yml"))$indicators)
  )
}
message("Contrato JSON y cobertura de todas las fuentes validados.")
