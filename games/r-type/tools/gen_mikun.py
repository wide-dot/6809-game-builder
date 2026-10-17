#!/usr/bin/env python3
"""Genere les tables du Mikun (stage 8) depuis la ROM arcade.

  1000:4284  le repartiteur de vitesses par difficulte : 9010, 9050, 9090,
             90D0 — le MEME pool que le pique du wick (1000:3b22). Seize
             directions par difficulte, (vx, vy) 8.8, axe Y arcade vers le
             haut. Converti ici au repere v2 : vx x 0,375, vy x -0,75 (toutes
             les valeurs du pool sont des multiples de 16 : conversion exacte,
             verifiee a la generation).
  1000:943C  le pool des periodes d'emission, indexe par le jeton & 15
  1000:428C  la recette de chaque direction (deux poses de six octets, la
             seconde quand le bit 3 du compteur global est arme) : les 32
             recettes sont contigues de 1000:42AC a 1000:4371, et
             images/frames/cycle.txt (arcade_to_sprites.py --dedup) dit
             quelle pose importee porte chacune.
             Avec leur variante decalee d'un pixel, les 28 poses ne tiennent
             pas dans une page : celles des directions 0-7 (poses 0-13) vivent
             avec le code (stage8.mikun, set_mikun_N), celles des directions
             8-15 (poses 14-27) dans stage8.mikun.img (set_mikunb_N-14). Le
             script verifie que la coupure passe bien entre les deux moities.

Les images ne passent pas par ce script : catalog `mikun` de re.arcade.r-type
(animation `frames`, les 32 recettes dans l'ordre de la ROM), puis
tools/palette-replay.sh (l'invocation arcade_to_sprites.py du mikun).

Sortie : src/enemies/mikun/tables.asm.
Rejeu : python3 tools/gen_mikun.py (depuis games/r-type/) ;
        python3 tools/gen_mikun.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/mikun/tables.asm'
CYCLE = 'src/enemies/mikun/images/frames/cycle.txt'
SPLIT = 14                  # first pose of stage8.mikun.img


def w(rom, a):
    return struct.unpack_from('<H', rom, SEG + a)[0]


def sw(rom, a):
    return struct.unpack_from('<h', rom, SEG + a)[0]


def conv(v, num, den):
    if (v * num) % den:
        sys.exit('vitesse %d non convertible exactement (x%d/%d)' % (v, num, den))
    return v * num // den


def render(rom):
    L = ['; GENERE par tools/gen_mikun.py depuis la ROM arcade — ne pas editer.', '']
    L += ['; 1000:4284 -> 9010/9050/9090/90D0 : les seize directions de lancement,',
          '; une table par difficulte. v2 : vx x 0,375, vy x -0,75 (Y vers le bas).',
          '; Direction 0 = vers le haut, 16 = a droite, 32 = en bas, 48 = a gauche ;',
          '; l\'offset dans une table EST la direction (multiple de 4).',
          'mikun.Vel']
    for d in range(4):
        base = w(rom, 0x4284 + 2 * d)
        L.append('; --- difficulte %d (1000:%04X) ---' % (d, base))
        for k in range(16):
            vx, vy = sw(rom, base + 4 * k), sw(rom, base + 4 * k + 2)
            L.append('        fdb   %d,%d%s; dir %2d  arcade %d,%d' % (
                conv(vx, 3, 8), conv(-vy, 3, 4),
                ' ' * max(1, 14 - len('%d,%d' % (conv(vx, 3, 8), conv(-vy, 3, 4)))),
                4 * k, vx, vy))
    L += ['', '; 1000:943C la periode d\'emission, en trames de jeu, par jeton & 15',
          'mikun.Periods']
    per = [w(rom, 0x943C + 2 * i) for i in range(16)]
    L.append('        fdb   ' + ','.join('%d' % v for v in per[:8]))
    L.append('        fdb   ' + ','.join('%d' % v for v in per[8:]))
    slots = [int(v) for v in open(CYCLE).read().split('\n')[3].split()]
    if len(slots) != 32:
        sys.exit('%s : 32 slots attendus' % CYCLE)
    def name(k, p):
        if (p < SPLIT) != (k < 8):
            sys.exit('pose %d de la direction %d du mauvais cote de la coupure' % (p, k))
        return 'set_mikun_%d' % p if p < SPLIT else 'set_mikunb_%d' % (p - SPLIT)
    L += ['', '; les poses des directions 8 a 15, dans stage8.mikun.img',
          'mikun.DIR_IMG2 equ 32                   ; premiere direction de cette page']
    L += ['set_mikunb_%d EXTERNAL' % i for i in range(max(slots) + 1 - SPLIT)]
    L += ['', '; 1000:428C les deux poses de chaque direction (recette, recette+6) :',
          '; l\'offset dans la table EST la direction. Rang = pose importee',
          '; (images/frames, cycle.txt).',
          'mikun.Poses']
    for k in range(16):
        ptr = w(rom, 0x428C + 2 * k)
        if ptr != 0x42AC + 12 * k:
            sys.exit('recettes non contigues a la direction %d' % k)
        L.append('        fdb   %s,%s  ; dir %2d  1000:%04X' % (
            name(k, slots[2 * k]), name(k, slots[2 * k + 1]), 4 * k, ptr))
    return '\n'.join(L) + '\n'


def main():
    rom = open(ROM, 'rb').read()
    text = render(rom)
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        if cur != text:
            print('%s : PERIMEE — relancer sans --check' % OUT)
            return 1
        print('%s : a jour' % OUT)
        return 0
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
