#!/usr/bin/env python3
"""Genere les tables de Bellmite (boss du stage 5) depuis la ROM arcade.

Bellmite est porte en REPERE ARCADE : ses positions, vitesses et seuils
restent en pixels arcade (x vers la droite, y vers le HAUT), seul le dessin
convertit. Les tables sont donc recopiees TELLES QUELLES, sans conversion —
c'est ce qui permet a la trace TO8 d'etre comparee octet pour octet a la
trace MAME (tools/fidelity/).

Quatre tables, toutes dans le segment de donnees 0x1000 :

  1000:5F6C  bellmite_satellite_position_script
             {x_off:word, y_off:word} jusqu'a la sentinelle x = 0x8000.
             TRENTE-SEPT entrees (et non douze comme le dit la plate de
             0x40:B1FA : la boucle teste l'entree SUIVANTE, et la trace MAME
             en compte 37 vivantes).
  1000:6002  bellmite_parent_target_positions
             32 cibles {x:word, y:word}, indexees par random & 0x1F.
  1000:5F64  bellmite_difficulty_satellite_velocity_table_base : une table
             de vitesses d'attaque par difficulte (0x8FD0, 0x9050, 0x9090,
             0x90D0), chacune 16 directions {vx:word, vy:word} en 8.8,
             indexees par le code de set_direction_to (0x00 = N ... 0x3C =
             NNW, pas de 4).
  1000:5F5C  bellmite_difficulty_phase_period : 4 mots, par difficulte.

Les IMAGES ne passent pas par ce script : elles sortent du catalogue de
re.arcade.r-type (entree `bellmite`, export --export-catalog) copie dans
src/enemies/bellmite/images/original/, puis de arcade_to_sprites.py en
reduction PAR SURFACE et symetrie de silhouette (constat auteur 16/10/2026 :
le plus proche voisin cassait la symetrie de l'etoile et mangeait ses rayons) :

  python3 tools/arcade_to_sprites.py bellmite --palette 05 --reduction aire \\
      --symetrie xy-forme --opacite 0.25 --poses body,body_flash
  python3 tools/arcade_to_sprites.py bellmite --palette 05 --reduction aire \\
      --symetrie xy-forme --opacite 0.4 --poses satellite,satellite_flash

(0,25 garde entiers les rayons diagonaux d'un pixel arcade du noyau ; 0,4
garde la boule ronde.)

Sortie : src/enemies/bellmite/tables.asm.
Rejeu : python3 tools/gen_bellmite.py (depuis games/r-type/) ;
        python3 tools/gen_bellmite.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/bellmite/tables.asm'
SENTINEL = 0x8000


def words(rom, off, n):
    return struct.unpack_from('<%dh' % n, rom, SEG + off)


def satellites(rom):
    out, off = [], 0x5F6C
    while True:
        x, y = words(rom, off, 2)
        out.append((x, y))
        # la boucle arcade (b276) teste l'entree SUIVANTE avant d'avancer
        if struct.unpack_from('<H', rom, SEG + off + 4)[0] == SENTINEL:
            return out
        off += 4
        if len(out) > 64:
            sys.exit('sentinelle introuvable')


def pairs(rom, off, n):
    w = words(rom, off, 2 * n)
    return [(w[2 * i], w[2 * i + 1]) for i in range(n)]


def render(rom):
    sats = satellites(rom)
    targets = pairs(rom, 0x6002, 32)
    bases = [b & 0xFFFF for b in words(rom, 0x5F64, 4)]
    vels = [pairs(rom, b, 16) for b in bases]
    period = words(rom, 0x5F5C, 4)
    lines = [
        '; GENERE par tools/gen_bellmite.py depuis la ROM arcade — ne pas editer.',
        '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.',
        '',
        '; 1000:5F5C bellmite_difficulty_phase_period, par difficulte',
        'bellmite.Period',
        '        fdb   ' + ','.join('$%04X' % (p & 0xFFFF) for p in period),
        'bellmite.NSAT   equ %d' % len(sats),
        '',
        '; 1000:5F6C les decalages d\'orbite des satellites, {x, y}',
        'bellmite.SatOffsets',
    ]
    for i, (x, y) in enumerate(sats):
        lines.append('        fdb   %d,%d%s; satellite %d' % (x, y, ' ' * max(1, 12 - len('%d,%d' % (x, y))), i + 1))
    lines += ['', '; 1000:6002 les 32 cibles du noyau, {x, y}', 'bellmite.Targets']
    for i, (x, y) in enumerate(targets):
        lines.append('        fdb   $%04X,$%04X  ; %2d' % (x & 0xFFFF, y & 0xFFFF, i))
    lines += ['', '; 1000:5F64 les vitesses d\'attaque, une table par difficulte',
              'bellmite.AttackVels',
              '        fdb   ' + ','.join('bellmite.AttackVel%d' % d for d in range(4))]
    names = ('N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
             'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW')
    for d, (base, vel) in enumerate(zip(bases, vels)):
        lines += ['', '; 1000:%04X vitesses d\'attaque (difficulte %d), {vx, vy} en 8.8,' % (base, d),
                  '; indexees par le code de direction (pas de 4 : N, NNE ... NNW)',
                  'bellmite.AttackVel%d' % d]
        for i, (x, y) in enumerate(vel):
            lines.append('        fdb   %d,%d%s; $%02X %s' % (x, y, ' ' * max(1, 12 - len('%d,%d' % (x, y))), 4 * i, names[i]))
    return '\n'.join(lines) + '\n'


def main():
    rom = open(ROM, 'rb').read()
    text = render(rom)
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        if cur != text:
            print('%s : PERIME — relancer tools/gen_bellmite.py' % OUT)
            return 1
        print('%s : a jour' % OUT)
        return 0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
