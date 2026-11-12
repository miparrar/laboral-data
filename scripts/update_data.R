#!/usr/bin/env Rscript
source("R/indicadores_principales.R")
source("R/redundancias.R")

sources <- yaml::read_yaml("config/fuentes.yml")$sources
# La publicación se reconstruye también cuando cambian políticas o código,
# aunque los archivos originales del INE mantengan su SHA-256.
build_files <- c(
  "R/indicadores_principales.R", "R/redundancias.R", "scripts/update_data.R",
  "config/analisis.yml", paste0("config/", names(sources), ".yml")
)
build_sha256 <- digest::digest(paste(vapply(build_files, function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}, character(1)), collapse = "\n"), algo = "sha256")

args <- commandArgs(trailingOnly = TRUE)
# --input= se mantiene como alias histórico para indicadores_principales.
input_args <- args[grepl("^--(input|[a-z_]+-input)=", args)]
inputs <- stats::setNames(vector("list", length(sources)), names(sources))
for (argument in input_args) {
  key <- sub("^--([^=]+)=.*$", "\\1", argument)
  id <- if (identical(key, "input")) "indicadores_principales" else
    sub("-input$", "", key)
  if (!id %in% names(sources)) stop("Fuente desconocida: ", id)
  if (length(inputs[[id]])) stop("Solo una ruta por fuente: ", id)
  inputs[[id]] <- sub("^[^=]+=", "", argument)
}
dir.create("data_raw", recursive = TRUE, showWarnings = FALSE)

datasets <- purrr::imap(sources, function(source, id) {
  path <- if (length(inputs[[id]])) inputs[[id]][[1L]] else file.path("data_raw", source$file)
  if (!length(inputs[[id]])) {
    message("Descargando Excel desde INE: ", source$url)
    utils::download.file(source$url, path, mode = "wb", quiet = TRUE)
  }
  if (!file.exists(path)) stop("No se encontró el Excel: ", path, call. = FALSE)
  cfg <- yaml::read_yaml(paste0("config/", id, ".yml"))
  list(path = path, config = cfg, source_url = source$url,
       hash = digest::digest(object = path, algo = "sha256", file = TRUE),
       title = source$name, source_file = source$file,
       build_sha256 = build_sha256)
})

catalog_path <- "api/v1/catalog.json"
if (file.exists(catalog_path)) {
  previous <- jsonlite::fromJSON(catalog_path, simplifyVector = FALSE)$datasets
  unchanged <- purrr::every(names(datasets), function(id) {
    old <- purrr::detect(previous, ~ identical(.x$id, id))
    !is.null(old) &&
      identical(old$source_sha256, datasets[[id]]$hash) &&
      identical(old$parser_version, 6L) &&
      identical(old$build_sha256, build_sha256) &&
      file.exists(file.path("api/v1/series", paste0(id, ".json")))
  })
  if (unchanged) {
    message("Sin cambios en las fuentes (SHA-256 coincide); no se reescriben los JSON.")
    quit(save = "no", status = 0L)
  }
}

datasets <- purrr::imap(datasets, function(entry, id) {
  entry$data <- ip_process(entry$path, entry$config)
  message(id, ": ", nrow(entry$data), " estimaciones, ",
          dplyr::n_distinct(entry$data$period), " períodos, ",
          dplyr::n_distinct(paste(entry$data$region, entry$data$sex)), " coberturas")
  published <- if (is.null(entry$config$public_indicators)) {
    entry$config$indicators
  } else entry$config$public_indicators
  if (dplyr::n_distinct(entry$data$indicator) != length(published)) {
    stop("Cobertura de indicadores incorrecta en: ", id)
  }
  if (identical(entry$config$dimension_from_indicator, "branch") &&
      dplyr::n_distinct(entry$data$branch) != length(entry$config$indicators)) {
    stop("Cobertura de ramas incorrecta en: ", id)
  }
  entry
})

# Comparar todo el universo original antes de elegir un único registro
# por concepto, período, cobertura, dimensiones y unidad.
redundancias <- laboral_resumen_redundancias(datasets)
if (nrow(redundancias)) {
  message("Solapamientos detectados en los tabulados del INE:")
  print(redundancias, n = Inf)
  if (any(redundancias$discrepancias > 0L)) {
    warning("Hay valores diferentes para claves compartidas. ",
            "Se conserva la fuente prioritaria y se informa la discrepancia.",
            call. = FALSE)
  }
}
datasets <- laboral_depurar_redundancias(datasets)
if (nrow(laboral_redundancias(datasets))) {
  stop("La publicación conserva observaciones redundantes.", call. = FALSE)
}
message("Observaciones únicas por conjunto: ",
        paste(vapply(datasets, function(x) nrow(x$data), integer(1)),
              collapse = ", "))

ip_publish(datasets)
message("API JSON generada en api/v1/ para: ", paste(names(datasets), collapse = ", "))
