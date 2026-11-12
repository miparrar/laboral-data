# Parser de la familia "Indicadores principales" del INE.
# Cada hoja: fila 6 nombres, fila 7 unidades, desde fila 8 datos;
# C:D, E:F, ... AA:AB son 13 pares (nota, valor).

ip_config <- function(path = "config/indicadores_principales.yml") {
  yaml::read_yaml(path)
}

ip_sheet_map <- function(config) {
  if (!is.null(config$sheet_dimensions)) {
    return(stats::setNames(
      vapply(config$sheet_dimensions, function(x) x$region, character(1)),
      names(config$sheet_dimensions)
    ))
  }
  c(AS = "nacional", H = "nacional", M = "nacional",
    unlist(config$regions, use.names = TRUE))
}

ip_period <- function(year, quarter) {
  months <- c(ene = 1L, feb = 2L, mar = 3L, abr = 4L, may = 5L,
              jun = 6L, jul = 7L, ago = 8L, sep = 9L, oct = 10L,
              nov = 11L, dic = 12L)
  initial <- stringr::str_to_lower(stringr::str_sub(trimws(quarter), 1L, 3L))
  month <- unname(months[initial])
  if (anyNA(month)) stop("Trimestres móviles no reconocidos.", call. = FALSE)
  # En el INE, Dic-Feb ya utiliza el año del mes central (enero).
  yy <- as.integer(year)
  mm <- (month %% 12L) + 1L
  sprintf("%04d-%02d", yy, mm)
}

tabulado_process_sheet <- function(path, sheet, config, header_row = 6L, data_row = 8L) {
  raw <- readxl::read_excel(
    path, sheet = sheet, skip = header_row - 1L, col_names = FALSE,
    col_types = "text", .name_repair = "minimal"
  )
  if (ncol(raw) < 4L) {
    stop(sprintf("La hoja %s no contiene pares nota/valor.", sheet), call. = FALSE)
  }
  # Ignora columnas finales completamente vacías (formato residual de Excel).
  while (ncol(raw) > 2L && all(is.na(raw[[ncol(raw)]]) | trimws(raw[[ncol(raw)]]) == "")) {
    raw <- raw[, -ncol(raw), drop = FALSE]
  }
  if ((ncol(raw) - 2L) %% 2L != 0L) {
    stop(sprintf("Pares de columnas (nota, valor) inválidos en %s.", sheet), call. = FALSE)
  }
  names(raw) <- paste0("V", seq_along(raw))
  headers <- unlist(raw[1, ], use.names = FALSE)
  subheaders <- unlist(raw[2, ], use.names = FALSE)
  starts <- seq.int(3L, ncol(raw) - 1L, by = 2L)
  specs <- config$indicators

  if (length(specs) != length(starts) ||
      anyNA(headers[starts]) ||
      any(!nzchar(trimws(headers[starts]))) ||
      any(tolower(trimws(subheaders[starts])) != "nota") ||
      any(!tolower(trimws(subheaders[starts + 1L])) %in% c("en miles", "tasa (%)", "en horas"))) {
    stop(sprintf("Encabezados inesperados en hoja %s.", sheet), call. = FALSE)
  }
  expected_units <- vapply(specs, function(x) {
    switch(x$unit,
           percent = "tasa (%)",
           thousand_persons = "en miles",
           hours = "en horas",
           stop("Unidad no declarada: ", x$unit))
  }, character(1))
  if (!identical(tolower(trimws(subheaders[starts + 1L])), expected_units)) {
    stop(sprintf("Unidades inesperadas en hoja %s.", sheet), call. = FALSE)
  }

  if (data_row <= header_row + 1L) stop("data_row debe seguir a las dos filas de encabezado.", call. = FALSE)
  values <- raw[-seq_len(data_row - header_row), , drop = FALSE] |>
    dplyr::filter(stringr::str_detect(.data$V1, "^[0-9]{4}(\\.0+)?$"))
  if (!nrow(values)) {
    stop(sprintf("Hoja %s sin observaciones.", sheet), call. = FALSE)
  }
  periods <- ip_period(values$V1, values$V2)
  sheet_dimensions <- config$sheet_dimensions[[sheet]]
  if (!is.null(sheet_dimensions)) {
    region <- sheet_dimensions$region
    sex <- sheet_dimensions$sex
  } else {
    region <- unname(ip_sheet_map(config)[[sheet]])
    sex <- switch(sheet, AS = "total", H = "hombre", M = "mujer", "total")
  }

  purrr::map2_dfr(starts, specs, function(col, spec) {
    note <- trimws(values[[col]])
    note[is.na(note) | note == ""] <- NA_character_
    unexpected <- setdiff(unique(stats::na.omit(note)), c("a", "b"))
    if (length(unexpected)) {
      stop(sprintf("Notas de calidad desconocidas en %s: %s",
                   sheet, paste(unexpected, collapse = ", ")), call. = FALSE)
    }
    raw_value <- trimws(values[[col + 1L]])
    missing <- is.na(raw_value) | raw_value %in% c("-", "")
    if (any(missing) && !isTRUE(config$allow_missing_values)) {
      stop(sprintf("Valores ausentes no esperados en %s / %s.", sheet, spec$id), call. = FALSE)
    }
    value <- suppressWarnings(as.numeric(raw_value))
    if (any(!missing & (is.na(value) | !is.finite(value)))) {
      stop(sprintf("Valores no numéricos en %s / %s.", sheet, spec$id), call. = FALSE)
    }
    tibble::tibble(
      period = periods,
      anio = as.integer(as.numeric(values$V1)),
      trimestre_movil = trimws(values$V2),
      region = region,
      sex = sex,
      source_sheet = sheet,
      age_group = if (is.null(sheet_dimensions$age_group)) NULL else sheet_dimensions$age_group,
      indicator = spec$id,
      value = value,
      unit = spec$unit,
      quality_code = note,
      quality = dplyr::case_when(
        missing ~ "sin_dato",
        is.na(note) ~ "sin_advertencia",
        note == "a" ~ "poco_fiable",
        note == "b" ~ "no_fiable"
      )
    )
  })
}

ip_process_sheet <- function(path, sheet, config) {
  tabulado_process_sheet(path, sheet, config)
}

ip_process <- function(path, config = ip_config()) {
  available <- readxl::excel_sheets(path)
  expected <- names(ip_sheet_map(config))
  if (length(available) < 2L || !setequal(available[-1L], expected)) {
    stop(paste0("Inventario de hojas cambiado. Faltan: ",
                paste(setdiff(expected, available), collapse = ", "),
                "; nuevas: ", paste(setdiff(available[-1L], expected), collapse = ", ")),
         call. = FALSE)
  }
  result <- purrr::map_dfr(expected, ~ ip_process_sheet(path, .x, config))
  if (!is.null(config$dimension_from_indicator)) {
    # El cuadro por rama publica un total y 22 categorías de la ocupación.
    # Todas son la misma medida, diferenciada por su rama de actividad.
    dimension <- config$dimension_from_indicator
    if (!identical(dimension, "branch") ||
        length(config$public_indicators) != 1L) {
      stop("Configuración de dimensión no soportada.", call. = FALSE)
    }
    result <- result |>
      dplyr::mutate(
        branch = .data$indicator,
        indicator = config$public_indicators[[1L]]$id
      )
  }
  order_cols <- intersect(c("indicator", "region", "sex", "age_group",
                            "branch", "period"), names(result))
  result <- result |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols)))

  key <- intersect(c("period", "region", "sex", "age_group", "branch", "indicator"),
                   names(result))
  if (anyDuplicated(result[key])) {
    stop("Observaciones duplicadas en la clave estadística.", call. = FALSE)
  }
  if (anyNA(result$period) || anyNA(result$source_sheet) ||
      !setequal(unique(result$source_sheet), expected) ||
      anyNA(result$quality) ||
      anyNA(result$anio) || anyNA(result$trimestre_movil)) {
    stop("Valores de período/calidad incompletos.", call. = FALSE)
  }
  published_indicators <- if (is.null(config$public_indicators)) {
    config$indicators
  } else config$public_indicators
  if (dplyr::n_distinct(result$indicator) != length(published_indicators) ||
      dplyr::n_distinct(result$period) < 1L) {
    stop("Cobertura insuficiente en el tabulado.", call. = FALSE)
  }
  result
}

# Metadatos de capacidades analíticas publicados junto a cada medida.
# Describen opciones posibles, no ejecutan cálculos ni garantizan inferencia.
ip_analisis_indicador <- function(spec, datos, reglas) {
  unidad <- reglas$units[[spec$unit]]
  if (is.null(unidad)) {
    stop("Sin política analítica para la unidad: ", spec$unit, call. = FALSE)
  }
  dims <- intersect(names(reglas$dimension_analyses), names(datos))
  dims <- dims[vapply(dims, function(d) dplyr::n_distinct(datos[[d]]) > 1L,
                       logical(1))]
  otras <- unname(unlist(reglas$dimension_analyses[dims], use.names = FALSE))
  extra <- reglas$indicators[[spec$id]]

  spec$analysis <- list(
    measurement_type = unidad$measurement_type,
    allowed = unique(c(unlist(unidad$analyses, use.names = FALSE), otras)),
    warnings = unname(unlist(unidad$warnings, use.names = FALSE))
  )
  if (!is.null(extra$definition)) spec$definition <- extra$definition
  if (!is.null(extra$aliases)) spec$aliases <- unname(unlist(extra$aliases))
  spec
}

# Convierte posiciones de columnas (1, 26, 27, ...) a referencias Excel.
ip_col_excel <- function(n) {
  vapply(n, function(x) {
    letras <- character()
    while (x > 0L) {
      x <- x - 1L
      letras <- c(LETTERS[(x %% 26L) + 1L], letras)
      x <- x %/% 26L
    }
    paste0(letras, collapse = "")
  }, character(1))
}

# Inventario a nivel de serie: indicador + combinación exacta de dimensiones.
# La procedencia se obtiene de las columnas y hojas realmente procesadas.
ip_series_catalogo <- function(data, config, dataset_id) {
  dims <- intersect(c("region", "sex", "age_group", "branch"), names(data))
  grupos <- c("indicator", dims)
  ids_originales <- vapply(config$indicators, function(x) x$id, character(1))
  resultado <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::summarise(
      source_sheet = dplyr::first(.data$source_sheet),
      first_period = min(.data$period),
      last_period = max(.data$period),
      first_valid_period = if (all(is.na(.data$value))) NA_character_ else
        min(.data$period[!is.na(.data$value)]),
      last_valid_period = if (all(is.na(.data$value))) NA_character_ else
        max(.data$period[!is.na(.data$value)]),
      observations = dplyr::n(),
      valid_observations = sum(!is.na(.data$value)),
      unit = dplyr::first(.data$unit),
      sheets_count = dplyr::n_distinct(.data$source_sheet),
      units_count = dplyr::n_distinct(.data$unit),
      .groups = "drop"
    )
  if (any(resultado$sheets_count != 1L) || any(resultado$units_count != 1L)) {
    stop("Una serie abarca varias hojas o unidades; revisar el mapeo.", call. = FALSE)
  }
  origen <- if ("branch" %in% names(resultado)) resultado$branch else
    resultado$indicator
  indice <- match(origen, ids_originales)
  if (anyNA(indice)) stop("Columna original desconocida para serie.", call. = FALSE)
  resultado <- resultado |>
    dplyr::mutate(
      note_column = ip_col_excel(3L + 2L * (.env$indice - 1L)),
      value_column = ip_col_excel(4L + 2L * (.env$indice - 1L)),
      .after = "source_sheet"
    ) |>
    dplyr::select(-dplyr::all_of(c("sheets_count", "units_count")))

  resultado$series_key <- vapply(seq_len(nrow(resultado)), function(i) {
    paste(c(dataset_id, resultado$indicator[[i]],
            unlist(resultado[i, dims, drop = FALSE], use.names = FALSE)),
          collapse = "/")
  }, character(1))
  resultado <- dplyr::relocate(resultado, .data$series_key, .before = 1L)
  if (anyDuplicated(resultado$series_key) || sum(resultado$observations) != nrow(data)) {
    stop("Inventario de series incompleto o con claves duplicadas.", call. = FALSE)
  }
  resultado
}

# Publicación conjunta de tabulados que comparten el mismo contrato JSON.
ip_publish <- function(datasets, root = "api/v1") {
  dir.create(file.path(root, "series"), recursive = TRUE, showWarnings = FALSE)
  updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  catalogs <- list()
  reglas_analisis <- yaml::read_yaml("config/analisis.yml")

  for (id in names(datasets)) {
    entry <- datasets[[id]]
    data <- entry$data
    config <- entry$config
    series_path <- paste0("series/", id, ".json")
    originales <- if (is.null(config$public_indicators)) {
      config$indicators
    } else config$public_indicators
    publicados <- Filter(function(spec) spec$id %in% unique(data$indicator),
                         originales)
    if (!length(publicados)) stop("Sin indicadores publicados en ", id)
    publicados <- lapply(publicados, ip_analisis_indicador,
                         datos = data, reglas = reglas_analisis)

    series <- list(
      schema_version = 1L, id = id,
      source = "Instituto Nacional de Estadísticas (Chile)",
      source_file = entry$source_file,
      source_url = entry$source_url,
      source_sha256 = entry$hash,
      frequency = "rolling_quarter",
      observations = data
    )
    jsonlite::write_json(
      series, file.path(root, series_path), pretty = TRUE,
      auto_unbox = TRUE, dataframe = "rows", na = "null", digits = NA
    )

    series_index <- ip_series_catalogo(data, config, id)
    catalogs[[length(catalogs) + 1L]] <- list(
      id = id, title = entry$title, path = series_path,
      frequency = "rolling_quarter",
      source_file = entry$source_file,
      source_url = entry$source_url,
      source_sha256 = entry$hash,
      build_sha256 = entry$build_sha256,
      parser_version = 6L,
      observations = nrow(data),
      first_period = min(data$period),
      last_period = max(data$period),
      status = "ok",
      source_sheets = names(ip_sheet_map(config)),
      indicators = publicados,
      series = series_index,
      dimension_labels = if (identical(config$dimension_from_indicator, "branch"))
        list(branch = lapply(Filter(function(x) x$id %in% unique(data$branch),
                                    config$indicators), function(x)
          list(id = x$id, label = x$label))) else NULL,
      quality_codes = list(
        sin_advertencia = "Sin nota de advertencia en el Excel",
        a = "Estimación poco fiable según el INE",
        b = "Estimación no fiable según el INE",
        sin_dato = "Valor no disponible en el archivo original"
      )
    )
  }
  jsonlite::write_json(
    list(
      schema_version = 2L,
      updated_at = updated_at,
      sdmx_mapping = list(
        series_key = c("indicator", "region", "sex", "age_group", "branch"),
        time_dimension = "period",
        primary_measure = "value",
        observation_attributes = c("quality_code", "quality"),
        series_attributes = c("unit", "source_sheet")
      ),
      datasets = catalogs
    ),
    file.path(root, "catalog.json"), pretty = TRUE, auto_unbox = TRUE,
    dataframe = "rows", na = "null", digits = NA
  )
  invisible(catalogs)
}
