;*******************************************************************************
; shellEraser — l'effaceur de la rotonde, porté de la v1 (stage 1)
;
; Objet HORS POOL : le stage l'appelle une fois par trame entre DrawTiles et
; DrawSprites (`_Obj_Run ObjID_shellEraser`), il n'a pas d'OST et RunObjects ne
; le voit jamais. Il relit la table que les shells remplissent et blitte un
; masque uni sur chaque position à effacer.
;
; Son blit est un sprite compilé recopié du généré v1 : il vit donc dans
; l'unité, pas dans un imageset — rien à indexer, aucun descripteur à lire.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

shellEraser.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; La table d'effacement vit dans la RAM du stage, écrite par les shells.
shellEraseTable     EXTERNAL
shellEraseTable_end EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
shellEraser.Object
        INCLUDE "src/enemies/shell/eraser.asm"

 ENDSECTION
