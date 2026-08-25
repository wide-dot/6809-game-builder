;*******************************************************************************
; slither — le renderer du BLANC, assemble AVEC les poses blanches du corps
;
; POURQUOI CE FICHIER EXISTE, et pas simplement trois routines de plus dans
; obj.asm : BuildSprites monte Img_Page_Index[id] AVANT DE LIRE L'IMAGESET
; (overlay-mode/BuildSprites.asm, ligne 110), puis en tire la page du sprite
; compile. L'invariant est donc « le faux imageset vit sur la page que
; Img_Page_Index designe ». Le renderer normal le respecte sans y penser : il
; y inscrit SA PROPRE page, celle ou vivent son imageset et ses sprites.
;
; Le renderer du blanc, lui, doit designer la page des poses blanches. Son
; faux imageset et sa routine de dessin doivent donc y vivre AUSSI — d'ou ce
; fichier, assemble dans le direntry stage5.cast.imgBodyHit. Les avoir laisses
; sur la page du cast faisait lire a BuildSprites des octets de sprite comme
; s'ils etaient une structure : le segment touche ne devenait pas blanc, il
; DISPARAISSAIT une trame (constat auteur).
;
; La page n'a pas besoin d'etre corrigee a l'execution comme le fait le
; renderer normal : elle est connue a l'assemblage, c'est celle de ce
; direntry-ci.
;
; Les SLOTS sont residents pour la meme raison — ils doivent se lire aussi
; bien depuis la page du cast que depuis celle-ci.
;*******************************************************************************

slither.FakeHit0 EXPORT
slither.FakeHit1 EXPORT
slither.FakeHit2 EXPORT

slither.hits0    EXTERNAL
slither.hits1    EXTERNAL
slither.hits2    EXTERNAL

slither.NHIT    equ 6                  ; DUPLIQUE — voir obj.asm et res.unit.asm

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"

 SECTION code

; Le dessin : la liste que la marche vient de deposer. Un compte, puis des
; entrees de quatre octets (x, y, routine compilee).
slither.DrawHit0
        ldx   #slither.hits0
        bra   slither.DrawHitCommon
slither.DrawHit1
        ldx   #slither.hits1
        bra   slither.DrawHitCommon
slither.DrawHit2
        ldx   #slither.hits2
slither.DrawHitCommon
        lda   ,x
        beq   @out                     ; rien ne flashe ce tour
        sta   slither.hn
        leax  1,x
        stx   slither.hp
@loop   ldx   slither.hp
        ldb   2,x                      ; la POSE, resolue ICI : l'imageset
        aslb                           ; blanc n'est lisible que sur CETTE page
        ldy   #slither.BodyHitSets
        leay  b,y                      ; (pas d'aby sur 6809)
        ldy   ,y                       ; Y = le set blanc de la pose
        ldy   14,y                     ; ... et sa routine compilee
        sty   slither.hr
        ldd   ,x                       ; A = x ecran, B = y ecran
        jsr   DRS_XYToAddress
        ldx   #0
slither.hr equ *-2
        ldu   <glb_screen_location_2
        jsr   ,x                       ; elle consomme U
        ldx   slither.hp
        leax  3,x
        stx   slither.hp
        dec   slither.hn
        bne   @loop
@out    rts

slither.hn      fcb 0
slither.hp      fdb 0

; Les seize poses BLANCHES du corps. Elles sont definies par le gfxcomp de CE
; direntry — meme unite d'assemblage, donc pas d'EXTERNAL a declarer.
slither.BodyHitSets
        fdb   set_slither_bodyhit_0,set_slither_bodyhit_1
        fdb   set_slither_bodyhit_2,set_slither_bodyhit_3
        fdb   set_slither_bodyhit_4,set_slither_bodyhit_5
        fdb   set_slither_bodyhit_6,set_slither_bodyhit_7
        fdb   set_slither_bodyhit_8,set_slither_bodyhit_9
        fdb   set_slither_bodyhit_10,set_slither_bodyhit_11
        fdb   set_slither_bodyhit_12,set_slither_bodyhit_13
        fdb   set_slither_bodyhit_14,set_slither_bodyhit_15

; Les trois faux imagesets. Meme forme que ceux du renderer normal, a une
; difference pres : leur octet de page est CONSTANT — celui de ce direntry.
slither.FakeHit0
        fcb   slither.FakeHitSub0-slither.FakeHit0,slither.FakeHitSub0-slither.FakeHit0
        fcb   slither.FakeHitSub0-slither.FakeHit0,slither.FakeHitSub0-slither.FakeHit0
        fcb   8,8,0
slither.FakeHitSub0
        fcb   0
        fcb   slither.FakeHitMf0-slither.FakeHitSub0
        fcb   0
        fcb   slither.FakeHitMf0-slither.FakeHitSub0
        fcb   0,0
slither.FakeHitMf0
        fcb   map.RAM_OVER_CART+stage5.cast.imgBodyHit.page
        fdb   slither.DrawHit0

slither.FakeHit1
        fcb   slither.FakeHitSub1-slither.FakeHit1,slither.FakeHitSub1-slither.FakeHit1
        fcb   slither.FakeHitSub1-slither.FakeHit1,slither.FakeHitSub1-slither.FakeHit1
        fcb   8,8,0
slither.FakeHitSub1
        fcb   0
        fcb   slither.FakeHitMf1-slither.FakeHitSub1
        fcb   0
        fcb   slither.FakeHitMf1-slither.FakeHitSub1
        fcb   0,0
slither.FakeHitMf1
        fcb   map.RAM_OVER_CART+stage5.cast.imgBodyHit.page
        fdb   slither.DrawHit1

slither.FakeHit2
        fcb   slither.FakeHitSub2-slither.FakeHit2,slither.FakeHitSub2-slither.FakeHit2
        fcb   slither.FakeHitSub2-slither.FakeHit2,slither.FakeHitSub2-slither.FakeHit2
        fcb   8,8,0
slither.FakeHitSub2
        fcb   0
        fcb   slither.FakeHitMf2-slither.FakeHitSub2
        fcb   0
        fcb   slither.FakeHitMf2-slither.FakeHitSub2
        fcb   0,0
slither.FakeHitMf2
        fcb   map.RAM_OVER_CART+stage5.cast.imgBodyHit.page
        fdb   slither.DrawHit2

 ENDSECTION
