# laboral-data

Datos tabulados de la **Encuesta Nacional de Empleo (ENE)** de Chile, preparados para consumo por aplicaciones como [laborales](https://github.com/miparrar/laborales).

Este repositorio implementa una primera familia: **Indicadores principales de empleo**. No descarga ni estima microdatos; publica las cifras que el INE ya difundió, preservando sus notas de calidad por observación.

## Arquitectura

```text
INE (Excel) → descarga → normalización R → validación → JSON → GitHub Pages
                    ↘ original XLSX → GitHub Release
```

- **GitHub Actions** ejecuta la actualización programada y manual.
- **Git (main)** conserva los JSON, el catálogo y el manifiesto, con historial de cambios.
- **GitHub Releases** conserva el Excel original de cada versión **distinta** descargada (identificada por hash).
- **GitHub Pages** distribuye una API estática con el contenido de `api/v1/` (requiere activar Pages con fuente GitHub Actions en Settings → Pages).
- El procesamiento se puede repetir localmente con **GNU Make y R**.

## Primer tabulado

Fuente: [indicadores_principales.xlsx](https://www.ine.gob.cl/docs/default-source/ocupacion-y-desocupacion/cuadros-estadisticos/series-vigentes/indicadores_principales.xlsx).

El parser de tabulados utiliza un patrón común: primera hoja como índice; fila 6 con nombres; fila 7 con unidades y notas; datos desde fila 8; cada variable ocupa dos columnas consecutivas (nota y valor). El número de pares se detecta desde las columnas, y se contrasta con la configuración declarada. Un formato desconocido falla antes de publicar.\n\nEl libro tiene un índice, tres hojas nacionales (`AS`, `H`, `M`) y 16 hojas regionales. Las regionales **no están desagregadas por sexo**. Cada estimación tiene su columna de nota y su columna de valor.

### Contrato de datos

- `api/v1/catalog.json`: metadatos e indicadores, cobertura **real** por combinación territorio/sexo.
- `api/v1/manifest.json`: archivo publicado, SHA-256 del Excel, período de cobertura y cantidad de observaciones.
- `api/v1/series/indicadores_principales.json`: observaciones normalizadas, con `period` (mes central del trimestre móvil), `region`, `sex`, `indicator`, `value`, `unit`, `quality_code` y `quality`.

Las magnitudes de población se mantienen **en miles de personas** y las tasas **en porcentaje** según la unidad explícita de la hoja; no todas las variables son miles. No se redondean valores.

Calidad:
- Nota vacía → `quality_code: null`, `quality: sin_advertencia` (no implica inferencia sobre precisión).
- `a` → `poco_fiable`.
- `b` → `no_fiable`.

No se eliminan observaciones marcadas como no fiables. Una nota desconocida hace fallar la validación, en lugar de inventar una interpretación.

**Advertencia metodológica:** las series de trimestres móviles solapados no son independientes. La existencia de dos estimaciones no permite afirmar significación estadística de su diferencia.

## Requisitos

R con `readxl`, `dplyr`, `tidyr`, `purrr`, `stringr`, `tibble`, `jsonlite`, `yaml` y `digest`. Se usa `renv` opcionalmente; el flujo CI instala dependencias de forma explícita.

```bash
make deps
make update
make test
```

Para probar usando un archivo local ya descargado:

```bash
Rscript scripts/update_data.R --input="/ruta/indicadores_principales.xlsx"
```

Los Excel descargados quedan en `data_raw/` (ignorado por Git). El pipeline en CI crea una Release adjuntando la fuente original **solo después** de validar la generación del JSON.

## Actualización

El workflow se ejecuta diariamente como comprobación y también admite `workflow_dispatch`. Solo registra un commit y una nueva Release cuando cambia el SHA-256 del Excel. Como el INE reemplaza el Excel en la misma URL, **cada cambio obliga a reprocesar la historia completa**, incluidos períodos históricos revisados.

Las publicaciones en Pages pueden requerir habilitar el entorno `github-pages` en la configuración del repositorio. La programación puede retrasarse: una comprobación diaria con idempotencia evita depender de una ejecución en el minuto preciso.

## Extensión a otros cuadros

Agregar otros tabulados requiere un adaptador de formato, un registro de fuente y pruebas de equivalencia frente al Excel. No asumir que todos los Excel del INE comparten encabezados, unidades o clasificaciones.
