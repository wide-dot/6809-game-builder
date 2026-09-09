#!/usr/bin/env python3
"""Genere la cascade d'explosions de la mort du NOYAU du vaisseau (boss du
stage 3).

La borne (tick_warship_core_destroy_explosion_chain, 0x40:DEC9) pose une
explosion toutes les QUATRE trames pendant 320 trames (0x140), aux offsets
d'une liste de 23 couples {dx, dy} (0x1000:80CE, terminee par 0x8000) qui
BOUCLE : 80 spawns, trois tours et demi. Une chance sur quatre (random & 6
== 0, 0x40:DF02) de grosse explosion grise-brune (0x40:E817), sinon la
petite (small_x3, 0x40:E7B6).

Ce que le TO8 en garde (la regle du gomander, decision auteur 08/09/2026) :
on echantillonne — une entree toutes les 8 trames video, soit un spawn
arcade sur deux, 40 entrees pour les 320 trames. Le marcheur commun
(src/common/fx/bosscascade/obj.asm) tient la duree. Le hasard de la grosse
est PRE-TIRE, graine fixe.

Conversion : x*0,375 ; y*0,75 EN CHANGEANT DE SIGNE (l'axe de la borne
monte). Le +4 vertical de l'ancrage arcade (0x40:DEB3) est laisse au noyau,
qui pose l'enfant.

Sortie : src/enemies/warship-elements/core/explosions.asm (commise ; le dump
arcade ne sert qu'a la REGENERER).
Rejeu : python3 tools/gen_core_death.py (depuis games/r-type/).
"""
import os
import random
import struct

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000                      # le segment de donnees 0x1000
LISTE = 0x80CE                     # les couples {dx, dy}, sentinelle 0x8000
VIE = 0x140                        # debe : 320 trames de cascade
PAS_ARCADE = 4                     # ded5 : une explosion quand compteur & 3 == 0
PERIODE = 8                        # notre pas : 8 trames video
GRAINE = 0x80CE


def lire_couples(rom):
    out = []
    off = LISTE
    while True:
        x, y = struct.unpack_from('<hh', rom, SEG + off)
        if x == -0x8000:
            return out
        out.append((x, y))
        off += 4


def borne(v, quoi):
    if not -128 <= v <= 127:
        raise SystemExit('offset %s hors d\'un octet signe : %d' % (quoi, v))
    return v & 0xFF


def main():
    rom = open(ROM, 'rb').read()
    couples = lire_couples(rom)
    spawns = VIE // PAS_ARCADE                  # 80 : ce que la borne joue
    pas = PERIODE // PAS_ARCADE                 # un spawn arcade sur deux
    tirage = random.Random(GRAINE)
    out = [
        '; ---------------------------------------------------------------------------',
        "; LA CASCADE DE MORT DU NOYAU DU VAISSEAU — table GENEREE, ne pas editer",
        '; ---------------------------------------------------------------------------',
        '; Rejeu : python3 tools/gen_core_death.py (depuis games/r-type/).',
        '; Une entree = {dx, dy, subtype} : deux octets signes a ajouter a la',
        "; position de l'enfant, puis le subtype d'explosion (animation + son).",
        '; Une entree toutes les bosscascade.PERIOD (%d) trames video ; la borne' % PERIODE,
        '; en jouait une toutes les %d trames sur sa liste de %d offsets qui boucle' % (PAS_ARCADE, len(couples)),
        '; (0x1000:80CE), 320 trames — ici un spawn sur %d. Fin de table : $80.' % pas,
        '',
        '; le pas du marcheur, en trames video : la table est echantillonnee dessus',
        'bosscascade.PERIOD equ %d' % PERIODE,
        'bosscascade.SMALL equ explosion.subtype.smallx3+explosion.sfx.cascade',
        'bosscascade.BIG   equ explosion.subtype.big.brown+explosion.sfx.cascade',
        '',
        'bosscascade.table',
    ]
    grosses = 0
    for i in range(0, spawns, pas):
        x, y = couples[i % len(couples)]
        vx = borne(round(x * 0.375), 'x')
        vy = borne(round(-y * 0.75), 'y')       # l'axe y de la borne MONTE
        grosse = (tirage.randrange(8) & 6) == 0  # df02 : random & 6 == 0
        grosses += grosse
        out.append('        fcb   $%02X,$%02X,bosscascade.%s   ; t=%3d  arcade %+4d,%+4d (#%d)'
                   % (vx, vy, 'BIG  ' if grosse else 'SMALL', i * PAS_ARCADE,
                      x, y, i % len(couples)))
    out.append('        fcb   $80')
    dst = 'src/enemies/warship-elements/core/explosions.asm'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('ecrit %s : %d entrees (%d grosses), %d offsets arcade, %d spawns arcade'
          % (dst, spawns // pas, grosses, len(couples), spawns))


if __name__ == '__main__':
    main()
