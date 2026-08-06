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
# ObjID_fade est resident (le fondu d'ouverture de chaque stage) : sa page est
# celle du moteur, pas celle du stage.
# Le joueur cite l'armement, qui n'est pas porte : ces identifiants sont
# numerotes avec les autres et pointent le bouchon du stage.
# La chaine de tir ennemi ne vient pas non plus de la wave : un ennemi cite
# createFoeFire et loadFirePreset comme sous-routines paginees (RunPgSubRoutine
# lit leur page et leur adresse dans l'index), et createFoeFire pose
# ObjID_foefire dans l'OST du projectile qu'il alloue.
names = ['ObjID_animation', 'ObjID_explosion', 'ObjID_fade', 'ObjID_Player1',
         'ObjID_Weapon', 'ObjID_commonmissile', 'ObjID_beamcharge',
         'ObjID_beamp', 'ObjID_emitter_flash', 'ObjID_collision',
         'ObjID_createFoeFire', 'ObjID_loadFirePreset', 'ObjID_foefire',
         'ObjID_initlevel1', 'ObjID_engineflames', 'ObjID_messages',
         # Les bonus : le POW vient de la wave, mais ce qu'il fait naitre en
         # mourant — la boite a option, ou le bit device quand le quartet haut
         # de son subtype vaut 5 — n'y figure pas.
         'ObjID_pow_optionbox', 'ObjID_bitdevice',
         # L'armement : le force pod vit dans un slot statique, la wave ne le
         # nomme donc jamais ; ses trois armes, c'est lui qui les fait naitre.
         'ObjID_forcepod', 'ObjID_forcepod_simplefire',
         'ObjID_forcepod_reboundlaser', 'ObjID_forcepod_counterairlaser',
         # Le tir du scant : la wave ne le nomme jamais, c'est scant qui le
         # fait naitre par LoadObject.
         'ObjID_scantfire']

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
# Garde d'inclusion : un membre de pageset porte plusieurs blocs qui incluent
# chacun cet en-tete (chaque objet a besoin des identifiants).
equ_out.append(f' IFNDEF OBJID_CONST_{stage}')
equ_out.append(f'OBJID_CONST_{stage}          equ 1')
equ_out.append('')
for i, name in enumerate(names, start=1):
    equ_out.append(f'{name:<28} equ {i}')
equ_out.append(f'objid.count                  equ {len(names)}')
equ_out.append('objid.animation              equ ObjID_animation')
equ_out.append('')
equ_out.append(' ENDC')
equ_out.append('')
open(f'src/stages/{stage}/objid.const.asm', 'w').write('\n'.join(equ_out))

out = ['* Index d\'objets — genere par tools/gen_objid.py, ne pas editer', '']
# Les ennemis portes vivent dans la page des ennemis et ont leur propre
# point d'entree ; les autres identifiants visent encore le bouchon du stage.
PORTED = {'ObjID_animation': ('common.anim', 'Ani_Asd_common'),
          'ObjID_fade':      ('common.fade', 'PaletteFade'),
          'ObjID_Player1':   ('common.player', 'Player'),
          'ObjID_patapata': (None, 'patapata.Object'),
          'ObjID_explosion': ('common.explosion', 'explosion.Object'),
          'ObjID_createFoeFire':  ('common.firechain', 'createFoeFire'),
          'ObjID_loadFirePreset': ('common.firechain', 'loadFirePreset.Object'),
          'ObjID_foefire':        ('common.foefire', 'foefire.Object'),
          'ObjID_engineflames':   ('common.engineflames', 'engineflames.Object'),
          'ObjID_Weapon':        ('common.weapon', 'Weapon'),
          'ObjID_beamcharge':    ('common.beamcharge', 'Beamcharge'),
          'ObjID_beamp':         ('common.beamp', 'Beam'),
          'ObjID_emitter_flash': ('common.emflash', 'emitterFlash.Object'),
          'ObjID_messages':      ('common.messages', 'messages.Object'),
          'ObjID_pow':           ('common.pow', 'pow.Object'),
          'ObjID_pow_optionbox': ('common.optionbox', 'powOptionbox.Object'),
          'ObjID_bitdevice':     ('common.bitdevice', 'bitdevice.Object'),
          'ObjID_forcepod':                 ('common.forcepod', 'forcepod.Object'),
          'ObjID_forcepod_simplefire':      ('common.simplefire', 'simplefire.Object'),
          'ObjID_forcepod_reboundlaser':    ('common.reboundlaser', 'reboundlaser.Object'),
          'ObjID_forcepod_counterairlaser': ('common.counterairlaser', 'counterairlaser.Object'),
          # Le cast d'ennemis : un direntry par ennemi, tous sur la page $05.
          'ObjID_bug':     (None, 'bug.Object'),
          # bink est RANGE PAR LE BUILDER dans la queue d'un pageset (un
          # <block>), pas dans une region declaree : sa page n'est pas
          # `<region>.page` mais l'equate que le pageset publie pour le
          # symbole du bloc, `<symbole>.page`. None marque ce cas.
          'ObjID_bink':    (None,      'bink.Object'),
          'ObjID_blaster': (None, 'blaster.Object')}
# Ce qui n'est porte que pour CERTAINS stages : la collision terrain a une
# unite par niveau, et seul le stage 1 a la sienne pour l'instant.
if stage == '01':
    PORTED['ObjID_collision'] = ('collision', 'terrainCollision.unit')
    # Les ennemis propres au niveau : ranges par le builder dans la queue des
    # pagesets de tuiles du stage, leur page est l'equate <symbole>.page.
    PORTED['ObjID_scant'] = (None, 'scant.Object')
    PORTED['ObjID_scantfire'] = (None, 'scantfire.Object')
    # La sequence d'ouverture est propre au niveau : elle vit dans l'unite du
    # stage, donc sa page est celle du stage et son adresse un symbole local.
    PORTED['ObjID_initlevel1'] = ('stageinit', 'initlevel1.Object')

out.append('Obj_Index_Page')
out.append('        fcb   0                        ; id 0 : slot reserve, jamais execute')
for name in names:
    if name in PORTED:
        region, addr = PORTED[name]
        page = f'{addr}.page' if region is None else f'{region}.page'
        out.append(f'        fcb   map.RAM_OVER_CART+{page}   ; {name}')
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
out.append('        fcb   map.RAM_OVER_CART+stage.page')
for name in names:
    if name in PORTED:
        region, addr = PORTED[name]
        page = f'{addr}.page' if region is None else f'{region}.page'
    else:
        page = 'stage.page'
    out.append(f'        fcb   map.RAM_OVER_CART+{page}   ; {name}')
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
    if name in PORTED:
        region, addr = PORTED[name]
        page = f'{addr}.page' if region is None else f'{region}.page'
    else:
        page = 'stage.page'
    out.append(f'        fcb   map.RAM_OVER_CART+{page}   ; {name}')
out.append('')

open(f'src/stages/{stage}/objid.index.asm', 'w').write('\n'.join(out))
print(f'stage {stage} : {len(names)} identifiants — {", ".join(names)}')
