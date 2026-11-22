"""Build the conceptual PS08 deck by editing native OOXML from the existing deck.

The supplied Artifact Tool runtime is not available in this Windows workspace.
This editor retains the PowerPoint master, theme, and slide size, uses native
text, tables, and editable queue connectors, and adds Thai presenter notes.
Run render_algorithm_slides.ps1 to render and export the candidate in PowerPoint.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED

from defusedxml import minidom

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / ".build_algorithm"
SOURCE = ROOT / "slides" / "PS08.pptx"
CONTENT = Path(__file__).with_name("algorithm_deck_content.json")
PPTX_SKILL = Path(r"C:\Users\kiati\.agents\skills\synced\9d4dce00-02ff-4a77-b827-10ee03225793_c29649b0-4ea4-4b77-9a05-3ea49f2cbe5a\pptx")
EMU = 914400
NS = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
ACCENT = "C0392B"
INK = "202020"
GRAY = "737373"
BLUE = "5B9BD5"


def ix(v):
    return str(round(v * EMU))


def font(text, code=False):
    if re.search(r"[\u0e00-\u0e7f]", text):
        return "Leelawadee UI"
    return "Courier New" if code else "Calibri"


def paragraph(text, size=21, color=INK, bold=False, align="l", bullet=False,
              code=False, after=0, family=None):
    family = family or font(text, code)
    indent = ' marL="228600" indent="-171450"' if bullet else ''
    bu = '<a:buChar char="•"/>' if bullet else '<a:buNone/>'
    ppr = (f'<a:pPr algn="{align}"{indent}><a:lnSpc><a:spcPct val="110000"/>'
           f'</a:lnSpc><a:spcAft><a:spcPts val="{int(after * 100)}"/></a:spcAft>{bu}</a:pPr>')
    rpr = (f'<a:rPr lang="{"th-TH" if family == "Leelawadee UI" else "en-US"}" '
           f'sz="{int(size * 100)}" b="{int(bold)}" dirty="0">'
           f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill>'
           f'<a:latin typeface="{family}"/><a:ea typeface="{family}"/>'
           f'<a:cs typeface="{family}"/></a:rPr>')
    return f'<a:p>{ppr}<a:r>{rpr}<a:t xml:space="preserve">{escape(text)}</a:t></a:r><a:endParaRPr lang="en-US" sz="{int(size*100)}"/></a:p>'


class Canvas:
    def __init__(self):
        self.parts = []
        self.shape_id = 2

    def next_id(self):
        value = self.shape_id
        self.shape_id += 1
        return value

    def text(self, text, x, y, w, h, size=21, color=INK, bold=False, align="l",
             fill=None, code=False, bullets=False, family=None, name="Text", margin=.035):
        sid = self.next_id()
        lines = text if isinstance(text, list) else text.split("\n")
        paras = ''.join(paragraph(t, size, color, bold, align, bullets, code,
                                 after=11 if bullets else 0, family=family) for t in lines)
        fillxml = f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else '<a:noFill/>'
        self.parts.append(f'''<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="{escape(name)}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
          <p:spPr><a:xfrm><a:off x="{ix(x)}" y="{ix(y)}"/><a:ext cx="{ix(w)}" cy="{ix(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{fillxml}<a:ln><a:noFill/></a:ln></p:spPr>
          <p:txBody><a:bodyPr wrap="square" lIns="{ix(margin)}" rIns="{ix(margin)}" tIns="{ix(margin)}" bIns="{ix(margin)}" anchor="t"><a:noAutofit/></a:bodyPr><a:lstStyle/>{paras}</p:txBody></p:sp>''')

    def box(self, title, subtitle, x, y, w, h):
        sid = self.next_id()
        paras = paragraph(title, 22, bold=True, align="ctr", after=5)+paragraph(subtitle,18,align="ctr")
        self.parts.append(f'''<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="Queue node {escape(title)}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="{ix(x)}" y="{ix(y)}"/><a:ext cx="{ix(w)}" cy="{ix(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="F5F5F5"/></a:solidFill><a:ln w="12700"><a:solidFill><a:srgbClr val="A0A0A0"/></a:solidFill></a:ln></p:spPr><p:txBody><a:bodyPr lIns="68580" rIns="68580" tIns="91440" bIns="68580" anchor="ctr"><a:noAutofit/></a:bodyPr><a:lstStyle/>{paras}</p:txBody></p:sp>''')

    def connector(self, x, y, w):
        sid = self.next_id()
        self.parts.append(f'''<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="{sid}" name="Successor link"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x="{ix(x)}" y="{ix(y)}"/><a:ext cx="{ix(w)}" cy="0"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="19050"><a:solidFill><a:srgbClr val="{GRAY}"/></a:solidFill><a:headEnd type="none"/><a:tailEnd type="triangle"/></a:ln></p:spPr><p:style><a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="0"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style></p:cxnSp>''')

    def table(self, headers, rows, widths, y=1.48, row_h=None, size=20,
              header_h=.50, header_size=18):
        sid = self.next_id()
        if row_h is None:
            row_h = {3:1.42,4:1.08,5:.86,6:.73}.get(len(rows),.73)
        h = header_h + row_h * len(rows)
        trs=[]
        for ri,row in enumerate([headers]+rows):
            cells=[]
            for ci,value in enumerate(row):
                header = ri == 0
                fill = BLUE if header else ('F3F5F7' if ri % 2 else 'FFFFFF')
                paras=''.join(paragraph(t,header_size if header else size,
                                       'FFFFFF' if header else INK,bold=header)
                              for t in str(value).split('\n'))
                border=''.join(f'<a:ln{side} w="6350"><a:solidFill><a:srgbClr val="D9DDE1"/></a:solidFill><a:prstDash val="solid"/></a:ln{side}>' for side in ['L','R','T','B'])
                cells.append(f'<a:tc><a:txBody><a:bodyPr wrap="square" lIns="91440" rIns="91440" tIns="91440" bIns="68580" anchor="ctr"><a:noAutofit/></a:bodyPr><a:lstStyle/>{paras}</a:txBody><a:tcPr marL="91440" marR="91440" marT="91440" marB="68580" anchor="ctr">{border}<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill></a:tcPr></a:tc>')
            trs.append(f'<a:tr h="{ix(header_h if ri==0 else row_h)}">'+''.join(cells)+'</a:tr>')
        grid=''.join(f'<a:gridCol w="{ix(v)}"/>' for v in widths)
        self.parts.append(f'''<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="{sid}" name="Editable analysis table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="{ix(.6)}" y="{ix(y)}"/><a:ext cx="{ix(sum(widths))}" cy="{ix(h)}"/></p:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblPr firstRow="1" bandRow="0"><a:tableStyleId>{{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}}</a:tableStyleId></a:tblPr><a:tblGrid>{grid}</a:tblGrid>{''.join(trs)}</a:tbl></a:graphicData></a:graphic></p:graphicFrame>''')


def fragment(doc, xml):
    holder=minidom.parseString(f'<root {NS}>{xml}</root>')
    return [doc.importNode(n, True) for n in holder.documentElement.childNodes if n.nodeType == n.ELEMENT_NODE]


def write_doc(path, doc):
    path.write_bytes(doc.toxml(encoding='UTF-8'))


def build_slide(data, slide, number):
    c=Canvas()
    member=data['members'][slide['owner']]
    layout=slide['layout']
    if layout == 'cover':
        c.text(slide['title'],1.0,2.1,11.33,1.4,44,align='ctr',family='Calibri Light',name='Title')
        c.text(slide['subtitle'],1.0,3.75,11.33,.55,24,align='ctr')
        c.text(slide['description'],1.0,4.47,11.33,.95,21,align='ctr')
    elif layout == 'section':
        c.text(slide['title'],.85,2.18,11.7,1.1,40,family='Calibri Light',name='Title')
        pair=slide['pair']
        pair_names='\n'.join(data['members'][i]['name']+'  '+data['members'][i]['id'] for i in pair)
        c.text(pair_names,.85,3.43,11.7,1.0,21,color=GRAY)
        c.text(slide['subtitle'],.85,4.7,11.7,.85,23)
    else:
        c.text(slide['title'],.6,.37,12.13,.82,32,family='Calibri Light',name='Title')
        if layout == 'roles':
            rows=[[m['id'],m['name'],m['role'],m['pages']] for m in data['members']]
            c.table(['Student ID','Presenter','Responsibility','Slides'],rows,[2.0,2.75,5.65,1.73],row_h=.75,size=18)
        elif layout in ['table','cases']:
            c.table(slide['headers'],slide['rows'],slide['widths'],size=20)
        elif layout == 'comparison':
            c.table(slide['headers'],slide['rows'],slide['widths'],
                    y=1.31,row_h=1.60,size=15.5,header_h=.65,header_size=15.5)
        elif layout == 'code':
            c.text(slide['bullets'],.65,1.55,5.05,4.9,22,bullets=True)
            c.text(slide['code'],6.0,1.46,6.68,4.75,20,fill='F5F5F5',code=True,margin=.14,name='Algorithm pseudocode')
        elif layout == 'columns':
            for i,col in enumerate(slide['columns']):
                x=.65+i*6.25
                c.text(col['title'],x,1.55,5.75,.74,24,bold=True)
                c.text(col['bullets'],x,2.45,5.65,3.9,22,bullets=True)
        elif layout == 'queue_code':
            for i,(t,sub) in enumerate(slide['nodes']):
                c.box(t,sub,.75+i*4.15,1.46,3.5,.94)
                if i<2:c.connector(4.3+i*4.15,1.93,.53)
            c.text('tail points to T2',9.05,2.5,3.5,.38,17,color=GRAY,align='ctr')
            c.text(slide['code'],.75,3.0,6.45,3.18,18,fill='F5F5F5',code=True,margin=.10,name='MCS acquisition pseudocode')
            c.text(slide['bullets'],7.65,3.05,5.0,3.18,21,bullets=True)
        elif layout == 'references':
            for i,(author,title,key) in enumerate(slide['refs']):
                y=1.4+i*.82
                c.text(author+': '+title,.67,y,12.0,.44,18,bold=False)
                url=data['sources'][key]
                if key=='assignment':url='PS08 assignment slides; Lecture 8: Locks Mechanism'
                c.text(url,.67,y+.43,12.0,.27,13,color=GRAY)
        if slide.get('takeaway'):
            if layout == 'comparison':
                c.text(slide['takeaway'],.65,6.86,12.0,.24,12,color=ACCENT,name='Key explanation')
            else:
                c.text(slide['takeaway'],.65,6.52,12.0,.53,18,color=ACCENT,name='Key explanation')
    c.text(member['name']+'  '+member['id'],.65,7.13,10.8,.22,11,color=GRAY,name='Presenter')
    c.text(str(number),12.0,7.1,.65,.26,12,color=GRAY,align='r',name='Slide number')
    return c.parts


def set_notes(package, data, slide, number):
    note_path=package/'ppt'/'notesSlides'/f'notesSlide{number}.xml'
    doc=minidom.parseString(note_path.read_bytes())
    body=None
    for sp in doc.getElementsByTagName('p:sp'):
        ph=sp.getElementsByTagName('p:ph')
        if ph and ph[0].getAttribute('type')=='body':body=sp.getElementsByTagName('p:txBody')[0];break
    if body is None:raise RuntimeError(f'No notes body in slide {number}')
    for n in list(body.childNodes):body.removeChild(n)
    member=data['members'][slide['owner']]
    text=[f"Presenter: {member['name']} ({member['id']})",'บทพูดภาษาไทย',slide['notes'],'Sources']
    text += [data['sources'][k] for k in slide['sources']]
    xml='<a:bodyPr/><a:lstStyle/>'+''.join(paragraph(t,14) for t in text)
    for n in fragment(doc,xml):body.appendChild(n)
    write_doc(note_path,doc)


def write_guide(data):
    guide=ROOT/'analysis'/'presenter-guide.md'
    guide.parent.mkdir(exist_ok=True)
    lines=['# PS08: หน้าที่และบทพูด','', f'สไลด์ {len(data["slides"])} หน้า แบ่งสองคนต่ออัลกอริทึม เวลาพูดรวมประมาณ 12–15 นาที ปรับตามความยาวคลิปที่ต้องส่งได้','',
           '| ผู้บรรยาย | ส่วนรับผิดชอบ | หน้า | หน้าที่ |','| --- | --- | --- | --- |']
    for m in data['members']:lines.append(f"| {m['name']} ({m['id']}) | {m['role']} | {m['pages']} | {m['duty']} |")
    lines+=['','คู่ผู้บรรยาย: Peterson = Tithinan + Siriwan; LL/SC = Kiatisak + Worawut; MCS = Thanaboon + Chanon','',
            'หน้าสุดท้ายเป็นตารางเปรียบเทียบภาษาอังกฤษ 7 คอลัมน์: Algorithm, Mechanism, Correctness/Progress, Fairness, Low Contention, High Contention และ Worst Case/Limitations หน้าอ้างอิงอยู่ก่อนหน้า เนื้อหาและตารางใน PowerPoint แก้ไขได้','']
    for i,s in enumerate(data['slides'],1):
        m=data['members'][s['owner']]
        lines += [f"## หน้า {i}: {s['title']}",'',f"ผู้บรรยาย: {m['name']}",'',s['notes'],'','แหล่งอ้างอิง:']
        lines += ['- '+data['sources'][k] for k in s['sources']]
        lines.append('')
    guide.write_text('\n'.join(lines)+'\n',encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=BUILD/'candidate.pptx')
    args=parser.parse_args()
    candidate=args.output.resolve()
    if not candidate.is_relative_to(BUILD.resolve()):
        raise RuntimeError('Candidate output must stay inside .build_algorithm')
    data=json.loads(CONTENT.read_text(encoding='utf-8'))
    assert len(data['slides'])==19
    assert data['slides'][-1]['title']=='Comparison: Advantages and Limitations'
    assert data['slides'][-2]['layout']=='references'
    BUILD.mkdir(exist_ok=True)
    package=Path(tempfile.mkdtemp(prefix='package-',dir=BUILD)).resolve()
    if not package.is_relative_to(BUILD.resolve()):raise RuntimeError('Unexpected build path')
    with ZipFile(SOURCE) as z:
        for info in z.infolist():
            target=(package/info.filename).resolve()
            if not target.is_relative_to(package):raise RuntimeError('Unsafe archive member')
            if info.is_dir():target.mkdir(parents=True,exist_ok=True);continue
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(z.read(info))
    pres_path=package/'ppt'/'presentation.xml'
    pres=minidom.parseString(pres_path.read_bytes())
    ids=pres.getElementsByTagName('p:sldIdLst')[0]
    slides=[n for n in ids.childNodes if n.nodeType==n.ELEMENT_NODE]
    for n in slides[len(data['slides']):]:ids.removeChild(n)
    write_doc(pres_path,pres)
    rel_path=package/'ppt'/'_rels'/'presentation.xml.rels'
    rels=minidom.parseString(rel_path.read_bytes())
    active={n.getAttribute('r:id') for n in slides[:len(data['slides'])]}
    for n in list(rels.documentElement.childNodes):
        if n.nodeType==n.ELEMENT_NODE and n.getAttribute('Type').endswith('/slide') and n.getAttribute('Id') not in active:
            rels.documentElement.removeChild(n)
    write_doc(rel_path,rels)
    for number,slide in enumerate(data['slides'],1):
        path=package/'ppt'/'slides'/f'slide{number}.xml'
        doc=minidom.parseString(path.read_bytes())
        tree=doc.getElementsByTagName('p:spTree')[0]
        for n in list(tree.childNodes):
            if n.nodeType==n.ELEMENT_NODE and n.tagName not in ['p:nvGrpSpPr','p:grpSpPr']:tree.removeChild(n)
        for part in build_slide(data,slide,number):
            for n in fragment(doc,part):tree.appendChild(n)
        write_doc(path,doc)
        sr_path=package/'ppt'/'slides'/'_rels'/f'slide{number}.xml.rels'
        sr=minidom.parseString(sr_path.read_bytes())
        for n in list(sr.documentElement.childNodes):
            if n.nodeType==n.ELEMENT_NODE and not any(n.getAttribute('Type').endswith('/'+typ) for typ in ['slideLayout','notesSlide']):
                sr.documentElement.removeChild(n)
        write_doc(sr_path,sr)
        set_notes(package,data,slide,number)
    # The skill helper removes only package parts no longer reachable after edits.
    subprocess.run([sys.executable,str(PPTX_SKILL/'scripts'/'clean.py'),str(package)],check=True,capture_output=True,text=True)
    # Reconcile declarations after pruning; namespace-sensitive helper cleanup
    # can otherwise retain overrides for removed slides, notes, and charts.
    types_path=package/'[Content_Types].xml'
    types=minidom.parseString(types_path.read_bytes())
    for n in list(types.documentElement.childNodes):
        if n.nodeType==n.ELEMENT_NODE and n.localName=='Override':
            part=n.getAttribute('PartName').lstrip('/')
            if not (package/part).is_file():types.documentElement.removeChild(n)
    write_doc(types_path,types)
    with ZipFile(candidate,'w',ZIP_DEFLATED) as z:
        for p in sorted(package.rglob('*')):
            if p.is_file():z.write(p,p.relative_to(package).as_posix())
    write_guide(data)
    print(f'Built {len(data["slides"])} slides: {candidate}')
    print('Guide: '+str(ROOT/'analysis'/'presenter-guide.md'))


if __name__=='__main__':main()
