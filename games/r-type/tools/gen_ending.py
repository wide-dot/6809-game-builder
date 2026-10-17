#!/usr/bin/env python3
"""Genere les tables de la sequence de fin (stage 8) depuis la ROM arcade.

La fin est portee en REPERE ARCADE, comme les boss : les tables sont
recopiees TELLES QUELLES.

  1000:945C  la flotte : 18 vaisseaux {script, y, palette} (spawn_floating_
             score_pickups 40:FB10 — le nom Ghidra est faux, c'est la flotte
             de R-9 du generique), la palette ecrite en RANG de couleur
             (l'ordre de images/fleet : 0x02, 0x64..0x68)
  les SCRIPTS de la flotte (run_floating_score_pickup 40:FB53) : entrees de
             8 octets {debut, vx, vy, image}, une plage BRUTE de la ROM, celle
             que les vaisseaux lisent vraiment (une emulation la trouve)
  1000:88E8  la table des lignes du directeur (40:EF1E), en RANG de descripteur
  les DESCRIPTEURS de texte (blit_text_string_fg 40:ED93) : {attr, 0, long,
             1, x, ligne} puis les caracteres. Ils sont ecrits deux fois :
             la ligne de tilemap et le rang de chaine (0 = ligne blanche, qui
             efface) pour le directeur, la chaine pour le dessin, residente
             (le dessin monte la page du HUD, dont la police fait le texte)

Sorties : src/stages/08/ending/tables.asm (l'unite de la fin) et
          src/stages/08/ending/text.asm (inclus par le main du stage 8).
Rejeu : python3 tools/gen_ending.py (depuis games/r-type/) ;
        python3 tools/gen_ending.py --check dit si les sorties sont a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT_TABLES = 'src/stages/08/ending/tables.asm'
OUT_TEXT = 'src/stages/08/ending/text.asm'

COLOURS = [0x02, 0x64, 0x65, 0x66, 0x67, 0x68]      # images/fleet, by rank
POSES = [0x96D6, 0x96E2, 0x96EE]                     # cells 0x20, 0x22, 0x24
FIRST = [0x8A02, 0x8A20]                             # 40:EEE5, EEEE
ENJOY = 0x8B88                                       # 40:EF64
TO8_RIGHT_COL = 38                                   # x 152: the playfield's edge


def w(rom, a):
    return struct.unpack_from('<H', rom, SEG + a)[0]


def sw(rom, a):
    return struct.unpack_from('<h', rom, SEG + a)[0]


def ships(rom):
    out, a = [], 0x945C
    while True:
        out.append((w(rom, a), w(rom, a + 2), w(rom, a + 4)))
        a += 6
        if w(rom, a) == 0:
            return out


def script_range(rom, fleet):
    """every byte a ship reads until it leaves at x >= 0x2E0 (40:FB83)"""
    used = set()
    for scr, _y, _p in fleet:
        bx, c12, x = scr, 0, 0x120 << 8
        for _ in range(4000):
            c12 += 1
            used.update(range(bx, bx + 10))
            nxt = w(rom, bx + 8)
            cur = bx
            if c12 >= nxt:
                bx += 8
            x += sw(rom, cur + 2)
            if (x >> 8) >= 0x2E0:
                break
    return min(used), max(used) + 1


def lines(rom):
    out, a = [], 0x88E8
    while True:
        v = w(rom, a)
        out.append(v)
        a += 2
        if v == 0:
            return out


def descriptor(rom, d):
    n = rom[SEG + d + 2]
    return {'attr': rom[SEG + d], 'len': n, 'x': rom[SEG + d + 4],
            'row': rom[SEG + d + 5], 'text': rom[SEG + d + 6:SEG + d + 6 + n].decode('ascii')}


def to8_text(desc):
    """the arcade's font draws '/' as a full stop and ':' as '!' ; the line
    keeps its leading spaces as a column shift, its trailing ones go"""
    t = desc['text'].replace('/', '.').replace(':', '!')
    lead = len(t) - len(t.lstrip(' '))
    t = t.strip(' ')
    px = (desc['x'] // 4 - 8) * 8 + lead * 8         # arcade pixel of the first glyph
    col = (8 + px * 3 // 8) // 4                       # its TO8 byte column
    col = min(col, TO8_RIGHT_COL - len(t))             # whole on the playfield
    return col, t


def render(rom):
    fleet = ships(rom)
    lo, hi = script_range(rom, fleet)
    table = lines(rom)
    descs = []
    for d in FIRST + [v for v in table if v] + [ENJOY]:
        if d not in descs:
            descs.append(d)
    named = [d for d in descs if descriptor(rom, d)['text'].strip(' ')]
    T = ['; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.',
         '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.', '',
         '; 1000:945C la flotte : {script (adresse arcade), y, rang de couleur}',
         'ending.Fleet']
    for scr, y, pal in fleet:
        T.append('        fdb   $%04X,$%04X' % (scr, y))
        T.append('        fcb   %d                       ; palette $%02X' % (COLOURS.index(pal), pal))
    T += ['ending.FleetEnd', '',
          '; les scripts de la flotte : la plage brute que les vaisseaux lisent',
          'ending.SCRIPT_LO equ $%04X' % lo,
          'ending.Scripts']
    data = rom[SEG + lo:SEG + hi]
    for i in range(0, len(data), 16):
        T.append('        fcb   ' + ','.join('$%02X' % v for v in data[i:i + 16]))
    T += ['', '; les trois poses (cellules 0x20, 0x22, 0x24) : recettes arcade',
          'ending.Poses',
          '        fdb   ' + ','.join('$%04X' % p for p in POSES), '',
          '; les descripteurs : {ligne de tilemap, rang de chaine + 1 (0 = blanche)}',
          'ending.Desc']
    for d in descs:
        de = descriptor(rom, d)
        k = named.index(d) + 1 if d in named else 0
        T.append('        fcb   $%02X,%d                  ; %04X %s' % (de['row'], k, d, de['text'].rstrip()))
    T += ['', '; les deux premieres lignes (40:EEE5), la table du directeur (1000:88E8,',
          '; en rang de descripteur, $FF = fin) et ENJOY (40:EF64)',
          'ending.D_FIRST0 equ %d' % descs.index(FIRST[0]),
          'ending.D_FIRST1 equ %d' % descs.index(FIRST[1]),
          'ending.D_ENJOY  equ %d' % descs.index(ENJOY),
          'ending.Lines',
          '        fcb   ' + ','.join('%d' % descs.index(v) if v else '$FF' for v in table)]
    X = ['; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.',
         '; Les chaines du generique, RESIDENTES : le dessin monte la page du HUD.',
         '; {colonne d\'octet TO8, caracteres, 0}', '',
         'ending.Strings']
    X.append('        fdb   ' + ','.join('ending.S%d' % i for i in range(len(named))))
    for i, d in enumerate(named):
        col, t = to8_text(descriptor(rom, d))
        X.append('ending.S%d fcb   %d' % (i, col))
        X.append("        fcc   '%s'" % t)
        X.append('        fcb   0')
    return '\n'.join(T) + '\n', '\n'.join(X) + '\n'


def main():
    tables, text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        ok = True
        for path, t in ((OUT_TABLES, tables), (OUT_TEXT, text)):
            cur = open(path).read() if os.path.exists(path) else ''
            print('%s : %s' % (path, 'a jour' if cur == t else 'PERIME — relancer tools/gen_ending.py'))
            ok = ok and cur == t
        return 0 if ok else 1
    os.makedirs(os.path.dirname(OUT_TABLES), exist_ok=True)
    for path, t in ((OUT_TABLES, tables), (OUT_TEXT, text)):
        open(path, 'w').write(t)
        print('%s ecrit' % path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
