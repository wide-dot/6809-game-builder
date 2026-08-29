;*******************************************************************************
; L'UNITE DE LA PAGE DES FLAMMES — le manager des gerbes et son art.
;
; Elle ne contient QUE ce que BuildSprites appelle et ce qu'il dessine : la
; page montee au moment du dessin est celle-ci, et rien d'ici ne peut sauter
; dans le cast. D'ou la liste courte ci-dessous — le moteur resident, les
; variables de la couche, et la table des gerbes, residente elle aussi.
;*******************************************************************************

        INCLUDE "src/common/engine/api.asm"

; Le resident du stage : la table d'index que le manager patche a sa naissance.
Img_Page_Index    EXTERNAL
; La couche battleship : le manager suit sa camera comme les autres pieces.
mscroll.camera.x  EXTERNAL
mscroll.camera.y  EXTERNAL
; La table des gerbes, armee par le cast (flameslots.asm).
flamemgr.Slots    EXTERNAL
flamemgr.live     EXTERNAL

flamemgr.Object   EXPORT

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/enemies/warship-elements/reactor/flamemgr.asm"

 ENDSECTION
