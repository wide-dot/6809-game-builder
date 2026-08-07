#!/usr/bin/env python3
"""Générer l'unité hôte et le bloc de configuration d'un ennemi porté de la v1.

Le travail de câblage d'un ennemi est mécanique et se répète : une unité hôte
qui porte les en-têtes communs et la table de liaison `Img_* -> set_*`, un bloc
`<direntry>` avec son `<gfxcomp>`, et le retrait des INCLUDE v1 du fichier
importé. Ce qui varie, c'est la liste de sprites — et elle est déjà écrite, dans
le .properties de la v1.

Le script LIT ce .properties et produit les deux morceaux. Il ne devine rien :
les variantes (NB0, XB0, NB1) sont traduites par la table de sprite-variants.md,
et une variante inconnue est une erreur, pas un défaut silencieux.

    usage : tools/gen_enemy_unit.py <nom> <chemin .properties v1> [<répertoire images v2>]

Écrit l'unité dans src/enemies/<nom>/<nom>.unit.asm et le bloc XML sur stdout,
à coller dans to8.config.xml.
"""
import os
import re
import sys

# sprite-variants.md, la table de correspondance
VARIANTS = {
    'NB0': ('bdraw', 'none', 0),
    'NB1': ('bdraw', 'none', 1),
    'XB0': ('bdraw', 'x', 0),
    'XB1': ('bdraw', 'x', 1),
    'ND0': ('draw', 'none', 0),
    'XD0': ('draw', 'x', 0),
}

name = sys.argv[1]
props = sys.argv[2]
imgdir = sys.argv[3] if len(sys.argv) > 3 else f'src/enemies/{name}/images'

sprites = []          # (symbole v1, fichier png, [variantes])
for line in open(props, encoding='utf-8', errors='replace'):
    m = re.match(r'^sprite\.(\w+)=([^;]+);(.*)$', line.strip())
    if not m:
        continue
    sym, path, variants = m.group(1), m.group(2), m.group(3).split(',')
    for v in variants:
        if v.strip() not in VARIANTS:
            raise SystemExit(f"variante inconnue '{v}' pour {sym} — cf. sprite-variants.md")
    sprites.append((sym, os.path.basename(path), [v.strip() for v in variants]))

if not sprites:
    raise SystemExit(f"aucun sprite dans {props}")

# --- le bloc XML ---------------------------------------------------------
out = []
out.append(f'                <direntry name="common.{name}" loadtimelink="LINK" bake="auto">')
out.append(f'                    <lwasm gensource="gen/enemies/{name}.asm">')
out.append('                        <asm filename="gen/directories/disk0/entries.asm"/>')
out.append(f'                        <asm filename="src/enemies/{name}/{name}.unit.asm"/>')
out.append(f'                        <gfxcomp gendir="gen/enemies/{name}"')
out.append(f'                                 gensource="gen/enemies/{name}/includes.asm"')
out.append(f'                                 genindex="gen/enemies/{name}/index.asm"')
out.append(f'                                 file="common.{name}">')
for i, (sym, png, variants) in enumerate(sprites):
    short = sym[4:] if sym.startswith('Img_') else sym
    out.append(f'                            <image name="{short}" filename="{imgdir}/{png}" index="{i}">')
    for v in variants:
        enc, mirror, shift = VARIANTS[v]
        out.append(f'                                <encoder name="{enc}" mirror="{mirror}" shift="{shift}"/>')
    out.append('                            </image>')
out.append('                        </gfxcomp>')
out.append('                    </lwasm>')
out.append('                </direntry>')
print('\n'.join(out))

# --- l'unité hôte --------------------------------------------------------
aliases = '\n'.join(
    f"{sym:<28} equ set_{sym[4:] if sym.startswith('Img_') else sym}"
    for sym, _, _ in sprites)

unit = f''';*******************************************************************************
; {name} — ennemi porté de la v1
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

{name}.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : les macros de tir y lisent la page et
; l'adresse des sous-routines paginées avant de les faire monter.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par décalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/animation/index.equ"
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
{aliases}

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
{name}.Object
        INCLUDE "@@SOURCE@@"

 ENDSECTION
'''
dest = f'src/enemies/{name}/{name}.unit.asm'
open(dest, 'w', encoding='utf-8').write(unit)
print(f"\n* unité écrite : {dest} ({len(sprites)} sprites)"
      f" — remplacer @@SOURCE@@ par le .asm v1", file=sys.stderr)
