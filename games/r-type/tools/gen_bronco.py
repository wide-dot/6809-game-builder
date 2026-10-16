#!/usr/bin/env python3
"""Genere les tables de Bronco (boss du stage 7) depuis la ROM arcade.

Bronco est porte en REPERE ARCADE, comme Bellmite, le Compiler et l'essaim de
Dops : les tables sont recopiees TELLES QUELLES.

  1000:611E  les x de chute des debris (curseur du repartiteur, 0x8000 = fin)
  1000:612C  la table de repartition : 32 installateurs, ecrits ici en RANG
             d'installateur (bro.I_*), l'adresse arcade en commentaire
  1000:627C  les x d'apparition des poursuivants (0x8000 = rien, 0 = fin)
  1000:6312  les images des sous-enfants : rang de l'image de debris
  1000:631A  la vitesse x de l'attaquant principal, 16 pas de 16 trames
  1000:60B6  les douze decalages d'explosion d'un segment
  1000:27FE  la table des bonus (create_bonus 40:5811) : le type tire
  les SCRIPTS du sous-enfant (move_by_script 40:F5C1, 1000:A7FC) : des
             plages BRUTES de la ROM, lues adresse arcade pour adresse arcade
             (bro.RomX traduit), octets tels quels (mots en little-endian)

Les images ne passent pas par ce script : catalog `bronco` de
re.arcade.r-type (une animation par CELLULE arcade partagee : la tete de
l'attaquant, la tete du poursuivant), puis tools/arcade_to_sprites.py :

  python3 tools/arcade_to_sprites.py bronco --palette 07 --reduction aire

Sortie : src/enemies/bronco/tables.asm.
Rejeu : python3 tools/gen_bronco.py (depuis games/r-type/) ;
        python3 tools/gen_bronco.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/bronco/tables.asm'

INSTALLERS = [0xBB40, 0xBB72, 0xBB7E, 0xBB8A, 0xBB96, 0xBBA2, 0xBBAE, 0xBBC3,
              0xBC08, 0xBC31, 0xBC63]
# the move_by_script ranges the sub-child reads (scripts, then segments)
RANGES = [(0xA7FC, 0xA81C), (0xAA54, 0xAA6E), (0xAB28, 0xAB3A),
          (0xB071, 0xB0DE), (0xB10A, 0xB10C)]


def w(rom, a):
    return struct.unpack_from('<H', rom, SEG + a)[0]


def sw(rom, a):
    return struct.unpack_from('<h', rom, SEG + a)[0]


def render(rom):
    L = ['; GENERE par tools/gen_bronco.py depuis la ROM arcade — ne pas editer.',
         '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.', '']
    L += ['; 1000:611E les x de chute des debris (0x8000 : le curseur revient)', 'bro.DebrisX']
    a = 0x611E
    xs = []
    while True:
        xs.append(w(rom, a))
        if w(rom, a) == 0x8000:
            break
        a += 2
    L.append('        fdb   ' + ','.join('$%04X' % v for v in xs))
    L += ['', '; 1000:612C la repartition : 32 rangs d\'installateur (bro.I_*)', 'bro.Dispatch']
    for i in range(0, 32, 8):
        row = [w(rom, 0x612C + 2 * (i + k)) for k in range(8)]
        L.append('        fcb   ' + ','.join('%d' % INSTALLERS.index(v) for v in row)
                 + '  ; ' + ' '.join('%04X' % v for v in row))
    L += ['', '; 1000:627C les x des poursuivants (0x8000 : aucun, 0 : le curseur revient)',
          'bro.ChaserX']
    a = 0x627C
    xs = []
    while True:                                  # up to its first 0, kept
        xs.append(w(rom, a))
        if xs[-1] == 0:
            break
        a += 2
    L.append('        fdb   ' + ','.join('$%04X' % v for v in xs))
    L += ['', '; 1000:6312 les images des sous-enfants : rang dans les debris', 'bro.SubImg']
    L.append('        fcb   ' + ','.join('%d' % ((w(rom, 0x6312 + 2 * i) - 0x616C) // 6)
                                       for i in range(4)))
    L += ['', '; 1000:631A la vitesse x de l\'attaquant principal (8.8)', 'bro.MainVx']
    L.append('        fdb   ' + ','.join('$%04X' % w(rom, 0x631A + 2 * i) for i in range(16)))
    L += ['', '; 1000:60B6 les douze explosions d\'un segment, {dx, dy}', 'bro.SegBoom']
    for i in range(0, 12, 6):
        L.append('        fdb   ' + ','.join('%d,%d' % (sw(rom, 0x60B6 + 4 * k), sw(rom, 0x60B8 + 4 * k))
                                          for k in range(i, i + 6)))
    L += ['', '; 1000:27FE create_bonus : l\'octet haut, par (type & 7) * 2 + (compteur & 2) / 2',
          'bro.Bonus']
    L.append('        fcb   ' + ','.join('$%02X' % (w(rom, 0x27FE + 2 * i) >> 8) for i in range(16)))
    L += ['', '; move_by_script : les plages brutes (debut arcade, longueur, donnees)', 'bro.Ranges']
    for lo, hi in RANGES:
        L.append('        fdb   $%04X,%d,bro.R%04X' % (lo, hi - lo, lo))
    L.append('        fdb   0')
    for lo, hi in RANGES:
        L.append('bro.R%04X' % lo)
        data = rom[SEG + lo:SEG + hi]
        for i in range(0, len(data), 16):
            L.append('        fcb   ' + ','.join('$%02X' % v for v in data[i:i + 16]))
    return '\n'.join(L) + '\n'


def main():
    text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text else 'PERIME — relancer tools/gen_bronco.py'))
        return 0 if cur == text else 1
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
