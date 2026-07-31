 INCLUDE "engine/system/thomson/bootloader/loader.const.asm"

_loader.scene.load MACRO
        ldx   \1
        jsr   loader.ADDRESS+loader.scene.load.IDX
 ENDM

; prompts the user for a disk change if the mounted disk is not the one asked
_loader.dir.load MACRO
        lda   \1
        jsr   loader.ADDRESS+loader.dir.load.IDX
 ENDM

_loader.file.getPageID MACRO
        ldd   \1
        jsr   loader.ADDRESS+loader.file.getPageID.IDX
 ENDM

_loader.file.linkData.unload MACRO
        ldb   \1
        ldx   \2
        jsr   loader.ADDRESS+loader.file.linkData.unload.IDX
 ENDM

_loader.file.linkData.count MACRO
        jsr   loader.ADDRESS+loader.file.linkData.count.IDX
 ENDM

; sets CC : ne = file is loaded, eq = file is not loaded
; (also returns page id in B, $ff if not loaded)
_loader.file.isLoaded MACRO
        ldd   \1
        jsr   loader.ADDRESS+loader.file.getPageID.IDX
        cmpb  #$ff
 ENDM