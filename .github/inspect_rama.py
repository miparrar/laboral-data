#!/usr/bin/env python3
"""Inspect the exact sheet structure of INE rama.xlsx without external packages."""
import json, posixpath, re, urllib.request, zipfile, xml.etree.ElementTree as ET
from pathlib import Path

url = "https://www.ine.gob.cl/docs/default-source/ocupacion-y-desocupacion/cuadros-estadisticos/series-vigentes/rama.xlsx?sfvrsn=23a76b12_214"
p = Path("/tmp/rama_ine.xlsx")
request = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0","Accept":"*/*"})
with urllib.request.urlopen(request, timeout=120) as response:
    p.write_bytes(response.read())
if not zipfile.is_zipfile(p):
    raise RuntimeError("La fuente INE no devolvió un XLSX válido")
ns={"m":"http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r":"http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
with zipfile.ZipFile(p) as zipf:
    wb=ET.fromstring(zipf.read("xl/workbook.xml"))
    relroot=ET.fromstring(zipf.read("xl/_rels/workbook.xml.rels"))
    rels={x.attrib["Id"]:x.attrib["Target"] for x in relroot}
    strings=[]
    if "xl/sharedStrings.xml" in zipf.namelist():
        ss=ET.fromstring(zipf.read("xl/sharedStrings.xml"))
        for si in ss.findall("m:si",ns):
            strings.append("".join(t.text or "" for t in si.findall(".//m:t",ns)))
    sheets=[]
    for sh in wb.findall("m:sheets/m:sheet",ns):
        name=sh.attrib["name"]
        rid=sh.attrib["{"+ns["r"]+"}id"]
        dest=rels[rid].lstrip("/")
        if not dest.startswith("xl/"): dest=posixpath.normpath("xl/"+dest)
        root=ET.fromstring(zipf.read(dest))
        dim=root.find("m:dimension",ns)
        sheetdata=root.find("m:sheetData",ns)
        samples=[]; nrows=0; first=None; last=None; note_values=set()
        if sheetdata is not None:
            for row in sheetdata:
                idx=int(row.attrib.get("r","0"))
                cells=[]
                for c in row:
                    if not c.tag.endswith("}c"):continue
                    reference=c.attrib.get("r","")
                    match=re.match("[A-Z]+",reference)
                    if not match:continue
                    col=0
                    for ch in match.group():col=col*26+ord(ch)-64
                    v=c.find("m:v",ns); inline=c.find("m:is",ns)
                    value=v.text if v is not None else None
                    if value is not None and c.attrib.get("t")=="s":
                        value=strings[int(value)]
                    elif inline is not None:
                        value="".join(t.text or "" for t in inline.findall(".//m:t",ns))
                    if value is not None and str(value).strip()!="":
                        if col<=85 and idx<=13:cells.append([reference,str(value)[:170]])
                        if 7<=idx<=100 and str(value).strip() in ("a","b","c","d","e","-"):note_values.add(str(value).strip())
                if cells and idx<=13:samples.append({"row":idx,"cells":cells})
                # Count populated rows via underlying XML, not just sampled cells.
                if len(row)>0:nrows+=1;first=idx if first is None else first;last=idx
        sheets.append({"sheet":name,"dimension":dim.attrib.get("ref") if dim is not None else None,
            "num_rows":nrows,"first_row":first,"last_row":last,
            "sample":samples,"special_values":sorted(note_values)})
out=Path("config/rama_inspection.json")
out.write_text(json.dumps({"source_url":url,"file_bytes":p.stat().st_size,"sheets":sheets},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("INSPECT_RAMA",len(sheets),"sheets",out.stat().st_size,"JSON bytes")
