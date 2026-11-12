# laboral-data

**laboral-data transforma los tabulados de la Encuesta Nacional de Empleo (ENE) del INE en archivos JSON públicos, estructurados y actualizados.** Así facilita su consulta y análisis desde R, Python o modelos de lenguaje.

De este modo buscamos hacer más accesible esta información para contribuir a comprender la situación de los trabajadores en Chile.

Los datos conservan tanto el valor de cada estimación como las notas de calidad estadística publicadas por el INE, que permiten distinguir estimaciones sin advertencia de calidad, poco fiables y no fiables, de acuerdo con el [Estándar para la evaluación de la calidad de las estimaciones en encuestas de hogares](https://www.ine.gob.cl/docs/default-source/institucionalidad/buenas-pr%C3%A1cticas/clasificaciones-y-estandares/est%C3%A1ndar-evaluaci%C3%B3n-de-calidad-de-estimaciones-publicaci%C3%B3n-27022020.pdf).

La metadata se construye a partir de los tabulados originales y sus definiciones. Está pensada para facilitar la exploración de los datos y su integración con sistemas agénticos. Cada observación mantiene, además, la referencia al archivo y la hoja de Excel de la que proviene.

## Datos disponibles

- [Indicadores principales](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json): ocupación, desocupación y participación; nacional por sexo y regiones.
- [Indicadores complementarios](https://miparrar.github.io/laboral-data/api/v1/series/complementarios.json): presión laboral, subutilización y fuerza de trabajo potencial; nacional por sexo y regiones.
- [Horas trabajadas](https://miparrar.github.io/laboral-data/api/v1/series/horas.json): jornadas y promedios de horas habituales y efectivas; nacional por sexo.
- [Ocupación por rama](https://miparrar.github.io/laboral-data/api/v1/series/rama.json): ocupados por actividad económica; nacional por sexo y regiones.
- [Indicadores por edad](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales_edad.json): indicadores principales en seis tramos de edad; total nacional.

Todas las series incluyen trimestre móvil y notas de calidad. Los indicadores repetidos entre tabulados se publican una sola vez por período y cobertura estadística: la tasa de desocupación general, la fuerza de trabajo y los totales de ocupados y desocupados se consultan en **indicadores principales**. El total de ocupados por rama tampoco se duplica: el desglose por actividad permanece en **rama** y el total se obtiene desde principales. Los indicadores por edad se mantienen porque aportan un desglose diferente. `no_sabe_no_responde` no es una actividad económica. Consulta el [catálogo](https://miparrar.github.io/laboral-data/api/v1/catalog.json) para identificar indicadores, unidades, dimensiones y análisis admitidos.

## Metadatos y análisis posibles

El catálogo JSON incluye, para cada indicador, el tipo de medida, los análisis posibles, sus dimensiones y advertencias estadísticas. Estas reglas se mantienen en [`config/analisis.yml`](config/analisis.yml), inspiradas en conceptos de SDMX, sin implementar todo el estándar.

Por ejemplo, una **tasa** admite evolución temporal, comparaciones y diferencias en puntos porcentuales; una **cantidad estimada** admite variaciones absolutas y relativas; y un **promedio de horas** admite diferencias de horas. Las comparaciones por región, sexo, edad o rama sólo se ofrecen cuando existe ese desglose. Son posibilidades analíticas, **no instrucciones para sumar tasas, promediar resultados arbitrariamente ni inferir significación estadística sin el diseño muestral**.

La redundancia se identifica por indicador, unidad, período y todas sus dimensiones. Se conserva una fuente prioritaria y se registra cualquier discrepancia de valores entre tabulados originales. Los Excel no se alteran.

Para revisar solapamientos de las series publicadas:

```bash
make audit
```

La función `laboral_redundancias(datasets)` de [`R/redundancias.R`](R/redundancias.R) permite auditar una lista de tabulados antes de depurarla, y `laboral_resumen_redundancias(datasets)` resume las coincidencias y discrepancias.

## Usar desde R

La consulta sigue cuatro pasos: descubrir las series disponibles, buscar indicadores, revisar su metadata y obtener las observaciones por código exacto.

```r
source("R/cliente_api.R")

# 1. Explorar los tabulados
laboral_catalogo()

# 2. Buscar indicadores
laboral_buscar("desocupación")

# 3. Revisar definición, análisis posibles y fuente
laboral_describir("indicadores_principales/tasa_desocupacion")

# 4. Descargar los datos como tibble
desocupacion <- laboral_obtener(
  "indicadores_principales/tasa_desocupacion",
  desde = "2020-01",
  region = "nacional",
  sexo = "total"
)

# Identificar el tabulado y la hoja de Excel de cada observación
desocupacion |>
  dplyr::select(period, value, quality, source_file, source_sheet, source_url)
```

`laboral_obtener()` admite varios códigos de serie y filtros por período, región, sexo, edad y rama. Los resultados están en formato largo. La función anterior, `laboral_leer()`, se mantiene para consultar un tabulado completo o filtrarlo directamente:

```r
construccion <- laboral_leer("rama", rama = "construccion")
```

El cliente requiere `jsonlite`, `dplyr` y `tibble`, no utiliza credenciales y conserva en memoria los JSON ya descargados durante la sesión. Para volver a consultarlos, utiliza `actualizar = TRUE`.

La interfaz está inspirada en [**`bcchr`**, de Joshua Kunst e Ignacio Rossi](https://github.com/jbkunst/bcchr), especialmente en la separación entre búsqueda, descripción y descarga de series. `laboral-data` es un cliente independiente y no necesita instalar `bcchr`.

### Ejemplos de consulta

**Desocupación de hombres y mujeres desde 2022:**

```r
laboral_obtener(
  "indicadores_principales/tasa_desocupacion",
  desde = "2022-01",
  region = "nacional",
  sexo = c("hombre", "mujer")
) |>
  dplyr::select(period, sex, value, quality)
```

**Desocupación de jóvenes de 15 a 24 años, con la hoja de origen:**

```r
laboral_obtener(
  "indicadores_principales_edad/tasa_desocupacion",
  desde = "2024-01",
  edad = "15-24"
) |>
  dplyr::select(period, age_group, value, source_file, source_sheet)
```

**Ocupación en construcción en dos regiones:**

```r
laboral_obtener(
  "rama/ocupados",
  desde = "2025-01",
  region = c("metropolitana", "biobio"),
  rama = "construccion"
) |>
  dplyr::select(period, region, branch, value)
```

**Consultar dos indicadores en una sola llamada:**

```r
laboral_obtener(
  c(
    "indicadores_principales/tasa_desocupacion",
    "complementarios/su3"
  ),
  desde = "2023-01",
  region = "nacional",
  sexo = "total"
) |>
  dplyr::select(period, series_id, value, unit)
```

Los ejemplos devuelven **tibbles** y mantienen las notas de calidad. Recuerda que `period` identifica el mes central de un trimestre móvil, no un mes independiente.

### Trazabilidad

Cada observación conserva `source_sheet`, el **nombre exacto de la hoja** procesada del Excel original. El JSON de cada tabulado identifica también `source_file` (archivo Excel), `source_url` (enlace oficial del INE) y `source_sha256` (huella del archivo descargado). El cliente R incorpora esos metadatos como columnas, de modo que se puede volver desde una estimación al tabulado y la hoja de origen.

También puedes leer directamente los JSON, sin utilizar el cliente:

```r
respuesta <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json"
)

datos <- tibble::as_tibble(respuesta$observations)
```

## Calendario oficial de publicaciones

El calendario de **Empleo Nacional** del INE se mantiene en este repositorio. Cada año conserva la fecha y hora oficial de publicación, el trimestre móvil y su período correspondiente (mes central).

- [Calendario 2026, fuente YAML](config/calendario_ene/2026.yaml).
- [Calendario 2026 en JSON](https://miparrar.github.io/laboral-data/api/v1/calendario/2026.json).
- [Índice de años disponibles](https://miparrar.github.io/laboral-data/api/v1/calendario/index.json).
- [Calendario oficial del INE](https://www.ine.gob.cl/docs/default-source/prensa-y-comunicacion/calendario/calendario-de-publicaciones.pdf.pdf?sfvrsn=93b45045_58).

Por ejemplo, en R:

```r
publicaciones <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/calendario/2026.json"
)$publicaciones |>
  tibble::as_tibble()

publicaciones |>
  dplyr::select(fecha, hora, trimestre, periodo)
```

El YAML es la **fuente única** para mantener las fechas; el JSON se genera automáticamente a partir de él. `laborales` consume el calendario directamente desde `laboral-data`. La fecha programada no garantiza que un CSV o tabulado ya esté disponible: la descarga debe comprobarlo.

## Cómo funciona

Los archivos Excel originales se descargan desde el [INE](https://www.ine.gob.cl/estadisticas-por-tema/mercado-laboral/ocupacion-y-desocupacion), se procesan y validan con R y se publican mediante GitHub Pages. Se preservan notas de calidad, hashes SHA-256 y versiones de procesamiento. Los Excel se respaldan en GitHub Releases.

La actualización sigue el calendario oficial ENE versionado aquí. Los trimestres móviles son períodos superpuestos, no observaciones mensuales independientes.

## Ejecución local

```bash
make deps
make update
make test
```

**Autores:** [Matías Parra](https://github.com/miparrar) y [Joshua Kunst](https://github.com/jbkunst), K&P. Véase [AUTHORS.md](AUTHORS.md).

**Proyecto independiente; no es un servicio oficial del INE.**
