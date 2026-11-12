# Cliente de consulta para los JSON públicos de laboral-data.
# Interfaz inspirada en bcchr: descubrir, buscar, describir y obtener series.
# Requiere jsonlite, tibble y dplyr; no necesita credenciales.

.laboral_api <- "https://miparrar.github.io/laboral-data/api/v1/"
.laboral_cache <- new.env(parent = emptyenv())

.laboral_validar_texto <- function(x, nombre) {
  if (!is.character(x) || !length(x) || anyNA(x) ||
      any(!nzchar(trimws(x)))) {
    stop("'", nombre, "' debe ser un vector de texto no vacío.", call. = FALSE)
  }
  invisible(x)
}

.laboral_request <- function(path, simplify = FALSE, actualizar = FALSE) {
  if (!is.logical(actualizar) || length(actualizar) != 1L ||
      is.na(actualizar)) {
    stop("'actualizar' debe ser TRUE o FALSE.", call. = FALSE)
  }

  key <- paste0(if (simplify) "table:" else "raw:", path)
  if (actualizar || !exists(key, envir = .laboral_cache, inherits = FALSE)) {
    respuesta <- tryCatch(
      jsonlite::fromJSON(
        paste0(.laboral_api, path), simplifyVector = simplify
      ),
      error = function(e) {
        stop("No se pudo consultar '", path, "': ",
             conditionMessage(e), call. = FALSE)
      }
    )
    assign(key, respuesta, envir = .laboral_cache)
  }
  get(key, envir = .laboral_cache, inherits = FALSE)
}

.laboral_fuente <- function(x) {
  if (!is.null(x$source_file)) return(x$source_file)
  if (is.null(x$source_url)) return(NA_character_)
  basename(strsplit(x$source_url, "?", fixed = TRUE)[[1L]][1L])
}

#' Conjuntos de datos publicados
#' @return Tibble con el identificador y la descripción de cada tabulado.
laboral_catalogo <- function() {
  datasets <- .laboral_request("catalog.json")$datasets
  tibble::tibble(
    serie = vapply(datasets, function(x) x$id, character(1)),
    descripcion = vapply(datasets, function(x) x$title, character(1))
  )
}

#' Metadata del catálogo: una fila por indicador y tabulado.
#' @return Tibble con códigos, etiquetas, dimensiones y fuentes oficiales.
laboral_metadata <- function() {
  datasets <- .laboral_request("catalog.json")$datasets

  dplyr::bind_rows(lapply(datasets, function(dataset) {
    labels <- if (!is.null(dataset$dimension_labels$branch)) {
      vapply(dataset$dimension_labels$branch,
             function(x) paste(x$id, x$label), character(1))
    } else character()

    tibble::tibble(
      series_id = paste(
        dataset$id,
        vapply(dataset$indicators, function(x) x$id, character(1)),
        sep = "/"
      ),
      tabulado = dataset$id,
      titulo = dataset$title,
      indicador = vapply(dataset$indicators,
                         function(x) x$id, character(1)),
      descripcion = vapply(dataset$indicators,
                           function(x) x$label, character(1)),
      unidad = vapply(dataset$indicators,
                      function(x) x$unit, character(1)),
      dimensiones = {
        series <- if (!is.null(dataset$series)) dataset$series else dataset$coverage
        paste(intersect(c("region", "sex", "age_group", "branch"),
                        names(series[[1L]])), collapse = ", ")
      },
      hojas = paste(unlist(dataset$source_sheets), collapse = ", "),
      archivo = .laboral_fuente(dataset),
      fuente_url = dataset$source_url,
      ramas = paste(labels, collapse = " "),
      tipo_medida = vapply(dataset$indicators, function(x)
        if (is.null(x$analysis$measurement_type)) "" else
          x$analysis$measurement_type, character(1)),
      analisis = vapply(dataset$indicators, function(x)
        paste(unlist(x$analysis$allowed, use.names = FALSE),
              collapse = ", "), character(1)),
      advertencias = vapply(dataset$indicators, function(x)
        paste(unlist(x$analysis$warnings, use.names = FALSE),
              collapse = " | "), character(1)),
      definicion = vapply(dataset$indicators, function(x)
        if (is.null(x$definition)) "" else x$definition, character(1)),
      sinonimos = vapply(dataset$indicators, function(x)
        paste(unlist(x$aliases, use.names = FALSE), collapse = ", "),
        character(1))
    )
  }))
}

#' Catálogo de series estadísticas en formato largo (sin observaciones).
#' Cada fila identifica indicador y combinación de dimensiones, hoja y columnas
#' del Excel del INE, períodos de cobertura y metadatos analíticos.
laboral_series <- function() {
  datasets <- .laboral_request("catalog.json")$datasets
  series <- dplyr::bind_rows(lapply(datasets, function(ds) {
    if (is.null(ds$series)) return(tibble::tibble())
    dplyr::mutate(
      dplyr::bind_rows(ds$series),
      tabulado = ds$id,
      titulo = ds$title,
      archivo = .laboral_fuente(ds),
      fuente_url = ds$source_url,
      path = ds$path,
      .before = 1L
    )
  }))
  if (!nrow(series)) {
    stop("El catálogo aún no contiene el inventario de series.", call. = FALSE)
  }
  definiciones <- laboral_metadata() |>
    dplyr::select(
      .data$tabulado, .data$indicador, .data$descripcion,
      .data$definicion, .data$sinonimos, .data$tipo_medida,
      .data$analisis, .data$advertencias
    )
  dplyr::left_join(
    series, definiciones,
    by = c("tabulado", "indicator" = "indicador")
  )
}

#' Buscar candidatos a series por texto, sin elegir automáticamente una.
#' @param query Uno o varios textos (sin distinguir acentos ni mayúsculas).
#' @return Tibble con las series candidatas y el texto que las encontró.
laboral_buscar <- function(query) {
  .laboral_validar_texto(query, "query")
  catalogo <- laboral_metadata()

  normalizar <- function(x) {
    x <- iconv(x, to = "ASCII//TRANSLIT")
    x[is.na(x)] <- ""
    tolower(x)
  }
  # El título del tabulado NO determina relevancia del indicador:
  # evita devolver todos los complementarios por mencionar "desocupación".
  descripcion <- normalizar(catalogo$descripcion)
  sinonimos <- normalizar(catalogo$sinonimos)
  busqueda <- normalizar(paste(catalogo$series_id, catalogo$descripcion,
                               catalogo$sinonimos, catalogo$ramas))

  dplyr::bind_rows(lapply(query, function(texto) {
    texto_norm <- trimws(normalizar(texto))
    exactos <- descripcion == texto_norm |
      vapply(strsplit(sinonimos, ", ", fixed = TRUE),
             function(x) texto_norm %in% x, logical(1))
    if (any(exactos)) {
      seleccion <- exactos
    } else {
      terminos <- strsplit(texto_norm, "[[:space:]]+")[[1L]]
      candidatos <- vapply(terminos, function(t) grepl(t, busqueda, fixed = TRUE),
                          logical(nrow(catalogo)))
      seleccion <- if (length(terminos) == 1L) candidatos else {
        rowSums(candidatos) == length(terminos)
      }
    }
    dplyr::mutate(catalogo[seleccion, , drop = FALSE],
                  query = texto, .before = 1L)
  }))
}

#' Describir una o varias series mediante sus códigos exactos.
laboral_describir <- function(series_id) {
  .laboral_validar_texto(series_id, "series_id")
  x <- laboral_metadata()
  desconocidos <- setdiff(series_id, x$series_id)
  if (length(desconocidos)) {
    stop("Series desconocidas: ", paste(desconocidos, collapse = ", "),
         ". Usa laboral_buscar() para encontrar códigos.", call. = FALSE)
  }
  x[match(series_id, x$series_id), , drop = FALSE]
}

.laboral_datos <- function(serie, actualizar = FALSE) {
  .laboral_validar_texto(serie, "serie")
  disponibles <- c("indicadores_principales", "complementarios", "horas",
                   "indicadores_principales_edad", "rama")
  if (length(serie) != 1L || !serie %in% disponibles) {
    stop("Tabulado no disponible. Usa laboral_catalogo().", call. = FALSE)
  }

  respuesta <- .laboral_request(
    paste0("series/", serie, ".json"), simplify = TRUE, actualizar = actualizar
  )
  if (!is.data.frame(respuesta$observations)) {
    stop("La respuesta no contiene observaciones tabulares.", call. = FALSE)
  }

  datos <- tibble::as_tibble(respuesta$observations)
  if (!"source_sheet" %in% names(datos)) {
    # La API anterior no publicaba hojas; no se infiere una hoja inexistente.
    datos$source_sheet <- NA_character_
  }

  dplyr::mutate(
    datos,
    series_id = paste0(serie, "/", .data$indicator),
    source_dataset = serie,
    source_file = .laboral_fuente(respuesta),
    source_url = respuesta$source_url,
    source_sha256 = respuesta$source_sha256
  )
}

.laboral_filtrar <- function(datos, filtros) {
  for (columna in names(filtros)) {
    valores <- filtros[[columna]]
    if (is.null(valores)) next
    if (!columna %in% names(datos)) {
      stop("Este tabulado no tiene dimensión '", columna, "'.",
           call. = FALSE)
    }
    .laboral_validar_texto(valores, columna)
    datos <- dplyr::filter(datos, .data[[columna]] %in% .env$valores)
  }
  datos
}

.laboral_fechas <- function(datos, desde = NULL, hasta = NULL) {
  validar <- function(x, nombre) {
    if (is.null(x)) return(invisible(NULL))
    if (!is.character(x) || length(x) != 1L || is.na(x) ||
        !grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", x)) {
      stop("'", nombre, "' debe tener formato YYYY-MM.", call. = FALSE)
    }
  }
  validar(desde, "desde")
  validar(hasta, "hasta")
  if (!is.null(desde) && !is.null(hasta) && desde > hasta) {
    stop("'desde' no puede ser posterior a 'hasta'.", call. = FALSE)
  }
  if (!is.null(desde)) datos <- dplyr::filter(datos, .data$period >= .env$desde)
  if (!is.null(hasta)) datos <- dplyr::filter(datos, .data$period <= .env$hasta)
  datos
}

#' Obtener una o varias series exactas, en formato largo.
#' Conserva tabulado, archivo, hoja y URL originales para cada observación.
laboral_obtener <- function(series_id, desde = NULL, hasta = NULL,
                            region = NULL, sexo = NULL, edad = NULL,
                            rama = NULL, actualizar = FALSE) {
  .laboral_validar_texto(series_id, "series_id")
  ids <- unique(series_id)
  laboral_describir(ids) # Comprueba códigos contra el catálogo vigente.

  # Una sola descarga por tabulado, incluso al solicitar varios indicadores.
  tabulados <- unique(sub("/.*$", "", ids))
  fuentes <- stats::setNames(
    lapply(tabulados, .laboral_datos, actualizar = actualizar),
    tabulados
  )
  datos <- dplyr::bind_rows(lapply(ids, function(id) {
    partes <- strsplit(id, "/", fixed = TRUE)[[1L]]
    dplyr::filter(fuentes[[partes[[1L]]]], .data$indicator == partes[[2L]])
  }))

  datos <- .laboral_filtrar(datos, list(
    region = region, sex = sexo, age_group = edad, branch = rama
  ))
  .laboral_fechas(datos, desde = desde, hasta = hasta)
}

#' Lectura por tabulado: interfaz anterior conservada por compatibilidad.
laboral_leer <- function(serie = "indicadores_principales",
                         indicador = NULL, region = NULL, sexo = NULL,
                         edad = NULL, rama = NULL, actualizar = FALSE,
                         desde = NULL, hasta = NULL) {
  datos <- .laboral_datos(serie, actualizar = actualizar)
  datos <- .laboral_filtrar(datos, list(
    indicator = indicador, region = region, sex = sexo,
    age_group = edad, branch = rama
  ))
  .laboral_fechas(datos, desde = desde, hasta = hasta)
}
