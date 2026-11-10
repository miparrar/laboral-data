#!/usr/bin/env python3
"""Inspección reproducible del libro ENE complementarios, sin publicar estimaciones."""
import json, pathlib, urllib.request
from openpyxl import load_workbook

url = "https://www.ine.gob.cl/docs/default-source/ocupacion-y-desocupacion/cuadros-estadisticos/series-vigentes/complementarios.xlsx?sfvrsn=513dfbba_203"
path = pathlib.Path("/tmp/ene_complementarios.xlsx")
urllib.request.urlretrieve(url, path)
book = load_workbook(path, read_only=True, data_only=True)
report = {"source_url": url, "worksheets": []}
for sheet in book:
    sample = []
    for row in sheet.iter_rows(min_row=1, max_row=min(sheet.max_row, 16), values_only=True):
        cells = [{"col": i+1, "value": str(v)[:130]} for i,v in enumerate(row) if v is not None]
        sample.append(cells[:35])
    tail = []
    for row in sheet.iter_rows(min_row=max(1,sheet.max_row-5), max_row=sheet.max_row, values_only=True):
        tail.append([str(v)[:60] for v in row[:5]])
    report["worksheets"].append({"sheet": sheet.title, "rows": sheet.max_row, "cols": sheet.max_column, "top": sample, "tail": tail})
pathlib.Path("config/complementarios_inspeccion.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print("Inspección guardada para",len(report["worksheets"]),"hojas")
