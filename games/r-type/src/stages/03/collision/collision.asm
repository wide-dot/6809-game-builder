;*******************************************************************************
; La collision terrain du stage 3 — unite paginee, gabarit du stage 1
;
; La moitie RESIDENTE (terrainCollision.main + init.do) est au moteur ; cette
; unite est la moitie MONTEE : le code de consultation, ses tables
; dimensionnees par lvlMapWidth, et les cartes du niveau — deux plans distincts (fond et decor), comme la v1
; (vérité : le terrain.asm v1 du stage, dans src/stages/03/terrain/).
;
; L'entree est le PREMIER octet : quatre jmp en tete du moteur inclus, que
; terrainCollision.init.do adresse par l'index d'objets a +0/+3/+6/+9.
;
; LE PLAN DE FOND DE CE STAGE A SA PROPRE CAMERA (26/08/2026). Ce n'est pas du
; terrain : c'est le BATTLESHIP, la couche mscroll, qui defile sur les DEUX
; axes et derive de l'avant-plan (jusqu'a 1462 px et 17 lignes de collision au
; bout du script de choregraphie). Le decalage du stage 1 — un glissement du
; plan de fond vers la droite, pour suivre le boss — ne peut pas rendre ca :
; il est a un seul axe et a un seul sens.
; On pose donc BG_OWN_CAMERA, qui assemble dans le moteur un second chemin
; d'indexation du plan 0 : ses propres base et reste sous-tuile, sur les deux
; axes — la formulation meme de l'arcade (40:1eb5 replie x/y_background_camera
; avec leur reste). Les autres stages ne posent pas l'equate et ne changent pas
; d'un octet. Etude complete : doc/bship-collision-plan.md
;*******************************************************************************

terrainCollision.unit EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

; Le plan 0 s'indexe par la camera de la couche battleship, pas par le scroll.
BG_OWN_CAMERA equ 1

        ; la geometrie du plan de fond, partagee avec le main qui recale les
        ; registres de lecture a chaque trame
        INCLUDE "src/stages/03/collision/collision.equ"

lvlMapWidth equ 48 ; stage 03 width (terrain.asm v1)
 IFNE lvlMapWidth-bship.COLSTRIDE
        ERROR le stride du plan de fond a derive de lvlMapWidth
 ENDC
; La borne d'impact, en px : la largeur de la carte de CE stage.
map_width   equ 96*12

terrainCollision.unit
        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   collisionMapBackground
        fdb   collisionMapForeground

; LE PLAN DE FOND : la silhouette du battleship, DEJA dans le repere de la
; couche. Mesure (26/08/2026) : le bin occupe x 216..438, y 12..144 — la boite
; de map/battleship.png a l'octet pres. C'est une extraction arcade, donc la
; verite ; l'art n'en est qu'une vue. Rien a convertir : il manquait le chemin
; de lecture.
;
; LA COUCHE BOUCLE VERTICALEMENT. mscroll replie sa camera dans [0, hauteur[
; (« wrap camera position in map, infinite level loop ») : camera.y vaut donc
; 0..383, et l'excursion negative du script (-37,5 px) se presente comme
; 346..383. La fenetre de vue enjambe la couture, la collision doit l'enjamber
; aussi — et on paye ca en DONNEES, pas en tests :
;   lignes  0..29  le bin, les 180 px du haut de couche ou vit le vaisseau
;   lignes 30..63  le bas de couche, vide (l'art n'y met rien)
;   lignes 64..93  LA REPETITION des lignes 0..29, pour la couture
; La ligne consultee vaut base + 0..30, base = camera.y/6 dans 0..63 : l'index
; reste dans 0..93, la lecture ne sort jamais et ne teste rien.
collisionMapBackground
        INCLUDEBIN "src/stages/03/terrain/level3_bc.bin"
        fill  0,(bship.ROWS-bship.BINROWS)*lvlMapWidth
        INCLUDEBIN "src/stages/03/terrain/level3_bc.bin"   ; la couture

collisionMapForeground
        INCLUDEBIN "src/stages/03/terrain/level3_fc.bin"

 ENDSECTION
