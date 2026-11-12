# Detección y depuración de duplicaciones entre tabulados ENE.
# Una observación es redundante sólo cuando coinciden el concepto, la unidad,
# el período y TODAS sus dimensiones. La rama "total" equivale a no desglosar
# por rama. Los tramos de edad son dimensiones distintas, no duplicaciones.

.laboral_clave <- c("indicator", "unit", "period", "region", "sex",
                    "age_group", "branch")

.laboral_preparar_redundancias <- function(datasets) {
  if (is.null(names(datasets)) || any(!nzchar(names(datasets)))) {
    stop("Los datasets deben tener nombres.", call. = FALSE)
  }
  purrr::imap_dfr(datasets, function(entry, id) {
    datos <- if (is.data.frame(entry)) entry else entry$data
    if (!is.data.frame(datos)) stop("Dataset inválido: ", id, call. = FALSE)

    requeridas <- c("indicator", "unit", "period", "region", "sex", "value")
    if (!all(requeridas %in% names(datos))) {
      stop("Faltan columnas en ", id, ": ",
           paste(setdiff(requeridas, names(datos)), collapse = ", "),
           call. = FALSE)
    }
    if (!"age_group" %in% names(datos)) datos$age_group <- NA_character_
    if (!"branch" %in% names(datos)) datos$branch <- NA_character_

    datos |>
      dplyr::mutate(
        .dataset = id,
        .row = dplyr::row_number(),
        branch = dplyr::na_if(.data$branch, "total")
      ) |>
      dplyr::select(.data$.dataset, .data$.row,
                    dplyr::all_of(.laboral_clave), .data$value)
  })
}

#' Detectar observaciones repetidas entre conjuntos de datos.
#' @param datasets Lista con nombre: data frames o entradas con $data.
#' @return Tibble con cada observación duplicada y su fuente.
laboral_redundancias <- function(datasets) {
  datos <- .laboral_preparar_redundancias(datasets)
  datos |>
    dplyr::group_by(dplyr::across(dplyr::all_of(.laboral_clave))) |>
    dplyr::filter(dplyr::n_distinct(.data$.dataset) > 1L) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$indicator, .data$period, .data$.dataset)
}

#' Resumir solapamientos: indicador, fuentes, observaciones y discrepancias.
#' Las discrepancias se reportan; no se asume que los valores sean idénticos.
laboral_resumen_redundancias <- function(datasets, tolerancia = 0.05) {
  detalle <- laboral_redundancias(datasets)
  if (!nrow(detalle)) {
    return(tibble::tibble(
      indicator = character(), fuentes = character(),
      claves_duplicadas = integer(), discrepancias = integer(),
      diferencia_maxima = double()
    ))
  }
  detalle |>
    dplyr::group_by(dplyr::across(dplyr::all_of(.laboral_clave))) |>
    dplyr::summarise(
      fuentes = paste(sort(unique(.data$.dataset)), collapse = " + "),
      diferencia = if (all(is.na(.data$value))) 0 else
        if (anyNA(.data$value)) Inf else
          diff(range(.data$value)),
      .groups = "drop"
    ) |>
    dplyr::group_by(.data$indicator, .data$fuentes) |>
    dplyr::summarise(
      claves_duplicadas = dplyr::n(),
      discrepancias = sum(.data$diferencia > tolerancia),
      diferencia_maxima = max(.data$diferencia),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$claves_duplicadas))
}

#' Mantener una única fuente por clave estadística, según prioridad declarada.
#' Conserva los archivos originales del INE; depura sólo los datos publicados.
laboral_depurar_redundancias <- function(
  datasets,
  prioridad = c("indicadores_principales", "complementarios", "horas",
                "rama", "indicadores_principales_edad")
) {
  faltantes <- setdiff(names(datasets), prioridad)
  if (length(faltantes)) {
    stop("Falta prioridad para: ", paste(faltantes, collapse = ", "),
         call. = FALSE)
  }

  datos <- .laboral_preparar_redundancias(datasets)
  seleccion <- datos |>
    dplyr::mutate(.prioridad = match(.data$.dataset, prioridad)) |>
    dplyr::arrange(.data$.prioridad) |>
    dplyr::distinct(dplyr::across(dplyr::all_of(.laboral_clave)),
                    .keep_all = TRUE)

  purrr::imap(datasets, function(entry, id) {
    filas <- sort(seleccion$.row[seleccion$.dataset == id])
    datos_originales <- if (is.data.frame(entry)) entry else entry$data
    depurados <- datos_originales[filas, , drop = FALSE]
    if (!nrow(depurados)) {
      stop("La depuración dejó vacío el dataset: ", id, call. = FALSE)
    }
    if (is.data.frame(entry)) depurados else {
      entry$data <- depurados
      entry
    }
  })
}

#' Comprobar los JSON publicados sin descargar nuevamente los Excel.
laboral_auditar_publicadas <- function(root = "api/v1") {
  archivos <- list.files(file.path(root, "series"), pattern = "\\.json$",
                        full.names = TRUE)
  if (!length(archivos)) stop("No hay series JSON en ", root, call. = FALSE)
  datasets <- stats::setNames(lapply(archivos, function(path) {
    tibble::as_tibble(jsonlite::fromJSON(path)$observations)
  }), sub("\\.json$", "", basename(archivos)))
  laboral_resumen_redundancias(datasets)
}
