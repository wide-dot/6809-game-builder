#!/usr/bin/env python3
"""Reacteurs et capsules du vaisseau : tables depuis la ROM.

Ce que ca produit (src/enemies/warship-elements/reactor/tables.asm) :
  - le SCRIPT D'ORIENTATION des quatre reacteurs de ventre (1000:7e56) :
    des paires {seuil en trames depuis la naissance du maitre, etat}, l'etat
    portant l'orientation en octet bas et, au bit 15, l'ordre de LACHER UNE
    FLAMME. Les quatre reacteurs lisent le MEME script — c'est ce qui les
    synchronise alors qu'ils naissent a des instants differents.
  - la table de directions (1000:7e9a) : six entrees vers cinq recettes.
  - les boites des cinq pieces, converties.

Usage : python3 tools/gen_warship_reactors.py   (depuis games/r-type)
"""
import os

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
DATA = 0x1000 * 16
SCRIPT, DIRS = 0x7E56, 0x7E9A
# recette arcade -> le jeu d'images converti
POSES = {0x7EA6: 'bottom_reactor_bottom',
         0x7EAC: 'bottom_reactor_bottom_right',
         0x7EB2: 'bottom_reactor_bottom_right_full',
         0x7EB8: 'bottom_reactor_bottom_left',
         0x7EBE: 'bottom_reactor_bottom_left_full'}
BOITES = (('rreactor.BODYBOX', 'rreactor.BODYCTR', 0x7A3C, 'corps du reacteur arriere'),
          ('rreactor.FLAMEBOX', 'rreactor.FLAMECTR', 0x7A44, 'ses flammes geantes'),
          ('breactor.BOX', 'breactor.CTR', 0x7ECA, 'reacteur de ventre'),
          ('capsule.BOX', 'capsule.CTR', 0x7B46, 'capsule de survie'),
          ('detach.BOX', 'detach.CTR', 0x7A8C, 'petite capsule et triangle'))


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rom = open(ROM, 'rb').read()

    def w(o):
        return rom[DATA + o] | (rom[DATA + o + 1] << 8)

    def sw(o):
        v = w(o)
        return v - 0x10000 if v >= 0x8000 else v

    out = [
        "; Reacteurs et capsules — GENERE par tools/gen_warship_reactors.py",
        "; depuis le dump arcade.",
        "",
        "; LE SCRIPT D'ORIENTATION des quatre reacteurs de ventre (1000:7e56).",
        "; Une entree : fdb seuil (trames depuis la naissance du MAITRE), fcb",
        "; orientation (0..5), fcb flamme (0 ou 1). Fin : seuil = -1.",
        "; Les quatre reacteurs lisent ce meme script — c'est ce qui les",
        "; synchronise alors qu'ils naissent a des instants differents.",
        "breactor.script",
    ]
    i = 0
    while True:
        thr, st = w(SCRIPT + 4 * i), w(SCRIPT + 4 * i + 2)
        if thr == 0xFFFF:
            out.append('        fdb   -1')
            break
        # le seuil arcade est un compte de trames : la v2 tourne a 50 Hz contre
        # 55 en arcade, mais tout le portage garde les timestamps arcade tels
        # quels (cf. la wave) — on ne convertit pas.
        out.append('        fdb   %d' % thr)
        out.append('        fcb   %d,%d ; #%d etat %04X'
                   % ((st & 0xFF) // 2, 1 if st & 0x8000 else 0, i, st))
        i += 1
    out += ["", "; Les six directions (1000:7e9a) vers cinq jeux d'images.",
            "breactor.Sets"]
    for k in range(6):
        out.append('        fdb   set_%s_0 ; %d' % (POSES[w(DIRS + 2 * k)], k))
    out.append("")
    for nomb, nomc, adr, libelle in BOITES:
        x0, x1, y0, y1 = sw(adr), sw(adr + 2), sw(adr + 4), sw(adr + 6)
        rx, ry = round((x1 - x0) * .375 / 2), round((y1 - y0) * .75 / 2)
        cx, cy = round((x0 + x1) / 2 * .375), round(-(y0 + y1) / 2 * .75)
        out.append('; %s (1000:%04X) arcade x[%d..%d] y[%d..%d]'
                   % (libelle, adr, x0, x1, y0, y1))
        out.append('%s equ $%02X%02X' % (nomb, rx, ry))
        out.append('%s equ $%02X%02X' % (nomc, cx & 255, cy & 255))
    out.append("")
    dst = os.path.join(racine, 'src/enemies/warship-elements/reactor/tables.asm')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out))
    print('%d entrees de script -> reactor/tables.asm' % i)


if __name__ == '__main__':
    main()
