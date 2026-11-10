#!/usr/bin/env Rscript
source("R/indicadores_principales.R")

sources <- yaml::read_yaml("config/fuentes.yml")$sources
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
       title = source$name)
})

manifest_path <- "api/v1/manifest.json"
if (file.exists(manifest_path)) {
  previous <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)$datasets
  unchanged <- purrr::every(names(datasets), function(id) {
    old <- purrr::detect(previous, ~ identical(.x$id, id))
    !is.null(old) &&
      identical(old$source_sha256, datasets[[id]]$hash) &&
      identical(old$parser_version, 3L) &&
      file.exists(file.path("api/v1/series", paste0(id, ".json")))
  })
  if (unchanged && file.exists("api/v1/catalog.json")) {
    message("Sin cambios en las fuentes (SHA-256 coincide); no se reescriben los JSON.")
    quit(save = "no", status = 0L)
  }
}

datasets <- purrr::imap(datasets, function(entry, id) {
  entry$data <- ip_process(entry$path, entry$config)
  message(id, ": ", nrow(entry$data), " estimaciones, ",
          dplyr::n_distinct(entry$data$period), " períodos, ",
          dplyr::n_distinct(paste(entry$data$region, entry$data$sex)), " coberturas")
  if (dplyr::n_distinct(entry$data$indicator) != length(entry$config$indicators)) {
    stop("Cobertura de indicadores incorrecta en: ", id)
  }
  entry
})

ip_publish(datasets)
message("API JSON generada en api/v1/ para: ", paste(names(datasets), collapse = ", "))
