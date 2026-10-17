#!/usr/bin/env python3
"""Genere les tables du Compiler (boss du stage 4) depuis la ROM arcade.

Le Compiler est porte en REPERE ARCADE, comme Bellmite : positions,
vitesses, seuils et scripts restent ceux de la borne, seul le dessin
convertit. Les tables sont donc recopiees TELLES QUELLES.

La piece maitresse est une PLAGE BRUTE de la ROM, 1000:58EE a 1000:5F08 :
les listes d'explosions de mort, la table des variantes, les neuf
configurations et les scripts de mouvement — et les octets qui les suivent.
Pourquoi brute : apres la fin de ses scripts, une piece ne s'arrete pas.
compiler_part_motion_step (40:AFE6) recule son curseur de configuration sur
le terminateur mais laisse avancer son curseur de script, qui lit alors les
segments QUI SUIVENT en ROM (le script de la piece suivante, puis la premiere
liste de Bellmite) jusqu'a la sentinelle suivante. Le port lit la meme
memoire, adresse arcade pour adresse arcade. La borne ne lit jamais au-dela
de 5F07 (mesure sur les huit variantes, tools/fidelity/models/).

Les mots sont ecrits en big-endian (6809) ; un pointeur arcade A s'adresse
chez nous cpl.ROM + (A - cpl.ROM.BASE).

Sortie : src/enemies/compiler/tables.asm.
Rejeu : python3 tools/gen_compiler.py (depuis games/r-type/) ;
        python3 tools/gen_compiler.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/compiler/tables.asm'
BLOB = (0x58EE, 0x5F08)


def words(rom, a, n):
    return struct.unpack_from('<%dh' % n, rom, SEG + a)


def render(rom):
    cad = list(rom[SEG + 0x5844:SEG + 0x5848])
    lvx = words(rom, 0x5848, 4)
    pool_r = words(rom, 0x5850, 8)
    pool_l = words(rom, 0x5860, 8)
    tdir = struct.unpack_from('<32H', rom, SEG + 0x5870)
    pre = {(d, p): struct.unpack_from('<3H', rom, SEG + 0x8E10 + d * 96 + (p >> 4) * 6)
           for d in range(4) for p in (0x30, 0x40)}
    L = [
        '; GENERE par tools/gen_compiler.py depuis la ROM arcade — ne pas editer.',
        '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.',
        '',
        '; 1000:5844 la cadence des lasers, par difficulte',
        'cpl.Cadence',
        '        fcb   ' + ','.join(str(v) for v in cad),
        '; 1000:5848 la vitesse du laser horizontal, par difficulte, 8.8',
        'cpl.LaserVx',
        '        fdb   ' + ','.join('$%04X' % (v & 0xFFFF) for v in lvx),
        '; 8E10 + difficulte*96 + preset*6 : les seuils de tir des tourelles,',
        '; par difficulte {preset 0x30 : seuil, remise ; preset 0x40 : idem}',
        'cpl.TurretPre'] + [
        '        fdb   %d,%d,%d,%d' % (pre[d, 0x30][0], pre[d, 0x30][1], pre[d, 0x40][0], pre[d, 0x40][1])
        for d in range(4)] + [
        '',
        '; 1000:5850 / 5860 les hauteurs du laser, piece droite puis gauche',
        'cpl.PoolR',
        '        fdb   ' + ','.join(str(v) for v in pool_r),
        'cpl.PoolL',
        '        fdb   ' + ','.join(str(v) for v in pool_l),
        '',
        '; 1000:5870 par direction (code/4) : le drapeau de tir (+0x16, non nul =',
        '; la tourelle tire) — seules les cinq directions vers la gauche l\'ont',
        'cpl.TurretFire',
        '        fcb   ' + ','.join('$%02X' % tdir[2 * i] for i in range(16)),
        '',
        '; 1000:%04X..%04X brute, mots en big-endian' % BLOB,
        'cpl.ROM.BASE equ $%04X' % BLOB[0],
        'cpl.ROM',
    ]
    for a in range(BLOB[0], BLOB[1], 2):
        if (a - BLOB[0]) % 16 == 0:
            L.append('        fdb   ' + ','.join(
                '$%04X' % struct.unpack_from('<H', rom, SEG + b)[0]
                for b in range(a, min(a + 16, BLOB[1]), 2)) + '  ; %04X' % a)
    return '\n'.join(L) + '\n'


def main():
    text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text else 'PERIME — relancer tools/gen_compiler.py'))
        return 0 if cur == text else 1
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
