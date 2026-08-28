#!/usr/bin/env python3
"""Le script de spawn du vaisseau : l'export arcade -> la table v2.

L'export de re.arcade (out/warship/warship-spawn-script.asm) est un SQUELETTE :
il porte les seuils et les positions deja converties, et cite en commentaire le
tick arcade de chaque entree, en attendant que les objets v2 existent. Ce script
fait la derniere etape : associer a chaque tick arcade son ObjID v2 et son
sous-type, et emettre la table que le pilote parcourt.

Une entree dont le tick n'est pas encore porte recoit l'identifiant 0 — le
parcours la saute. C'est ce qui rend la campagne livrable par tranches : les
seuils et les positions des 68 entrees sont posees une fois pour toutes, et
chaque tranche en allume une famille.

Usage : python3 tools/gen_warship_spawn.py   (depuis games/r-type)
"""
import os
import re
import sys

EXPORT = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
          '/out/warship/warship-spawn-script.asm')

# tick arcade -> (ObjID v2, sous-type, libelle). Ce qui n'est pas ici n'est pas
# encore porte : l'entree garde sa place et sa position, avec l'identifiant 0.
PORTE = {
    0xE26A: ('ObjID_warship_turret', 'turret.TOP',    'petite tourelle HAUT'),
    0xE277: ('ObjID_warship_turret', 'turret.BOTTOM', 'petite tourelle BAS'),
    0xE129: ('ObjID_warship_turret', 'turret.BIG',    'grosse tourelle'),
}

# Les 27 sous-parties de coque : leurs vignettes se suivent de douze en douze
# a partir de 40:c656, et le RANG de la vignette est le sous-type de la piece —
# c'est lui qui designe sa boite dans la table extraite de la ROM.
for _i in range(27):
    PORTE[0xC656 + 12 * _i] = ('ObjID_warship_part', str(_i),
                               'sous-partie de coque #%d' % _i)

# L'EXPORT CONVERTIT L'ABSCISSE COMME UN DELTA. Les trois champs convertis par
# l'extracteur ne sont pas de meme nature : le seuil et l'ecart en y sont des
# DISTANCES (le rapport suffit, et l'export est juste), mais l'abscisse est une
# POSITION — il lui faut aussi le decalage d'origine, `(x - 320) x 0,375 + 8`,
# la formule de Conv.java que tout le portage utilise. L'export applique le
# seul rapport, d'ou 269 la ou le jeu attend 157.
# La correction est affine et exacte, sans repasser par la ROM :
#   x_juste = (x_export / 0,375 - 320) x 0,375 + 8 = x_export - 112
# 157 est bien l'ancre de naissance des autres ennemis (gouger, brood : 158).
# A remonter a l'extracteur — ici on corrige au plus pres de l'usage.
X_ORIGINE = 112

ENTREE = re.compile(r'fdb\s+(-?\d+),(-?\d+),(-?\d+)\s*;\s*#(\d+)\s+arcade tick '
                    r'0x([0-9A-Fa-f]+)')


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if not os.path.exists(EXPORT):
        sys.exit('export absent : ' + EXPORT)
    out = [
        "; Le script de spawn du vaisseau — GENERE par tools/gen_warship_spawn.py",
        "; depuis re.arcade.r-type/out/warship/warship-spawn-script.asm.",
        ";",
        "; Une entree : fdb seuil (px de course de la couche), fdb x ecran,",
        ";              fdb dy (relatif a l'ancre du maitre), fcb objid, fcb sous-type",
        "; Fin : seuil = -1.",
        ";",
        "; L'abscisse est corrigee du decalage d'origine que l'export oublie",
        "; (il traite une POSITION comme une DISTANCE) : voir le generateur.",
        "; Le seuil se compare a mscroll.camera.x, la course de la couche (0..285).",
        "; L'ordonnee vaut warship.BASEY + dy : l'arcade fait naitre chaque piece a",
        "; `parent.Y + dy` et son maitre est pose a Y=0xF0 (create_warship 40:c46e),",
        "; soit 117 chez nous.",
        ";",
        "; UN IDENTIFIANT NUL veut dire « pas encore porte » : le parcours saute",
        "; l'entree. Les 68 places sont posees une fois pour toutes, chaque tranche",
        "; de la campagne en allume une famille (doc/warship-parts-plan.md).",
        "; L'etiquette warship.spawn.script est posee par le wrapper <unit> du",
        "; config, comme pour le script de camera — ne pas la redefinir ici.",
        "",
        '        INCLUDE "src/stages/03/objid.const.asm"',
        '        INCLUDE "src/enemies/warship-elements/turret/turret.equ"',
        "",
    ]
    n_porte = n_total = 0
    familles = {}
    for ligne in open(EXPORT):
        m = ENTREE.search(ligne)
        if not m:
            continue
        seuil, x, dy, idx, tick = (int(m.group(1)), int(m.group(2)),
                                   int(m.group(3)), int(m.group(4)),
                                   int(m.group(5), 16))
        n_total += 1
        if tick in PORTE:
            objid, sous, libelle = PORTE[tick]
            n_porte += 1
            familles[libelle] = familles.get(libelle, 0) + 1
        else:
            objid, sous, libelle = '0', '0', 'arcade %04X, pas encore porte' % tick
        out.append('        fdb   %d,%d,%d' % (seuil, x - X_ORIGINE, dy))
        out.append('        fcb   %s,%s ; #%d %s' % (objid, sous, idx, libelle))
    out.append('        fdb   -1')
    out.append('')
    dst = os.path.join(racine, 'src/stages/03/warship/spawn-script.asm')
    with open(dst, 'w') as f:
        f.write('\n'.join(out))
    print('%d entrees, %d portees :' % (n_total, n_porte))
    for k, v in sorted(familles.items()):
        print('   %-22s x%d' % (k, v))
    print('ecrit : src/stages/03/warship/spawn-script.asm')


if __name__ == '__main__':
    main()
