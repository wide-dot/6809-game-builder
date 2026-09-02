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
main.eyemgr.collision  EXPORT
stage1.collisionMap           EXTERNAL
terrainCollision.nerves       EXTERNAL

eyepieces.DrawAll      EXTERNAL
eyepieces.DrawAll$PAGE EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"

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
; ---------------------------------------------------------------------------
; main.eyemgr.collision — la collision d'un nerf optique, dans la carte
; d'AVANT-PLAN du stage (02/09/2026, decision auteur). L'arcade efface les
; tuiles du nerf a sa mort ; chez nous les nerfs sont deja solides dans
; level1_fc.bin et rien ne les effacait. Resident parce que la carte vit sur
; la page de collision, que le manager ne peut pas monter depuis la sienne.
;   entree : B = nerf 0..3 ; A = 0 effacer (ET NON), autre restaurer (OU)
; Les tables sont sur la page de la carte : une seule page a monter. La
; restauration sert a l'Init du manager (rejeu de checkpoint, restart : la
; carte n'est pas rechargee). Analyse : doc/analyse-collision-nerfs.md
; ---------------------------------------------------------------------------
main.eyemgr.collision
        pshs  x,y,u                    ; U est l'OST de l'appelant, X/Y ses curseurs :
                                       ; on les rend intacts (la premiere version
                                       ; clobbait U — l'Init du manager ecrivait alors
                                       ; `inc routine,u` dans le vide, l'objet restait
                                       ; en Init et les yeux ne s'armaient jamais)
        pshs  a                        ; 1,s (puis 2,s) : le mode
        _GetCartPageA
        pshs  a                        ; ,s : la page de l'appelant
        lda   #map.RAM_OVER_CART+collision.page   ; la REGION collision : sa page est une equate du layout
        _SetCartPageA
        aslb
        ldx   #terrainCollision.nerves
        ldx   b,x                      ; X -> la table du nerf
        ldb   ,x+                      ; nombre d'entrees
        beq   @done
        pshs  b                        ; ,s : le compteur ; 1,s : la page ; 2,s : le mode
        ldy   #stage1.collisionMap
@loop   ldd   ,x++                     ; offset dans la carte
        leau  d,y
        lda   ,x+                      ; masque des bits du nerf
        tst   2,s
        bne   @set
        coma
        anda  ,u                       ; effacer
        bra   @w
@set    ora   ,u                       ; restaurer
@w      sta   ,u
        dec   ,s
        bne   @loop
        leas  1,s
@done   puls  a
        _SetCartPageA                  ; la page de l'appelant
        puls  a                        ; le mode, sans usage
        puls  x,y,u,pc

 ENDSECTION
