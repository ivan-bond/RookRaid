"""Turn the piece design sheets into the game's piece images (iOS and web).

Each sheet `set-<name>-<light|dark>.png` shows one set on a magenta or green background in a 2 x 3 grid:
King, Queen, Rook on top, Bishop, Knight, Pawn below. `rookraid` is the standard set, every other name is a bot set.

    python3 Tools/art/cut_pieces.py <folder with the sheets> [--preview out.png]

For every piece the script
  1. removes the background (soft edge, colour spill cleaned up),
  2. adds volume: light from the upper left, shade to the lower right, a soft highlight and a bevelled rim,
  3. adds a contact shadow under the base and a soft cast shadow to the lower right,
  4. places it on a square canvas: centred, all pieces of a set (light and dark) at one scale, standing on one baseline,
  5. writes a 320 px PNG into RookRaid/Assets.xcassets and a 256 px WebP into web/public.
The shadow is part of the image, so the boards draw no extra shadow under the pieces.
"""
import sys, os, glob, json, argparse
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ORDER = [['K', 'Q', 'R'], ['B', 'N', 'P']]
WORK = 1024                                   # working canvas
TOP, BASE, MAX_W = 0.02, 0.915, 0.90          # tallest piece from 2 % to the baseline at 91.5 %; widest at 90 %
LIGHT = np.array([-0.55, -0.83])              # light from the upper left (x, y; y grows downwards)
IOS_PX, WEB_PX = 320, 256


# MARK: Background

def key_out(rgb):
    """Alpha from how strongly a pixel shows the background colour, then remove the colour spill."""
    border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3), rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
    key = np.median(border, axis=0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = key[1] > key[0] and key[1] > key[2]
    if green:
        m, mk = g - np.maximum(r, b), key[1] - max(key[0], key[2])
    else:
        m, mk = np.minimum(r, b) - g, min(key[0], key[2]) - key[1]
    lo, hi = 0.10 * mk, 0.88 * mk
    alpha = 1 - np.clip((m - lo) / (hi - lo), 0, 1)
    # Unmix: observed = a * piece + (1 - a) * key
    a = alpha[..., None]
    fg = np.clip(np.where(a > 0.02, (rgb - (1 - a) * key) / np.maximum(a, 0.02), 0), 0, 255)
    # Leftover spill, only near the edge (the designs' own pinks and purples stay untouched)
    edge = ndimage.binary_dilation(alpha < 0.98, iterations=3)
    if green:
        fg[..., 1] = np.where(edge, np.minimum(fg[..., 1], np.maximum(fg[..., 0], fg[..., 2])), fg[..., 1])
    else:
        extra = np.clip(np.minimum(fg[..., 0], fg[..., 2]) - fg[..., 1], 0, None) * edge
        fg[..., 0] -= extra
        fg[..., 2] -= extra
    return fg, alpha


def cut(path):
    """The six pieces of one sheet, each cropped to its outline."""
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    fg, alpha = key_out(rgb)
    h, w = alpha.shape
    lab, _ = ndimage.label(alpha > 0.04)
    cells = {}
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if (lab[sl] == i).sum() < 40:
            continue
        cy, cx = ndimage.center_of_mass(lab == i)
        cells.setdefault(ORDER[min(1, int(cy // (h / 2)))][min(2, int(cx // (w / 3)))], []).append(i)
    out = {}
    for letter, ids in cells.items():
        a = np.where(np.isin(lab, ids), alpha, 0)
        ys, xs = np.nonzero(a > 0.04)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        out[letter] = Image.fromarray(np.dstack([fg[y0:y1, x0:x1], a[y0:y1, x0:x1] * 255]).astype(np.uint8), 'RGBA')
    assert sorted(out) == sorted('KQRBNP'), (path, sorted(out))
    return out


# MARK: Volume and shadow

def lit(piece):
    """Light from the upper left, shade towards the lower right, a soft highlight and a bevelled rim."""
    arr = np.asarray(piece).astype(np.float64)
    rgb, a = arr[..., :3], arr[..., 3] / 255
    h, w = a.shape
    ys, xs = np.nonzero(a > 0.5)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx - x0) / max(1, x1 - x0) - 0.5          # -0.5 … 0.5 across the piece
    v = (yy - y0) / max(1, y1 - y0) - 0.5
    # Directional light: up to +10 % on the lit side, -24 % on the far side
    d = np.clip(u * LIGHT[0] + v * LIGHT[1] * 0.6, -0.6, 0.6) / 0.6
    shade = np.where(d > 0, 1 + 0.10 * d, 1 + 0.24 * d)
    # Round body: left and right edges turn away from the light
    shade *= 1 - 0.18 * np.clip(np.abs(u + 0.08) * 2, 0, 1) ** 2.2
    rgb = rgb * shade[..., None]
    # Soft highlight high on the lit side (screen blend)
    hl = np.exp(-(((u + 0.17) / 0.16) ** 2 + ((v + 0.2) / 0.32) ** 2)) * 0.24
    rgb = 255 - (255 - rgb) * (1 - hl[..., None])
    # Bevel: edges facing the light get a thin bright rim, edges facing away a dark one
    soft = ndimage.gaussian_filter(a, 6)
    gy, gx = np.gradient(soft)
    facing = -(gx * LIGHT[0] + gy * LIGHT[1]) / (np.hypot(gx, gy) + 1e-6)
    rim = np.clip(facing, -1, 1) * np.clip(np.hypot(gx, gy) * 18, 0, 1)
    rgb = np.where(rim[..., None] > 0, 255 - (255 - rgb) * (1 - 0.32 * rim[..., None]), rgb * (1 + 0.28 * rim[..., None]))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), 'RGBA')


def with_shadow(canvas):
    """Contact shadow under the base plus a soft cast shadow to the lower right, drawn under the piece."""
    a = np.asarray(canvas)[..., 3].astype(np.float64) / 255
    h, w = a.shape
    ys, xs = np.nonzero(a > 0.5)
    base_y = ys.max()
    base = xs[ys > base_y - h * 0.02]
    bx0, bx1 = base.min(), base.max()
    # Cast shadow: the silhouette moved down-right and blurred
    dx, dy = int(w * 0.024), int(h * 0.016)
    cast = np.zeros_like(a)
    cast[dy:, dx:] = a[:h - dy, :w - dx]
    cast = ndimage.gaussian_filter(cast, w * 0.014) * 0.30
    # Contact shadow: a dark ellipse where the base meets the board
    yy, xx = np.mgrid[0:h, 0:w]
    cx, rx, ry = (bx0 + bx1) / 2 + w * 0.012, (bx1 - bx0) / 2 * 1.06, h * 0.03
    contact = np.clip(1 - (((xx - cx) / rx) ** 2 + ((yy - base_y + h * 0.004) / ry) ** 2), 0, 1)
    contact = ndimage.gaussian_filter(contact, w * 0.008) * 0.55
    shadow = np.clip(1 - (1 - cast) * (1 - contact), 0, 1)
    layer = Image.fromarray(np.dstack([np.full((h, w, 3), 8), shadow * 255]).astype(np.uint8), 'RGBA')
    layer.alpha_composite(canvas)
    return layer


def place(piece, scale):
    pw, ph = piece.size
    nw, nh = max(1, round(pw * scale)), max(1, round(ph * scale))
    canvas = Image.new('RGBA', (WORK, WORK), (0, 0, 0, 0))
    canvas.alpha_composite(lit(piece.resize((nw, nh), Image.LANCZOS)), ((WORK - nw) // 2, round(BASE * WORK) - nh))
    return with_shadow(canvas)


# MARK: Output

def write_ios(name, img, skin):
    iset = os.path.join(ROOT, 'RookRaid/Assets.xcassets', 'Skins' if skin else '', f'{name}.imageset')
    assert os.path.isdir(iset), iset
    for old in glob.glob(os.path.join(iset, '*.pdf')) + glob.glob(os.path.join(iset, '*.png')):
        os.remove(old)
    img.resize((IOS_PX, IOS_PX), Image.LANCZOS).save(os.path.join(iset, f'{name}.png'), optimize=True)
    with open(os.path.join(iset, 'Contents.json'), 'w') as f:
        json.dump({'images': [{'filename': f'{name}.png', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}}, f, indent=2)


def write_web(name, img, skin):
    path = os.path.join(ROOT, 'web/public', 'skins' if skin else 'pieces', f'{name}.webp')
    img.resize((WEB_PX, WEB_PX), Image.LANCZOS).save(path, 'WEBP', quality=88, method=6, alpha_quality=95)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('--preview')
    args = ap.parse_args()
    sets = sorted({os.path.basename(f)[4:].rsplit('-', 1)[0] for f in glob.glob(os.path.join(args.src, 'set-*.png'))})
    rows = []
    for s in sets:
        both = {c: cut(os.path.join(args.src, f'set-{s}-{v}.png')) for c, v in (('w', 'light'), ('b', 'dark'))}
        allp = [p for d in both.values() for p in d.values()]
        scale = min((BASE - TOP) * WORK / max(p.size[1] for p in allp), MAX_W * WORK / max(p.size[0] for p in allp))
        row = []
        for c in 'wb':
            for letter in 'KQRBNP':
                img = place(both[c][letter], scale)
                skin = s != 'rookraid'
                name = f'skin-{s}-{c}{letter}' if skin else f'{c}{letter}'
                write_ios(name, img, skin)
                write_web(name, img, skin)
                row.append(img)
        rows.append((s, row))
        print(f'{s}: 12 pieces')
    if args.preview:
        S = 120
        sheet = Image.new('RGB', (S * 12, S * len(rows)))
        for r, (_, row) in enumerate(rows):
            for i, img in enumerate(row):
                x, y = i * S, r * S
                sheet.paste((238, 238, 210) if (i + r) % 2 == 0 else (118, 150, 86), (x, y, x + S, y + S))
                small = img.resize((S, S), Image.LANCZOS)
                sheet.paste(small, (x, y), small)
        sheet.save(args.preview)


if __name__ == '__main__':
    main()
