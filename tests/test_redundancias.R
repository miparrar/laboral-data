# Contrato de detección y deduplicación entre tabulados sin red.
source("R/redundancias.R")

ejemplo <- function(indicador, valor, unidad = "thousand_persons", ...) {
  tibble::tibble(
    period = "2026-08", region = "nacional", sex = "total",
    indicator = indicador, value = valor, unit = unidad, ...
  )
}
principal <- dplyr::bind_rows(
  ejemplo("ocupados", 100),
  ejemplo("tasa_desocupacion", 8.5, "percent")
)
complementarios <- dplyr::bind_rows(
  ejemplo("ocupados", 100),
  ejemplo("tasa_desocupacion", 8.5, "percent"),
  ejemplo("su3", 12, "percent")
)
horas <- dplyr::bind_rows(
  ejemplo("ocupados", 100),
  ejemplo("promedio_horas_habituales", 40, "hours")
)
rama <- dplyr::bind_rows(
  ejemplo("ocupados", 100, branch = "total"),
  ejemplo("ocupados", 20, branch = "construccion")
)
edad <- ejemplo("tasa_desocupacion", 12.5, "percent",
                age_group = "15-24")

datasets <- list(
  indicadores_principales = list(data = principal),
  complementarios = list(data = complementarios),
  horas = list(data = horas),
  rama = list(data = rama),
  indicadores_principales_edad = list(data = edad)
)
duplicados <- laboral_redundancias(datasets)
resumen <- laboral_resumen_redundancias(datasets)

stopifnot(
  nrow(duplicados) == 6L,
  nrow(resumen) == 2L,
  setequal(resumen$indicator, c("ocupados", "tasa_desocupacion")),
  all(resumen$discrepancias == 0L),
  !any(duplicados$.dataset == "indicadores_principales_edad")
)

depurados <- laboral_depurar_redundancias(datasets)
stopifnot(
  nrow(laboral_redundancias(depurados)) == 0L,
  nrow(depurados$indicadores_principales$data) == 2L,
  identical(depurados$complementarios$data$indicator, "su3"),
  identical(depurados$horas$data$indicator,
            "promedio_horas_habituales"),
  identical(depurados$rama$data$branch, "construccion"),
  identical(depurados$indicadores_principales_edad$data$age_group,
            "15-24")
)

# Detectar y reportar un conflicto, sin confundirlo con una nueva medida.
conflictivos <- datasets
conflictivos$complementarios$data$value[[1L]] <- 115
conflictos <- laboral_resumen_redundancias(conflictivos)
stopifnot(any(conflictos$discrepancias > 0L))

# Las reglas analíticas deben estar disponibles para todas las unidades.
reglas <- yaml::read_yaml("config/analisis.yml")
stopifnot(
  setequal(names(reglas$units), c("percent", "hours", "thousand_persons")),
  "tasa_desocupacion" %in% names(reglas$indicators),
  "comparacion_territorial" %in%
    unname(unlist(reglas$dimension_analyses, use.names = FALSE))
)
message("Pruebas de redundancias y política analítica completadas.")
