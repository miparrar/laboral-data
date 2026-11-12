# Cliente liviano de la API pública de laboral-data.
# Requiere: jsonlite, dplyr y tibble.
# Los archivos JSON completos se guardan en memoria durante la sesión.

.laboral_api <- "https://miparrar.github.io/laboral-data/api/v1/"
.laboral_cache <- new.env(parent = emptyenv())

laboral_catalogo <- function() {
  datasets <- jsonlite::fromJSON(
    paste0(.laboral_api, "catalog.json"), simplifyVector = FALSE
  )$datasets

  tibble::tibble(
    serie = vapply(datasets, function(x) x$id, character(1)),
    descripcion = vapply(datasets, function(x) x$title, character(1))
  )
}

laboral_leer <- function(serie = "indicadores_principales",
                         indicador = NULL, region = NULL, sexo = NULL,
                         edad = NULL, rama = NULL, actualizar = FALSE) {
  disponibles <- c(
    "indicadores_principales", "complementarios", "horas",
    "indicadores_principales_edad", "rama"
  )

  if (!is.character(serie) || length(serie) != 1L ||
      is.na(serie) || !serie %in% disponibles) {
    stop("Serie no disponible. Consulta laboral_catalogo().", call. = FALSE)
  }
  if (!is.logical(actualizar) || length(actualizar) != 1L ||
      is.na(actualizar)) {
    stop("'actualizar' debe ser TRUE o FALSE.", call. = FALSE)
  }

  if (actualizar || !exists(serie, envir = .laboral_cache, inherits = FALSE)) {
    url <- paste0(.laboral_api, "series/", serie, ".json")
    respuesta <- tryCatch(
      jsonlite::fromJSON(url),
      error = function(e) {
        stop("No se pudo leer la serie '", serie, "': ",
             conditionMessage(e), call. = FALSE)
      }
    )

    if (!is.data.frame(respuesta$observations)) {
      stop("La respuesta no contiene observaciones tabulares.", call. = FALSE)
    }

    assign(serie, tibble::as_tibble(respuesta$observations),
           envir = .laboral_cache)
  }

  datos <- get(serie, envir = .laboral_cache, inherits = FALSE)
  filtros <- list(
    indicator = indicador,
    region = region,
    sex = sexo,
    age_group = edad,
    branch = rama
  )

  for (columna in names(filtros)) {
    valores <- filtros[[columna]]
    if (is.null(valores)) next

    if (!columna %in% names(datos)) {
      stop("La serie '", serie, "' no tiene dimensión '",
           columna, "'.", call. = FALSE)
    }
    if (!is.character(valores) || !length(valores) || anyNA(valores)) {
      stop("El filtro '", columna, "' debe contener texto.", call. = FALSE)
    }

    datos <- dplyr::filter(datos, .data[[columna]] %in% .env$valores)
  }

  datos
}
