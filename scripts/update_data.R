#!/usr/bin/env Rscript
source("R/indicadores_principales.R")

config <- yaml::read_yaml("config/fuentes.yml")$sources$indicadores_principales
args <- commandArgs(trailingOnly = TRUE)
input <- sub("^--input=", "", args[grepl("^--input=", args)])
if (length(input) > 1L) stop("Especifique como máximo un --input.", call. = FALSE)
dir.create("data_raw", recursive = TRUE, showWarnings = FALSE)

path <- if (length(input)) input[[1L]] else file.path("data_raw", config$file)
if (!length(input)) {
  message("Descargando Excel desde INE: ", config$url)
  utils::download.file(config$url, path, mode = "wb", quiet = TRUE)
}
if (!file.exists(path)) stop("No se encontró el Excel: ", path, call. = FALSE)
hash <- digest::digest(object = path, algo = "sha256", file = TRUE)
manifest_path <- "api/v1/manifest.json"

if (file.exists(manifest_path)) {
  previous <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  old <- previous$datasets[[1L]]$source_sha256
  if (identical(old, hash) &&
      file.exists("api/v1/catalog.json") &&
      file.exists("api/v1/series/indicadores_principales.json")) {
    message("Sin cambios en el Excel (SHA-256 coincide); no se reescriben los JSON.")
    quit(save = "no", status = 0L)
  }
}

data <- ip_process(path)
message("Observaciones validadas: ", nrow(data),
        " | períodos: ", dplyr::n_distinct(data$period),
        " | hojas de datos: 19")
ip_publish(data, path, config$url, hash)
message("API JSON generada en api/v1/")
