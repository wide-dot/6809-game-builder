#!/usr/bin/env python3
"""Générer les identifiants d'objets d'un stage et son index, depuis sa wave.

La v1 numérotait les objets d'un game mode dans un .glb généré par son pipeline
(ObjID_*), et l'index page/adresse suivait le bin-packing des objets en pages.
Tant que les ennemis ne sont pas portés, chaque identifiant d'une wave pointe
sur l'objet bouchon du stage : la wave, elle, est la vraie — ses horodatages
sont ceux de l'arcade.

Ne lit que les lignes actives : la wave du niveau 2 a plus d'entrées commentées
que d'actives, les ennemis correspondants n'existant pas encore.

    usage : tools/gen_objid.py <NN>
"""
import re
import sys

stage = sys.argv[1]
src = f'src/stages/{stage}/wave.asm'

names = []
# Quelques identifiants ne viennent pas de la wave mais du code des objets :
# pata-pata cite l'explosion en mourant. Ils sont numerotes avec les autres.
# L'objet des scripts d'animation a lui aussi un identifiant : moveByScript
# lit sa page et son adresse dans l'index, comme n'importe quel objet.
names = ['ObjID_animation', 'ObjID_explosion']

for line in open(src):
    code = line.split(';')[0]
    if not re.match(r'\s+(fcb|fdb)\s', code):
        continue
    for name in re.findall(r'ObjID_[A-Za-z0-9_]+', code):
        if name not in names:
            names.append(name)

# Les equates partent d'un cote (la wave en a besoin, et elle vit desormais
# dans le comblement d'un pageset), les tables de l'autre (elles restent
# residentes : RunObjects les lit sans monter de page).
equ_out = [f"""* ===========================================================================
* Objets du stage {stage} — genere par tools/gen_objid.py {stage}
* ===========================================================================
* Les {len(names)} identifiants que la wave reelle du niveau {stage} reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.
"""]
equ_out.append('')
for i, name in enumerate(names, start=1):
    equ_out.append(f'{name:<28} equ {i}')
equ_out.append(f'objid.count                  equ {len(names)}')
equ_out.append('objid.animation              equ ObjID_animation')
equ_out.append('')
open(f'src/stages/{stage}/objid.const.asm', 'w').write('\n'.join(equ_out))

out = ['* Index d\'objets — genere par tools/gen_objid.py, ne pas editer', '']
# Les ennemis portes vivent dans la page des ennemis et ont leur propre
# point d'entree ; les autres identifiants visent encore le bouchon du stage.
# ObjID_patapata vise encore le bouchon : l'unite de l'ennemi est construite
# et chargee, mais l'executer plante — voir le readme.
PORTED = {'ObjID_animation': ('anim', 'Ani_Asd_common')}

out.append('Obj_Index_Page')
out.append('        fcb   0                        ; id 0 : slot reserve, jamais execute')
for name in names:
    if name in PORTED:
        out.append(f'        fcb   map.RAM_OVER_CART+{PORTED[name][0]}.page   ; {name}')
    else:
        out.append(f'        fcb   map.RAM_OVER_CART+stage.page   ; {name}')
out.append('')
out.append('Obj_Index_Address')
out.append('        fdb   0')
for name in names:
    if name in PORTED:
        out.append(f'        fdb   {PORTED[name][1]}        ; {name}')
    else:
        out.append(f'        fdb   stage.placeholder        ; {name}')
out.append('')
out.append('* Les scripts d\'animation. Les vrais vivent dans un objet commun qui')
out.append('* n\'est pas encore chargeable (8 Ko de donnees de lien) : en attendant,')
out.append('* la table est locale et vide — aucun objet ne s\'anime encore.')
out.append('Ani_Page_Index')
for _ in range(len(names) + 1):
    out.append('        fcb   map.RAM_OVER_CART+stage.page')
out.append('')
out.append('Ani_Asd_Index')
for _ in range(len(names) + 1):
    out.append('        fdb   Ani_Asd_none')
out.append('')
out.append('Ani_Asd_none')
out.append('        fdb   0')
out.append('')
out.append('* La page des images de chaque objet. Tant que les ennemis ne sont pas')
out.append('* portes, le bouchon ne dessine rien et la valeur ne sert pas.')
out.append('Img_Page_Index')
out.append('        fcb   map.RAM_OVER_CART+stage.page')
for name in names:
    page = PORTED[name][0] if name in PORTED else 'stage'
    out.append(f'        fcb   map.RAM_OVER_CART+{page}.page   ; {name}')
out.append('')

open(f'src/stages/{stage}/objid.index.asm', 'w').write('\n'.join(out))
print(f'stage {stage} : {len(names)} identifiants — {", ".join(names)}')
