#!/usr/bin/env python3
import os, io, sys
from datetime import datetime

ROOT = os.getcwd()
PUBS_DIR = os.path.join(ROOT, "pubs")
OUT_MD   = os.path.join(ROOT, "_includes", "feature.md")

def read_front_matter(qmd_path):
    """
    Lit un front matter très simple (clé: valeur) entre --- ... ---.
    Ne dépend pas de PyYAML.
    Retourne dict (title, date... si présents).
    """
    fm = {}
    try:
        with io.open(qmd_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        if not lines or not lines[0].strip().startswith("---"):
            return fm
        i = 1
        while i < len(lines) and not lines[i].strip().startswith("---"):
            line = lines[i].strip()
            # clés simples `key: value`
            if ":" in line and not line.startswith("#"):
                key, val = line.split(":", 1)
                fm[key.strip()] = val.strip().strip('"').strip("'")
            i += 1
        return fm
    except Exception:
        return fm

def parse_date(s):
    """
    Accepte surtout YYYY-MM-DD. Si absent/échec, renvoie None.
    """
    if not s:
        return None
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None

def read_metadata(meta_path):
    """
    Lit _metadata.yml minimal (lignes `key: "value"`).
    Retourne dict avec au moins 'pdf' et 'image' si présents.
    """
    out = {}
    if not os.path.exists(meta_path):
        return out
    with io.open(meta_path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or ":" not in line:
                continue
            key, val = line.split(":", 1)
            out[key.strip()] = val.strip().strip('"').strip("'")
    return out

def candidate_from_dir(dirpath):
    slug = os.path.basename(dirpath)
    qmd  = os.path.join(dirpath, "index.qmd")
    if not os.path.exists(qmd):
        return None

    fm   = read_front_matter(qmd)
    title = fm.get("title") or slug.replace("-", " ").title()
    d     = parse_date(fm.get("date"))

    # fallback date = mtime du fichier si pas de date
    if d is None:
        try:
            d = datetime.fromtimestamp(os.path.getmtime(qmd))
        except Exception:
            d = datetime(1970,1,1)

    meta = read_metadata(os.path.join(dirpath, "_metadata.yml"))
    pdf  = meta.get("pdf", f"/files/papers/{slug}.pdf")

    url  = f"/pubs/{slug}/"

    return {
        "slug": slug,
        "title": title,
        "date": d,
        "date_str": d.strftime("%Y-%m-%d"),
        "pdf": pdf,
        "url": url,
    }

def pick_latest(cands):
    if not cands:
        return None
    return sorted(cands, key=lambda c: c["date"], reverse=True)[0]

def main():
    os.makedirs(os.path.join(ROOT, "_includes"), exist_ok=True)

    if not os.path.isdir(PUBS_DIR):
        with io.open(OUT_MD, "w", encoding="utf-8") as f:
            f.write("_Aucune publication trouvée._\n")
        return

    cands = []
    for name in os.listdir(PUBS_DIR):
        dirpath = os.path.join(PUBS_DIR, name)
        if os.path.isdir(dirpath):
            c = candidate_from_dir(dirpath)
            if c:
                cands.append(c)

    feat = pick_latest(cands)
    if not feat:
        out = "_Aucune publication trouvée._\n"
    else:
        # THIS IS THE CORRECTED PART: No ::: wrapper
        out = (
f"""### {feat['title']}
*{feat['date_str']}*

[Lire]({feat['url']}){{.btn .btn-primary .me-2}}
[PDF]({feat['pdf']}){{.btn .btn-outline-secondary}}
"""
        )

    with io.open(OUT_MD, "w", encoding="utf-8") as f:
        f.write(out)

if __name__ == "__main__":
    main()