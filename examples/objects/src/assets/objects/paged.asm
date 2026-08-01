;*******************************************************************************
; Objects that live in a page of their own
;
; This unit is loaded at the 'objects' region, page $06 over the cartridge
; window. Nothing in it is addressable until something mounts that page — which
; is the whole point : it is the v1 memory model, where the resident page holds
; the engine and each object's code is paged in on the frame it runs.
;
; Everything here is reached from the game mode by name, through the load time
; linker : the game mode's object index carries EXTERNAL references, and the
; loader patches them with the addresses this unit exports.
;*******************************************************************************

 SECTION code

obj.paged.run   EXPORT
obj.paged.sub   EXPORT

        INCLUDE "engine/constants.asm"
        INCLUDE "src/common/result.const.asm"

; ---------------------------------------------------------------------------
; The object's run routine, called by RunObjects with u pointing at its OST.
;
; It reports a byte that only exists in this unit. Running at all already
; proves the page was mounted — the code is not addressable otherwise — but
; the magic also proves it was mounted on the *right* page, which a stale
; mount left over from another object would not give.
; ---------------------------------------------------------------------------
obj.paged.run
        lda   magic,pcr
        sta   result.paged
        ; count the runs in the object's own extension area, so the game mode
        ; can tell "ran once" from "ran every frame"
        inc   ext_variables,u
        rts

; ---------------------------------------------------------------------------
; A plain subroutine, not an object : reached through RunPgSubRoutine, which
; mounts this page, calls, and puts back the caller's page. b carries the
; parameter, and is echoed so the caller can check it survived the trip.
; ---------------------------------------------------------------------------
obj.paged.sub
        lda   magic,pcr
        sta   result.pgsub
        stb   result.pgsub+1
        rts

magic   fcb   $5A

 ENDSECTION
