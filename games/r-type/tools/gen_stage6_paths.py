#!/usr/bin/env python3
"""Precalcule les trajets des Dops et des Newts de la wave du stage 6.

Ni le Dop (40:5F3C) ni le Newt (40:72D2) ne tirent au hasard : ils avancent a
vitesse fixe et tournent sur la reponse d'une sonde de la carte de tuiles,
elle-meme fixe ; la camera du stage est min(g / 2, 2684). Tout le trajet d'un
objet de la wave est donc une fonction de sa trame de naissance et de son
jeton. Ce script rejoue la borne objet par objet (les modeles verifies contre
la trace MAME : dop6/newt6) et n'ecrit que les CHANGEMENTS :

  {trame absolue, etat}   etat = la voie (Dop), la phase (Newt),
                           +$80 : la gigue (Newt coince : la phase bascule
                           apres chaque trame), $FF : sorti de l'ecran

L'evenement de la trame g s'applique APRES le deplacement de cette trame,
comme le virage de la borne. Le runtime n'a plus de sonde : il avance et
compare une trame (src/enemies/dop/dops.asm, src/enemies/newt/obj.asm).

Deux horloges de naissance : depuis le debut du stage, et depuis la reprise
au checkpoint ($0C80 : la wave repart apres 3200, la file d'une creation par
trame vide) ; une naissance qui differe a son propre trajet.

Sortie : src/stages/06/paths.asm.
Rejeu : python3 tools/gen_stage6_paths.py (depuis games/r-type/) ;
        python3 tools/gen_stage6_paths.py --check dit si la sortie est a jour.
"""
import os
import re
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
WAVE = 'src/stages/06/wave.asm'
MAP = 'src/stages/06/terrain/level6_fc.bin'   # 48 octets par rangee, 30 rangees
OUT = 'src/stages/06/paths.asm'
CAMSTOP = 2684
CHECKPOINT = 0x0C80
END = 9000                    # au-dela du stage : un Newt coince y reste

# La fraction de y d'un Newt neuf : create_newt (40:7294) pose la partie
# entiere et LAISSE la fraction du dernier occupant de l'enregistrement. A un
# pixel pres elle decide de la trame d'un virage (8 px d'ecart ensuite). Elle
# depend de la partie jouee ; celle-ci est la partie de reference (trace MAME
# du stage 6, vaisseau epingle : PILOT_PLAYER=513,223), relevee a la premiere
# apparition de chaque enregistrement — par naissance, 0 sinon.
NEWT_YFRAC = {
    16: 21, 17: 35, 400: 98, 401: 73, 552: 29, 680: 176, 980: 191,
    1382: 90, 1528: 194, 1648: 209, 2384: 195, 3700: 176, 3798: 88,
    3840: 240, 3932: 90, 4080: 67, 4262: 141, 4263: 163, 4624: 129,
    4625: 18, 4884: 245, 5272: 20, 5280: 6,
}


def cam(g):
    return min(g // 2, CAMSTOP)


def visible(x, y):
    """is_visible_range 40:1D6B"""
    return ((x - 300) & 0xFFFF) < 424 and ((y - 124) & 0xFFFF) < 280


class Arcade:
    def __init__(self, rom, fc):
        self.rom, self.fc = rom, fc

    def w16(self, a):
        return struct.unpack_from('<H', self.rom, SEG + a)[0]

    def s16(self, a):
        return struct.unpack_from('<h', self.rom, SEG + a)[0]

    def solid(self, wx, y, ring=None):
        """probe_foreground_tile 40:1E6C sur la carte du stage ; ring : la
        derniere tuile de 64 px dans la RAM de tuiles (64 colonnes)"""
        col = (wx - 320) >> 3
        row = max(0, 0x17F - y) >> 3
        if ring is not None:
            while (col >> 3) > ring:
                col -= 64
            while (col >> 3) < ring - 7:
                col += 64
        if not (0 <= row < 30) or not (0 <= col < 384):
            return False
        return bool(self.fc[row * 48 + (col >> 3)] & (0x80 >> (col & 7)))


def move(pos, v):
    return (pos + (v - 0x10000 if v & 0x8000 else v)) & 0xFFFFFF


def ipart(pos):
    return (pos >> 8) & 0xFFFF


def dop_path(A, g0, tok):
    """40:5F3C, depuis la naissance a g0 ; -> [(g, etat)]"""
    b = 0x9324 + (tok & 0xF) * 6
    x = ((A.w16(b) + cam(g0)) & 0xFFFF) << 8
    y = A.w16(b + 2) << 8
    lane = A.w16(b + 4) & 0xFF
    turn = 1 if tok & 0x100 else -1
    look = 0x2A40 + (0x20 if tok & 0x40 else 0)
    vel = 0x2A80 + A.w16(0x931C + ((tok >> 4) & 3) * 2)
    ev = []
    g = g0
    while g < END:
        g += 1
        v = vel + lane * 4
        x = move(x, A.w16(v))
        y = move(y, A.w16(v + 2))
        xi, yi = ipart(x), ipart(y)
        xs = (xi - cam(g)) & 0xFFFF
        if not visible(xs, yi):
            ev.append((g, 0xFF))
            return ev
        la = look + lane * 8
        px = (xs + A.s16(la)) & 0xFFFF
        py = (yi + A.s16(la + 2)) & 0xFFFF
        for _ in range(3):
            if px < 0x2C0 and A.solid(px + cam(g), py):
                lane = (lane + turn) & 3
                ev.append((g, lane))
                break
            px = (px + A.s16(la + 4)) & 0xFFFF
            py = (py + A.s16(la + 6)) & 0xFFFF
    return ev


def newt_path(A, g0, tok):
    """40:72D2, depuis la naissance a g0 ; -> [(g, etat)], gigues repliees"""
    b = 0x93DC + (tok & 0xF) * 4
    x = ((A.w16(b) + cam(g0)) & 0xFFFF) << 8
    y = A.w16(b + 2) << 8 | NEWT_YFRAC.get(g0, 0)
    ph = ((tok >> 8) & 1) * 2
    flips = []                  # (g, phase apres la trame g)
    g = g0
    gone = None
    while g < END:
        g += 1
        v = 0x329E + ph * 4
        x = move(x, A.w16(v))
        y = move(y, A.w16(v + 2))
        xi, yi = ipart(x), ipart(y)
        xs = (xi - cam(g)) & 0xFFFF
        p = 0x32AE + ph * 4
        px = (xs + A.s16(p)) & 0xFFFF
        py = (yi + A.s16(p + 2)) & 0xFFFF
        o = ph
        if not visible(px, py):
            ph ^= 1
        if not A.solid(px + cam(g), py, (cam(g - 1) >> 6) + 6):
            ph ^= 1
        if ph != o:
            flips.append((g, ph))
        if not visible(xs, yi):
            gone = g            # (une bascule de cette trame ne sert plus)
            if flips and flips[-1][0] == g:
                flips.pop()
            break
    # une suite de bascules a chaque trame devient une gigue : l'etat +$80
    # a la premiere, l'etat simple a la derniere
    ev = []
    i = 0
    while i < len(flips):
        j = i
        while j + 1 < len(flips) and flips[j + 1][0] == flips[j][0] + 1:
            j += 1
        if j > i:
            ev.append((flips[i][0], flips[i][1] | 0x80))
            ev.append((flips[j][0], flips[j][1]))
        else:
            ev.append(flips[i])
        i = j + 1
    if gone is not None:
        ev.append((gone, 0xFF))
    return ev


def decode_newt(A, g0, tok, ev, g1):
    """le runtime, rejoue : la position et la phase de chaque trame"""
    b = 0x93DC + (tok & 0xF) * 4
    x = ((A.w16(b) + cam(g0)) & 0xFFFF) << 8
    y = A.w16(b + 2) << 8 | NEWT_YFRAC.get(g0, 0)
    ph, jig, k, out = ((tok >> 8) & 1) * 2, 0, 0, []
    for g in range(g0 + 1, g1 + 1):
        v = 0x329E + ph * 4
        x = move(x, A.w16(v))
        y = move(y, A.w16(v + 2))
        if jig:
            ph ^= 1
        if k < len(ev) and ev[k][0] == g:
            if ev[k][1] == 0xFF:
                break
            ph, jig = ev[k][1] & 3, ev[k][1] & 0x80
            k += 1
        out.append((x, y, ph))
    return out


def newt_frames(A, g0, tok, g1):
    """le modele, trame par trame, pour la verification du replie"""
    b = 0x93DC + (tok & 0xF) * 4
    x = ((A.w16(b) + cam(g0)) & 0xFFFF) << 8
    y = A.w16(b + 2) << 8 | NEWT_YFRAC.get(g0, 0)
    ph, out = ((tok >> 8) & 1) * 2, []
    for g in range(g0 + 1, g1 + 1):
        v = 0x329E + ph * 4
        x = move(x, A.w16(v))
        y = move(y, A.w16(v + 2))
        xi, yi = ipart(x), ipart(y)
        xs = (xi - cam(g)) & 0xFFFF
        p = 0x32AE + ph * 4
        px = (xs + A.s16(p)) & 0xFFFF
        py = (yi + A.s16(p + 2)) & 0xFFFF
        if not visible(px, py):
            ph ^= 1
        if not A.solid(px + cam(g), py, (cam(g - 1) >> 6) + 6):
            ph ^= 1
        if not visible(xs, yi):
            break
        out.append((x, y, ph))
    return out


def births():
    """la wave, file d'une creation par trame (OBJECTWAVE_ONE_PER_FRAME) :
    -> {kind: [(g, jeton)]} depuis le debut et depuis le checkpoint"""
    ents = []
    for line in open(WAVE):
        m = re.match(r'\s*fcb\s+\$([0-9A-F]{2}),\$([0-9A-F]{2}),(\w+),'
                     r'\$([0-9A-F]{2}),\$([0-9A-F]{2})', line)
        if m:
            ents.append((int(m.group(1) + m.group(2), 16), m.group(3),
                         int(m.group(4) + m.group(5), 16)))
    out = {'ObjID_dop': set(), 'ObjID_newt': set()}
    for start, last in ((0, -1), (CHECKPOINT, CHECKPOINT)):
        for T, kind, tok in ents:
            if T == 0 or T <= start and start:
                continue
            last = max(T, last + 1)
            if kind in out:
                out[kind].add((last, tok))
    return {k: sorted(v) for k, v in out.items()}


def render(A):
    b = births()
    L = ['; GENERE par tools/gen_stage6_paths.py — ne pas editer.',
         '; Les trajets des Dops et des Newts de la wave, rejoues sur la carte',
         '; du stage : {trame absolue, etat}, l\'etat applique APRES le',
         '; deplacement de sa trame ; $FF sorti de l\'ecran, +$80 la gigue.',
         '; Un chemin de Newt est precede de la fraction de y de sa naissance.',
         '']
    body = []
    for kind, name, fn in (('ObjID_dop', 'dop', dop_path),
                           ('ObjID_newt', 'newt', newt_path)):
        L.append('; {naissance, chemin}, $FFFF au bout')
        L.append('%s.Paths' % name)
        for i, (g0, tok) in enumerate(b[kind]):
            ev = fn(A, g0, tok)
            if kind == 'ObjID_newt':
                end = ev[-1][0] if ev and ev[-1][1] == 0xFF else END
                if decode_newt(A, g0, tok, ev, end) != newt_frames(A, g0, tok, end):
                    raise SystemExit('newt %d : replie infidele' % g0)
            lbl = '%s.path%02d' % (name, i)
            L.append('        fdb   %d,%s  ; jeton $%04X' % (g0, lbl, tok))
            if kind == 'ObjID_newt':   # sa fraction de y, juste avant
                body.append('        fcb   %d' % NEWT_YFRAC.get(g0, 0))
            body.append(lbl)
            for g, s in ev:
                body.append('        fdb   %d' % g)
                body.append('        fcb   $%02X' % s)
            body.append('        fdb   $FFFF')
        L.append('        fdb   $FFFF')
        L.append('')
    return '\n'.join(L + body) + '\n'


def main():
    A = Arcade(open(ROM, 'rb').read(), open(MAP, 'rb').read())
    text = render(A)
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text
                           else 'PERIME — relancer tools/gen_stage6_paths.py'))
        return 0 if cur == text else 1
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
