#!/usr/bin/env python3
"""Genere les listes d'explosions de la mort du Compiler (boss du stage 4).

Quand une piece du boss tombe, la borne ne pose pas une explosion mais un
CHAPELET : un marcheur (compiler_part_destroy_with_explosion_cascade,
0x40:B062) parcourt une liste d'offsets pendant 64 trames et seme une
explosion a chacun, une trame sur deux. Chaque piece a sa liste — le nuage
fleurit differemment selon qu'on abat la droite, le bas ou la gauche.

Les trois listes vivent en ROM (0x1000:58EE, 0x594E, 0x59A6), en entrees de
quatre octets {x:word, y:word} terminees par la sentinelle 0x8000. Ce script
les lit, les convertit a notre echelle (x0,375 en x ; x0,75 EN CHANGEANT DE
SIGNE en y, l'axe de la borne montant) et les ecrit en octets signes.

Sortie : gen/enemies/compiler/explosions.asm, inclus par compiler.unit.asm.
Rejeu : python3 tools/gen_compiler_death.py (depuis games/r-type/).
"""
import os
import struct

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000                      # le segment de donnees 0x1000
LISTES = (('right',  0x58EE), ('bottom', 0x594E), ('left', 0x59A6))
SENTINELLE = 0x8000
MAX = 24                           # garde-fou : aucune liste connue n'en a plus


def lire(rom, off):
    """Les entrees {x, y} d'une liste, jusqu'a la sentinelle."""
    out = []
    for i in range(MAX):
        x, y = struct.unpack_from('<hh', rom, SEG + off + i * 4)
        if (x & 0xFFFF) == SENTINELLE:
            break
        out.append((x, y))
    return out


def borne(v, quoi):
    if not -128 <= v <= 127:
        raise SystemExit('offset %s hors d\'un octet signe : %d' % (quoi, v))
    return v & 0xFF


def main():
    rom = open(ROM, 'rb').read()
    out = [
        '; ---------------------------------------------------------------------------',
        "; LES CHAPELETS D'EXPLOSION DU COMPILER — table GENEREE, ne pas editer",
        '; ---------------------------------------------------------------------------',
        '; Rejeu : python3 tools/gen_compiler_death.py (depuis games/r-type/).',
        '; Une entree = deux octets signes {dx, dy}, a ajouter au centre de la piece.',
        "; L'ordre est celui de la borne : c'est lui qui dessine la forme du nuage.",
        '',
    ]
    tailles = []
    for nom, off in LISTES:
        e = lire(rom, off)
        tailles.append((nom, len(e)))
        out.append('cpl.boom.%s' % nom)
        for x, y in e:
            vx = borne(round(x * 0.375), 'x')
            vy = borne(round(-y * 0.75), 'y')   # l'axe y de la borne MONTE
            out.append('        fcb   $%02X,$%02X          ; arcade %+4d,%+4d'
                       % (vx, vy, x, y))
        out.append('')
    out.append('; Le nombre d\'entrees de chaque liste, dans l\'ordre des pieces')
    out.append('; (droite, bas, gauche) — le marcheur s\'y arrete.')
    out.append('cpl.boom.count')
    out.append('        fcb   %s' % ','.join(str(n) for _, n in tailles))
    out.append('')
    out.append('cpl.boom.index')
    out.append('        fdb   %s' % ','.join('cpl.boom.%s' % n for n, _ in LISTES))

    dst = 'gen/enemies/compiler/explosions.asm'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('ecrit %s : %s' % (dst, ', '.join('%s %d' % t for t in tailles)))


if __name__ == '__main__':
    main()
