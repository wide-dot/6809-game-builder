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
;   +13 : T13 multi-sector directory : marker zz is the last INDEX entry,
;         its dir entry lives in the 3rd directory sector ($FA/$FB)
;   +14 : T14 index churn : 16 cycles of +22 export-only files (realloc
;         8->16->24->32 on first pass) then mass unload ($FC..$FE)
;   +15 : T15 multi-disk : switch to disk 1, load from it, cross-disk link
;         both ways, disk 0 files still linked, switch back ($EA..$EE)
;   +16 : T16 multi object group : an asm member concatenated after a 256
;         byte blob in one direntry, its export and its relocation must both
;         be shifted by the size of what precedes it ($E1..$E3)
;
;   +24 : (word, info) value of #marker.cc.begin BEFORE scene "second"
;         (expected $0000 : unresolved symbols silently resolve to 0)
;   +26 : T11 progress : remaining stress iterations (1 when completed)
;   +27 : T15 disk handshake, for the operator/emulator :
;         $D1 waiting for disk 1, $D2 disk 1 loaded,
;         $D3 waiting for disk 0, $D4 back on disk 0
;   +31 : $00 running, $0D all tests passed, $E0+n : n test(s) failed
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
pad.a.VALUE     EXTERNAL
pad.p.VALUE     EXTERNAL
marker.zz.begin EXTERNAL
marker.d1.begin EXTERNAL
marker.grp.begin EXTERNAL
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
addr.marker.zz   equ $1400
marker.zz.SIZE   equ $0100
addr.group       equ $1C00
addr.group.asm   equ addr.group+256   ; the asm member starts after the blob
marker.grp.SIZE  equ $0100
marker.grp.ID    equ $6B
addr.marker.d1   equ $1800
marker.d1.SIZE   equ $0200
marker.d1.ID     equ $1D
STRESS.ITERS     equ 128

init
        ; clear result table and set magic
        ldx   #result
        ldb   #32
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
        stx   result+24

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
        sta   result+26                       ; progress, for the debugger
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

        ; T13 : multi-sector directory - marker zz is the LAST directory
        ; entry, so its dir entry lives in the 3rd INDEX sector
        ;   $FA bad content, $FB not indexed at the marker page
        lda   #$01
        sta   @res13
        _loader.scene.load #scenes.stress.zz
        _ram.cart.set #page.markers
        ldx   #addr.marker.zz
        lda   #$5A
        ldy   #marker.zz.SIZE-6
        jsr   marker.check
        cmpa  #$01
        beq   >
        lda   #$FA
        bra   @fail13
!       _loader.file.getPageID #data.marker.zz
        cmpb  #page.markers
        beq   @end13
        lda   #$FB
        bra   @fail13
@fail13 sta   @res13
@end13  lda   #0
@res13  equ   *-1
        jsr   test.next

        ; T14 : index churn - 16 cycles of loading 22 export-only files
        ; (iface + pad scenes ; first pass walks the realloc steps
        ; 8->16->24->32) then mass-unloading them all
        ;   $FC peak count wrong, $FD a pad value not resolved,
        ;   $FE an unload failed or floor count wrong
        lda   #$01
        sta   @res14
        _loader.file.linkData.count
        std   test.t14.count                  ; floor : gm, cc, hub, variant, zz
        lda   #16
        sta   stress.iter                     ; reuse the T11 counter
@t14loop
        _loader.scene.load #scenes.stress.iface
        _loader.scene.load #scenes.stress.pad
        _loader.file.linkData.count
        subd  #22
        cmpd  test.t14.count
        beq   >
        lda   #$FC
        lbra  @fail14
!       ldd   #pad.a.VALUE
        cmpd  #$0B01
        bne   @f14b
        ldd   #pad.p.VALUE
        cmpd  #$0B10
        beq   >
@f14b   lda   #$FD
        lbra  @fail14
!       ldy   #test.t14.list                  ; mass unload : 6 ifaces + 16 pads
@t14ul  ldx   ,y++
        cmpx  #$FFFF
        beq   @t14chk
        ldb   #0
        jsr   loader.ADDRESS+loader.file.linkData.unload.IDX
        tstb
        beq   @t14ul
        lda   #$FE
        lbra  @fail14
@t14chk
        _loader.file.linkData.count
        cmpd  test.t14.count
        beq   >
        lda   #$FE
        lbra  @fail14
!       dec   stress.iter
        lbne  @t14loop
        bra   @end14
@fail14 sta   @res14
@end14  lda   #0
@res14  equ   *-1
        jsr   test.next

        ; T15 : multi-disk - switch to disk 1, load a file from it, check
        ; cross-disk linking in both directions, then switch back to disk 0.
        ; result+27 is the handshake byte : the operator (or the emulator
        ; driver) mounts the requested disk and presses a key when it sees
        ; $D1 / $D3 — the loader itself is blocked in its "Insert disk"
        ; prompt at that point
        ;   $EA disk 1 marker content or inbound extern fixup
        ;   $EB cross-disk symbol not resolved in the running game mode
        ;   $EC a disk 0 file lost its links after the disk change
        ;   $ED index count wrong
        ;   $EE disk 0 unusable after switching back
        lda   #$01
        sta   @res15
        _loader.file.linkData.count
        std   test.t15.count
        lda   #$D1
        sta   result+27                       ; ask for disk 1
        _loader.dir.load #1
        lda   #$D2
        sta   result+27                       ; disk 1 directory is loaded
        _loader.scene.load #d1.scenes.main
        _ram.cart.set #page.markers
        ; inbound cross-disk fixup : gm.anchor (disk 0) patched into disk 1 data
        ldd   >addr.marker.d1
        cmpd  #gm.anchor
        bne   @f15a
        ldx   #addr.marker.d1+2
        lda   #marker.d1.ID
        ldy   #marker.d1.SIZE-8
        jsr   marker.check
        cmpa  #$01
        beq   >
@f15a   lda   #$EA
        lbra  @fail15
!       ; outbound cross-disk symbol : disk 1 export used by the disk 0 gm
        ldx   #marker.d1.begin
        cmpx  #addr.marker.d1
        beq   >
        lda   #$EB
        lbra  @fail15
!       ; file identity across disks : file ids are allocated globally by the
        ; builder, so getPageID tells the disk 1 file apart from the disk 0
        ; game mode (with per-disk numbering both were file id 0 and the
        ; disk 1 file resolved to the game mode's page)
        lda   #$01
        sta   @res15b
        _loader.file.getPageID #d1.marker
        cmpb  #page.markers
        beq   >
        ldb   #$FF
        stb   @res15b
!       _loader.file.getPageID #assets.gm.loaderut
        cmpb  #1
        beq   >
        ldb   #$FF
        stb   @res15b
!       lda   #0
@res15b equ   *-1
        cmpa  #$01
        beq   >
        lda   #$EF
        lbra  @fail15
!       ; disk 0 files must keep their links across the disk change
        ldd   >addr.marker.hub+4
        cmpd  #gm.anchor
        bne   @f15c
        ldx   #marker.zz.begin
        cmpx  #addr.marker.zz
        beq   >
@f15c   lda   #$EC
        lbra  @fail15
!       _loader.file.linkData.count
        subd  #1
        cmpd  test.t15.count
        beq   >
        lda   #$ED
        lbra  @fail15
!       ; back to disk 0 : the directory must be usable again
        lda   #$D3
        sta   result+27                       ; ask for disk 0
        _loader.dir.load #0
        lda   #$D4
        sta   result+27                       ; disk 0 directory is loaded
        _loader.scene.load #scenes.stress.zz
        _ram.cart.set #page.markers
        ldx   #addr.marker.zz
        lda   #$5A
        ldy   #marker.zz.SIZE-6
        jsr   marker.check
        cmpa  #$01
        beq   @end15
        lda   #$EE
@fail15 sta   @res15
@end15  lda   #0
@res15  equ   *-1
        jsr   test.next

        ; T16 : multi object group. The direntry holds a 256 byte blob then an
        ; asm member ; the member's exported label and its extern fixup are
        ; emitted relative to the member, so both must land 256 bytes in.
        ;   $E1 blob not loaded where expected
        ;   $E2 exported symbol not shifted by the preceding object
        ;   $E3 relocation inside the member not shifted, or content wrong
        lda   #$01
        sta   @res16
        _loader.scene.load #scenes.group
        _ram.cart.set #page.markers
        lda   >addr.group
        cmpa  #$77
        beq   >
        lda   #$E1
        lbra  @fail16
!       ldx   #marker.grp.begin
        cmpx  #addr.group.asm
        beq   >
        lda   #$E2
        lbra  @fail16
!       ldd   >addr.group.asm                 ; extern fixup written in the member
        cmpd  #gm.anchor
        bne   @f16c
        ldx   #addr.group.asm+2
        lda   #marker.grp.ID
        ldy   #marker.grp.SIZE-8
        jsr   marker.check
        cmpa  #$01
        beq   @end16
@f16c   lda   #$E3
@fail16 sta   @res16
@end16  lda   #0
@res16  equ   *-1
        jsr   test.next

        ; done : write final status
        lda   #result.DONE_OK
        ldb   test.fails
        beq   >
        addb  #result.DONE_KO
        tfr   b,a
!       sta   result+31
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
test.t14.count fdb 0
test.t15.count fdb 0
test.t14.list  fdb iface.a,iface.b,iface.c,iface.d,iface.e,iface.f
               fdb pad.a,pad.b,pad.c,pad.d,pad.e,pad.f,pad.g,pad.h
               fdb pad.i,pad.j,pad.k,pad.l,pad.m,pad.n,pad.o,pad.p
               fdb $FFFF
stress.iter    fcb 0
stress.id      fcb 0
stress.exp.dd  fdb 0
stress.exp.ee  fdb 0

 ENDSECTION
