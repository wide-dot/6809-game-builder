;*******************************************************************************
; scores — les dix lignes de chiffres du tableau des scores, portées de la v1
;
; Le code v1 est repris tel quel ; l'unité est paginée dans l'arène title,
; colocalisée avec ses images gfxcomp et leur index (même direntry). Dix
; instances du même objet (sous-types $80-$89 : le bit 7 CACHE la ligne, la
; routine de scores du texte le retire pour les révéler une à une).
;*******************************************************************************

title.scores.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1
; (la ligne 01 de la v1 est l'image 00 de la série).
Img_number_01 equ set_number_0
Img_number_02 equ set_number_1
Img_number_03 equ set_number_2
Img_number_04 equ set_number_3
Img_number_05 equ set_number_4
Img_number_06 equ set_number_5
Img_number_07 equ set_number_6
Img_number_08 equ set_number_7
Img_number_09 equ set_number_8
Img_number_10 equ set_number_9

title.scores.Object
        INCLUDE "src/title/scores/scores.asm"

 ENDSECTION
