#!/usr/bin/env python3
"""Controler la derive des wicks releves par object_track_probe.py (ids 54).

    python3 tools/wick_track_check.py <releve.txt>

Le wick n'est pas deterministe (sa cible verticale est tiree a chaque
tour), mais chaque PAS l'est : entre deux echantillons d'un meme wick en
derive (routine 1), separes de d trames de jeu,
  - x a recule d'exactement 144 x d (1/256 px, difficulte 0),
  - y a bouge de osc + track, ou osc = +/-48 x d selon le bit 6 de la phase
    d'ondulation A LA FIN du tour (wick.uOsc, ext+15 : le wick avance sa
    phase de d PUIS lit le bit) et track = +/-12 x d, le signe etant le
    seul aleas.
Un tour rendu = un pas de d trames, donc la relation vaut entre deux
releves consecutifs (object_track_probe.py releve a chaque RunObjects).
d n'est PAS l'ecart d'horloge de jeu (l'IRQ l'incremente a son heure, le
drop du tour est latche a une autre) : c'est l'avance du compteur
d'animation du wick (ext+16), qui vaut exactement le drop du tour. Le pas
est borne a 32 trames (wick.STRIDE) : au-dela la relation ne tient plus,
ces intervalles sont ignores.
"""
import re
import sys

VX, VTRACK, VOSC, STRIDE = 144, 12, 48, 32


def main(path):
    prev = {}
    ok = bad = 0
    for l in open(path):
        m = re.match(r'\s*(\d+) t\s+(\d+) slot\s+(\d+) id (\d+) rt (\d) sub\s+(\d+) x\s+(\d+)\.([0-9A-F]{2}) y\s+(\d+)\.([0-9A-F]{2}) anim\s+\d+ ext ([0-9A-F]+)', l)
        if not m:
            continue
        f, t, slot, _, rt, _, xi, xf, yi, yf, ext = m.groups()
        key = int(slot)
        t = int(t)
        X = ((int(xi) << 8) | int(xf, 16)) & 0xFFFFFF
        Y = ((int(yi) << 8) | int(yf, 16)) & 0xFFFFFF
        osc = int(ext[12:14], 16)                  # ext+15 = octet 6 de la tranche 9..19
        anim = int(ext[14:16], 16)                 # ext+16 : += drop a chaque tour
        if rt != '1':
            prev.pop(key, None)
            continue
        if key in prev:
            t0, X0, Y0, osc0, anim0 = prev[key]
            d = (anim - anim0) & 0xFF
            if 0 < d <= STRIDE:
                dx = (X - X0) & 0xFFFFFF
                dx = dx - 0x1000000 if dx >= 0x800000 else dx
                dy = (Y - Y0) & 0xFFFFFF
                dy = dy - 0x1000000 if dy >= 0x800000 else dy
                o = VOSC * d if osc & 0x40 else -VOSC * d
                if dx == -VX * d and dy in (o + VTRACK * d, o - VTRACK * d):
                    ok += 1
                else:
                    bad += 1
                    if bad <= 10:
                        print('slot %2d t %d -> %d (d=%d) : dx=%d attendu %d ; dy=%d attendu %d ou %d (osc %02X)'
                              % (key, t0, t, d, dx, -VX * d, dy, o + VTRACK * d, o - VTRACK * d, osc))
        prev[key] = (t, X, Y, osc, anim)
    print('%d pas conformes, %d en defaut' % (ok, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
