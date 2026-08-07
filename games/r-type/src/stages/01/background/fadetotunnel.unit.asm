;*******************************************************************************
; fadetotunnel — le passage de palette a l'entree et a la sortie du tunnel
;
; La wave le seme aux deux bouts de la section souterraine du niveau 1. Il arme
; le fondu de palette resident vers la palette du tunnel, ou vers celle du jeu
; au retour (subtype), attend qu'il soit fini, puis se supprime.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
fadetotunnel.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; Les deux palettes et la fin de fondu vivent dans le stage, resident : l'objet
; est pagine, il les atteint par le lien.
Pal_stage                EXTERNAL
Pal_tunnel               EXTERNAL
stage.paletteFadeDone    EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/objects/palette/fade/fade.equ"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : la palette du jeu s'appelle Pal_stage en v2 (png2pal du
; stage) ; la v1 la nomme Pal_game.
Pal_game equ Pal_stage
; V2-DEVIATION : le rappel de fin de fondu est celui du corps de stage — un
; simple rts, comme le Palette_FadeCallback du main v1.
Palette_FadeCallback equ stage.paletteFadeDone

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
fadetotunnel.Object
        INCLUDE "src/stages/01/background/obj_fadetotunnel.asm"

 ENDSECTION
