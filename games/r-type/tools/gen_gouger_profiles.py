#!/usr/bin/env python3
"""Le profil de plongee de chaque gouger, PRECALCULE (idee auteur, 08/09/2026).

    python3 tools/gen_gouger_profiles.py

Lit src/stages/02/wave.asm (les gougers actifs, dans l'ordre) et le masque
src/stages/02/terrain/level2_gouger.bin (le decor tel que le gouger le sonde :
tout sauf 0xFA0, tools/gen_gouger_mask.py), ecrit
src/stages/02/gouger-profiles.asm et numerote les gougers dans la wave
(le 4e octet du descripteur, l'index de profil).

POURQUOI C'EST EXACT. Le gouger ne bouge pas dans le monde en attente (la
borne le verrouille sur le defilement, nous le posons en coordonnees
playfield) : sa plongee part TOUJOURS de sa position de spawn, quel que soit
le declencheur — compte a rebours ou guet du joueur. La carte est statique.
La suite de verdicts « case vide -> plongee, case solide -> reptation »,
trame de jeu par trame de jeu, ne depend donc que du gouger : elle se
calcule ici une fois, et le runtime la rejoue sans sonder le decor. Le
recul (23 trames sans deplacement) et la mort ne changent rien a la
trajectoire, ils la retardent ou l'interrompent.

LA POSITION DE SPAWN. La borne pose l'objet a x = $02D0 quand frame_time
atteint l'horodatage ; en v2 : camera + 158 a l'instant arcade. La camera
avance de 3/16 px par trame de jeu (stage.SCROLL_VEL $0030) depuis 0 a
l'horloge 0 — le point de reprise pose camera = 24 x tuile et horloge =
128 x tuile, le meme rapport. x_spawn = floor(3t/16) + 158, fraction nulle.
Le runtime PREND cette valeur (au lieu de camera + 158 - retard x vitesse,
qui pouvait tomber 1 px a gauche selon l'arrondi) : la trajectoire est la
meme a chaque partie, quel que soit le debit du rendu.

LA SIMULATION est l'arithmetique du runtime : positions 16.8 sur trois
octets, vitesses 8.8 des tables de gouger/obj.asm, sonde a la cellule 3x6
contenant l'entier de la position — colonne = x div 3 (monde), rangee =
(y - 11) div 6, bornee a [0, 29] comme la borne borne la sienne a la
rangee 0 (probe_foreground_tile, `0x17F - y` ecrete a zero). L'ordre
arcade, run_gouger 7048 : sonde PUIS deplacement, chaque trame.

FORMAT d'un profil : x_spawn (fdb), puis des octets de run — bit 7 = 1
reptation / 0 plongee, bits 0-6 = nombre de trames (1..127, les runs plus
longs sont coupes), 0 = fin : le runtime garde alors le dernier mode, le
gouger etant deja hors cadre (la simulation s'arrete quand y sort de
-6..204, les bornes de gouger.Frame, ou a 512 trames).
"""
import os
import re
import sys

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WAVE = 'src/stages/02/wave.asm'
MASK = 'src/stages/02/terrain/level2_gouger.bin'
OUT = 'src/stages/02/gouger-profiles.asm'
W, H = 384, 30                       # cellules de la carte (48 octets x 30 rangees)
SCROLL_NUM, SCROLL_DEN = 3, 16       # 3/16 px par trame ($0030 en 8.8)
SPAWN_X = 158                        # (720 - 320) x 0,375 + 8, comme gouger.Init
PRESET_Y = (15, 15, 183, 183)        # gouger.PresetY
VEL_PRIM = ((144, 384), (-144, 384), (144, -384), (-144, -384))   # gouger.VelPrim
VEL_TRAIL = ((36, 96), (-36, 96), (36, -96), (-36, -96))          # gouger.VelTrail
VP_Y = 11                            # scroll_vp_y_pos : la rangee 0 commence a y = 11
# gouger.MovePrim/MoveTrail n'ont plus de table : elles DECALENT (9n << 4, 3n << 7,
# 9n << 2, 3n << 5) et le signe vient de la variante. Ces constantes en sont la
# seule autre copie : changer l'une sans l'autre desynchroniserait le jeu de sa
# simulation.
assert [abs(v) for v in VEL_PRIM[0]] == [9 << 4, 3 << 7], VEL_PRIM
assert [abs(v) for v in VEL_TRAIL[0]] == [9 << 2, 3 << 5], VEL_TRAIL
assert all((vx < 0) == bool(var & 1) and (vy < 0) == bool(var & 2)
           for var, (vx, vy) in enumerate(VEL_PRIM)), 'signes = bits de la variante'
Y_MIN, Y_MAX = -6, 204               # gouger.Frame
MAX_FRAMES = 512


def solid(mask, x_int, y_int):
    col = x_int // 3
    row = (y_int - VP_Y) // 6
    row = max(0, min(H - 1, row))
    if col < 0 or col >= W:
        return False
    return (mask[row * 48 + col // 8] >> (7 - col % 8)) & 1 == 1


def simulate(mask, x_spawn, var):
    """Les verdicts par trame de jeu, depuis la position de spawn."""
    X = x_spawn * 256                # 16.8, fraction nulle (gouger.Init)
    Y = PRESET_Y[var] * 256
    verdicts = []
    for _ in range(MAX_FRAMES):
        x_int, y_int = X >> 8, Y >> 8
        if y_int < Y_MIN or y_int > Y_MAX:
            break
        crawl = solid(mask, x_int, y_int)
        verdicts.append(crawl)
        vx, vy = (VEL_TRAIL if crawl else VEL_PRIM)[var]
        X += vx
        Y += vy
    return verdicts


def runs(verdicts):
    out = []
    for v in verdicts:
        if out and out[-1][0] == v and out[-1][1] < 127:
            out[-1][1] += 1
        else:
            out.append([v, 1])
    return out


def main():
    mask = open(MASK, 'rb').read()
    if len(mask) != W * H // 8:
        raise SystemExit('%s : %d octets, attendu %d' % (MASK, len(mask), W * H // 8))
    lines = open(WAVE).read().split('\n')
    pat = re.compile(r'^(\s*fcb\s+)\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2}),ObjID_gouger,\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2})(.*)$')
    profiles = []
    for i, l in enumerate(lines):
        m = pat.match(l)
        if not m:
            continue
        idx = len(profiles)
        t = int(m.group(2) + m.group(3), 16)
        param = int(m.group(5), 16)
        var = param & 3
        x_spawn = (SCROLL_NUM * t) // SCROLL_DEN + SPAWN_X
        r = runs(simulate(mask, x_spawn, var))
        profiles.append((idx, t, var, param, x_spawn, r))
        lines[i] = '%s$%s,$%s,ObjID_gouger,$%02X,$%s%s' % (m.group(1), m.group(2), m.group(3),
                                                           idx, m.group(5), m.group(6))
    if not profiles:
        raise SystemExit('aucun gouger actif dans %s' % WAVE)
    if len(profiles) > 64:
        raise SystemExit('%d gougers : l\'index tient sur un octet signe x 2 (64 au plus)' % len(profiles))
    open(WAVE, 'w').write('\n'.join(lines))

    out = ['; GENERE par tools/gen_gouger_profiles.py — ne pas editer a la main.',
           '; Un profil par gouger de la wave : x de spawn (monde), puis les runs',
           '; bit 7 = 1 reptation / 0 plongee, bits 0-6 = trames ; 0 = fin.',
           '; Le 4e octet du descripteur de wave est l\'index dans cette table.',
           'stage.gougerProfiles EXPORT',
           'stage.gougerProfiles']
    for idx, *_ in profiles:
        out.append('        fdb   gouger.profile.%d' % idx)
    total = 0
    for idx, t, var, param, x_spawn, r in profiles:
        frames = sum(n for _, n in r)
        out.append('gouger.profile.%d' % idx)
        out.append('        fdb   %d                ; t=$%04X var %d (param $%02X), %d trames, %d runs'
                   % (x_spawn, t, var, param, frames, len(r)))
        bytes_ = ['$%02X' % ((0x80 if crawl else 0) | n) for crawl, n in r] + ['0']
        for k in range(0, len(bytes_), 12):
            out.append('        fcb   ' + ','.join(bytes_[k:k + 12]))
        total += 2 + len(bytes_)
        print('profil %2d  t=$%04X var %d  x=%4d  %s' % (
            idx, t, var, x_spawn, ' '.join(('R' if c else 'P') + str(n) for c, n in r)))
    open(OUT, 'w').write('\n'.join(out) + '\n')
    print('%s : %d profils, %d octets (table comprise : %d)'
          % (OUT, len(profiles), total, total + 2 * len(profiles)))


if __name__ == '__main__':
    main()
