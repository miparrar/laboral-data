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
    length(description$coverage) == 19L,
    length(description$indicators) == if (id == "complementarios") 15L else 13L
  )
}
message("Contrato JSON y cobertura de ambas fuentes validados.")
