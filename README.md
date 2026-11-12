# laboral-data

**[Explorar datos y colecciones](https://miparrar.github.io/laboral-data/)** · [Catálogo JSON](https://miparrar.github.io/laboral-data/api/v1/catalog.json) · [Manifiesto de versiones](https://miparrar.github.io/laboral-data/api/v1/manifest.json)

**laboral-data transforma los tabulados que publica el Instituto Nacional de Estadísticas (INE) para la Encuesta Nacional de Empleo (ENE) en archivos JSON estructurados, validados y accesibles públicamente.**

La descripción de las estadísticas, sus definiciones y los tabulados originales se encuentran en la [página oficial de Ocupación y Desocupación del INE](https://www.ine.gob.cl/estadisticas-por-tema/mercado-laboral/ocupacion-y-desocupacion).

## Cómo funciona

El proyecto descarga los Excel del INE, los procesa con R y normaliza las observaciones y sus notas de calidad. Luego valida los resultados y publica archivos JSON mediante GitHub Pages. Los Excel originales se respaldan en GitHub Releases.

La actualización automática utiliza el [calendario de publicaciones ENE de `laborales`](https://github.com/miparrar/laborales/tree/main/src_data/calendario_ene). También puede ejecutarse manualmente.

## Consumo de datos

- [Catálogo](https://miparrar.github.io/laboral-data/api/v1/catalog.json): conjuntos de datos y variables disponibles.
- [Manifiesto](https://miparrar.github.io/laboral-data/api/v1/manifest.json): versiones, cobertura temporal y archivos.
- [Indicadores principales (JSON)](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json).
- [Indicadores complementarios (JSON)](https://miparrar.github.io/laboral-data/api/v1/series/complementarios.json).
- [Horas trabajadas (JSON)](https://miparrar.github.io/laboral-data/api/v1/series/horas.json).
- [Ocupación por rama de actividad (JSON)](https://miparrar.github.io/laboral-data/api/v1/series/rama.json): total de ocupados y 22 categorías del cuadro (21 actividades y «No sabe / No responde»), por sexo a nivel nacional y por región para ambos sexos. Los registros incorporan `branch` y mantienen el indicador común `ocupados` (en miles). Nota: no sumar `branch=total` a las ramas; `no_sabe_no_responde` no es una actividad económica.
- [Indicadores principales por tramo etario (JSON)](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales_edad.json): 13 indicadores, seis tramos nacionales de 15–24 a 65 años o más. Las observaciones incluyen `age_group` (`15-24`, `25-34`, `35-44`, `45-54`, `55-64` o `65+`), además de `region` y `sex`.

Ejemplo en R:

```r
datos <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json"
)
```

## Ejecución local

```bash
make deps
make update
make test
```
