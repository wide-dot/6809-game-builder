#!/usr/bin/env python3
"""Genere les tables du Newt (stage 6) depuis la ROM arcade.

Le Newt est porte en REPERE ARCADE comme les Dops : les tables sont recopiees
TELLES QUELLES.

  1000:329E  la vitesse par phase, 8.8 : {vx, vy} (gauche, droite, haut, bas)
  1000:32AE  le point sonde par phase : {dx, dy}, en pixels
  1000:93DC  les seize departs (load_xy_preset_16_alt 40:FA75, bits 0-3 du
             jeton) : {x ecran, y}

Sortie : src/enemies/newt/tables.asm.
Rejeu : python3 tools/gen_newt.py (depuis games/r-type/) ;
        python3 tools/gen_newt.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/newt/tables.asm'


def words(rom, a, n):
    return struct.unpack_from('<%dh' % n, rom, SEG + a)


def render(rom):
    vel = words(rom, 0x329E, 8)
    probe = words(rom, 0x32AE, 8)
    start = words(rom, 0x93DC, 32)
    L = ['; GENERE par tools/gen_newt.py depuis la ROM arcade — ne pas editer.',
         '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.',
         '', '; 1000:329E la vitesse par phase, 8.8 : {vx, vy}', 'newt.Vel']
    for i in range(4):
        L.append('        fdb   $%04X,$%04X  ; phase %d' % (vel[2 * i] & 0xFFFF, vel[2 * i + 1] & 0xFFFF, i))
    L += ['', '; 1000:32AE le point sonde par phase : {dx, dy}', 'newt.Probe']
    for i in range(4):
        L.append('        fdb   %d,%d  ; phase %d' % (probe[2 * i], probe[2 * i + 1], i))
    L += ['', '; 1000:93DC les departs, par bits 0-3 du jeton : {x ecran, y}', 'newt.Start']
    for i in range(16):
        L.append('        fdb   %d,%d  ; %X' % (start[2 * i], start[2 * i + 1], i))
    return '\n'.join(L) + '\n'


def main():
    text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text else 'PERIME — relancer tools/gen_newt.py'))
        return 0 if cur == text else 1
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
