#!/usr/bin/env python3
"""Genere les tables du Bydo core (boss du stage 8) depuis la ROM arcade.

Le Bydo est porte en REPERE ARCADE, comme Bellmite, le Compiler, l'essaim de
Dops et Bronco : les tables sont recopiees TELLES QUELLES.

  1000:6416  la chronologie du noyau : {seuil, appel}, l'appel ecrit ici en
             RANG d'action (bydo.A_*), l'adresse arcade en commentaire ; elle
             s'arrete a l'entree 0x8000 (jamais atteinte, le delai 0x2000
             tue le noyau avant)
  1000:69BC  la bouche, phase A : 8 recettes 8x7 (ecrites en rang d'image,
             l'ordre de 0x69EC..0x6C8C, celui de images/tentacle)
  1000:69CC  la bouche, phase B : 16 recettes
  1000:8F90  la poursuite des Win, phase A puis B (1000:9090) : {vx, vy} 8.8
             par direction / 4
  les SCRIPTS des Win (move_by_script 40:F5C1, 1000:A872 / A90C / A96C /
             A9F6) : des plages BRUTES de la ROM, celles que le script lit
             vraiment (un parcours les trouve), lues adresse arcade pour
             adresse arcade (bydo.RomX traduit), octets tels quels

Les images ne passent pas par ce script : catalog `bydo` de re.arcade.r-type
(moteur tile_block : les recettes de tuiles que la borne ecrit dans la RAM du
plan de fond), regroupees en deux jeux sous images/original (head : le repos
0x64BC puis les quatre boules de feu 0x65BC..0x68BC ; tentacle : les huit
recettes 8x7), puis :

  python3 tools/arcade_to_sprites.py bydo --palette 08 --reduction aire --opaque

Les Win reprennent images/ de src/enemies/win (palette du stage 8).

Sortie : src/enemies/bydo/tables.asm.
Rejeu : python3 tools/gen_bydo.py (depuis games/r-type/) ;
        python3 tools/gen_bydo.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/bydo/tables.asm'

# the timeline's calls, by action rank (obj.asm, bydo.A_*)
ACTIONS = [(0x9758, 'WIN_A'), (0x978D, 'WIN_B'), (0x97C7, 'WIN_C'), (0x9801, 'WIN_D'),
           (0xC37F, 'MOUTH'), (0xC30A, 'HEAD'), (0xC2F6, 'HALT'), (0xC2F0, 'SFX'),
           (0xC37A, 'CLOSE'), (0xC31B, 'FIRE_A'), (0xC326, 'FIRE_B'), (0xC32C, 'FIRE_C'),
           (0xC332, 'FIRE_D'), (0xC315, 'REST'), (0xC305, 'FREE'), (0xF366, 'MUSIC'),
           (0xFFF2, 'NONE')]
TENTACLES = [0x69EC, 0x6A40, 0x6A94, 0x6AE8, 0x6B90, 0x6BE4, 0x6C38, 0x6C8C]
WIN_SCRIPTS = [0xA872, 0xA90C, 0xA96C, 0xA9F6]


def w(rom, a):
    return struct.unpack_from('<H', rom, SEG + a)[0]


def script_ranges(rom):
    """Every byte move_by_script reads from the Win scripts: their command
    words and their segments, as merged [lo, hi) ranges."""
    used = set()
    todo, seen = list(WIN_SCRIPTS), set()
    while todo:
        s12 = todo.pop()
        if s12 in seen:
            continue
        seen.add(s12)
        used.update((s12, s12 + 1))
        seg = w(rom, s12)
        while True:
            a = seg                                 # a segment: up to its end byte
            while True:
                used.add(a)
                b = rom[SEG + a]
                if not (b & 0x80) and (b & 0x04):
                    break
                a += 1
            while True:                             # the next command word
                s12 += 2
                used.update((s12, s12 + 1))
                ax = w(rom, s12)
                if ax == 0:
                    used.update((s12 + 2, s12 + 3))
                    todo.append(w(rom, s12 + 2))
                    seg = None
                    break
                if (ax >> 8) == 0xF0:
                    continue
                seg = ax
                break
            if seg is None:
                break
    out = []
    for a in sorted(used):
        if out and out[-1][1] == a:
            out[-1][1] = a + 1
        else:
            out.append([a, a + 1])
    return out


def render(rom):
    names = dict(ACTIONS)
    rank = {a: i for i, (a, _) in enumerate(ACTIONS)}
    L = ['; GENERE par tools/gen_bydo.py depuis la ROM arcade — ne pas editer.',
         '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.', '']
    L += ['; 1000:6416 la chronologie du noyau : {seuil, rang d\'action (bydo.A_*)}',
          'bydo.Timeline']
    a = 0x6416
    while True:
        t, f = w(rom, a), w(rom, a + 2)
        L.append('        fdb   $%04X' % t)
        L.append('        fcb   %-2d                      ; %04X %04X %s'
                 % (rank[f], a, f, names[f]))
        a += 4
        if t >= 0x8000:
            break
    for k, base, n in (('A', 0x69BC, 8), ('B', 0x69CC, 16)):
        L += ['', '; 1000:%04X la bouche, phase %s : rang de recette (images/tentacle)' % (base, k),
              'bydo.Mouth%s' % k]
        L.append('        fcb   ' + ','.join('%d' % TENTACLES.index(w(rom, base + 2 * i))
                                           for i in range(n)))
    for k, base in (('A', 0x8F90), ('B', 0x9090)):
        L += ['', '; 1000:%04X la poursuite des Win, phase %s : {vx, vy} 8.8 par direction / 4'
              % (base, k), 'bydo.Aim%s' % k]
        for i in range(0, 32, 8):
            L.append('        fdb   ' + ','.join('$%04X' % w(rom, base + 2 * j)
                                               for j in range(i, i + 8)))
    L += ['', '; move_by_script : les plages brutes (debut arcade, longueur, donnees)',
          'bydo.Ranges']
    ranges = script_ranges(rom)
    for lo, hi in ranges:
        L.append('        fdb   $%04X,%d,bydo.R%04X' % (lo, hi - lo, lo))
    L.append('        fdb   0')
    for lo, hi in ranges:
        L.append('bydo.R%04X' % lo)
        data = rom[SEG + lo:SEG + hi]
        for i in range(0, len(data), 16):
            L.append('        fcb   ' + ','.join('$%02X' % v for v in data[i:i + 16]))
    return '\n'.join(L) + '\n'


def main():
    text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text else 'PERIME — relancer tools/gen_bydo.py'))
        return 0 if cur == text else 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
