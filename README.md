# laboral-data

**laboral-data transforma los tabulados de la Encuesta Nacional de Empleo (ENE) publicados por el INE en datos JSON estructurados, validados y accesibles públicamente.** Su objetivo es facilitar la consulta de las cifras oficiales sin tener que procesar los archivos Excel en cada uso.

## Cómo funciona

1. **Descarga** los archivos Excel oficiales desde el INE.
2. **Procesa** las hojas de datos con R: la primera hoja es el índice; las columnas A y B contienen año y trimestre móvil; desde la fila 8, cada indicador utiliza un par de columnas (nota de calidad y valor).
3. **Normaliza** las observaciones por período, indicador y dimensiones disponibles (sexo y territorio, cuando corresponde), conservando valores y notas originales: sin advertencia, `a` (poco fiable) y `b` (no fiable). Las magnitudes de población se expresan en miles y las tasas en porcentaje.
4. **Valida y publica** los JSON. GitHub conserva las versiones; GitHub Releases archiva los Excel originales y GitHub Pages distribuye los datos.

La actualización automática consulta el [calendario de publicaciones ENE de `laborales`](https://github.com/miparrar/laborales/tree/main/src_data/calendario_ene). GitHub Actions comprueba diariamente si hay una publicación pendiente y, cuando corresponde, vuelve a descargar y procesar el Excel completo para incorporar también posibles revisiones históricas. Puede ejecutarse manualmente.

## Datos disponibles

Por ahora se publica **Indicadores principales**: total nacional, hombres, mujeres y las 16 regiones (sin desagregación regional por sexo).

Para consumirlos, consulta:

- [Catálogo de indicadores](https://miparrar.github.io/laboral-data/api/v1/catalog.json): variables y cobertura.
- [Manifiesto](https://miparrar.github.io/laboral-data/api/v1/manifest.json): períodos, origen, versión y archivos.
- [Observaciones JSON](https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json): cifras y calidad de cada observación.

En R:

```r
datos <- jsonlite::fromJSON(
  "https://miparrar.github.io/laboral-data/api/v1/series/indicadores_principales.json"
)
```

## Desarrollo

Requiere R y los paquetes declarados en el `Makefile`. Desde la raíz del repositorio:

```bash
make deps
make update
make test
```

Para trabajar con un Excel local:

```bash
Rscript scripts/update_data.R --input="/ruta/indicadores_principales.xlsx"
```

Los archivos descargados durante la ejecución quedan en `data_raw/`, fuera del control de versiones. Los JSON se publican en `api/v1/`.
