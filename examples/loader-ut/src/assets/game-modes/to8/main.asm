;*******************************************************************************
; Loader unit test - game mode
; ------------------------------------------------------------------------------
; Runs a sequence of checks against the file/scene loader and writes each
; result to a fixed table in RAM, readable from an emulator/debugger :
;
; result table ($9C00) :
;   +0  : $CA magic (test program is running)
;   +1  : T1 marker aa content @ cart page 6, $0000 (zx0)
;   +2  : T2 marker bb content @ cart page 6, $0800 (raw)
;   +3  : T3 extern16 link : #marker.aa.begin / #marker.bb.begin
;   +4  : T4 loader.file.getPageID for aa and bb
;   +5  : T5 scene "second" loaded : marker cc content @ cart page 6, $0800
;   +6  : T6 re-link after scene load : #marker.cc.begin
;   +7  : T7 loader.file.getPageID for cc
;   +8  : T8 implicit unload : loading cc at bb's destination deindexed bb
;   +9  : T9 dedup : reloading scene "second" does not grow the index
;   +10 : T10 explicit linkData.unload of aa : status, isLoaded, count drop
;   +12 : (word, info) value of #marker.cc.begin BEFORE scene "second"
;         (expected $0000 : unresolved symbols silently resolve to 0)
;   +15 : $00 running, $0D all tests passed, $E0+n : n test(s) failed
;
; each test slot : $00 not run, $01 pass, $FF fail
;*******************************************************************************

marker.aa.begin EXTERNAL
marker.bb.begin EXTERNAL
marker.cc.begin EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

marker.SIZE      equ $0400
result           equ $9C00
result.MAGIC     equ $CA
result.DONE_OK   equ $0D
result.DONE_KO   equ $E0

page.markers     equ 6
addr.marker.aa   equ $0000
addr.marker.bb   equ $0800
addr.marker.cc   equ $0800

init
        ; clear result table and set magic
        ldx   #result
        ldb   #16
!       clr   ,x+
        decb
        bne   <
        lda   #result.MAGIC
        sta   result

        ; keep the loader visible in data space for the whole test
        _ram.data.set #loader.PAGE

        ; info : marker.cc.begin before scene "second" is loaded
        ; (file cc is not loaded yet, symbol should have resolved to 0)
        ldx   #marker.cc.begin
        stx   result+12

        ; T1 : marker aa content (zx0 compressed file)
        _ram.cart.set #page.markers
        ldx   #addr.marker.aa
        lda   #$A1
        jsr   marker.check
        jsr   test.next

        ; T2 : marker bb content (raw file)
        ldx   #addr.marker.bb
        lda   #$B2
        jsr   marker.check
        jsr   test.next

        ; T3 : extern16 resolution of marker begin labels
        lda   #$01
        ldx   #marker.aa.begin
        cmpx  #addr.marker.aa
        beq   >
        lda   #$FF
!       ldx   #marker.bb.begin
        cmpx  #addr.marker.bb
        beq   >
        lda   #$FF
!       jsr   test.next

        ; T4 : getPageID for aa and bb
        lda   #$01
        sta   @res
        _loader.file.getPageID #data.marker.aa
        cmpb  #page.markers
        beq   >
        ldb   #$FF
        stb   @res
!       _loader.file.getPageID #data.marker.bb
        cmpb  #page.markers
        beq   >
        ldb   #$FF
        stb   @res
!       lda   #0
@res    equ   *-1
        jsr   test.next

        ; T5 : load scene "second" (marker cc over marker bb), check content
        _loader.scene.load #scenes.second
        _ram.cart.set #page.markers
        ldx   #addr.marker.cc
        lda   #$C3
        jsr   marker.check
        jsr   test.next

        ; T6 : full re-link has patched this operand with cc load address
        lda   #$01
        ldx   #marker.cc.begin
        cmpx  #addr.marker.cc
        beq   >
        lda   #$FF
!       jsr   test.next

        ; T7 : getPageID for cc
        ; (getPageID clobbers D, keep the result in code space)
        lda   #$01
        sta   @res
        _loader.file.getPageID #data.marker.cc
        cmpb  #page.markers
        beq   >
        ldb   #$FF
        stb   @res
!       lda   #0
@res    equ   *-1
        jsr   test.next

        ; T8 : implicit unload - loading cc at bb's destination (T5) must
        ; have removed bb from the index ; an explicit unload of bb then
        ; reports not found
        lda   #$01
        sta   @res8
        _loader.file.isLoaded #data.marker.bb
        beq   >                               ; eq : not loaded, as expected
        ldb   #$FF
        stb   @res8
!       _loader.file.linkData.unload #0,#data.marker.bb
        cmpb  #$FF                            ; not found expected
        beq   >
        ldb   #$FF
        stb   @res8
!       lda   #0
@res8   equ   *-1
        jsr   test.next

        ; T9 : dedup on reload - loading the same scene again must not
        ; grow the link data index, and cc must stay valid and linked
        lda   #$01
        sta   @res9
        _loader.file.linkData.count
        std   test.t9.count
        _loader.scene.load #scenes.second
        _loader.file.linkData.count
        cmpd  test.t9.count
        beq   >                               ; index must not grow
        ldb   #$FF
        stb   @res9
!       _ram.cart.set #page.markers
        ldx   #addr.marker.cc
        lda   #$C3
        jsr   marker.check
        cmpa  #$01
        beq   >                               ; content must still be valid
        ldb   #$FF
        stb   @res9
!       ldx   #marker.cc.begin
        cmpx  #addr.marker.cc
        beq   >                               ; re-link must keep the reference patched
        ldb   #$FF
        stb   @res9
!       lda   #0
@res9   equ   *-1
        jsr   test.next

        ; T10 : explicit unload of marker aa : success, deindexed,
        ; and the index count drops by one
        lda   #$01
        sta   @res10
        _loader.file.linkData.count
        std   test.t10.count
        _loader.file.linkData.unload #0,#data.marker.aa
        tstb
        beq   >                               ; success expected
        ldb   #$FF
        stb   @res10
!       _loader.file.isLoaded #data.marker.aa
        beq   >                               ; eq : not loaded, as expected
        ldb   #$FF
        stb   @res10
!       _loader.file.linkData.count
        addd  #1
        cmpd  test.t10.count                  ; count must have dropped by one
        beq   >
        ldb   #$FF
        stb   @res10
!       lda   #0
@res10  equ   *-1
        jsr   test.next

        ; done : write final status
        lda   #result.DONE_OK
        ldb   test.fails
        beq   >
        addb  #result.DONE_KO
        tfr   b,a
!       sta   result+15
done    bra   done

;---------------------------------------
; marker.check
;
; input  REG : [X] start address
; input  REG : [A] marker id
; output REG : [A] $01 pass, $FF fail
;---------------------------------------
; check marker file content :
; marker.SIZE-6 bytes of id,
; then $F0,$F1,$F2,$F3,$F4,id
;---------------------------------------
marker.check
        pshs  b,y
        ldy   #marker.SIZE-6
@body   cmpa  ,x+
        bne   @ko
        leay  -1,y
        bne   @body
        ldb   #$F0
@tail   cmpb  ,x+
        bne   @ko
        incb
        cmpb  #$F5
        bne   @tail
        cmpa  ,x+
        bne   @ko
        lda   #$01
        puls  b,y,pc
@ko     lda   #$FF
        puls  b,y,pc

;---------------------------------------
; test.next
;
; input  REG : [A] $01 pass, $FF fail
;---------------------------------------
; store result in next slot of the
; result table, count failures
;---------------------------------------
test.next
        pshs  b,x
        ldx   #result
        ldb   test.idx
        incb
        stb   test.idx
        sta   b,x
        cmpa  #$01
        beq   >
        inc   test.fails
!       puls  b,x,pc

test.idx       fcb 0
test.fails     fcb 0
test.t9.count  fdb 0
test.t10.count fdb 0

 ENDSECTION
