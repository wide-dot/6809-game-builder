;*******************************************************************************
; Les flammes de réacteur — unité paginée
;
; La traînée sous le vaisseau pendant la séquence d'ouverture : elle se colle à
; `player1+x_pos - 12` à chaque trame, s'anime, et se supprime quand
; `initlevel1` lui pose `routine = 2`.
;
; Elle aurait sa place dans l'unité du JOUEUR — c'est une pièce du vaisseau, et
; ses trois tables d'index désigneraient la même page. Mais les deux fichiers v1
; nomment leurs routines internes `Init`, `Live` et `Routines` : les réunir dans
; une unité les fait entrer en collision. C'est la même raison qui donne à
; chacune des quatre armes sa propre région.
;
; L'entrée doit être le premier octet : le code d'abord, les scripts ensuite.
;*******************************************************************************

engineflames.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"

; V2-DEVIATION: entrées d'imageset en set_<nom>, le nom que gfxcomp génère.
Img_engineflames_0 equ set_engineflames_0
Img_engineflames_1 equ set_engineflames_1

engineflames.Object
        INCLUDE "src/common/player/engineflames/obj.asm"

; Les deux scripts, portés des properties v1 :
;   Ani_engineflames_init  = 1;Img_0;Img_1;_resetAnim
;   Ani_engineflames_speed = 4;Img_0;Img_1;x4;_nextRoutine
; L'octet qui PRÉCÈDE l'étiquette est la durée d'une image, comme pour les
; scripts du joueur et ceux de l'éclair d'émission.
        fcb   1
Ani_engineflames_init
        fdb   Img_engineflames_0
        fdb   Img_engineflames_1
        fcb   _resetAnim
; ARCADE (run_bonus_speed_flame 0x405914) : le compteur part de 0x10 et
; l'image se lit dans ses bits 2-3 — QUATRE images, quatre trames chacune,
; SEIZE trames en tout, puis l'objet se libere. Quatre entrees a duree 4 :
; meme duree au chiffre pres. V2-DEVIATION : deux images au lieu de quatre,
; c'est l'art que le portage a (celui de la sequence d'intro).
        fcb   4
Ani_engineflames_speed
        fdb   Img_engineflames_0
        fdb   Img_engineflames_1
        fdb   Img_engineflames_0
        fdb   Img_engineflames_1
        fcb   _nextRoutine

 ENDSECTION
