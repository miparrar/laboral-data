#!/usr/bin/env python3
"""One-off inspection of an INE workbook using only Python stdlib."""
import json
import posixpath
import re
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

source = "https://www.ine.gob.cl/docs/default-source/ocupacion-y-desocupacion/cuadros-estadisticos/series-vigentes/indicadores_principales_edad.xlsx?sfvrsn=3fc0d55f_36"
p = Path("/tmp/indicadores_principales_edad.xlsx")
req = urllib.request.Request(source, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"})
with urllib.request.urlopen(req, timeout=120) as response:
    p.write_bytes(response.read())
if not zipfile.is_zipfile(p):
    raise RuntimeError("INE did not return a valid XLSX archive")
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
      "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
      "p": "http://schemas.openxmlformats.org/package/2006/relationships"}
ns = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
with zipfile.ZipFile(p) as z:
    workbook = ET.fromstring(z.read("xl/workbook.xml"))
    relroot = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rels = {r.attrib["Id"]: r.attrib["Target"] for r in relroot}
    strings = []
    if "xl/sharedStrings.xml" in z.namelist():
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.findall("m:si", NS):
            strings.append("".join(t.text or "" for t in si.findall(".//m:t", NS)))
    sheets = []
    for sheet in workbook.findall("m:sheets/m:sheet", NS):
        name = sheet.attrib["name"]
        rid = sheet.attrib["{"+NS["r"]+"}id"]
        target = rels[rid].lstrip("/")
        if not target.startswith("xl/"): target = posixpath.normpath("xl/"+target)
        root = ET.fromstring(z.read(target))
        dimension = root.find("m:dimension", NS)
        sheetData = root.find("m:sheetData", NS)
        sampled = []
        data_rows = []
        for row in sheetData:
            idx = int(row.attrib.get("r", "0"))
            cells = []
            for cell in row:
                if not cell.tag.endswith("}c"): continue
                ref = cell.attrib.get("r", "")
                column = re.match("[A-Z]+", ref)
                if not column: continue
                col = 0
                for char in column.group(): col = col*26+ord(char)-64
                if col>100: continue
                v = cell.find("m:v", NS)
                inline = cell.find("m:is", NS)
                value = v.text if v is not None else None
                if value is not None and cell.attrib.get("t") == "s":
                    value = strings[int(value)]
                elif inline is not None:
                    value = "".join(t.text or "" for t in inline.findall(".//m:t", NS))
                if value is not None and value != "":
                    cells.append([ref, str(value)[:200]])
            if cells:
                data_rows.append(idx)
                if idx<=12:
                    sampled.append({"row":idx, "cells":cells})
        sheets.append({"name":name,"state":sheet.attrib.get("state","visible"),"dimension":dimension.attrib.get("ref") if dimension is not None else None,"nonempty_rows":len(data_rows),"first_row":data_rows[0] if data_rows else None,"last_row":data_rows[-1] if data_rows else None,"top_rows":sampled})
report = {"url":source,"bytes":p.stat().st_size,"sheets":sheets}
out = Path("config/edad_inspection.json")
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print("Inspected",len(sheets),"sheets; wrote",out,"bytes",out.stat().st_size)
