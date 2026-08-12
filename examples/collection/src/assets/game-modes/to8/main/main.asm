;*******************************************************************************
; Mixed collection — example
;
; One arena <file> holding forty compiled tiles (gfxcomp, divisible) AND a
; <unit> (indivisible), too big for the arena's first zone : the packer cuts
; it between elements — never inside one — and this bench verifies on machine
; what the cut must preserve. No display ; results at $9C00 :
;   +0 : $CA the game mode runs
;   +1 : $01 the unit's eight bytes read back through the member it landed in
;   +2 : $01 the cut happened : the unit's page differs from tile 1's
;   +3 : $01 the tileset itself is cut : tile 1 and tile 39 sit on different pages
;   +4 : $01 the pointer INSIDE the unit equals the game mode's own linked
;             pointer to the same tile — the member's merged link data was
;             rebased right, across the run/unit concatenation
;   +7 : $0D all pass, $E0+n for n failures
;*******************************************************************************

mixed.table                   EXTERNAL
mixed.table$PAGE              EXTERNAL
adr_assets.mixed_1_ND0        EXTERNAL
adr_assets.mixed_1_ND0$PAGE   EXTERNAL
adr_assets.mixed_39_ND0$PAGE  EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"

        ; the scene loads this at the game mode place and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        lda   #$CA
        sta   >$9C00

        ; t1 : the unit's bytes, read through the member the packing chose
t1      ldb   >table.page
        stb   >map.CF74021.CART
        ldx   #mixed.table
        ldy   #t1.expected
        ldb   #8
!       lda   ,x+
        cmpa  ,y+
        bne   t2
        decb
        bne   <
        lda   #$01
        sta   >$9C01

        ; t2 : the cut happened — the unit does not share tile 1's page
t2      lda   >table.page
        cmpa  >tile1.page
        beq   t3
        lda   #$01
        sta   >$9C02

        ; t3 : the tileset itself is cut between elements
t3      lda   >tile1.page
        cmpa  >tile39.page
        beq   t4
        lda   #$01
        sta   >$9C03

        ; t4 : the pointer the unit carries equals the game mode's own —
        ; both were link-resolved against the same tile, from two members
t4      ldb   >table.page
        stb   >map.CF74021.CART
        ldx   #mixed.table
        ldd   8,x
        cmpd  >gm.tile1.ptr
        bne   done
        lda   #$01
        sta   >$9C04

done    ldb   >$9C01
        addb  >$9C02
        addb  >$9C03
        addb  >$9C04
        lda   #$0D
        cmpb  #$04
        beq   >
        lda   #$E0+4                   ; failures = 4 - passes
        pshs  b
        suba  ,s+
!       sta   >$9C07
loop    bra   loop

; the pages are the builder's answers, baked where a table would bake them
table.page   fcb   map.RAM_OVER_CART+mixed.table$PAGE
tile1.page   fcb   map.RAM_OVER_CART+adr_assets.mixed_1_ND0$PAGE
tile39.page  fcb   map.RAM_OVER_CART+adr_assets.mixed_39_ND0$PAGE
gm.tile1.ptr fdb   adr_assets.mixed_1_ND0
t1.expected  fcb   $C0,$1E,$C7,$10,$A5,$5A,$3C,$99

 ENDSECTION
