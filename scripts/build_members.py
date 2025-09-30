#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère/maintient une page membres/<id>.qmd pour chaque personne du JSON.
- Lit data/members.json
- Scanne les publications (pubs/**/index.qmd) dont 'author-ids' contient l'id
- Écrit une page élégante avec photo, bio, et la liste des publications
"""

import os, json, re, sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]  # scripts/ -> racine projet
DATA = ROOT / "data" / "members.json"
PUBS = ROOT / "pubs"
OUTDIR = ROOT / "membres"

YAML_RE = re.compile(r"^---\s*(.*?)\s*---", re.S | re.M)

def load_yaml_frontmatter(text):
    m = YAML_RE.match(text)
    if not m:
        return {}
    block = m.group(1)
    # parse minimal YAML safely (require PyYAML if dispo)
    try:
        import yaml
        return yaml.safe_load(block) or {}
    except Exception:
        # fallback très simple (author-ids seulement)
        ids = []
        for line in block.splitlines():
            if line.strip().startswith("author-ids:"):
                # author-ids: [a,b,c]
                rest = line.split(":",1)[1]
                ids = [x.strip().strip("[],'\"") for x in rest.split(",") if x.strip()]
        return {"author-ids": ids}

def list_publications_for(author_id):
    """Retourne une liste de dicts: {title, date, url, pdf, image, subtitle}"""
    items = []
    for idx in PUBS.rglob("index.qmd"):
        txt = idx.read_text(encoding="utf-8")
        meta = load_yaml_frontmatter(txt)
        ids = meta.get("author-ids") or []
        # normalise ids (liste de str)
        if isinstance(ids, str):
            ids = [ids]
        ids = [str(x).strip() for x in ids]

        if author_id not in ids:
            continue

        title = str(meta.get("title","")).strip()
        subtitle = str(meta.get("subtitle","")).strip()
        date = str(meta.get("date","")).strip()
        # chemins/urls
        folder = idx.parent  # .../pubs/<slug>/
        slug = folder.name
        url = f"/pubs/{slug}/"  # index.html
        pdf = meta.get("pdf") or f"/files/papers/{slug}.pdf"
        image = meta.get("image") or f"/images/pubs/{slug}.png"

        # date parsing pour tri
        try:
            dsort = datetime.fromisoformat(date)
        except Exception:
            dsort = datetime.min

        items.append({
            "title": title, "subtitle": subtitle, "date": date,
            "url": url, "pdf": pdf, "image": image, "dsort": dsort
        })

    items.sort(key=lambda x: x["dsort"], reverse=True)
    return items

def ensure_outdir():
    OUTDIR.mkdir(parents=True, exist_ok=True)

from html import escape as h
from datetime import datetime

MONTHS_FR = ["janvier","février","mars","avril","mai","juin",
             "juillet","août","septembre","octobre","novembre","décembre"]

def format_date_fr(date_str: str) -> str:
    if not date_str:
        return ""
    try:
        d = datetime.fromisoformat(date_str)
        return f"{d.day} {MONTHS_FR[d.month-1]} {d.year}"
    except Exception:
        return date_str  # fallback si la date n'est pas ISO

from html import escape as h

def render_member_page(m, pubs):
    name  = m.get("name","").strip()
    role  = m.get("role","").strip()
    photo = m.get("photo","").strip()
    bio   = m.get("bio","").strip()
    url   = (m.get("url") or "").strip()
    social = m.get("social") or {}   # ex: {"x":"...", "linkedin":"...", "threads":"...", "email":"mailto:...","facebook":"...","wh":"..."}

    lines = [
        "---",
        f'title: "{name}"',
        "page-layout: full",
        "class: memberpage",
        "---",
        "",
        "<div class='member-hero'>",
    ]
    if photo:
        lines.append(f"<img class='member-hero-photo' src='{photo}' alt='{h(name)}'>")
    lines.append("<div class='member-hero-text'>")
    lines.append(f"<h1 class='member-hero-name'>{h(name)}</h1>")
    if role:
        lines.append(f"<div class='member-hero-role'>{h(role)}</div>")

    # --- Actions (bouton + réseaux) ---
    btns = []
    if url:
        btns.append(f"<a href='{url}'>Page personnelle</a>")

    def add_btn(key, cls, svg):
        link = (social.get(key) or "").strip()
        if link:
            btns.append(f"<a href='{link}' class='btn-icon {cls}' aria-label='{key}'>{svg}</a>")

    # Icônes (mêmes que tes share buttons)
    SVG_X = "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M18.146 3H21l-6.98 7.98L21.5 21h-5.73l-4.17-5.31L6.7 21H3l7.43-8.49L2.5 3h5.77l3.86 5.06L18.146 3z'/></svg>"
    SVG_LI = "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M4.98 3.5C4.98 4.88 3.86 6 2.5 6S0 4.88 0 3.5 1.12 1 2.5 1 4.98 2.12 4.98 3.5zM0 8h5v16H0V8zm7.5 0h4.8v2.2h.07C13.2 8.6 15.1 7.5 17.6 7.5 22.2 7.5 24 10.4 24 15.1V24h-5v-7.6c0-1.8-.03-4.1-2.5-4.1-2.5 0-2.9 2-2.9 4v7.7h-5V8z'/></svg>"
    SVG_EMAIL = "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M22 6H2l10 6 10-6z'/><path d='M12 13L2 6.76V18a2 2 0 002 2h16a2 2 0 002-2V6.76L12 13z'/></svg>"
    SVG_THREADS = "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M12.01 2C6.49 2 2 6.48 2 12s4.49 10 10.01 10C17.52 22 22 17.52 22 12S17.52 2 12.01 2zm5.11 10.18c-.18-1.65-1.01-2.98-2.39-3.86-1.03-.65-2.32-.98-3.82-.98H9.4v2.11h1.21c1.13 0 1.99.16 2.6.5.69.39 1.11.98 1.27 1.77-1.04-.62-2.2-.92-3.5-.92-2.67 0-4.57 1.61-4.57 3.92 0 2.26 1.83 3.82 4.47 3.82 1.6 0 2.9-.47 3.86-1.41.7-.66 1.18-1.52 1.42-2.57l.04-.18c.05-.19.09-.39.12-.6.07-.41.11-.83.11-1.27v-.33zm-3.99 2.92c-.54.51-1.28.77-2.23.77-1.41 0-2.31-.76-2.31-1.99 0-1.22.92-2.02 2.31-2.02 1.71 0 2.79.88 3.2 2.35-.22.38-.51.7-.97.89z'/></svg>"
    SVG_FB = "<svg width='18' height='18' viewBox='0 0 24 24' fill='currentColor'><path d='M22 12.06C22 6.49 17.52 2 11.94 2S2 6.49 2 12.06c0 4.99 3.66 9.13 8.44 9.94v-7.03H7.9v-2.9h2.54V9.41c0-2.5 1.49-3.88 3.77-3.88 1.09 0 2.23.2 2.23.2v2.45h-1.25c-1.23 0-1.61.76-1.61 1.54v1.85h2.74l-.44 2.9h-2.3V22c4.78-.81 8.44-4.95 8.44-9.94z'/></svg>"
    SVG_WH = "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M20.52 3.48A11.76 11.76 0 0012 0C5.37 0 0 5.37 0 12c0 2.12.55 4.12 1.6 5.92L0 24l6.2-1.61A12 12 0 0012 24c6.63 0 12-5.37 12-12 0-3.2-1.25-6.21-3.48-8.52zM12 21.82a9.77 9.77 0 01-5-1.38l-.36-.21-3.68.95.98-3.58-.23-.37A9.82 9.82 0 012.18 12c0-5.4 4.4-9.82 9.82-9.82 2.62 0 5.08 1.02 6.93 2.87a9.78 9.78 0 012.87 6.95c0 5.42-4.42 9.82-9.82 9.82zm5.6-7.32c-.3-.15-1.76-.87-2.03-.97s-.47-.15-.67.15c-.2.3-.77.97-.95 1.17-.17.2-.35.23-.65.08-.3-.15-1.27-.47-2.42-1.5-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.38-.02-.53-.08-.15-.67-1.6-.92-2.19-.24-.58-.49-.5-.67-.51l-.57-.01c-.2 0-.53.08-.8.38s-1.05 1.03-1.05 2.5 1.08 2.9 1.23 3.1c.15.2 2.14 3.3 5.19 4.63.73.32 1.3.5 1.74.64.73.23 1.4.2 1.93.12.59-.09 1.76-.72 2.01-1.41.25-.69.25-1.28.17-1.41-.08-.13-.3-.2-.61-.35z'/></svg>"

    add_btn("x",        "btn-x",        SVG_X)
    add_btn("linkedin", "btn-linkedin", SVG_LI)
    add_btn("threads",  "btn-threads",  SVG_THREADS)
    add_btn("facebook", "btn-facebook", SVG_FB)
    add_btn("wh",       "btn-wh",       SVG_WH)
    add_btn("email",    "btn-email",    SVG_EMAIL)


    if btns:
        lines.append("<div class='member-hero-actions'>")
        # le premier bouton (page perso) puis le groupe RS
        if url:
            lines.append(btns[0])  # Page personnelle
            rest = btns[1:]
        else:
            rest = btns
        if rest:
            lines.append("<div class='socials'>" + "".join(rest) + "</div>")
        lines.append("</div>")

    if bio:
        lines.append(f"<p class='member-hero-bio'>{h(bio)}</p>")
    lines.append("</div></div>")  # /member-hero-text + /member-hero

    # ===== Publications =====
    if pubs:
        lines.append("")
        lines.append("## Publications")
        lines.append('<div class="member-pubs">')
        for p in pubs:
            title = p.get("title","")
            subtitle = p.get("subtitle","")
            date = p.get("date","")
            purl = p.get("url","")
            pdf  = p.get("pdf","")
            image= p.get("image","")

            html_block = f"""
<div class="member-pub">
  <a class="thumb" href="{purl}"><img src="{image}" alt=""></a>
  <div class="meta">
    <h3 class="t"><a href="{purl}">{h(title)}</a></h3>
    {f"<div class='s'>{h(subtitle)}</div>" if subtitle else ""}
    {f"<div class='d'>{h(format_date_fr(date))}</div>" if date else ""}
    <div class="links">
      {f"<a class='btn-pdf' href='{pdf}'>PDF</a>" if pdf else ""}
    </div>
  </div>
</div>
""".strip()
            lines.extend(["```{=html}", html_block, "```"])
        lines.append("</div>")  # /member-pubs

    return "\n".join(lines) + "\n"


def main():
    if not DATA.exists():
        print(f"[build_members] ERREUR: {DATA} introuvable", file=sys.stderr)
        return
    members = json.loads(DATA.read_text(encoding="utf-8")).get("members", [])
    ensure_outdir()
    n = 0
    for m in members:
        mid = m.get("id")
        if not mid:
            continue
        pubs = list_publications_for(mid)
        out = OUTDIR / f"{mid}.qmd"
        out.write_text(render_member_page(m, pubs), encoding="utf-8")
        n += 1
    print(f"[build_members] Pages membres générées: {n}")

if __name__ == "__main__":
    main()
