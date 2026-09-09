;*******************************************************************************
; L'UNITE RESIDENTE du manager des pieces mobiles du vaisseau — le code, la
; table des slots et le faux imageset, en RAM permanente (arene stage3.res),
; parce que le dessin doit monter lui-meme les pages des pieces. Voir
; wsmgr.asm.
;*******************************************************************************

        INCLUDE "src/common/engine/api.asm"

wsmgr.Object   EXPORT                  ; l'objet, dans l'index du stage
wsmgr.Draw     EXPORT                  ; l'inscription, depuis le cast
wsmgr.page     EXPORT                  ; son entree : la page des descripteurs

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/enemies/warship-elements/wsmgr/wsmgr.asm"

 ENDSECTION
