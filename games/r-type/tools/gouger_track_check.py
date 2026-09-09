#!/usr/bin/env python3
"""Confronter un releve de object_track_probe.py (gougers) a la simulation des profils.

    python3 tools/gouger_track_check.py <releve.txt>

Pour chaque gouger releve en plongee (routine 2), la simulation de
gen_gouger_profiles.py (memes constantes, meme masque) donne la position a
chaque trame de jeu depuis le depart de la plongee. Le depart n'est pas
releve (il tombe entre deux rendus) : on le retrouve en cherchant, pour le
premier echantillon, le rang k dont la position simulee coincide, puis
chaque echantillon suivant doit tomber sur sim[k + (t - t0)] — a la
fraction pres, moins le pixel de calage (gouger.Snap ote 1 a x avant le
dessin, sur les positions impaires par rapport a la camera : on tolere x
ou x + 1).
"""
import os
import re
import sys

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, 'tools')
import gen_gouger_profiles as G


def positions(mask, x_spawn, var):
    X = x_spawn * 256
    Y = G.PRESET_Y[var] * 256
    out = []
    for _ in range(G.MAX_FRAMES):
        x_int, y_int = X >> 8, Y >> 8
        out.append((X & 0xFFFFFF, Y & 0xFFFFFF))
        if y_int < G.Y_MIN or y_int > G.Y_MAX:
            break
        crawl = G.solid(mask, x_int, y_int)
        vx, vy = (G.VEL_TRAIL if crawl else G.VEL_PRIM)[var]
        X += vx
        Y += vy
    return out


def main(path):
    mask = open(G.MASK, 'rb').read()
    wave = open(G.WAVE).read()
    pat = re.compile(r'^\s*fcb\s+\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2}),ObjID_gouger,\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2})', re.M)
    prof = {}
    for m in pat.finditer(wave):
        t = int(m.group(1) + m.group(2), 16)
        idx = int(m.group(3), 16)
        var = int(m.group(4), 16) & 3
        x_spawn = (G.SCROLL_NUM * t) // G.SCROLL_DEN + G.SPAWN_X
        prof[idx] = (var, x_spawn, positions(mask, x_spawn, var))
    samples = {}
    for l in open(path):
        m = re.match(r'\s*(\d+) t\s+(\d+) slot\s+(\d+) id (\d+) rt (\d) sub\s+(\d+) x\s+(\d+)\.([0-9A-F]{2}) y\s+(\d+)\.([0-9A-F]{2})', l)
        if not m:
            continue
        f, t, slot, _, rt, sub, xi, xf, yi, yf = m.groups()
        if rt != '2':
            continue
        key = (int(slot), int(sub))
        X = ((int(xi) << 8) | int(xf, 16)) & 0xFFFFFF
        Y = ((int(yi) << 8) | int(yf, 16)) & 0xFFFFFF
        y_int = int(yi) if int(yi) < 32768 else int(yi) - 65536
        if y_int < G.Y_MIN or y_int > G.Y_MAX:
            continue                     # deja hors cadre : au-dela de l'horizon
                                         # de la simulation, Frame l'ote au rendu suivant
        samples.setdefault(key, []).append((int(t), X, Y))
    ok = bad = 0
    for (slot, idx), pts in sorted(samples.items(), key=lambda kv: kv[1][0][0]):
        var, x_spawn, sim = prof[idx]
        t0, X0, Y0 = pts[0]
        ks = [k for k, (sx, sy) in enumerate(sim) if sy == Y0 and sx in (X0, X0 + 256)]
        if not ks:
            print('profil %2d slot %2d : premier echantillon t=%d x=%d.%02X y=%d.%02X absent de la simulation'
                  % (idx, slot, t0, X0 >> 8, X0 & 255, Y0 >> 8, Y0 & 255))
            bad += 1
            continue
        k0 = ks[0]
        errs = []
        for t, X, Y in pts[1:]:
            k = k0 + (t - t0)
            if k >= len(sim):
                break
            sx, sy = sim[k]
            if sy != Y or sx not in (X, X + 256):
                errs.append((t, X, Y, sx, sy))
        if errs:
            bad += 1
            t, X, Y, sx, sy = errs[0]
            print('profil %2d slot %2d : %d/%d echantillons faux, premier a t=%d : releve %d.%02X,%d.%02X simule %d.%02X,%d.%02X'
                  % (idx, slot, len(errs), len(pts) - 1, t, X >> 8, X & 255, Y >> 8, Y & 255,
                     sx >> 8, sx & 255, sy >> 8, sy & 255))
        else:
            ok += 1
            print('profil %2d slot %2d : %3d echantillons de plongee = la simulation (depart trame %d)'
                  % (idx, slot, len(pts), t0 - k0))
    print('%d profils conformes, %d en defaut' % (ok, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
