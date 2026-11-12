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

**Sin instalar nada adicional al lector JSON:**

```r
datos <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json"
)$observations |>
  tibble::as_tibble()
```

**Con el cliente incluido** (desde una copia local del repositorio):

```r
source("R/cliente_api.R")

laboral_catalogo() # Series disponibles

desocupacion <- laboral_leer(
  "indicadores_principales",
  indicador = "tasa_desocupacion",
  region = "nacional",
  sexo = "total"
)

construccion <- laboral_leer(
  "rama",
  rama = "construccion",
  region = "nacional"
)
```

`laboral_leer()` devuelve un **tibble**. Permite filtrar por `indicador`, `region`, `sexo`, `edad` y `rama` (según la serie). Guarda el JSON descargado en memoria durante la sesión; usa `actualizar = TRUE` para volver a consultarlo. Requiere `jsonlite`, `dplyr` y `tibble`.

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
