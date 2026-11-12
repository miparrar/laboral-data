# laboral-data

**Datos abiertos de la Encuesta Nacional de Empleo (ENE) de Chile.** Tabulados del Instituto Nacional de Estadísticas (INE) convertidos a JSON estructurado, validado y actualizado automáticamente.

## ¿Por qué laboral-data?

La idea es sencilla: facilitar el acceso a las estadísticas de la ENE para trabajar con ellas desde distintos entornos. En lugar de descargar los Excel del INE y procesarlos cada vez, las series quedan disponibles en archivos JSON que se pueden consultar directamente desde R, Python u otras herramientas.

Hay una segunda razón: facilitar su uso con modelos de lenguaje y sistemas agénticos. Elegí JSON porque es un formato estándar, con una estructura bien definida y ampliamente utilizado para intercambiar información entre aplicaciones. YAML puede ser más cómodo de leer y escribir para una persona; JSON, en cambio, resulta práctico para integrarlo con APIs y herramientas que trabajan con datos estructurados.

No se trata de producir nuevas estadísticas, sino de hacer más accesibles las que ya publica el INE, manteniendo la referencia a sus fuentes y las notas de calidad.

## Datos disponibles

- [Indicadores principales](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json): ocupación, desocupación y participación; nacional por sexo y regiones.
- [Indicadores complementarios](https://miparrar.github.io/laboral-data/api/v1/series/complementarios.json): presión laboral, subutilización y fuerza de trabajo potencial; nacional por sexo y regiones.
- [Horas trabajadas](https://miparrar.github.io/laboral-data/api/v1/series/horas.json): jornadas y promedios de horas habituales y efectivas; nacional por sexo.
- [Ocupación por rama](https://miparrar.github.io/laboral-data/api/v1/series/rama.json): ocupados por actividad económica; nacional por sexo y regiones.
- [Indicadores por edad](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales_edad.json): indicadores principales en seis tramos de edad; total nacional.

Todas las series incluyen trimestre móvil y notas de calidad. En la serie por rama, `branch = "total"` **no se suma** a las actividades; `no_sabe_no_responde` no es una actividad económica. Consulta el [catálogo](https://miparrar.github.io/laboral-data/api/v1/catalog.json) para identificar indicadores, unidades y dimensiones.

## Usar desde R

La consulta sigue cuatro pasos: descubrir las series disponibles, buscar indicadores, revisar su metadata y obtener las observaciones por código exacto.

```r
source("R/cliente_api.R")

# 1. Explorar los tabulados
laboral_catalogo()

# 2. Buscar indicadores
laboral_buscar("desocupación")

# 3. Revisar la definición y la fuente
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

**Proyecto independiente; no es un servicio oficial del INE.**
