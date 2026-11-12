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

### Trazabilidad

Cada observación conserva `source_sheet`, el **nombre exacto de la hoja** procesada del Excel original. El JSON de cada tabulado identifica también `source_file` (archivo Excel), `source_url` (enlace oficial del INE) y `source_sha256` (huella del archivo descargado). El cliente R incorpora esos metadatos como columnas, de modo que se puede volver desde una estimación al tabulado y la hoja de origen.

También puedes leer directamente los JSON, sin utilizar el cliente:

```r
respuesta <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json"
)

datos <- tibble::as_tibble(respuesta$observations)
```

## Cómo funciona

Los archivos Excel originales se descargan desde el [INE](https://www.ine.gob.cl/estadisticas-por-tema/mercado-laboral/ocupacion-y-desocupacion), se procesan y validan con R y se publican mediante GitHub Pages. Se preservan notas de calidad, hashes SHA-256 y versiones de procesamiento. Los Excel se respaldan en GitHub Releases.

La actualización sigue el [calendario ENE de `laborales`](https://github.com/miparrar/laborales/tree/main/src_data/calendario_ene). Los trimestres móviles son períodos superpuestos, no observaciones mensuales independientes.

## Ejecución local

```bash
make deps
make update
make test
```

**Proyecto independiente; no es un servicio oficial del INE.**
