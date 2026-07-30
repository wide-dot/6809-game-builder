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
;   +11 : T11 stress : 128 load/unload/relink cycles of dd/ee variants over
;         the same destination, hub extern refs flip checked each cycle,
;         pool/index stability ($01 pass, $F1..$F5 first failing check)
;   +12 : T12 index growth : +6 export-only files (realloc beyond 8 slots),
;         symbol values resolved, mass unload ($01 pass, $F6..$F9)
;   +14 : T11 progress : remaining stress iterations (0 when loop completed)
;   +15 : $00 running, $0D all tests passed, $E0+n : n test(s) failed
;   +16 : (word, info) value of #marker.cc.begin BEFORE scene "second"
;         (expected $0000 : unresolved symbols silently resolve to 0)
;
; each test slot : $00 not run, $01 pass, $FF fail
;*******************************************************************************

marker.aa.begin EXTERNAL
marker.bb.begin EXTERNAL
marker.cc.begin EXTERNAL
marker.dd.begin EXTERNAL
marker.ee.begin EXTERNAL
iface.a.VALUE   EXTERNAL
iface.f.VALUE   EXTERNAL
gm.anchor       EXPORT

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
addr.marker.hub  equ $0C00
addr.variant     equ $1000
STRESS.ITERS     equ 128

init
        ; clear result table and set magic
        ldx   #result
        ldb   #24
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
        stx   result+16

        ; T1 : marker aa content (zx0 compressed file)
        _ram.cart.set #page.markers
        ldx   #addr.marker.aa
        lda   #$A1
        ldy   #marker.SIZE-6
        jsr   marker.check
        jsr   test.next

        ; T2 : marker bb content (raw file)
        ldx   #addr.marker.bb
        lda   #$B2
        ldy   #marker.SIZE-6
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
        ldy   #marker.SIZE-6
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
        ldy   #marker.SIZE-6
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

        ; T11 : stress - swap variants dd/ee over the same destination
        ; STRESS.ITERS times, checking after each cycle :
        ;   $F1 variant header word (extern ref to gm.anchor in fresh data)
        ;   $F2 variant body and tail content
        ;   $F3 gm immediates flip (#marker.dd.begin / #marker.ee.begin)
        ;   $F4 hub words flip + stable ref + fill
        ;   $F5 linkData.count steady at 4
        ; every 16th cycle the current variant is explicitly unloaded first
        ; (exercises the unload->append path instead of implicit unload) ;
        ; the whole loop must run within the 4 KB memory pool : any alloc/
        ; free imbalance aborts the run long before 128 cycles
        lda   #$01
        sta   @res11
        _loader.scene.load #scenes.stress.hub
        lda   #STRESS.ITERS
        sta   stress.iter
@sloop
        lda   stress.iter
        sta   result+14                       ; progress, for the debugger
        anda  #15
        bne   @swap
        _loader.file.linkData.unload #0,#data.marker.dd
        _loader.file.linkData.unload #0,#data.marker.ee
@swap
        lda   stress.iter
        anda  #1
        beq   @even
        _loader.scene.load #scenes.stress.dd
        lda   #$D4
        sta   stress.id
        ldd   #addr.variant
        std   stress.exp.dd
        ldd   #0
        std   stress.exp.ee
        bra   @check
@even
        _loader.scene.load #scenes.stress.ee
        lda   #$E5
        sta   stress.id
        ldd   #0
        std   stress.exp.dd
        ldd   #addr.variant
        std   stress.exp.ee
@check
        _ram.cart.set #page.markers
        ; variant header word : extern ref patched in freshly loaded data
        ldd   >addr.variant
        cmpd  #gm.anchor
        beq   >
        lda   #$F1
        lbra  @fail11
!       ; variant body and tail
        ldx   #addr.variant+2
        lda   stress.id
        ldy   #marker.SIZE-8
        jsr   marker.check
        cmpa  #$01
        beq   >
        lda   #$F2
        lbra  @fail11
!       ; gm immediates re-patched by the global re-link
        ldx   #marker.dd.begin
        cmpx  stress.exp.dd
        bne   @f3
        ldx   #marker.ee.begin
        cmpx  stress.exp.ee
        beq   >
@f3     lda   #$F3
        lbra  @fail11
!       ; hub words : flip refs, stable ref, fill byte
        ldd   >addr.marker.hub
        cmpd  stress.exp.dd
        bne   @f4
        ldd   >addr.marker.hub+2
        cmpd  stress.exp.ee
        bne   @f4
        ldd   >addr.marker.hub+4
        cmpd  #gm.anchor
        bne   @f4
        lda   >addr.marker.hub+6
        cmpa  #$4B
        beq   >
@f4     lda   #$F4
        lbra  @fail11
!       ; index must stay at 4 entries (gm, cc, hub, variant)
        _loader.file.linkData.count
        cmpd  #4
        beq   >
        lda   #$F5
        lbra  @fail11
!       dec   stress.iter
        lbne  @sloop
        bra   @end11
@fail11 sta   @res11
@end11  lda   #0
@res11  equ   *-1
        jsr   test.next

        ; T12 : index growth beyond the initial 8 slots (realloc path) :
        ; +6 export-only files, check resolved values, then mass unload
        ;   $F6 count did not grow by 6
        ;   $F7 iface symbol values not resolved
        ;   $F8 unload of an iface file failed
        ;   $F9 count did not come back to its initial value
        lda   #$01
        sta   @res12
        _loader.file.linkData.count
        std   test.t12.count
        _loader.scene.load #scenes.stress.iface
        _loader.file.linkData.count
        subd  #6
        cmpd  test.t12.count
        beq   >
        lda   #$F6
        lbra  @fail12
!       ldd   #iface.a.VALUE
        cmpd  #$0A01
        bne   @f7
        ldd   #iface.f.VALUE
        cmpd  #$0A06
        beq   >
@f7     lda   #$F7
        lbra  @fail12
!       _loader.file.linkData.unload #0,#iface.a
        tstb
        bne   @f8
        _loader.file.linkData.unload #0,#iface.b
        tstb
        bne   @f8
        _loader.file.linkData.unload #0,#iface.c
        tstb
        bne   @f8
        _loader.file.linkData.unload #0,#iface.d
        tstb
        bne   @f8
        _loader.file.linkData.unload #0,#iface.e
        tstb
        bne   @f8
        _loader.file.linkData.unload #0,#iface.f
        tstb
        beq   >
@f8     lda   #$F8
        lbra  @fail12
!       _loader.file.linkData.count
        cmpd  test.t12.count
        beq   @end12
        lda   #$F9
        lbra  @fail12
@fail12 sta   @res12
@end12  lda   #0
@res12  equ   *-1
        jsr   test.next

        ; done : write final status
        lda   #result.DONE_OK
        ldb   test.fails
        beq   >
        addb  #result.DONE_KO
        tfr   b,a
!       sta   result+15
done    bra   done

; exported anchor : a non-zero resident address, referenced as an extern
; by the stress marker files (dd, ee, hub) and checked back by value
gm.anchor

;---------------------------------------
; marker.check
;
; input  REG : [X] start address
; input  REG : [A] marker id
; input  REG : [Y] body length
; output REG : [A] $01 pass, $FF fail
;---------------------------------------
; check marker file content :
; Y bytes of id,
; then $F0,$F1,$F2,$F3,$F4,id
;---------------------------------------
marker.check
        pshs  b,y
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
test.t12.count fdb 0
stress.iter    fcb 0
stress.id      fcb 0
stress.exp.dd  fdb 0
stress.exp.ee  fdb 0

 ENDSECTION
