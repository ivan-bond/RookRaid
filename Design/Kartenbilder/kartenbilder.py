import math, cairosvg, random
from skins import PIECES, BASE, BAND
NAVY="#0B1A33"; W,H=160,200
ROLE={"attack":("#E0613A","#5A1C10","#FFB08A"),"control":("#5BB5D9","#0E2F4A","#BFE8FA"),"defense":("#6FBF73","#123A1E","#C8F0C0"),
      "mana":("#8B5CF6","#24124F","#D9C8FF"),"comeback":("#F2C14E","#4A3205","#FFF0B8"),"ult":("#F2C14E","#3A2604","#FFF4C2")}

def bg(role, uid, rays=True, seed=1):
    mid,dark,light=ROLE[role]
    g=[f'<defs><radialGradient id="bg{uid}" cx="50%" cy="52%" r="70%"><stop offset="0" stop-color="{mid}"/><stop offset="0.55" stop-color="{dark}"/><stop offset="1" stop-color="#060B18"/></radialGradient></defs>',
       f'<rect width="{W}" height="{H}" fill="url(#bg{uid})"/>']
    if rays:
        for i in range(12):
            a=i*30+7
            x1=80+260*math.cos(math.radians(a-5)); y1=108+260*math.sin(math.radians(a-5))
            x2=80+260*math.cos(math.radians(a+5)); y2=108+260*math.sin(math.radians(a+5))
            g.append(f'<polygon points="80,108 {x1:.1f},{y1:.1f} {x2:.1f},{y2:.1f}" fill="{light}" opacity="0.07"/>')
    rnd=random.Random(seed)
    for _ in range(14):
        x,y,r=rnd.uniform(6,154),rnd.uniform(6,194),rnd.uniform(0.6,1.6)
        g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{light}" opacity="{rnd.uniform(0.3,0.8):.2f}"/>')
    return "".join(g)

def piece(p, x, y, size, fill="#FFF4DE", accent="#F2C14E", sw=None):
    """Figur aus den Skin-Silhouetten, (x,y) = Mitte unten."""
    s=size/100; sw=sw or 4.2
    parts=[d for _,d in PIECES[p]]
    body=[d for n,d in PIECES[p] if n=="body"]
    rest=[d for n,d in PIECES[p] if n!="body"]
    out=[f'<g transform="translate({x-50*s:.2f} {y-92*s:.2f}) scale({s:.4f})">']
    for d in body: out.append(f'<path d="{d}" fill="{fill}" stroke="{NAVY}" stroke-width="{sw}" stroke-linejoin="round"/>')
    out.append(f'<path d="{BAND}" fill="{accent}" stroke="{NAVY}" stroke-width="{sw}" stroke-linejoin="round"/>')
    out.append(f'<path d="{BASE}" fill="{fill}" stroke="{NAVY}" stroke-width="{sw}" stroke-linejoin="round"/>')
    for d in rest: out.append(f'<path d="{d}" fill="{fill}" stroke="{NAVY}" stroke-width="{sw}" stroke-linejoin="round"/>')
    if p=="N": out.append(f'<circle cx="44" cy="31" r="2.8" fill="{NAVY}"/>')
    if p=="B": out.append(f'<path d="M54 27 L45 37" stroke="{NAVY}" stroke-width="3.2" stroke-linecap="round"/>')
    if p=="K": out.append(f'<path d="M50 6 L50 22 M43 12 L57 12" stroke="{NAVY}" stroke-width="7" stroke-linecap="round"/><path d="M50 6 L50 22 M43 12 L57 12" stroke="{accent}" stroke-width="3.4" stroke-linecap="round"/>')
    out.append('</g>')
    return "".join(out)

def star(x,y,r,fill="#FFFFFF",op=1):
    return f'<path d="M{x} {y-r} Q {x+r*0.2} {y-r*0.2} {x+r} {y} Q {x+r*0.2} {y+r*0.2} {x} {y+r} Q {x-r*0.2} {y+r*0.2} {x-r} {y} Q {x-r*0.2} {y-r*0.2} {x} {y-r} Z" fill="{fill}" opacity="{op}"/>'

def glow(x,y,r,color,op=0.6,uid="g"):
    return (f'<defs><radialGradient id="gl{uid}"><stop offset="0" stop-color="{color}" stop-opacity="{op}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient></defs>'
            f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#gl{uid})"/>')

def drop(x,y,s=1,fill="#8B5CF6",hl="#D9C8FF"):
    return (f'<g transform="translate({x} {y}) scale({s})"><path d="M0 -14 C6 -6 10 -1 10 5 A10 10 0 0 1 -10 5 C-10 -1 -6 -6 0 -14 Z" fill="{fill}" stroke="{NAVY}" stroke-width="3"/>'
            f'<path d="M-4 -2 C-5 2 -5 5 -3 8" stroke="{hl}" stroke-width="2.4" stroke-linecap="round" fill="none"/></g>')

def bolt(x,y,s=1,fill="#FFE066"):
    return f'<path transform="translate({x} {y}) scale({s})" d="M4 -30 L-14 4 L-2 4 L-8 30 L14 -6 L2 -6 Z" fill="{fill}" stroke="{NAVY}" stroke-width="3.4" stroke-linejoin="round"/>'

def snowflake(x,y,r,color="#FFFFFF",w=3):
    g=[]
    for k in range(3):
        g.append(f'<g transform="translate({x} {y}) rotate({k*60})"><path d="M0 {-r} L0 {r} M{-r*0.3} {-r*0.7} L0 {-r*0.45} L{r*0.3} {-r*0.7} M{-r*0.3} {r*0.7} L0 {r*0.45} L{r*0.3} {r*0.7}" stroke="{NAVY}" stroke-width="{w+2.4}" stroke-linecap="round" fill="none"/>'
                 f'<path d="M0 {-r} L0 {r} M{-r*0.3} {-r*0.7} L0 {-r*0.45} L{r*0.3} {-r*0.7} M{-r*0.3} {r*0.7} L0 {r*0.45} L{r*0.3} {r*0.7}" stroke="{color}" stroke-width="{w}" stroke-linecap="round" fill="none"/></g>')
    return "".join(g)

def ground(color, y=172, op=0.5):
    return f'<ellipse cx="80" cy="{y}" rx="58" ry="10" fill="{color}" opacity="{op}"/>'

# ---------------- Karten ----------------
def art_shield():
    g=[bg("defense","s",seed=2), glow(80,108,70,"#C8F0C0",0.55,"s")]
    g.append('<circle cx="80" cy="108" r="58" fill="none" stroke="#C8F0C0" stroke-width="3" opacity="0.55" stroke-dasharray="6 6"/>')
    g.append(f'<path d="M80 46 L128 62 L126 108 C124 140 102 160 80 170 C58 160 36 140 34 108 L32 62 Z" fill="#3E8E4A" stroke="{NAVY}" stroke-width="6" stroke-linejoin="round"/>')
    g.append(f'<path d="M80 56 L118 69 L116 108 C114 133 97 150 80 158 Z" fill="#6FBF73"/>')
    g.append(f'<path d="M80 56 L42 69 L44 108 C46 133 63 150 80 158 Z" fill="#9AD89A"/>')
    g.append(piece("R",80,140,64,fill="#FFF4DE",accent="#F2C14E",sw=5))
    g.append(f'<path d="M80 46 L128 62 L126 108 C124 140 102 160 80 170 C58 160 36 140 34 108 L32 62 Z" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2.5" transform="translate(0 4) scale(1)"/>')
    g.append(star(130,48,7)+star(28,150,5)+star(134,150,4))
    return g

def art_freeze():
    g=[bg("control","f",seed=3), glow(80,112,66,"#BFE8FA",0.6,"f")]
    g.append(piece("P",80,160,96,fill="#9FB4D6",accent="#5BB5D9",sw=5))
    # Eisblock
    g.append(f'<path d="M34 70 L118 58 L130 150 L44 166 Z" fill="#BFE8FA" fill-opacity="0.55" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    g.append(f'<path d="M42 78 L70 74 L48 120 Z" fill="#FFFFFF" fill-opacity="0.55"/>')
    g.append(f'<path d="M112 72 L120 130" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="3" stroke-linecap="round"/>')
    for (x,y,a) in ((30,180,-30),(130,176,25),(80,182,0)):
        g.append(f'<path transform="translate({x} {y}) rotate({a})" d="M-6 0 L0 -18 L6 0 Z" fill="#E6F7FF" stroke="{NAVY}" stroke-width="2.5" stroke-linejoin="round"/>')
    g.append(snowflake(120,52,15))
    g.append(star(32,52,6)+star(140,110,4))
    return g

def art_bulwark():
    g=[bg("defense","b",seed=4), glow(80,110,70,"#C8F0C0",0.45,"b")]
    for i,x in enumerate((40,80,120)):
        g.append(piece("P",x,118-(6 if i==1 else 0),56,fill="#FFF4DE",accent="#6FBF73",sw=5.5))
    # Mauer mit Zinnen
    g.append(f'<path d="M14 120 L14 104 L32 104 L32 112 L48 112 L48 104 L66 104 L66 112 L94 112 L94 104 L112 104 L112 112 L128 112 L128 104 L146 104 L146 120 L146 176 L14 176 Z" fill="#8E9AAF" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    for y in (130,146,162):
        g.append(f'<line x1="16" y1="{y}" x2="144" y2="{y}" stroke="{NAVY}" stroke-width="2.4" opacity="0.6"/>')
    for row,y in enumerate((120,136,152)):
        for x in range(26 if row%2 else 42,146,32):
            g.append(f'<line x1="{x}" y1="{y}" x2="{x}" y2="{y+16}" stroke="{NAVY}" stroke-width="2.4" opacity="0.6"/>')
    g.append(f'<path d="M80 30 C104 34 122 46 132 62" stroke="#C8F0C0" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/><path d="M80 30 C56 34 38 46 28 62" stroke="#C8F0C0" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/>')
    g.append(star(80,30,9,"#FFFFFF"))
    return g

def art_sprint():
    g=[bg("attack","sp",seed=5), glow(80,110,60,"#FFB08A",0.5,"sp")]
    for i,(y,l) in enumerate(((70,40),(92,56),(116,46),(138,60))):
        g.append(f'<path d="M{20} {y} L{20+l} {y}" stroke="#FFD7C2" stroke-width="5" stroke-linecap="round" opacity="0.75"/>')
    g.append(f'<path d="M96 70 L120 46 L144 70" fill="none" stroke="{NAVY}" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/><path d="M96 70 L120 46 L144 70" fill="none" stroke="#FFE066" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(f'<path d="M96 92 L120 68 L144 92" fill="none" stroke="{NAVY}" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/><path d="M96 92 L120 68 L144 92" fill="none" stroke="#FFB347" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(f'<g transform="rotate(12 76 160)">{piece("P",76,166,104,fill="#FFF4DE",accent="#E0613A",sw=4.6)}</g>')
    for (x,y,r) in ((40,176,8),(54,182,6),(28,184,5)):
        g.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFD7C2" opacity="0.55"/>')
    return g

def art_lightning():
    g=[bg("control","l",seed=6), glow(80,120,64,"#FFE066",0.5,"l")]
    g.append(f'<path d="M30 20 C50 10 110 10 130 20 C140 34 120 40 100 36 C80 44 50 42 30 36 C14 32 18 24 30 20 Z" fill="#2B3E66" stroke="{NAVY}" stroke-width="4"/>')
    g.append(piece("P",78,176,92,fill="#C9D3E8",accent="#5BB5D9",sw=5))
    g.append(f'<path d="M64 112 L74 124 L66 134 L78 150" stroke="{NAVY}" stroke-width="4" fill="none" stroke-linejoin="round"/>')
    g.append(bolt(84,78,1.7))
    for a in range(0,360,45):
        x=80+30*math.cos(math.radians(a)); y=112+22*math.sin(math.radians(a))
        g.append(f'<line x1="{80+16*math.cos(math.radians(a)):.1f}" y1="{112+12*math.sin(math.radians(a)):.1f}" x2="{x:.1f}" y2="{y:.1f}" stroke="#FFE066" stroke-width="3" stroke-linecap="round"/>')
    return g

def art_knighting():
    g=[bg("attack","k",seed=7), glow(80,104,70,"#FFB08A",0.5,"k")]
    g.append(piece("N",84,170,120,fill="#FFF4DE",accent="#F2C14E",sw=4.4))
    # Schwert schräg
    g.append(f'<g transform="rotate(-38 70 80)"><rect x="66" y="10" width="10" height="84" rx="3" fill="#E6EEF8" stroke="{NAVY}" stroke-width="3.6"/><path d="M66 10 L71 0 L76 10 Z" fill="#E6EEF8" stroke="{NAVY}" stroke-width="3.6" stroke-linejoin="round"/>'
             f'<rect x="54" y="92" width="34" height="8" rx="3" fill="#F2C14E" stroke="{NAVY}" stroke-width="3.6"/><rect x="67" y="100" width="8" height="18" rx="3" fill="#9A6A3C" stroke="{NAVY}" stroke-width="3.6"/></g>')
    g.append(star(40,58,10,"#FFE066")+star(126,40,6)+star(30,140,5))
    return g

def art_reinforce():
    g=[bg("defense","r",seed=8)]
    g.append(f'<ellipse cx="80" cy="166" rx="54" ry="16" fill="#C8F0C0" opacity="0.35"/><ellipse cx="80" cy="166" rx="42" ry="11" fill="none" stroke="#C8F0C0" stroke-width="4"/>')
    g.append(f'<path d="M50 166 L58 40 L102 40 L110 166 Z" fill="#C8F0C0" opacity="0.18"/>')
    g.append(piece("P",80,166,100,fill="#FFF4DE",accent="#6FBF73",sw=4.6))
    g.append(f'<g transform="translate(118 58)"><circle r="18" fill="#6FBF73" stroke="{NAVY}" stroke-width="4"/><path d="M0 -9 L0 9 M-9 0 L9 0" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/></g>')
    g.append(star(40,70,7)+star(36,120,4)+star(126,120,5))
    return g

def art_revive():
    g=[bg("comeback","rv",seed=9), glow(80,100,74,"#FFF0B8",0.6,"rv")]
    # Flügel
    for sx in (-1,1):
        pts=[]
        g.append(f'<path transform="translate(80 92) scale({sx} 1)" d="M10 0 C30 -30 60 -40 74 -30 C62 -24 66 -16 58 -10 C64 -6 60 2 50 2 C56 8 48 14 38 12 C30 18 18 14 10 8 Z" fill="#FFF4DE" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
    g.append(piece("N",80,166,104,fill="#F2C14E",accent="#FFF4DE",sw=4.6))
    g.append(f'<ellipse cx="82" cy="40" rx="22" ry="6" fill="none" stroke="#FFE066" stroke-width="5"/>')
    g.append(f'<path d="M40 182 C50 168 60 176 64 164 C70 176 78 168 80 156 C84 168 92 176 96 164 C100 176 110 168 120 182 Z" fill="#E0613A" stroke="{NAVY}" stroke-width="3.6" stroke-linejoin="round"/>')
    g.append(star(30,40,6)+star(136,56,7)+star(132,140,4))
    return g

def art_bishopize():
    g=[bg("attack","bp",seed=10), glow(80,96,68,"#FFF0B8",0.55,"bp")]
    g.append(f'<path d="M58 0 L102 0 L118 176 L42 176 Z" fill="#FFF0B8" opacity="0.16"/>')
    g.append(piece("B",80,168,124,fill="#FFF4DE",accent="#8B5CF6",sw=4.2))
    g.append(piece("P",134,176,44,fill="#C9D3E8",accent="#E0613A",sw=6))
    g.append(f'<path d="M118 150 C112 136 112 128 116 118" stroke="#FFE066" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M110 122 L116 114 L122 122" stroke="#FFE066" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(star(32,48,8,"#FFE066")+star(130,40,6)+star(26,128,5))
    return g

def art_advance():
    g=[bg("attack","a",seed=11), glow(80,110,70,"#FFB08A",0.4,"a")]
    for i,x in enumerate((36,80,124)):
        g.append(f'<path d="M{x-12} 64 L{x} 46 L{x+12} 64" fill="none" stroke="{NAVY}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/><path d="M{x-12} 64 L{x} 46 L{x+12} 64" fill="none" stroke="#FFE066" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')
        g.append(piece("P",x,166 - (10 if i==1 else 0),72,fill="#FFF4DE",accent="#E0613A",sw=5.6))
    g.append(f'<path d="M14 182 L146 182" stroke="#FFD7C2" stroke-width="3" stroke-dasharray="8 6" opacity="0.6"/>')
    return g

def art_swap():
    g=[bg("defense","sw",seed=12), glow(80,108,70,"#C8F0C0",0.45,"sw")]
    g.append(f'<path d="M40 60 C60 30 100 30 120 60" fill="none" stroke="{NAVY}" stroke-width="11" stroke-linecap="round"/><path d="M40 60 C60 30 100 30 120 60" fill="none" stroke="#FFE066" stroke-width="5" stroke-linecap="round"/>')
    g.append(f'<path d="M110 52 L122 62 L126 46" fill="none" stroke="#FFE066" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(f'<path d="M120 162 C100 186 60 186 40 162" fill="none" stroke="{NAVY}" stroke-width="11" stroke-linecap="round"/><path d="M120 162 C100 186 60 186 40 162" fill="none" stroke="#FFE066" stroke-width="5" stroke-linecap="round"/>')
    g.append(f'<path d="M50 172 L38 160 L34 176" fill="none" stroke="#FFE066" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(piece("K",50,154,88,fill="#FFF4DE",accent="#F2C14E",sw=5))
    g.append(piece("R",112,154,78,fill="#6FBF73",accent="#FFF4DE",sw=5.4))
    return g

def art_drain():
    g=[bg("control","d",seed=13)]
    for i in range(5):
        r=64-i*11
        g.append(f'<circle cx="80" cy="104" r="{r}" fill="none" stroke="#8B5CF6" stroke-width="5" stroke-dasharray="{r*0.9:.0f} {r*0.5:.0f}" opacity="{0.25+i*0.13:.2f}" transform="rotate({i*40} 80 104)"/>')
    g.append(f'<circle cx="80" cy="104" r="14" fill="#060B18" stroke="#8B5CF6" stroke-width="4"/>')
    for (x,y,s,a) in ((36,52,1.4,-30),(128,66,1.2,30),(118,156,1.0,140),(40,150,0.9,-140)):
        g.append(f'<g transform="rotate({a} {x} {y})">{drop(x,y,s)}</g>')
        g.append(f'<path d="M{x} {y} Q {80+(x-80)*0.3} {104+(y-104)*0.6} 80 104" stroke="#D9C8FF" stroke-width="2.5" fill="none" stroke-dasharray="4 4" opacity="0.7"/>')
    g.append(drop(80,108,1.6,"#5BB5D9","#E6F7FF"))
    return g

def art_focus():
    g=[bg("mana","fo",seed=14), glow(80,100,70,"#D9C8FF",0.6,"fo")]
    g.append(f'<ellipse cx="80" cy="164" rx="40" ry="10" fill="#24124F" stroke="{NAVY}" stroke-width="4"/>')
    g.append(f'<path d="M56 164 L62 148 L98 148 L104 164 Z" fill="#9A6A3C" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
    g.append(f'<circle cx="80" cy="104" r="44" fill="#8B5CF6" stroke="{NAVY}" stroke-width="5"/><circle cx="80" cy="104" r="44" fill="#D9C8FF" opacity="0.25"/>')
    g.append(f'<path d="M58 84 C64 72 76 66 90 68" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.7"/>')
    g.append(f'<path d="M58 106 C66 94 94 94 102 106 C94 118 66 118 58 106 Z" fill="#FFFFFF" stroke="{NAVY}" stroke-width="4"/><circle cx="80" cy="106" r="8" fill="#5BB5D9" stroke="{NAVY}" stroke-width="3"/><circle cx="83" cy="103" r="2.5" fill="#FFFFFF"/>')
    for k in range(4):
        a=math.radians(k*90-45); x=80+66*math.cos(a); y=104+60*math.sin(a)
        g.append(drop(round(x,1),round(y,1),0.95))
    g.append(f'<text x="132" y="40" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="26" fill="#FFFFFF" stroke="{NAVY}" stroke-width="5" paint-order="stroke" text-anchor="middle">+4</text>')
    return g

def art_sacrifice():
    g=[bg("mana","sc",seed=15), glow(80,96,64,"#FFB347",0.5,"sc")]
    g.append(f'<path d="M30 176 L40 140 L120 140 L130 176 Z" fill="#6A5A7A" stroke="{NAVY}" stroke-width="4.5" stroke-linejoin="round"/><rect x="34" y="132" width="92" height="12" rx="3" fill="#8A7A9A" stroke="{NAVY}" stroke-width="4.5"/>')
    g.append(f'<path d="M56 132 C50 110 64 104 62 86 C72 96 74 104 78 92 C82 76 92 66 92 56 C102 72 112 92 104 110 C110 108 112 102 112 96 C120 112 112 128 104 132 Z" fill="#FF7A2F" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
    g.append(f'<path d="M66 132 C62 118 72 112 74 102 C80 110 82 118 88 108 C92 116 98 124 94 132 Z" fill="#FFE066"/>')
    g.append(piece("P",80,138,56,fill="#FFF4DE",accent="#8B5CF6",sw=6).replace('fill="#FFF4DE"','fill="#FFF4DE" fill-opacity="0.85"'))
    for (x,y,s) in ((34,62,1.1),(128,48,1.3),(132,104,0.9)):
        g.append(drop(x,y,s))
    g.append(f'<text x="36" y="110" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="22" fill="#D9C8FF" stroke="{NAVY}" stroke-width="5" paint-order="stroke" text-anchor="middle">+3</text>')
    return g

# ---------------- Ultimates ----------------
def art_meteor():
    g=[bg("ult","um",seed=21)]
    g.append(f'<path d="M150 0 L110 0 L40 120 L66 136 Z" fill="#FFB347" opacity="0.35"/>')
    g.append(f'<path d="M150 10 L128 4 L58 112 L74 122 Z" fill="#FFE066" opacity="0.5"/>')
    g.append(f'<circle cx="60" cy="124" r="30" fill="#7A3B1E" stroke="{NAVY}" stroke-width="5"/><circle cx="50" cy="116" r="7" fill="#5A2810"/><circle cx="70" cy="134" r="5" fill="#5A2810"/><circle cx="68" cy="112" r="4" fill="#5A2810"/>')
    g.append(f'<path d="M30 126 C26 104 40 90 58 92 C50 98 48 104 50 110 C40 108 34 116 30 126 Z" fill="#FFE066" opacity="0.8"/>')
    g.append(f'<path d="M20 186 C30 166 44 172 50 160 C56 172 66 168 72 156 C80 170 92 166 98 176 C108 168 120 172 130 186 Z" fill="#E0613A" stroke="{NAVY}" stroke-width="3.6" stroke-linejoin="round"/>')
    g.append(star(126,150,6)+star(24,52,5))
    return g

def art_iceage():
    g=[bg("ult","ui",seed=22)]
    g.append(f'<rect width="{W}" height="{H}" fill="#5BB5D9" opacity="0.35"/>')
    g.append(f'<path d="M6 184 L40 96 L58 128 L84 52 L110 120 L126 92 L156 184 Z" fill="#E6F7FF" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    g.append(f'<path d="M84 52 L74 100 L90 90 L96 112 L110 120 Z" fill="#BFE8FA"/><path d="M40 96 L34 132 L48 120 L58 128 Z" fill="#BFE8FA"/>')
    g.append(snowflake(118,42,18)+snowflake(30,46,10)+snowflake(140,140,8))
    for i in range(10):
        x=(i*37)%150+5; y=(i*53)%170+10
        g.append(f'<circle cx="{x}" cy="{y}" r="2" fill="#FFFFFF" opacity="0.8"/>')
    return g

def art_fortress():
    g=[bg("ult","uf",seed=23)]
    g.append(f'<path d="M14 150 A66 66 0 0 1 146 150" fill="#FFF4C2" opacity="0.25" stroke="#FFF4C2" stroke-width="3"/>')
    g.append(f'<path d="M24 176 L24 104 L40 104 L40 114 L52 114 L52 104 L68 104 L68 76 L60 76 L60 60 L72 60 L72 68 L88 68 L88 60 L100 60 L100 76 L92 76 L92 104 L108 104 L108 114 L120 114 L120 104 L136 104 L136 176 Z" fill="#B9C3D6" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    g.append(f'<path d="M70 176 L70 150 A10 10 0 0 1 90 150 L90 176 Z" fill="#3A2604" stroke="{NAVY}" stroke-width="4"/>')
    g.append(f'<path d="M80 60 L80 34" stroke="{NAVY}" stroke-width="4"/><path d="M80 34 L104 42 L80 50 Z" fill="#E0453B" stroke="{NAVY}" stroke-width="3.4" stroke-linejoin="round"/>')
    g.append(f'<path d="M80 108 L96 114 L95 128 C94 136 87 141 80 144 C73 141 66 136 65 128 L64 114 Z" fill="#F2C14E" stroke="{NAVY}" stroke-width="3.6" stroke-linejoin="round"/>')
    return g

def art_coronation():
    g=[bg("ult","uc",seed=24), glow(80,96,72,"#FFF4C2",0.65,"uc")]
    g.append(f'<path d="M56 0 L104 0 L112 170 L48 170 Z" fill="#FFF4C2" opacity="0.18"/>')
    g.append(piece("P",80,176,96,fill="#FFF4DE",accent="#E0453B",sw=5))
    g.append(f'<path d="M54 74 L48 40 L66 56 L80 30 L94 56 L112 40 L106 74 Z" fill="#F2C14E" stroke="{NAVY}" stroke-width="4.6" stroke-linejoin="round"/>')
    g.append(f'<circle cx="80" cy="62" r="5" fill="#E0453B" stroke="{NAVY}" stroke-width="2.4"/><circle cx="48" cy="38" r="4" fill="#FFF4DE" stroke="{NAVY}" stroke-width="2.4"/><circle cx="112" cy="38" r="4" fill="#FFF4DE" stroke="{NAVY}" stroke-width="2.4"/><circle cx="80" cy="28" r="4" fill="#FFF4DE" stroke="{NAVY}" stroke-width="2.4"/>')
    g.append(star(30,60,8,"#FFE066")+star(132,84,6)+star(36,140,5))
    return g

def art_rebirth():
    g=[bg("ult","ur",seed=25), glow(80,110,74,"#FFB347",0.6,"ur")]
    for sx in (-1,1):
        g.append(f'<path transform="translate(80 104) scale({sx} 1)" d="M8 0 C28 -40 64 -60 78 -44 C66 -40 70 -30 60 -24 C70 -20 64 -10 52 -10 C60 -2 50 6 38 4 C30 12 16 10 8 6 Z" fill="#FF7A2F" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
        g.append(f'<path transform="translate(80 104) scale({sx} 1)" d="M14 -2 C30 -30 56 -44 66 -40" stroke="#FFE066" stroke-width="4" fill="none" stroke-linecap="round"/>')
    g.append(piece("Q",80,170,96,fill="#FFF4DE",accent="#E0453B",sw=5))
    g.append(f'<path d="M30 192 C40 174 52 180 58 168 C64 180 74 176 80 164 C86 176 96 180 102 168 C108 180 120 174 130 192 Z" fill="#E0613A" stroke="{NAVY}" stroke-width="3.6" stroke-linejoin="round"/>')
    g.append(star(30,40,6)+star(132,36,7))
    return g

CARDS={"shield":art_shield,"freeze":art_freeze,"bulwark":art_bulwark,"sprint":art_sprint,"lightning":art_lightning,"knighting":art_knighting,
       "reinforce":art_reinforce,"revive":art_revive,"bishopize":art_bishopize,"advance":art_advance,"swap":art_swap,"drain":art_drain,
       "focus":art_focus,"sacrifice":art_sacrifice}
ULTS={"meteor":art_meteor,"iceAge":art_iceage,"fortress":art_fortress,"coronation":art_coronation,"rebirth":art_rebirth}

def svg_of(fn):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{"".join(fn())}</svg>'

if __name__=="__main__":
    import subprocess, os
    os.makedirs("prev",exist_ok=True)
    files=[]
    for k,f in list(CARDS.items())+list(ULTS.items()):
        out=f"prev/{k}.png"
        cairosvg.svg2png(bytestring=svg_of(f).encode(), write_to=out, output_width=160, output_height=200)
        files.append(out)
    subprocess.run(["convert",*files[:10],"+append","row1.png"],check=True)
    subprocess.run(["convert",*files[10:],"+append","row2.png"],check=True)
    subprocess.run(["convert","row1.png","row2.png","-append","sheet.png"],check=True)
