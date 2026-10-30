#!/usr/bin/env python3
"""Gemalte Kartenbilder in die App übernehmen.

Benutzung (im Ordner RookRaid, Python 3 mit Pillow: `pip3 install pillow`):

    python3 Design/Kartenbilder/einbauen.py ~/Downloads/kartenbilder

Der Quellordner enthält je Karte ein Bild, benannt nach dem Schlüssel aus PROMPTS.md
(z. B. `shield.png`, `freeze.jpg`, `meteor.webp`). Das Skript schneidet jedes Bild auf 4:5 zu,
verkleinert es auf 600 × 750 Pixel und legt es als Bildsatz `painted-art-card-<schlüssel>` bzw.
`painted-art-ult-<schlüssel>` (JPEG) in `RookRaid/Assets.xcassets/CardArtPainted/`.
Die App zeigt ab dem nächsten Build das gemalte Bild statt des gezeichneten.

Zuschnitt: `zuschnitt.json` neben diesem Skript legt je Schlüssel fest, wie geschnitten wird –
`zoom` (1.0 = größtmögliches 4:5, größer = enger am Motiv), `cx`/`cy` (Bildmitte des Ausschnitts,
0…1 im nutzbaren Bereich) und optional `inner` = [links, oben, rechts, unten] in Pixeln, um z. B.
einen gemalten Rahmen abzuschneiden. Schlüssel ohne Eintrag werden mittig auf 4:5 geschnitten.
"""
import json
import shutil
import sys
from pathlib import Path

CARDS = ["shield", "freeze", "bulwark", "sprint", "lightning", "knighting", "reinforce",
         "revive", "bishopize", "advance", "swap", "drain", "focus", "sacrifice", "retreat"]
ULTS = ["meteor", "iceAge", "fortress", "coronation", "rebirth"]
SIZE = (600, 750)
QUALITY = 86

def cut(img, c):
    l, t, r, b = c.get("inner", [0, 0, img.width, img.height])
    aw, ah = r - l, b - t
    w = min(aw, ah * 0.8) / max(1.0, c.get("zoom", 1.0))
    h = w / 0.8
    cx = l + aw * c.get("cx", 0.5)
    cy = t + ah * c.get("cy", 0.5)
    x0 = min(max(cx - w / 2, l), r - w)
    y0 = min(max(cy - h / 2, t), b - h)
    return img.crop((round(x0), round(y0), round(x0 + w), round(y0 + h)))

def contents(filename=None):
    if filename is None:
        return {"info": {"author": "xcode", "version": 1}}
    return {"images": [{"filename": filename, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1}}

def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    try:
        from PIL import Image
    except ImportError:
        print("Pillow fehlt: pip3 install pillow")
        sys.exit(1)
    here = Path(__file__).resolve().parent
    src = Path(sys.argv[1]).expanduser()
    crops_file = here / "zuschnitt.json"
    crops = {k.lower(): v for k, v in json.loads(crops_file.read_text()).items()} if crops_file.exists() else {}
    out = here.parents[1] / "RookRaid" / "Assets.xcassets" / "CardArtPainted"
    out.mkdir(parents=True, exist_ok=True)
    (out / "Contents.json").write_text(json.dumps(contents(), indent=2))
    keys = {k.lower(): ("art-card-" + k) for k in CARDS}
    keys.update({k.lower(): ("art-ult-" + k) for k in ULTS})
    done, unknown = [], []
    for f in sorted(src.iterdir()):
        if f.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        name = keys.get(f.stem.lower())
        if not name:
            unknown.append(f.name)
            continue
        img = cut(Image.open(f).convert("RGB"), crops.get(f.stem.lower(), {}))
        img = img.resize(SIZE, Image.LANCZOS)
        folder = out / f"painted-{name}.imageset"
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir()
        img.save(folder / f"painted-{name}.jpg", quality=QUALITY, optimize=True, progressive=True)
        (folder / "Contents.json").write_text(json.dumps(contents(f"painted-{name}.jpg"), indent=2))
        done.append(f.stem)
    print(f"Übernommen: {len(done)} – {', '.join(done) or '–'}")
    missing = [k for k in CARDS + ULTS if k.lower() not in {d.lower() for d in done}]
    if missing:
        print(f"Noch ohne gemaltes Bild (zeigen weiter das gezeichnete): {', '.join(missing)}")
    if unknown:
        print(f"Unbekannte Dateinamen übersprungen: {', '.join(unknown)}")

if __name__ == "__main__":
    main()
