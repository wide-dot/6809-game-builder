 INCLUDE "engine/system/thomson/bootloader/loader.const.asm"

_loader.scene.load MACRO
        ldx   \1
        jsr   loader.ADDRESS+loader.scene.load.IDX
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