 INCLUDE "engine/system/thomson/bootloader/loader.const.asm"

_loader.scene.load MACRO
        ldx   \1
        jsr   loader.ADDRESS+loader.scene.load.IDX
 ENDM

; Retire de l'index tout ce que la scene nommee avait charge. A appeler AVANT
; le chargement de la suivante : sinon le nouveau fichier s'indexe alors que
; l'ancien y est encore, a la meme destination. L'ordre appartient au jeu,
; il n'y a pas de primitive qui enchaine les deux.
_loader.scene.unload MACRO
        ldx   \1
        jsr   loader.ADDRESS+loader.scene.unload.IDX
 ENDM

; Fait converger la RAM vers un etat declare. \1 = l'adresse de sa table,
; generee par <layout gencompositions>. Redemander l'etat courant ne fait rien.
_loader.composition.load MACRO
        ldx   \1
        jsr   loader.ADDRESS+loader.composition.load.IDX
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