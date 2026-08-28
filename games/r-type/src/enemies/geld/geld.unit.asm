;*******************************************************************************
; geld — le mangeur de gommes du stage 4, porte depuis l'arcade
;
; Pas de source v1 (la v1 ne portait que le stage 1) : le portage suit le
; skill enemy-port, la base Ghidra fait foi. L'unite porte les en-tetes
; communs, les tables arcade converties et la table de liaison des images.
;
; L'entree doit etre le PREMIER octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

geld.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

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
        INCLUDE "src/stages/04/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"

geld.Object
        INCLUDE "src/enemies/geld/obj.asm"

; --- les presets de spawn, la MEME table que bug et pow (arcade 0x18DD0)
PresetXYIndex
        INCLUDE "src/common/lib/presets/18dd0_preset-xy.asm"

; ---------------------------------------------------------------------------
; LES CONSTANTES DU PORTAGE — les valeurs arcade, converties une fois
; ---------------------------------------------------------------------------
; L'echelle : 1 px arcade = 0,375 px v2 en X, 0,75 en Y (scale.asm porte les
; pas 8.8 partages). Les fenetres d'engagement et le coin de creusement sont
; donnes en px arcade par la borne ; on les pose ici convertis, pour que le
; code n'ait pas une multiplication a faire par trame.
geld.WINX     equ 6           ; 0x10 = 16 px arcade -> 6 px v2 (8fe3)
geld.WINY     equ 3           ; 4 px arcade -> 3 lignes v2 (9007)
geld.CARVE_X  equ 2           ; x - 4 px arcade -> -1,5 px v2, arrondi (90ec)
geld.CARVE_Y  equ 3           ; y + 4 px arcade -> +3 lignes v2 (90f0)
; Le decalage applique aux caps HORIZONTAUX : une rangee de gommes entiere.
; C'est la hauteur de cellule du champ (pscroll.CELL_H) — le geld d'un ennemi
; ne peut pas nommer un symbole du stage, la valeur est donc reprise ici, et
; elle est verifiee par le rendu : un pas plus court passe sous l'arrondi de
; la division par six et ne deplace rien.
geld.CARVE_ROW equ 6
geld.TURN     equ 31          ; 9055 : la duree du virage, en trames
geld.SCREEN_W equ 160         ; le champ visible, en px v2
geld.SCREEN_H equ 200

; --- slot de spawn -> direction (arcade 0x1000:3F76, 16 octets)
;     0 = DROITE, 1 = GAUCHE, 2 = BAS, 3 = HAUT
geld.slot.variant
        fcb   3,3,3,1,1,1,1,1,1,2,2,2,0,0,0,0

; --- la vitesse par direction, en 8.8 v2 (arcade 0x1000:3F86, difficulte 0)
; L'arcade donne 1,0 px/trame arcade a la premiere difficulte : en v2 cela
; vaut $0060 en X (0,375 px) et $00C0 en Y (0,75) — les memes pas que le
; script de mouvement du cytron, et pour la meme raison (scale.asm).
; Ordre : dx, dy. Variantes 0=droite, 1=gauche, 2=bas, 3=haut ; l'axe Y de la
; v2 est INVERSE de celui de l'arcade, la conversion est cuite ici.
; Le pas d'UNE trame, en 8.8 sur un octet — le code choisit l'axe et le sens
; par la variante (cf. obj.asm) et multiplie par le frame drop, comme cancer.
geld.STEPX    equ $60         ; 1 px arcade = 0,375 px v2
geld.STEPY    equ $C0         ; 1 px arcade = 0,75 ligne v2

; --- les poses : 4 par direction (arcade 0x1000:4006, 16 recettes)
; L'ordre suit les variantes : droite, gauche, bas, haut.
geld.images
        fdb   set_geld_right_0,set_geld_right_1,set_geld_right_2,set_geld_right_3
        fdb   set_geld_left_0,set_geld_left_1,set_geld_left_2,set_geld_left_3
        fdb   set_geld_down_0,set_geld_down_1,set_geld_down_2,set_geld_down_3
        ; V2-DEVIATION : pas d'art propre pour le cap HAUT — l'export arcade
        ; n'a que trois jeux de patrouille (right/left/down). On reemploie les
        ; poses « bas » : le geld vertical se distingue par sa trajectoire, et
        ; un miroir Y de la meme image donnerait le meme symbole (gfxcomp
        ; deduplique par contenu).
        fdb   set_geld_down_0,set_geld_down_1,set_geld_down_2,set_geld_down_3

; --- les poses d'engagement : 2 par cap vise (arcade 0x1000:3FE6)
; La borne en garde 8 paires dont 4 seulement sont atteignables ; on pose les
; quatre utiles, indexees par le CAP (0..3), deux images chacune.
geld.engaged
        fdb   set_geld_engage_0,set_geld_engage_1    ; cap 0 : droite
        fdb   set_geld_engage_2,set_geld_engage_3    ; cap 1 : gauche
        fdb   set_geld_engage_4,set_geld_engage_5    ; cap 2 : bas
        fdb   set_geld_engage_6,set_geld_engage_7    ; cap 3 : haut


 ENDSECTION
