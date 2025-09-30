#!/usr/bin/env python3
import os, io, sys

ROOT = os.getcwd()
PUBS_DIR = os.path.join(ROOT, "pubs")

def ensure_line(lines, key, value):
    """Ajoute `key: value` s'il n'existe pas déjà dans le fichier."""
    has = any(l.strip().startswith(f"{key}:") for l in lines)
    if not has:
        lines.append(f'{key}: "{value}"\n')
    return lines

def process_pub_dir(dirpath):
    slug = os.path.basename(dirpath)              # ex: ai-exposure
    index_qmd = os.path.join(dirpath, "index.qmd")
    if not os.path.exists(index_qmd):
        return

    meta_path = os.path.join(dirpath, "_metadata.yml")
    lines = []
    if os.path.exists(meta_path):
        with io.open(meta_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    else:
        # fichier neuf : on met un en-tête explicite
        lines = ["# Auto-généré (pre-render) — champs par défaut pour le listing\n"]

    pdf   = f"/files/papers/{slug}.pdf"
    image = f"/images/pubs/{slug}.png"

    lines = ensure_line(lines, "pdf",   pdf)
    lines = ensure_line(lines, "image", image)

    with io.open(meta_path, "w", encoding="utf-8") as f:
        f.writelines(lines)

def main():
    if not os.path.isdir(PUBS_DIR):
        # rien à faire si pas de répertoire
        sys.exit(0)
    for name in os.listdir(PUBS_DIR):
        dirpath = os.path.join(PUBS_DIR, name)
        if os.path.isdir(dirpath):
            process_pub_dir(dirpath)

if __name__ == "__main__":
    main()
