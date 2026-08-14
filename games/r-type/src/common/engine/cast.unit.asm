;*******************************************************************************
; La convergence des lots d'ennemis — l'unité résidente `common.cast`
;
; Un stage entrant porte un masque de lots (src/common/cast.const.asm) ; cette
; routine fait converger la RAM : elle décharge les lots que la cible ne veut
; pas, charge ceux qui lui manquent, et laisse en place ce que les deux stages
; partagent — zéro relecture disque pour l'intersection. Les lots vivent dans
; le répertoire 0, un lot = une scène de lot (voir
; docs/lang/fr/analyse-lots-ennemis-2026-08.md).
;
; RÉSIDENTE et HORS de l'unité engine : la fenêtre $6100-$7FFF du moteur est
; pleine à 45 octets près — cette routine loge dans la marge visible de la
; page résidente ($8776-$87DA, entre les témoins du banc et le pool d'objets),
; déclarée région `cast` du layout. Elle doit être en RAM fixe : pendant un
; scene.load le loader monte des pages dans les deux fenêtres commutées, tout
; code paginé serait escamoté sous ses propres pieds.
;
; Contrat : appelée par game.stage.switch, page loader montée dans la fenêtre
; DATA, IRQ coupées. B = masque de la cible. Détruit tous les registres.
;*******************************************************************************

cast.converge EXPORT

        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 SECTION code

cast.converge
        cmpb  cast.mask
        beq   cast.done                 ; même cast : rien à faire
        pshs  b
        clra                            ; répertoire 0 : la bibliothèque
        jsr   loader.ADDRESS+loader.dir.load.IDX
        ldb   ,s                        ; à décharger : chargé ET non voulu
        comb
        andb  cast.mask
        ldu   #loader.ADDRESS+loader.scene.unload.IDX
        bsr   cast.walk
        ldb   cast.mask                 ; à charger : voulu ET non chargé
        comb
        andb  ,s
        ldu   #loader.ADDRESS+loader.scene.load.IDX
        bsr   cast.walk
        puls  b
        stb   cast.mask
cast.done
        rts

; B = sous-masque de lots, U = l'entrée loader à appeler pour chacun d'eux.
; Les scènes de lot détruisent tout : l'état de la marche vit en mémoire.
cast.walk
        stb   cast.bits
        stu   cast.fn
        ldx   #cast.lots
@loop   stx   cast.slot
        lsr   cast.bits                 ; le bit du lot courant tombe dans C
        bcc   @next
        ldx   [cast.slot]
        jsr   [cast.fn]
@next   ldx   cast.slot
        leax  2,x
        tst   cast.bits                 ; plus aucun bit : fini
        bne   @loop
        rts

; Le masque des lots présents en RAM, et les scènes de lot dans l'ordre des
; bits du masque.
cast.mask fcb   0
cast.bits fcb   0
cast.fn   fdb   0
cast.slot fdb   0
cast.lots fdb   scenes.lot.bink
          fdb   scenes.lot.patapata
          fdb   scenes.lot.cancer
          fdb   scenes.lot.bugpstaff
          fdb   scenes.lot.scant
          fdb   scenes.lot.mid

 ENDSECTION
