import cairosvg, math
OUT="#0B1A33"; SW=4.2

THEMES = {
 "easy":       dict(name="Bruno",          light=("#F2FAE6","#B9DF97"), dark=("#4C8A43","#1F4A22"), accent="#6FBF73", accent2="#9A6A3C", pattern="wood",     symbol="leaf"),
 "apprentice": dict(name="Lotte",          light=("#F0F9FE","#BFE3F4"), dark=("#3A7EA0","#173E57"), accent="#5BB5D9", accent2="#E0453B", pattern="pages",    symbol="book"),
 "medium":     dict(name="Mila",           light=("#F5EEFF","#D3BDFD"), dark=("#6A40C9","#2D1666"), accent="#8B5CF6", accent2="#FFD45C", pattern="sparkles", symbol="star"),
 "jester":     dict(name="Kasimir",        light=("#FFEEF6","#F8B8D6"), dark=("#B33A78","#5E1640"), accent="#F06BA8", accent2="#F2C14E", pattern="harlequin",symbol="jester"),
 "knight":     dict(name="Sir Konrad",     light=("#F7F9FC","#C3CEDF"), dark=("#35599E","#14274F"), accent="#2F6FE4", accent2="#E0453B", pattern="steel",    symbol="shield"),
 "tactician":  dict(name="Frieda Falk",    light=("#FFF6E6","#F5CD8F"), dark=("#B06D22","#5C3209"), accent="#E39B3A", accent2="#3C6BD6", pattern="feathers", symbol="scope"),
 "shadow":     dict(name="Nox",            light=("#EEEAFB","#B7AEE3"), dark=("#3A3270","#120E2B"), accent="#7C6FD0", accent2="#CDE0FF", pattern="stars",    symbol="moon"),
 "baron":      dict(name="Baron Rabe",     light=("#F5F6F9","#C9CFDA"), dark=("#56627A","#262D3B"), accent="#B08D3C", accent2="#1C2233", pattern="bricks",   symbol="feather"),
 "hard":       dict(name="Viktor",         light=("#FFEDEB","#F4A79F"), dark=("#9C2222","#3D0A0A"), accent="#E0413A", accent2="#FFB547", pattern="cracks",   symbol="bolt"),
 "frost":      dict(name="Magnus Frost",   light=("#F7FDFF","#BFE8FA"), dark=("#3479A8","#123552"), accent="#7FD3F5", accent2="#FFFFFF", pattern="ice",      symbol="snowflake"),
 "sphinx":     dict(name="Die Sphinx",     light=("#FFF8E6","#E9CF98"), dark=("#9A7535","#4A3412"), accent="#C9A96E", accent2="#2F5BB5", pattern="stripes",  symbol="eye"),
 "queen":      dict(name="Die Turmkönigin",light=("#FFFBE8","#F6D27A"), dark=("#9C6A12","#4A2E05"), accent="#F2C14E", accent2="#E0453B", pattern="facets",   symbol="crown"),
}

# ---------- Silhouetten (100er Raster, Boden bei y=92) ----------
BASE = "M18 84 Q18 80 22 80 L78 80 Q82 80 82 84 L82 89 Q82 92 78 92 L22 92 Q18 92 18 89 Z"
BAND = "M25 73 L75 73 Q77 73 77 75 L77 79 Q77 81 75 81 L25 81 Q23 81 23 79 L23 75 Q23 73 25 73 Z"
def rr(x1,y1,x2,y2,r):
    return f"M{x1+r} {y1} L{x2-r} {y1} Q{x2} {y1} {x2} {y1+r} L{x2} {y2-r} Q{x2} {y2} {x2-r} {y2} L{x1+r} {y2} Q{x1} {y2} {x1} {y2-r} L{x1} {y1+r} Q{x1} {y1} {x1+r} {y1} Z"

PIECES = {
 "P": [("body","M31 75 C34 65 40 59 42 53 L58 53 C60 59 66 65 69 75 Z"), ("collar",rr(36,47,64,54,3)), ("head","M50 22 A13.5 13.5 0 1 1 49.99 22 Z")],
 "R": [("body","M30 75 L33 41 L67 41 L70 75 Z"), ("top","M27 43 L27 21 Q27 18 30 18 L35 18 Q38 18 38 21 L38 26 L44.5 26 L44.5 21 Q44.5 18 47.5 18 L52.5 18 Q55.5 18 55.5 21 L55.5 26 L62 26 L62 21 Q62 18 65 18 L70 18 Q73 18 73 21 L73 43 Z"), ("collar",rr(28,39,72,46,3))],
 "B": [("body","M32 75 C34 65 40 61 41 57 L59 57 C60 61 66 65 68 75 Z"), ("collar",rr(36,51,64,58,3)), ("head","M50 15 C62 24 66 34 62.5 44 C60.5 49.5 56 52 50 52 C44 52 39.5 49.5 37.5 44 C34 34 38 24 50 15 Z"), ("ball","M50 6 A4.6 4.6 0 1 1 49.99 6 Z")],
 "Q": [("body","M30 75 C33 63 38 55 40 47 L60 47 C62 55 67 63 70 75 Z"), ("crown","M33 42 L27 19 L40 31 L50 14 L60 31 L73 19 L67 42 Z"), ("collar",rr(34,40,66,48,3))],
 "K": [("body","M30 75 C33 61 37 53 38 45 L62 45 C63 53 67 61 70 75 Z"), ("head","M36 40 C33 31 38 24 50 24 C62 24 67 31 64 40 Z"), ("collar",rr(33,38,67,46,3))],
 "N": [("body","M33 75 C33 63 38 57 44 51 C38 53 30 55 26 51 C21.5 47 23 41 29 37 L43 25 C43 19 46 15 50 12 L54 20 C67 22 75 34 73 52 C72 62 69 70 69 75 Z")],
}

def grad_id(key,var): return f"g_{key}_{var}"

def pattern(theme, var, clip):
    t=THEMES[theme]; p=t["pattern"]; dark = var=="b"
    ink = "#FFFFFF" if dark else "#0B1A33"
    a = 0.18 if dark else 0.12
    acc=t["accent"]; acc2=t["accent2"]
    out=[]
    if p=="wood":
        for y in range(14,92,7):
            out.append(f'<path d="M10 {y} C30 {y-3} 45 {y+3} 60 {y} S85 {y-2} 95 {y+1}" stroke="{ink}" stroke-opacity="{a+0.04}" stroke-width="1.4" fill="none"/>')
        out.append(f'<ellipse cx="60" cy="62" rx="4" ry="2.4" fill="none" stroke="{ink}" stroke-opacity="{a+0.06}" stroke-width="1.2"/>')
    elif p=="pages":
        for y in range(16,90,5):
            out.append(f'<line x1="10" y1="{y}" x2="90" y2="{y}" stroke="{acc}" stroke-opacity="{0.35 if not dark else 0.35}" stroke-width="1"/>')
        out.append(f'<line x1="36" y1="10" x2="36" y2="92" stroke="{acc2}" stroke-opacity="0.45" stroke-width="1.1"/>')
    elif p=="sparkles":
        for (x,y,r) in ((40,30,2.4),(58,22,1.6),(62,40,2),(44,60,1.8),(56,66,2.4),(38,48,1.4),(52,52,1.2)):
            out.append(f'<path d="M{x} {y-r*1.6} L{x+r*0.4} {y-r*0.4} L{x+r*1.6} {y} L{x+r*0.4} {y+r*0.4} L{x} {y+r*1.6} L{x-r*0.4} {y+r*0.4} L{x-r*1.6} {y} L{x-r*0.4} {y-r*0.4} Z" fill="{acc2 if dark else acc}" fill-opacity="0.8"/>')
    elif p=="harlequin":
        s=9
        for i in range(-1,12):
            for j in range(-1,12):
                if (i+j)%2==0:
                    cx,cy=i*s, j*s*1.4
                    out.append(f'<path d="M{cx} {cy-s*0.7} L{cx+s/2} {cy} L{cx} {cy+s*0.7} L{cx-s/2} {cy} Z" fill="{acc}" fill-opacity="{0.45 if not dark else 0.4}"/>')
    elif p=="steel":
        out.append(f'<rect x="40" y="0" width="7" height="100" fill="#FFFFFF" fill-opacity="{0.45 if not dark else 0.18}"/>')
        out.append(f'<rect x="49" y="0" width="2.5" height="100" fill="#FFFFFF" fill-opacity="{0.35 if not dark else 0.14}"/>')
        for y in range(20,80,10):
            out.append(f'<circle cx="60" cy="{y}" r="1.3" fill="{ink}" fill-opacity="{a+0.1}"/>')
    elif p=="feathers":
        for y in range(16,92,8):
            out.append(f'<path d="M20 {y} L50 {y+6} L80 {y}" stroke="{ink}" stroke-opacity="{a+0.03}" stroke-width="1.6" fill="none"/>')
    elif p=="stars":
        import random
        rnd=random.Random(7)
        for _ in range(26):
            x,y=rnd.uniform(15,85),rnd.uniform(10,90); r=rnd.uniform(0.5,1.3)
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{acc2 if dark else acc}" fill-opacity="{0.85 if dark else 0.55}"/>')
    elif p=="bricks":
        for row,y in enumerate(range(12,92,7)):
            out.append(f'<line x1="0" y1="{y}" x2="100" y2="{y}" stroke="{ink}" stroke-opacity="{a+0.04}" stroke-width="1.1"/>')
            off = 0 if row%2 else 8
            for x in range(off,100,16):
                out.append(f'<line x1="{x}" y1="{y}" x2="{x}" y2="{y+7}" stroke="{ink}" stroke-opacity="{a+0.04}" stroke-width="1.1"/>')
    elif p=="cracks":
        out.append(f'<path d="M44 20 L48 30 L42 38 L50 48 L45 58 L52 70 L48 82" stroke="{acc2}" stroke-width="2.2" fill="none" stroke-linejoin="round" stroke-opacity="{0.95 if dark else 0.75}"/>')
        out.append(f'<path d="M50 48 L58 52 L62 60" stroke="{acc2}" stroke-width="1.6" fill="none" stroke-opacity="{0.9 if dark else 0.7}"/>')
        out.append(f'<path d="M42 38 L36 42" stroke="{acc2}" stroke-width="1.4" fill="none" stroke-opacity="{0.9 if dark else 0.7}"/>')
    elif p=="ice":
        out.append(f'<path d="M30 10 L42 10 L24 60 L18 60 Z" fill="#FFFFFF" fill-opacity="{0.55 if not dark else 0.22}"/>')
        for (x,y,r) in ((58,30,3),(62,58,2.4),(48,70,2)):
            for k in range(3):
                a2=math.radians(k*60)
                out.append(f'<line x1="{x-r*math.cos(a2):.2f}" y1="{y-r*math.sin(a2):.2f}" x2="{x+r*math.cos(a2):.2f}" y2="{y+r*math.sin(a2):.2f}" stroke="#FFFFFF" stroke-opacity="{0.9 if dark else 0.85}" stroke-width="0.9"/>')
    elif p=="stripes":
        for i,y in enumerate(range(12,92,6)):
            if i%2==0:
                out.append(f'<rect x="0" y="{y}" width="100" height="3" fill="{acc2}" fill-opacity="{0.55 if not dark else 0.6}"/>')
    elif p=="facets":
        out.append(f'<path d="M34 10 L50 40 L66 10 Z" fill="#FFFFFF" fill-opacity="{0.35 if not dark else 0.15}"/>')
        out.append(f'<path d="M30 60 L50 40 L70 60 L50 88 Z" fill="#FFFFFF" fill-opacity="{0.22 if not dark else 0.1}"/>')
        out.append(f'<path d="M20 40 L50 40 L80 40" stroke="#FFFFFF" stroke-opacity="{0.4 if not dark else 0.2}" stroke-width="1"/>')
    return f'<g clip-path="url(#{clip})">{"".join(out)}</g>'

def symbol(name, cx, cy, r, theme, var, stroke=True):
    t=THEMES[theme]; acc=t["accent"]; acc2=t["accent2"]; dark=var=="b"
    sw = max(1.6, r*0.28) if stroke else 0
    st = f'stroke="{OUT}" stroke-width="{sw:.2f}" stroke-linejoin="round" stroke-linecap="round"'
    g=f'<g transform="translate({cx} {cy}) scale({r/10})">'
    if name=="leaf":
        g+=f'<path d="M-8 8 C-10 -4 -2 -10 9 -10 C 9 2 3 9 -8 8 Z" fill="{acc}" {st}/><path d="M-6 6 L5 -6" stroke="{OUT}" stroke-width="{sw*0.8:.2f}" stroke-linecap="round"/>'
    elif name=="book":
        g+=f'<path d="M0 -6 C-4 -9 -9 -9 -11 -8 L-11 8 C-8 7 -4 7 0 9 C4 7 8 7 11 8 L11 -8 C9 -9 4 -9 0 -6 Z" fill="#FFFFFF" {st}/><path d="M0 -6 L0 9" stroke="{OUT}" stroke-width="{sw*0.8:.2f}"/><path d="M5 -8 L5 0 L7 -2 L9 0 L9 -8" fill="{acc2}"/>'
    elif name=="star":
        pts=" ".join(f"{(10 if k%2==0 else 4.2)*math.sin(math.radians(k*36)):.2f},{-(10 if k%2==0 else 4.2)*math.cos(math.radians(k*36)):.2f}" for k in range(10))
        g+=f'<polygon points="{pts}" fill="{acc2}" {st}/>'
    elif name=="jester":
        g+=f'<path d="M-10 6 L-10 2 C-12 -4 -14 -6 -15 -9 C-9 -8 -6 -5 -4 -1 C-3 -6 -1 -10 0 -12 C1 -10 3 -6 4 -1 C6 -5 9 -8 15 -9 C14 -6 12 -4 10 2 L10 6 Z" fill="{acc}" {st}/>'
        for x,y in ((-15,-9),(0,-12),(15,-9)):
            g+=f'<circle cx="{x}" cy="{y}" r="3" fill="{acc2}" {st}/>'
    elif name=="diamond":
        g+=f'<path d="M0 -10 L8 0 L0 10 L-8 0 Z" fill="{acc}" {st}/>'
    elif name=="shield":
        g+=f'<path d="M-9 -9 L9 -9 L9 0 C9 6 4 9 0 11 C-4 9 -9 6 -9 0 Z" fill="{acc}" {st}/><path d="M0 -9 L0 10 M-9 -2 L9 -2" stroke="#FFFFFF" stroke-opacity="0.9" stroke-width="{sw*0.9:.2f}"/>'
    elif name=="scope":
        g+=f'<circle cx="0" cy="0" r="8" fill="#FFFFFF" {st}/><circle cx="0" cy="0" r="3" fill="{acc2}"/><path d="M0 -12 L0 -5 M0 5 L0 12 M-12 0 L-5 0 M5 0 L12 0" stroke="{OUT}" stroke-width="{sw:.2f}" stroke-linecap="round"/>'
    elif name=="moon":
        g+=f'<path d="M3 -10 A10 10 0 1 0 10 6 A8 8 0 1 1 3 -10 Z" fill="{acc2}" {st}/>'
    elif name=="feather":
        g+=f'<path d="M6 -11 C12 -4 6 6 -5 10 L-8 12 L-6 8 C-9 0 -3 -8 6 -11 Z" fill="{acc2}" {st}/><path d="M-6 9 L4 -6" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="{sw*0.6:.2f}"/>'
    elif name=="bolt":
        g+=f'<path d="M3 -12 L-7 2 L-1 2 L-4 12 L7 -3 L1 -3 Z" fill="{acc2}" {st}/>'
    elif name=="snowflake":
        for k in range(3):
            a=k*60
            g+=f'<g transform="rotate({a})"><path d="M0 -11 L0 11 M-3 -8 L0 -5 L3 -8 M-3 8 L0 5 L3 8" stroke="{OUT}" stroke-width="{sw+1.6:.2f}" stroke-linecap="round" fill="none"/><path d="M0 -11 L0 11 M-3 -8 L0 -5 L3 -8 M-3 8 L0 5 L3 8" stroke="#FFFFFF" stroke-width="{max(1.2,sw-0.6):.2f}" stroke-linecap="round" fill="none"/></g>'
    elif name=="eye":
        g+=f'<path d="M-11 0 C-6 -7 6 -7 11 0 C6 6 -6 6 -11 0 Z" fill="#FFFFFF" {st}/><circle cx="0" cy="0" r="3.4" fill="{acc2}"/><path d="M-3 5 L-5 11 M4 5 C6 9 9 9 10 6" stroke="{OUT}" stroke-width="{sw:.2f}" stroke-linecap="round" fill="none"/>'
    elif name=="crown":
        g+=f'<path d="M-10 6 L-11 -6 L-5 -1 L0 -9 L5 -1 L11 -6 L10 6 Z" fill="{acc}" {st}/><circle cx="0" cy="2" r="2" fill="{acc2}"/>'
    g+='</g>'
    return g


def pawn_hat(theme, var):
    t=THEMES[theme]; acc=t["accent"]; acc2=t["accent2"]; dark=var=="b"
    top,bot = t["light"] if var=="w" else t["dark"]
    O=f'stroke="{OUT}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"'
    if theme=="easy":
        return (f'<path d="M50 23 C50 18 50 15 51 11" stroke="{OUT}" stroke-width="3" fill="none" stroke-linecap="round"/>'
                f'<path d="M51 13 C55 7 62 7 64 9 C61 14 55 15 51 13 Z" fill="{acc}" {O}/>'
                f'<path d="M50 15 C46 10 40 10 38 12 C41 16 46 17 50 15 Z" fill="{acc}" {O}/>')
    if theme=="apprentice":
        return (f'<path d="M50 14 L68 20 L50 26 L32 20 Z" fill="#26324A" {O}/>'
                f'<path d="M40 23 L40 28 C46 31 54 31 60 28 L60 23" fill="#26324A" {O}/>'
                f'<path d="M50 20 L64 24 L64 32" stroke="{acc2}" stroke-width="2.2" fill="none" stroke-linecap="round"/><circle cx="64" cy="33" r="2.2" fill="{acc2}"/>')
    if theme=="medium":
        return (f'<path d="M37 27 C44 22 47 12 56 3 C56 12 60 20 63 27 Z" fill="{acc}" {O}/>'
                f'<ellipse cx="50" cy="27.5" rx="16" ry="3.6" fill="{acc}" {O}/>'
                f'<path d="M51 12 L52.2 15 L55.4 15.2 L52.9 17.1 L53.8 20.2 L51 18.4 L48.2 20.2 L49.1 17.1 L46.6 15.2 L49.8 15 Z" fill="{acc2}"/>')
    if theme=="jester":
        return (f'<path d="M37 28 C34 20 30 16 26 14 C34 12 40 16 43 22 C44 15 48 9 54 7 C54 14 57 20 58 22 C61 16 67 12 74 14 C70 17 66 21 63 28 Z" fill="{acc}" {O}/>'
                f'<circle cx="26" cy="14" r="3" fill="{acc2}" {O}/><circle cx="54" cy="7" r="3" fill="{acc2}" {O}/><circle cx="74" cy="14" r="3" fill="{acc2}" {O}/>')
    if theme=="knight":
        return (f'<path d="M36.5 34 L63.5 34 L63.5 38 L36.5 38 Z" fill="{OUT}"/>'
                f'<path d="M50 22 C47 15 52 10 58 11 C55 14 54 17 54 22 Z" fill="{acc2}" {O}/>')
    if theme=="tactician":
        return (f'<path d="M54 23 C58 14 66 10 70 11 C67 16 62 21 56 24 Z" fill="{acc}" {O}/>'
                f'<path d="M51 23 C51 15 55 9 59 7 C59 13 56 19 53 23 Z" fill="{acc2}" {O}/>')
    if theme=="shadow":
        hood = "#1A1538" if dark else "#3A3270"
        return (f'<path d="M35 44 C33 30 38 19 50 17 C62 19 67 30 65 44 C61 40 57 38 50 38 C43 38 39 40 35 44 Z" fill="{hood}" {O}/>'
                f'<ellipse cx="50" cy="35" rx="10" ry="6.5" fill="#05030F"/>'
                f'<circle cx="46" cy="35" r="1.8" fill="{acc2}"/><circle cx="54" cy="35" r="1.8" fill="{acc2}"/>')
    if theme=="baron":
        return (f'<path d="M50 23 C46 15 47 9 50 6 C51 12 53 17 52 23 Z" fill="{acc2}" {O}/>'
                f'<path d="M51 23 C55 16 60 13 63 13 C61 18 57 21 53 24 Z" fill="{acc2}" {O}/>')
    if theme=="hard":
        return (f'<path d="M41 27 C36 22 35 15 37 10 C40 16 43 20 46 23 Z" fill="{acc2}" {O}/>'
                f'<path d="M59 27 C64 22 65 15 63 10 C60 16 57 20 54 23 Z" fill="{acc2}" {O}/>'
                f'<circle cx="45.5" cy="36" r="2" fill="{acc2}"/><circle cx="54.5" cy="36" r="2" fill="{acc2}"/>')
    if theme=="frost":
        return (f'<path d="M37.5 31 C37 23 43 19 50 19 C57 19 63 23 62.5 31 C59 29 56 32 53 30 C50 33 47 29 44 31 C41 29 40 32 37.5 31 Z" fill="#FFFFFF" {O}/>'
                f'<path d="M44 31 L45.5 36 L47 31.2 M53 30 L54.5 35 L56 30.4" fill="#FFFFFF" stroke="{OUT}" stroke-width="1.5" stroke-linejoin="round"/>')
    if theme=="sphinx":
        return (f'<path d="M36 30 C36 22 42 19 50 19 C58 19 64 22 64 30 L67 46 L59 46 L60 34 L40 34 L41 46 L33 46 Z" fill="{acc}" {O}/>'
                f'<path d="M34.5 38 L40.5 38 M34 42 L40.8 42 M59.3 38 L65.5 38 M59.2 42 L66 42" stroke="{acc2}" stroke-width="2.2"/>'
                f'<rect x="38" y="25" width="24" height="4" fill="{acc2}"/>')
    if theme=="queen":
        return (f'<path d="M40 25 L39 14 L45 19 L50 11 L55 19 L61 14 L60 25 Z" fill="{acc}" {O}/>'
                f'<circle cx="50" cy="20.5" r="1.8" fill="{acc2}"/>')
    return ""

def piece_svg(theme, var, piece):
    t=THEMES[theme]; top,bot = t["light"] if var=="w" else t["dark"]
    acc=t["accent"]; acc2=t["accent2"]; gid="grad"
    defs=[f'<linearGradient id="{gid}" x1="0" y1="10" x2="0" y2="92" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>']
    body=[]
    comps = PIECES[piece]
    # Sockel und Band zuerst (hinter dem Körper liegt nichts)
    allc = comps
    def draw(name, d, fill=f"url(#{gid})", pat=True):
        cid=f"c_{name}"
        defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        s=f'<path d="{d}" fill="{fill}"/>'
        if pat: s+=pattern(theme,var,cid)
        s+=f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>'
        return s
    order = []
    if piece=="N":
        order=[("body",comps[0][1])]
    else:
        order=list(comps)
    # Körper vor Band/Sockel zeichnen, damit Band und Sockel die Unterkante abdecken
    sym=t["symbol"]
    main=[c for c in order if c[0]=="body"]
    rest=[c for c in order if c[0]!="body"]
    for n,d in main: body.append(draw(n,d))
    body.append(draw("band",BAND,fill=acc,pat=False))
    body.append(draw("base",BASE))
    for n,d in rest:
        if n=="ball": body.append(symbol("diamond" if sym=="jester" else sym,50,8,5.8,theme,var))
        else: body.append(draw(n,d))
    # Glanzlinie links
    gloss = "#FFFFFF"
    if piece in "PKQB":
        body.append(f'<path d="M37 70 C38 64 41 60 43 56" stroke="{gloss}" stroke-opacity="0.55" stroke-width="2.6" stroke-linecap="round" fill="none"/>')
    if piece=="R":
        body.append(f'<path d="M37 70 L38.5 50" stroke="{gloss}" stroke-opacity="0.55" stroke-width="2.6" stroke-linecap="round"/>')
    # Thema-Schmuck
    sym=t["symbol"]
    if piece=="K":
        body.append(symbol(sym,50,14,8.5,theme,var))
        body.append(symbol("diamond" if sym=="jester" else sym,50,61,6.2,theme,var))
    elif piece=="Q":
        for (x,y) in ((27,18),(73,18)):
            body.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{acc2}" stroke="{OUT}" stroke-width="3"/>')
        body.append(f'<circle cx="50" cy="12.5" r="4.6" fill="{acc}" stroke="{OUT}" stroke-width="3"/>')
        body.append(symbol("diamond" if sym=="jester" else sym,50,62,6,theme,var))
    elif piece=="R":
        body.append(symbol("diamond" if sym=="jester" else sym,50,58,6.6,theme,var))
    elif piece=="B":
        body.append(f'<path d="M54 27 L45 37" stroke="{OUT}" stroke-width="3.2" stroke-linecap="round"/>')
    elif piece=="P":
        body.append(f'<circle cx="45" cy="31" r="3.2" fill="#FFFFFF" fill-opacity="0.6"/>')
        body.append(pawn_hat(theme,var))
    elif piece=="N":
        body.append(f'<path d="M53 20 C62 23 68 32 69 46" stroke="{acc}" stroke-width="5" stroke-linecap="round" fill="none"/>')
        body.append(f'<path d="M53 20 C62 23 68 32 69 46" stroke="{OUT}" stroke-width="1.2" stroke-linecap="round" fill="none" stroke-opacity="0.5"/>')
        body.append(f'<circle cx="44" cy="31" r="2.6" fill="{OUT}"/><circle cx="44.8" cy="30.2" r="0.9" fill="#FFFFFF"/>')
        body.append(f'<circle cx="28.5" cy="46.5" r="1.3" fill="{OUT}"/>')
        if theme=="knight":  # Federbusch
            body.append(f'<path d="M50 12 C46 4 54 0 60 4 C56 6 55 9 54 14 Z" fill="{acc2}" stroke="{OUT}" stroke-width="2.6" stroke-linejoin="round"/>')
        else:
            body.append(symbol("diamond" if sym=="jester" else sym,58,62,5.6,theme,var))
    # Besonderheiten
    if theme=="frost":
        for x in (30,40,58,68):
            body.append(f'<path d="M{x-2.6} 80.5 L{x+2.6} 80.5 L{x} 86 Z" fill="#FFFFFF" stroke="{OUT}" stroke-width="1.4" stroke-linejoin="round"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100"><defs>{"".join(defs)}</defs>{"".join(body)}</svg>'

def render_png(svgtext, path, size):
    cairosvg.svg2png(bytestring=svgtext.encode(), write_to=path, output_width=size, output_height=size)

def render_pdf(svgtext, path):
    # 75 × 75 pt wie die bisherigen Figuren
    cairosvg.svg2pdf(bytestring=svgtext.replace('width="100" height="100"','width="75pt" height="75pt"').encode(), write_to=path)

if __name__=="__main__":
    import subprocess, os
    os.makedirs("prev",exist_ok=True)
    rows=[]
    for key in THEMES:
        files=[]
        for var in ("w","b"):
            for p in "KQRBNP":
                f=f"prev/{key}_{var}{p}.png"
                render_png(piece_svg(key,var,p), f, 96)
                files.append(f)
        subprocess.run(["convert",*files,"+append",f"prev/row_{key}.png"],check=True)
        rows.append(f"prev/row_{key}.png")
    subprocess.run(["convert",*rows,"-append","-background","#6E8F7A","-flatten","sheet.png"],check=True)
