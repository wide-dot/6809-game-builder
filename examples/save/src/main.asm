;*******************************************************************************
; save : the bench of loader.file.save (readme.md). One resident game mode :
; at each boot it reads save.data, counts the boot in it, writes it back,
; reads it again, then checks that the raw files around it are untouched and
; that a file not declared writable is refused. The results are witnesses at
; $9C00 ; the bench (ci/toje-bench/save_ut.py) boots it several times on the
; same disk image.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/pack/std.asm"

bench           equ   $9C00            ; the witnesses (readme.md)
bench.magic     equ   bench+0          ; $CA while running, $0D once done
bench.boots     equ   bench+1          ; the boot count read from save.data at this boot
bench.signed    equ   bench+2          ; 1 : save.data carries its "SAVE" signature
bench.saved     equ   bench+3          ; loader.file.save : 0 written, else its B (DK.STA, $80)
bench.readback  equ   bench+4          ; 1 : save.data read back as written
bench.counted   equ   bench+5          ; the boot count read back
bench.around    equ   bench+6          ; 1 : before.data and after.data as declared
bench.refused   equ   bench+7          ; loader.file.save on before.data : its B ($80), 0 : written
bench.hand      equ   bench+8          ; $D5 : the last save waits for bench.go (the disk check)
bench.go        equ   bench+9          ; set by the bench : the last save goes
bench.checked   equ   bench+10         ; that save : 0 written, else its B
bench.size      equ   11

SIZE            equ   512              ; save.data on the disk : 300 bytes, rounded up
buf             equ   $7000            ; the save in RAM (resident page)
copy            equ   $7200            ; the save read back
near            equ   $7400            ; a neighbour read

; ------------------------------------------------------------------------------
init
        ldx   #bench
!       clr   ,x+
        cmpx  #bench+bench.size
        bne   <
        lda   #$CA
        sta   bench.magic
        _ram.data.set #loader.PAGE    ; the loader, in the data window
        _loader.dir.load #save.data.dir

; the save as the disk holds it
        _loader.file.load #save.data,#1,#buf
        ldd   buf
        cmpd  #"SA"
        bne   count
        ldd   buf+2
        cmpd  #"VE"
        bne   count
        inc   bench.signed
count  lda   buf+4
        sta   bench.boots
        inca                           ; this boot counted
        sta   buf+4
        ldx   #buf+8                   ; the rest : the count, then up by one
fill   sta   ,x+
        inca
        cmpx  #buf+SIZE
        bne   fill

; written back, then read again from the disk
        _loader.file.save #save.data,#1,#buf
        bcs   saved
        clrb
saved  stb   bench.saved
        _loader.file.load #save.data,#1,#copy
        lda   copy+4
        sta   bench.counted
        ldx   #buf
        ldu   #copy
compare    lda   ,x+
        cmpa  ,u+
        bne   around
        cmpx  #buf+SIZE
        bne   compare
        inc   bench.readback

; the raw neighbours, untouched
around
        _loader.file.load #before.data,#1,#near
        ldx   #near
        lda   #$A5
        bsr   same
        bne   refuse
        _loader.file.load #after.data,#1,#near
        ldx   #near
        lda   #$5A
        bsr   same
        bne   refuse
        inc   bench.around

; a file not declared writable : refused, not written
refuse
        _loader.file.save #before.data,#1,#buf
        bcs   refused
        clrb
refused stb   bench.refused

; the disk checked before a write : the bench may put another disk in first
; (the loader reads the directory again, and asks for the right disk)
        lda   #$D5
        sta   bench.hand
wait    tst   bench.go
        beq   wait
        _loader.file.save #save.data,#1,#buf
        bcs   checked
        clrb
checked stb   bench.checked
        lda   #$0D
        sta   bench.magic
done    bra   done

; same : the 100 bytes at X all equal A. Z set when they are.
same    ldb   #100
@loop   cmpa  ,x+
        bne   @rts
        decb
        bne   @loop
@rts    rts

 ENDSECTION
