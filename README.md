# laboral-data

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
