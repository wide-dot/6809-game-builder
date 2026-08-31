;*******************************************************************************
; eyemgr-res — l'etat RESIDENT des quatre systemes d'oeil du dobkeratops
; (chantier nerfs-overlay), locataire de l'arene stage1.res : le main du
; stage touche la plage reservee du banc ($87F2), il ne peut plus grossir.
;
; Lu par trois pages a la fois — le manager (logique), ses bandes (hooks de
; dessin des deux parites) et les morceaux (eyepieces) — donc resident. Les
; boites vivent ici parce que les listes AABB du moteur se parcourent toutes
; pages confondues (table residente obligatoire, meme contrat que le manager
; de tirs). L'Init du manager remet tout a neuf a chaque apparition du boss ;
; les valeurs chargees ne comptent que pour la premiere trame du corps
; (eyesAlive != 0).
;
; Le trampoline drawPieces vit ici pour la meme raison : le hook des bandes
; tourne dans la fenetre cartouche et ne peut pas monter la page des
; morceaux sans se faire disparaitre — la bascule se fait en resident, et le
; rts de DrawAll retombe directement dans BuildSprites.
;*******************************************************************************
main.eyemgr.status     EXPORT
main.eyemgr.removed    EXPORT
main.eyemgr.eyesAlive  EXPORT
main.eyemgr.aabb       EXPORT
main.eyemgr.drawPieces EXPORT

eyepieces.DrawAll      EXTERNAL
eyepieces.DrawAll$PAGE EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"

main.eyemgr.status   fcb 0,0,0,0  ; par systeme : 0 intact, 1 en effacement, 2 fini
main.eyemgr.removed  fcb 0,0,0,0  ; morceaux retires (toujours un prefixe)
main.eyemgr.eyesAlive fcb 4       ; nerfs vivants — lu par le corps (obj.asm).
                                  ; Decremente a la FIN de la sequence
                                  ; d'effacement, pas a l'impact (arcade +0x34)
main.eyemgr.aabb     fill 0,4*9   ; 4 boites AABB (9 o), liens remis a zero a l'Init

main.eyemgr.drawPieces
        lda   #map.RAM_OVER_CART+eyepieces.DrawAll$PAGE
        _SetCartPageA
        jmp   eyepieces.DrawAll

 ENDSECTION
