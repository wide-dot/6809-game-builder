;*******************************************************************************
; push_button — le « PUSH FIRE BUTTON » clignotant du title, porté de la v1
;
; Le code v1 est repris tel quel ; l'unité est paginée dans l'arène title,
; colocalisée avec ses images gfxcomp et leur index (même direntry). Son
; entrée est auto-modifiée par le main comme celle du logo ($39/$A6, l'idiome
; v1 des phases 7 et 9).
;
; Le script d'animation vient des properties v1 :
;   animation.Ani_push_button=3;Img_0;Img_1;Img_2;Img_1;_resetAnim
; L'octet qui PRÉCÈDE l'étiquette est la durée d'une image (le format des
; scripts du joueur — voir engineflames.asm).
;*******************************************************************************

title.pushbutton.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
Img_push_button_0 equ set_push_button_0
Img_push_button_1 equ set_push_button_1
Img_push_button_2 equ set_push_button_2

title.pushbutton.Object
        INCLUDE "src/title/text/push_button.asm"

        fcb   3
Ani_push_button
        fdb   Img_push_button_0
        fdb   Img_push_button_1
        fdb   Img_push_button_2
        fdb   Img_push_button_1
        fcb   _resetAnim

 ENDSECTION
