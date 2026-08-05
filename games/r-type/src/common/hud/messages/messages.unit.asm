;*******************************************************************************
; Les messages READY / GAME OVER — unité montée
;
; L'objet de la v1, tel quel. Il prend un index de message dans B et dessine
; l'image BM4 correspondante au centre de l'écran, puis son masque de couleur
; ligne par ligne (dégradé orange → blanc → orange, dix lignes).
;
; Ce n'est pas un objet du pool : il n'a ni OST ni routine. Le stage le vise par
; `_Obj_Mount ObjID_messages`, qui monte sa page et rend son adresse dans X ;
; l'appel se fait ensuite par `jsr ,x` avec B posé — c'est exactement la forme
; de la v1 (game-mode/01/main.asm, séquence de mort).
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les images
; et le codec ensuite, comme dans le fichier v1.
;*******************************************************************************

messages.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/hud/messages/messages.const.asm"

messages.Object
        INCLUDE "src/common/hud/messages/obj.asm"

 ENDSECTION
