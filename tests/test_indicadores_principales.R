source("R/indicadores_principales.R")
stopifnot(
  identical(ip_period(c("2010", "2010", "2010"), c("Ene - Mar", "Nov - Ene", "Dic - Feb")),
            c("2010-02", "2010-12", "2011-01")),
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
    !anyDuplicated(data[c("period", "region", "sex", "indicator")])
  )
}
message("Pruebas completadas.")
