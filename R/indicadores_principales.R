# Parser de la familia "Indicadores principales" del INE.
# Cada hoja: fila 6 nombres, fila 7 unidades, desde fila 8 datos;
# C:D, E:F, ... AA:AB son 13 pares (nota, valor).

ip_config <- function(path = "config/indicadores_principales.yml") {
  yaml::read_yaml(path)
}

ip_sheet_map <- function(config) {
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
  result <- purrr::map_dfr(expected, ~ ip_process_sheet(path, .x, config)) |>
    dplyr::arrange(.data$indicator, .data$region, .data$sex, .data$period)

  if (anyDuplicated(result[c("period", "region", "sex", "indicator")])) {
    stop("Observaciones duplicadas en la clave estadística.", call. = FALSE)
  }
  if (anyNA(result$period) || anyNA(result$quality) ||
      anyNA(result$anio) || anyNA(result$trimestre_movil)) {
    stop("Valores de período/calidad incompletos.", call. = FALSE)
  }
  if (dplyr::n_distinct(result$indicator) != length(config$indicators) ||
      dplyr::n_distinct(result$period) < 1L) {
    stop("Cobertura insuficiente en el tabulado.", call. = FALSE)
  }
  result
}

# Publicación conjunta de tabulados que comparten el mismo contrato JSON.
ip_publish <- function(datasets, root = "api/v1") {
  dir.create(file.path(root, "series"), recursive = TRUE, showWarnings = FALSE)
  updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  catalogs <- list()
  manifests <- list()

  for (id in names(datasets)) {
    entry <- datasets[[id]]
    data <- entry$data
    config <- entry$config
    series_path <- paste0("series/", id, ".json")
    coverage <- data |>
      dplyr::distinct(.data$region, .data$sex) |>
      dplyr::arrange(.data$region, .data$sex)

    series <- list(
      schema_version = 1L, id = id,
      source = "Instituto Nacional de Estadísticas (Chile)",
      source_url = entry$source_url,
      source_sha256 = entry$hash,
      frequency = "rolling_quarter",
      observations = data
    )
    jsonlite::write_json(
      series, file.path(root, series_path), pretty = TRUE,
      auto_unbox = TRUE, dataframe = "rows", na = "null", digits = NA
    )

    catalogs[[length(catalogs) + 1L]] <- list(
      id = id, title = entry$title, path = series_path,
      frequency = "rolling_quarter",
      indicators = config$indicators, coverage = coverage,
      quality_codes = list(
        sin_advertencia = "Sin nota de advertencia en el Excel",
        a = "Estimación poco fiable según el INE",
        b = "Estimación no fiable según el INE",
        sin_dato = "Valor no disponible en el archivo original"
      )
    )
    manifests[[length(manifests) + 1L]] <- list(
      id = id, path = series_path, parser_version = 3L,
      source_url = entry$source_url, source_sha256 = entry$hash,
      observations = nrow(data),
      first_period = min(data$period),
      last_period = max(data$period),
      status = "ok"
    )
  }
  jsonlite::write_json(
    list(schema_version = 1L, updated_at = updated_at, datasets = catalogs),
    file.path(root, "catalog.json"), pretty = TRUE, auto_unbox = TRUE,
    dataframe = "rows", na = "null", digits = NA
  )
  jsonlite::write_json(
    list(schema_version = 1L, updated_at = updated_at, datasets = manifests),
    file.path(root, "manifest.json"), pretty = TRUE, auto_unbox = TRUE,
    dataframe = "rows", na = "null", digits = NA
  )
  invisible(manifests)
}
