#!/usr/bin/env python3
"""Trace une ou plusieurs courbes de cadence relevees par fps_curve.py.

    python3 ci/toje-bench/fps_plot.py sortie.svg base.csv=reference [autre.csv=overlay]

Sans dependance : le SVG est ecrit a la main (matplotlib n'est pas installe, et
une sortie sans dependance se relit dans dix ans). Le fichier est autonome et
s'embarque tel quel dans une page.

La cadence instantanee n'a que deux etats (une trame machine porte 0 ou 1
rendu) : la courbe est donc une MOYENNE GLISSANTE sur --window trames machine,
1 seconde par defaut. La bande du bas porte la position camera, qui est l'axe
commun de deux releves — a compensation de frame-drop egale, deux versions
traversent le niveau a la meme vitesse d'horloge, donc au meme instant elles
sont au meme endroit du decor.
"""
import argparse, csv, os

PALETTE = ["#BE3620", "#0F6C6F", "#5A3E8A", "#4A6B2A"]
PALETTE_DARK = ["#EB6544", "#3FA8A8", "#A78BD0", "#8FBF5A"]


def load(path):
    with open(path) as f:
        rows = [(int(r["machine_frame"]), int(r["delta"]), int(r["camera"]))
                for r in csv.DictReader(f)]
    return rows


def playable(rows, dry=100):
    """Ou s'arrete le JEU, avant le chargement de la scene suivante.

    Le releve va jusqu'au changement de stage, donc sa queue est un chargement
    disque : plusieurs centaines de trames sans un seul rendu. Le laisser dans
    la moyenne, c'est comparer deux versions sur la duree de leurs acces disque
    — qui n'ont rien a voir avec le rendu et dependent de la taille des
    fichiers. On rend l'indice du dernier rendu quand la queue muette depasse
    `dry` trames, sinon la fin du releve."""
    last = max((i for i, r in enumerate(rows) if r[1]), default=len(rows) - 1)
    return last + 1 if len(rows) - last > dry else len(rows)


def smooth(rows, window):
    """moyenne glissante centree, rendue en images/s"""
    d = [r[1] for r in rows]
    out, acc = [], 0
    half = window // 2
    for i in range(len(d)):
        lo, hi = max(0, i - half), min(len(d), i + half + 1)
        if i == 0:
            acc = sum(d[lo:hi])
        else:
            plo, phi = max(0, i - 1 - half), min(len(d), i + half)
            acc += sum(d[phi:hi]) - sum(d[plo:lo])
        out.append(50.0 * acc / (hi - lo))
    return out


p = argparse.ArgumentParser()
p.add_argument("out")
p.add_argument("series", nargs="+", metavar="fichier.csv=libelle")
p.add_argument("--window", type=int, default=50, help="fenetre glissante, trames machine")
p.add_argument("--ymax", type=float, default=0, help="0 = automatique")
p.add_argument("--width", type=int, default=980)
p.add_argument("--height", type=int, default=420)
p.add_argument("--title", default="Cadence de rendu — niveau 1")
a = p.parse_args()

series = []
for s in a.series:
    path, _, label = s.partition("=")
    rows = load(path)
    end = playable(rows)
    series.append((label or os.path.basename(path), rows, smooth(rows, a.window), end))

L, R, T, B = 58, 18, 44, 76          # marges ; B loge la bande camera
W, H = a.width, a.height
PW, PH = W - L - R, H - T - B
CAM_H, CAM_GAP = 16, 30              # bande camera

xmax = max(r[-1][0] for _, r, _, _ in series)
ymax = a.ymax or max(5 * (int(max(fs[:e]) / 5) + 1) for _, _, fs, e in series)
ymax = min(ymax, 50)


def X(frame):
    return L + PW * frame / xmax


def Y(fps):
    return T + PH * (1 - fps / ymax)


def path_of(rows, fps, step):
    """un point tous les `step` echantillons : 12 000 points de SVG ne se lisent pas"""
    pts = []
    for i in range(0, len(rows), step):
        pts.append(f"{X(rows[i][0]):.1f},{Y(fps[i]):.1f}")
    pts.append(f"{X(rows[-1][0]):.1f},{Y(fps[-1]):.1f}")
    return "M" + " L".join(pts)


o = []
o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
         f'width="100%" style="max-width:{W}px;height:auto" '
         f'font-family="IBM Plex Mono, ui-monospace, Menlo, monospace">')
o.append('<style>'
         '.ink{fill:#131920}.dim{fill:#5A6673}.rule{stroke:#D2D8DE}.grid{stroke:#E1E5E9}'
         '.cam{fill:#D2D8DE}.camf{fill:#5A6673}'
         '@media (prefers-color-scheme:dark){'
         '.ink{fill:#DCE2E9}.dim{fill:#8894A2}.rule{stroke:#242B33}.grid{stroke:#1C222A}'
         '.cam{fill:#242B33}.camf{fill:#8894A2}}'
         '</style>')
o.append(f'<text x="{L}" y="20" class="ink" font-size="13" font-weight="600">{a.title}</text>')
o.append(f'<text x="{L}" y="35" class="dim" font-size="10">'
         f'moyenne glissante sur {a.window} trames machine ({a.window/50:.1f} s) · '
         f'{xmax} trames = {xmax/50:.0f} s emulees</text>')

# grille + axe y
for k in range(0, int(ymax) + 1, 10 if ymax > 25 else 5):
    y = Y(k)
    o.append(f'<line x1="{L}" y1="{y:.1f}" x2="{L+PW}" y2="{y:.1f}" '
             f'class="grid" stroke-width="1"/>')
    o.append(f'<text x="{L-8}" y="{y+3.5:.1f}" class="dim" font-size="10" '
             f'text-anchor="end">{k}</text>')
o.append(f'<text x="{L-8}" y="{T-10}" class="dim" font-size="10" text-anchor="end">img/s</text>')

# axe x en secondes
for sec in range(0, int(xmax / 50) + 1, 30):
    x = X(sec * 50)
    o.append(f'<line x1="{x:.1f}" y1="{T}" x2="{x:.1f}" y2="{T+PH}" class="grid" stroke-width="1"/>')
    o.append(f'<text x="{x:.1f}" y="{T+PH+15}" class="dim" font-size="10" '
             f'text-anchor="middle">{sec}s</text>')
o.append(f'<line x1="{L}" y1="{T+PH}" x2="{L+PW}" y2="{T+PH}" class="rule" stroke-width="1"/>')

step = max(1, len(series[0][1]) // 900)

# la queue muette = chargement de la scene suivante : bande grisee, hors moyenne
tail = min(e for _, _, _, e in series)
if tail < len(series[0][1]):
    tx = X(series[0][1][tail - 1][0])
    o.append(f'<rect x="{tx:.1f}" y="{T}" width="{L+PW-tx:.1f}" height="{PH}" '
             f'class="cam" opacity=".45"/>')
    o.append(f'<text x="{tx+6:.1f}" y="{T+14}" class="dim" font-size="9">chargement</text>')

for i, (label, rows, fps, end) in enumerate(series):
    o.append(f'<path d="{path_of(rows[:end], fps[:end], step)}" fill="none" '
             f'stroke="{PALETTE[i % 4]}" stroke-width="1.6" '
             f'stroke-linejoin="round" stroke-linecap="round"/>')

# bande camera (premiere serie : les deux se superposent a la trame pres)
cy = T + PH + CAM_GAP
rows0 = series[0][1][:series[0][3]]
cmax = max(r[2] for r in rows0) or 1
o.append(f'<rect x="{L}" y="{cy}" width="{PW}" height="{CAM_H}" rx="2" class="cam" opacity=".55"/>')
seg = []
for i in range(0, len(rows0), step):
    seg.append(f"{X(rows0[i][0]):.1f},{cy + CAM_H - CAM_H * rows0[i][2] / cmax:.1f}")
o.append(f'<polyline points="{" ".join(seg)}" fill="none" class="camf" '
         f'stroke="currentColor" stroke-width="1.2" opacity=".85" '
         f'style="stroke:#5A6673"/>')
o.append(f'<text x="{L}" y="{cy + CAM_H + 13}" class="dim" font-size="10">'
         f'position camera · 0 a {cmax} px</text>')

# legende
lx = L + PW
for i, (label, rows, fps, end) in enumerate(reversed(series)):
    idx = len(series) - 1 - i
    avg = 50.0 * sum(r[1] for r in rows[:end]) / rows[end - 1][0]
    txt = f"{label} — {avg:.1f} img/s moy."
    lx -= 9 * len(txt) * 0.62 + 22
    o.append(f'<rect x="{lx:.0f}" y="{cy+CAM_H+4}" width="10" height="10" rx="2" fill="{PALETTE[idx % 4]}"/>')
    o.append(f'<text x="{lx+15:.0f}" y="{cy+CAM_H+13}" class="ink" font-size="10">{txt}</text>')

o.append('</svg>')
open(a.out, "w").write("\n".join(o))
print(f"ecrit {a.out}")
for label, rows, fps, end in series:
    avg = 50.0 * sum(r[1] for r in rows[:end]) / rows[end - 1][0]
    core = fps[a.window:end - a.window] or fps[:end]
    print(f"  {label:26s} moy {avg:5.1f}   min {min(core):5.1f}   max {max(core):5.1f}   "
          f"{rows[end-1][0]} trames jouees / {rows[-1][0]} relevees")
