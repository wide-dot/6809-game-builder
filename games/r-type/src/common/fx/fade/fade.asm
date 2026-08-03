;*******************************************************************************
; Le fondu de palette — unité paginée
;
; C'est un objet à part entière : il a un OST (hors pool, `palettefade` dans la
; zone `objects.static`) et un index de routine, et le stage le fait tourner par
; `_Obj_RunU ObjID_fade,#palettefade`.
;
; Il était RÉSIDENT, au motif que tout stage en a besoin à son ouverture. Mais
; la v1 le monte (`object.fade=…/fade.properties`), et elle a raison : rien ne
; le distingue de l'explosion, que `Obj_Run` va chercher dans sa page sans que
; personne y pense. Les 279 octets qu'il occupait en page 1 rejoignent le
; budget du pool d'objets — voir docs/lang/fr/analyse-residente-2026-08.md.
;
; Ce qu'il emprunte au moteur résident : la palette courante et son drapeau de
; rafraîchissement (`PalUpdateNow` tourne sous IRQ et les relit), l'horloge de
; trames, et `UnloadObject_u` pour se supprimer.
;
; L'entrée doit être le premier octet : le code d'abord.
;*******************************************************************************

PaletteFade EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"

        INCLUDE "engine/objects/palette/fade/fade.asm"

 ENDSECTION
