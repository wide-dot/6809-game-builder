;*******************************************************************************
; La collision terrain du stage 4 — unite paginee, gabarit du stage 1
;
; La moitie RESIDENTE (terrainCollision.main + init.do) est au moteur ; cette
; unite est la moitie MONTEE : le code de consultation, ses tables
; dimensionnees par lvlMapWidth, et les cartes du niveau — un seul plan servi deux fois, comme la v1
; (vérité : le terrain.asm v1 du stage, dans src/stages/04/terrain/).
;
; L'entree est le PREMIER octet : quatre jmp en tete du moteur inclus, que
; terrainCollision.init.do adresse par l'index d'objets a +0/+3/+6/+9.
;*******************************************************************************

terrainCollision.unit EXPORT
; LA CARTE DES GOMMES EST RESIDENTE, ET C'EST LE PLAN ARRIERE DE CE STAGE.
; Elle vit dans l'arene stage4.res (gumres.unit.asm) : pscroll la mute, le
; moteur de collision la lit comme seconde couche. Une seule carte, donc rien
; a tenir d'accord — avant le 24/08/2026 l'etat des gommes existait en deux
; exemplaires (le champ de pscroll et la carte de collision) et les deux
; divergeaient des la premiere pousse.
collisionMapForeground EXPORT
pscroll.gum.map        EXTERNAL

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

lvlMapWidth equ 48 ; stage 04 width (terrain.asm v1)
; La borne d'impact, en px : la largeur de la carte de CE stage.
map_width   equ 96*12

terrainCollision.unit
        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   pscroll.gum.map        ; plan 0 : les gommes, residentes
        fdb   collisionMapForeground ; plan 1 : le decor dur

; LES DEUX PLANS DE CE STAGE (24/08/2026)
;   AVANT   (plan 1) : le decor DUR seul, statique, jamais ecrit
;   ARRIERE (plan 0) : la carte des GOMMES, residente et mutable
;
; L'arcade obtient le meme resultat autrement : chez elle une gomme EST une
; tuile de la tilemap de premier plan, donc solide par le meme test que le
; decor. Ici on reutilise le DOUBLE TEST que le moteur sait deja faire pour un
; stage a deux plans : globals.backgroundSolid pose, chaque site teste l'avant
; puis l'arriere, et « solide » veut dire « dur OU gomme » sans une ligne de
; moteur en plus. Le double test gere en prime le cas ou les deux plans se
; deplacent l'un par rapport a l'autre (suivi du boss au stage 1, vaisseau de
; fond au stage 3) — c'est ce qui l'a fait preferer a une routine d'union.
;
; level4_fc n'est plus utilise : `hard OR ball == level4_fc` est verifie a
; l'extraction, les deux moities vivent maintenant chacune de leur cote.
collisionMapForeground
        INCLUDEBIN "src/stages/04/terrain/level4_hard.bin"

; Les gommes D'ORIGINE, en RLE (263 o au lieu de 1 440) : pellet.reset
; recompose C = T OR D0 a la reprise au checkpoint, pour que la vague ne rejoue
; pas Cytron par-dessus ses propres traces. Genere par tools/rle_mask.py depuis
; level4_ball.bin ; la region collision est trop bornee pour une copie brute.
pellet.ball0
        INCLUDEBIN "src/stages/04/terrain/level4_ball.rle"

; Les primitives du champ, au contact des deux cartes (meme page).
        INCLUDE "src/common/lib/pellet.asm"

 ENDSECTION
