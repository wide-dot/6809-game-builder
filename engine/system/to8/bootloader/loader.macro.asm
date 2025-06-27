_loader.scene.load MACRO
        ldx   \1
        jsr   loader.ADDRESS+3
 ENDM

_loader.file.getPage MACRO
        ldx   \1
        jsr   loader.ADDRESS+27
 ENDM