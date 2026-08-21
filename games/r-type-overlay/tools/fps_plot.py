#!/usr/bin/env python3
"""Le graphe d'un releve de cadence, depuis un fps.csv.

    python3 tools/fps_plot.py dist/stage2-fps/fps.csv [titre]

Sorti de warship_fps.py pour deux raisons : iterer sur la presentation ne doit
pas couter une nouvelle campagne d'emulation, et comparer deux releves (avant
et apres une optimisation) demande de retracer sans remesurer.

Ce que le graphe ajoute au nuage de points : les PHASES, lues dans la colonne
camera que le releve enregistre deja. Une camera qui avance = la traversee ;
une camera immobile assez longtemps = un combat de boss (le boss fige le
defilement) ; ce qui suit = la sortie de niveau. Chaque phase porte sa moyenne,
parce que c'est elle qu'on compare d'une mesure a l'autre. Le creux soutenu le
plus long est encadre a part : c'est la cible d'optimisation, et la mesurer
avant de toucher au code est tout l'interet du releve.
"""
import csv, sys, os

W, H = 1180, 660
ML, MR, MT, MB = 66, 26, 108, 270
PW, PH = W - ML - MR, H - MT - MB
YMAX = 14.0


def load(path):
    rows = []
    for r in csv.DictReader(open(path)):
        rows.append(dict(trame=int(r['trame']), seconde=float(r['seconde']),
                         camera=int(r['camera']), boucles=int(r['boucles']),
                         fps=float(r['fps'])))
    return rows


def phases(rows):
    """(nom, i0, i1) — decoupe par le comportement de la camera."""
    if not rows:
        return []
    cam = [r['camera'] for r in rows]
    top = max(cam)
    # la plus longue plage ou la camera ne bouge plus ET n'est pas encore au
    # bout de la carte : c'est le boss qui la tient
    best = (0, -1, -1)
    i = 0
    while i < len(rows):
        j = i
        while j + 1 < len(rows) and cam[j + 1] == cam[i]:
            j += 1
        if j - i > best[0] and cam[i] < top:
            best = (j - i, i, j)
        i = j + 1
    out = []
    if best[1] < 0 or best[0] < 4:
        return [('stage', 0, len(rows) - 1)]
    if best[1] > 0:
        out.append(('traversee', 0, best[1] - 1))
    out.append(('combat du boss (scroll fige)', best[1], best[2]))
    if best[2] < len(rows) - 1:
        out.append(('sortie de niveau', best[2] + 1, len(rows) - 1))
    return out


def trough(rows, phs):
    """La plus longue plage soutenue sous 70 % de la moyenne generale."""
    good = [r for r in rows if r['fps'] > 0]
    if not good:
        return None
    avg = sum(r['fps'] for r in good) / len(good)
    lim = avg * 0.7
    best = (0, -1, -1)
    i = 0
    while i < len(rows):
        if rows[i]['fps'] == 0 or rows[i]['fps'] > lim:
            i += 1
            continue
        j = i
        while j + 1 < len(rows) and 0 < rows[j + 1]['fps'] <= lim:
            j += 1
        if j - i > best[0]:
            best = (j - i, i, j)
        i = j + 1
    return None if best[0] < 3 else best[1:]


def plot(rows, path, title, ref=None, ref_label='avant'):
    span = rows[-1]['trame']
    total = sum(r['boucles'] for r in rows)
    avg = total * 50.0 / span
    serie = [(r['trame'] / 50.0, r['fps']) for r in rows]
    xmax = max(x for x, _ in serie)
    X = lambda v: ML + PW * v / xmax
    Y = lambda v: MT + PH * (1 - min(v, YMAX) / YMAX)

    sv = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
          'viewBox="0 0 %d %d" font-family="ui-sans-serif,system-ui,sans-serif">' % (W, H, W, H),
          '<rect width="%d" height="%d" fill="#12141a"/>' % (W, H),
          '<text x="%d" y="34" fill="#e8eaf0" font-size="19" font-weight="600">%s</text>'
          % (ML, title),
          '<text x="%d" y="56" fill="#8b93a7" font-size="12.5">'
          '%d boucles de jeu sur %d trames video (%.0f s) — mode invincible, sans joueur. '
          'Moyenne %.2f fps, soit %.2f trames video par boucle.</text>'
          % (ML, total, span, span / 50.0, avg, 50.0 / avg),
          '<text x="%d" y="75" fill="#8b93a7" font-size="12.5">'
          'Une boucle = un tour de stage.loop (temoin bench.frames, $87DD). '
          'Chaque point = les boucles terminees dans une fenetre de %d trames video.</text>'
          % (ML, rows[1]['trame'] - rows[0]['trame'] if len(rows) > 1 else 50)]

    # --- les phases, en fond ---
    band = ['#1b2130', '#2a1f2e', '#1b2a26']
    for k, (name, i0, i1) in enumerate(phases(rows)):
        x0, x1 = X(rows[i0]['trame'] / 50.0), X(rows[i1]['trame'] / 50.0)
        sub = rows[i0:i1 + 1]
        b = sum(r['boucles'] for r in sub)
        nf = rows[i1]['trame'] - rows[i0]['trame'] + (rows[1]['trame'] - rows[0]['trame'])
        sv.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>'
                  % (x0, MT, max(x1 - x0, 1), PH, band[k % len(band)]))
        sv.append('<text x="%.1f" y="%.1f" fill="#7e879c" font-size="11.5" '
                  'text-anchor="middle">%s</text>' % ((x0 + x1) / 2, MT - 22, name))
        sv.append('<text x="%.1f" y="%.1f" fill="#aab3c6" font-size="12" font-weight="600" '
                  'text-anchor="middle">%.2f fps</text>'
                  % ((x0 + x1) / 2, MT - 6, b * 50.0 / nf))

    # --- grille ---
    for v in (12.5, 10, 50 / 6.0, 50 / 7.0, 50 / 8.0):
        y = Y(v)
        sv.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#2b3040" '
                  'stroke-width="1" stroke-dasharray="4 4"/>' % (ML, y, ML + PW, y))
        sv.append('<text x="%.1f" y="%.1f" fill="#5d6579" font-size="10.5" text-anchor="end">'
                  '%.1f</text>' % (ML - 8, y + 3.5, v))
        sv.append('<text x="%.1f" y="%.1f" fill="#3f4657" font-size="10">'
                  '%d trames video / boucle</text>' % (ML + PW - 118, y - 5, round(50.0 / v)))
    for sec in range(0, int(xmax) + 1, 20):
        x = X(sec)
        sv.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#20242f"/>'
                  % (x, MT, x, MT + PH))
        sv.append('<text x="%.1f" y="%.1f" fill="#5d6579" font-size="10.5" '
                  'text-anchor="middle">%d s</text>' % (x, MT + PH + 17, sec))

    # --- le creux soutenu : la cible ---
    tr = trough(rows, None)
    if tr:
        i0, i1 = tr
        x0, x1 = X(rows[i0]['trame'] / 50.0), X(rows[i1]['trame'] / 50.0)
        sub = rows[i0:i1 + 1]
        f = sum(r['fps'] for r in sub) / len(sub)
        sv.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" '
                  'stroke="#ff6b6b" stroke-width="1.2" stroke-dasharray="5 3"/>'
                  % (x0, MT, max(x1 - x0, 1), PH))
        sv.append('<text x="%.1f" y="%.1f" fill="#ff6b6b" font-size="11.5" font-weight="600" '
                  'text-anchor="middle">creux soutenu — %.1f fps sur %.0f s</text>'
                  % ((x0 + x1) / 2, MT + PH + 38, f,
                     (rows[i1]['trame'] - rows[i0]['trame']) / 50.0))

    # --- chargements disque ---
    loads = [r['trame'] for r in rows if r['boucles'] == 0]
    for f in loads:
        x = X(f / 50.0)
        sv.append('<rect x="%.1f" y="%.1f" width="6" height="%.1f" fill="#ffb454" '
                  'opacity="0.30"/>' % (x - 3, MT, PH))
    if loads:
        sv.append('<text x="%.1f" y="%.1f" fill="#ffb454" font-size="10.5">'
                  '| chargement disque (%d)</text>' % (ML + PW - 150, MT - 22, len(loads)))

    # --- la courbe de reference (avant/apres) ---
    if ref:
        rs = [(r['trame'] / 50.0, r['fps']) for r in ref]
        rspan = ref[-1]['trame']
        ravg = sum(r['boucles'] for r in ref) * 50.0 / rspan
        rp = ' '.join('%.1f,%.1f' % (X(a), Y(b)) for a, b in rs if a <= xmax)
        sv.append('<polyline points="%s" fill="none" stroke="#6b7488" '
                  'stroke-width="1.2" stroke-dasharray="3 3"/>' % rp)
        sv.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#6b7488" '
                  'stroke-width="1" stroke-dasharray="3 3"/>' % (ML, Y(ravg), ML + PW, Y(ravg)))
        sv.append('<text x="%.1f" y="%.1f" fill="#6b7488" font-size="11">'
                  '%s : %.2f fps</text>' % (ML + 8, Y(ravg) + 14, ref_label, ravg))
        gain = (avg - ravg) / ravg * 100.0
        sv.append('<text x="%d" y="94" fill="#7ee081" font-size="12.5" font-weight="600">'
                  'gain %+.1f %% sur le stage entier (%.2f -> %.2f fps)</text>'
                  % (ML, gain, ravg, avg))

    # --- la courbe ---
    pts = ' '.join('%.1f,%.1f' % (X(a), Y(b)) for a, b in serie)
    sv.append('<polygon points="%.1f,%.1f %s %.1f,%.1f" fill="#4ea3ff" opacity="0.13"/>'
              % (ML, MT + PH, pts, ML + PW, MT + PH))
    sv.append('<polyline points="%s" fill="none" stroke="#4ea3ff" stroke-width="1.5" '
              'stroke-linejoin="round"/>' % pts)
    sv.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ffb454" '
              'stroke-width="1.4"/>' % (ML, Y(avg), ML + PW, Y(avg)))
    sv.append('<text x="%.1f" y="%.1f" fill="#ffb454" font-size="11">moyenne %.2f fps</text>'
              % (ML + 8, Y(avg) - 7, avg))
    sv.append('<text x="16" y="%.1f" fill="#8b93a7" font-size="11" '
              'transform="rotate(-90 16 %.1f)" text-anchor="middle">images par seconde</text>'
              % (MT + PH / 2, MT + PH / 2))

    # --- repartition ---
    from collections import Counter
    hist = Counter(r['fps'] for r in rows)
    hy = MT + PH + 78
    sv.append('<text x="%d" y="%d" fill="#e8eaf0" font-size="14" font-weight="600">'
              'Repartition</text>' % (ML, hy))
    sv.append('<text x="%d" y="%d" fill="#8b93a7" font-size="11.5">'
              'part du temps passe a chaque cadence</text>' % (ML, hy + 17))
    ks = sorted(hist)
    bw = min(132, int(PW / max(1, len(ks))))
    bx = ML
    for k in ks:
        pct = 100.0 * hist[k] / len(rows)
        bh = 96 * hist[k] / max(hist.values())
        sv.append('<rect x="%.1f" y="%.1f" width="%d" height="%.1f" fill="#4ea3ff" rx="2"/>'
                  % (bx, hy + 138 - bh, bw - 12, bh))
        sv.append('<text x="%.1f" y="%.1f" fill="#e8eaf0" font-size="11" text-anchor="middle">'
                  '%.0f %%</text>' % (bx + (bw - 12) / 2, hy + 132 - bh, pct))
        sv.append('<text x="%.1f" y="%.1f" fill="#8b93a7" font-size="11" text-anchor="middle">'
                  '%.0f</text>' % (bx + (bw - 12) / 2, hy + 155, k))
        bx += bw
    sv.append('<text x="%.1f" y="%.1f" fill="#5d6579" font-size="10.5">fps</text>'
              % (ML, hy + 172))
    sv.append('</svg>')
    open(path, 'w').write('\n'.join(sv))
    return avg


if __name__ == '__main__':
    # usage : fps_plot.py <releve.csv> [titre] [--vs <reference.csv>]
    args = sys.argv[1:]
    ref = None
    if '--vs' in args:
        i = args.index('--vs')
        ref = load(args[i + 1])
        args = args[:i] + args[i + 2:]
    src = args[0]
    title = args[1] if len(args) > 1 else 'R-Type TO8 — cadence'
    rows = load(src)
    dst = os.path.join(os.path.dirname(os.path.abspath(src)), 'fps.svg')
    print('%s  (moyenne %.2f fps)' % (dst, plot(rows, dst, title, ref)))
