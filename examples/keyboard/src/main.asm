;*******************************************************************************
; keyboard : the 6804's frames on screen, and the bench of keyboard.fast
; (readme.md). The monitor's text screen, the 50 Hz IRQ on throughout.
; Loaded at $6300 : the monitor's screen buffers sit below.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/pack/std.asm"
        INCLUDE "engine/system/to8/pack/irq.asm"
        INCLUDE "engine/system/to8/monitor/monitor.macro.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.macro.asm"

bench           equ   $9C00            ; the witnesses (readme.md)
bench.magic     equ   bench+0          ; $CA once running
bench.mode      equ   bench+1          ; written by the bench : MODE_*
bench.logged    equ   bench+2          ; frames keyboard.fast.read returned
bench.count     equ   bench+3          ; keyboard.fast.count then
bench.frame     equ   bench+4          ; the last frame returned (word)
bench.pressed   equ   bench+6          ; keyboard.fast.pressed with it (word)
bench.held      equ   bench+8          ; keyboard.fast.held, every pass (word)
bench.irqReads  equ   bench+10         ; frames read by the IRQ routine
bench.size      equ   11
bench.log       equ   $9D00            ; each frame returned, bit 15 : pressed (128 words, a ring)

MODE_IRQ        equ   $01              ; polled in the IRQ, read once a frame (else at every pass)
MODE_QUIET      equ   $80              ; nothing on screen

ROW             equ   5                ; the first value's row
COL             equ   11               ; the values' column

; ------------------------------------------------------------------------------
init
        _glb.init
        ldx   #bench
!       clr   ,x+
        cmpx  #bench+bench.size
        bne   <
        ldx   #bench.log
!       clr   ,x+
        cmpx  #bench.log+256
        bne   <
        _irq.init
        _irq.setRoutine #userIRQ
        _irq.set50Hz
init.call                              ; (the bench times the call between these)
        _keyboard.fast.init
init.done
        _irq.on

        lda   #$60                     ; the monitor's page, for PUTC
        tfr   a,dp
        ldx   #msg.screen
        jsr   monitor.print
        lda   #$CA
        sta   bench.magic

; ------------------------------------------------------------------------------
mainLoop
        lda   bench.mode
        bita  #MODE_IRQ
        beq   @read                    ; a read at every pass
        lda   tick                     ; or once a frame, after the IRQ's poll
!       cmpa  tick
        beq   <
@read
read.call                              ; (the bench times the call between these)
        _keyboard.fast.read
read.done
        ldx   keyboard.fast.held
        stx   bench.held
        bcc   mainLoop
        std   bench.frame
        ldx   keyboard.fast.pressed
        stx   bench.pressed
        ldb   bench.logged
        andb  #$7F
        aslb
        ldx   #bench.log
        abx
        ldd   bench.frame
        tst   bench.pressed
        bmi   >                        ; a repeat
        ora   #$80                     ; bit 15 : pressed
!       std   ,x
        inc   bench.logged
        lda   keyboard.fast.count
        sta   bench.count
        tst   bench.mode
        bmi   mainLoop                 ; MODE_QUIET
        jsr   show
        bra   mainLoop

; ------------------------------------------------------------------------------
userIRQ
        lda   bench.mode
        bita  #MODE_IRQ
        beq   >
poll.call
        jsr   keyboard.fast.poll       ; first thing, before any $E7C3 access
poll.done
        bcc   >
        inc   bench.irqReads
!       inc   tick
        rts

tick    fcb   0

; ------------------------------------------------------------------------------
; the last frame's values on screen (PUTC keeps X, not D) : ~100k cycles
; ------------------------------------------------------------------------------
show.hex8                              ; B : two hex digits
        pshs  b
        lsrb
        lsrb
        lsrb
        lsrb
        bsr   show.nibble
        puls  b
show.nibble                            ; B : its low nibble
        andb  #$0F
        addb  #'0
        cmpb  #'9
        bls   >
        addb  #'A-'9-1
!       _monitor.jmp.putc

show.dec3                              ; B : three decimal digits
        lda   #100
        bsr   @digit
        lda   #10
        bsr   @digit
        addb  #'0
        _monitor.jmp.putc
@digit  sta   @div
        clra
!       cmpb  @div
        blo   >
        subb  @div
        inca
        bra   <
!       pshs  b
        tfr   a,b
        addb  #'0
        _monitor.jsr.putc
        puls  b,pc
@div    fcb   0

show
        ldx   #at.frame
        jsr   monitor.print
        ldb   bench.frame
        bsr   show.nibble
        ldb   bench.frame+1
        bsr   show.hex8
        ldx   #at.key
        jsr   monitor.print
        ldb   bench.frame+1
        andb  #$7F
        bsr   show.hex8
        ldx   #msg.gap
        jsr   monitor.print
        ldb   bench.frame+1
        andb  #$7F
        cmpb  #$50
        blo   >
        ldb   #$50                     ; past the keys : "?"
!       lda   #6
        mul
        ldx   #names
        leax  d,x
        ldb   #6
@name   pshs  b
        ldb   ,x+
        _monitor.jsr.putc
        puls  b
        decb
        bne   @name
        ldx   #at.shift
        jsr   monitor.print
        ldx   #msg.no
        tst   bench.frame+1
        bpl   >
        ldx   #msg.yes
!       jsr   monitor.print
        ldx   #at.cnt
        jsr   monitor.print
        ldx   #msg.no
        ldb   bench.frame
        lsrb
        bcc   >
        ldx   #msg.yes
!       jsr   monitor.print
        ldx   #at.state
        jsr   monitor.print
        ldx   #msg.repeat
        tst   bench.pressed
        bmi   >
        ldx   #msg.pressed
!       jsr   monitor.print
        ldx   #at.frames
        jsr   monitor.print
        ldb   bench.logged
        lbsr  show.dec3
        ldx   #at.count
        jsr   monitor.print
        ldb   bench.count
        lbsr  show.dec3
        ldx   #at.irq
        jsr   monitor.print
        ldb   bench.irqReads
        lbsr  show.dec3
        ldx   #at.mode
        jsr   monitor.print
        ldx   #msg.main
        lda   bench.mode
        bita  #MODE_IRQ
        beq   >
        ldx   #msg.irqPoll
!       jmp   monitor.print

; ------------------------------------------------------------------------------
msg.screen      fcb   $0C              ; clear the screen
                fcb   $1F,$40+1,$40+2
                fcc   "KEYBOARD.FAST - THE 6804'S FRAMES"
                fcb   $1F,$40+3,$40+2
                fcc   "BIT 8 CNT, BIT 7 SHIFT, 6-0 THE KEY"
                fcb   $1F,$40+ROW,$40+2
                fcc   "FRAME    $"
                fcb   $1F,$40+ROW+1,$40+2
                fcc   "KEY      $"
                fcb   $1F,$40+ROW+2,$40+2
                fcc   "SHIFT"
                fcb   $1F,$40+ROW+3,$40+2
                fcc   "CNT"
                fcb   $1F,$40+ROW+4,$40+2
                fcc   "STATE"
                fcb   $1F,$40+ROW+6,$40+2
                fcc   "FRAMES         ENGINE COUNT"
                fcb   $1F,$40+ROW+7,$40+2
                fcc   "IRQ READ"
                fcb   $1F,$40+ROW+9,$40+2
                fcc   "MODE"
                fcb   $1F,$40+20,$40+2
                fcc   "PRESS A KEY, ALONE OR WITH SHIFT, CNT"
                fcb   $1F,$40+21,$40+2
                fcs   "HOLD IT : THE 6804 REPEATS IT"
at.frame        fcb   $1F,$40+ROW,$40+COL+1+$80
at.key          fcb   $1F,$40+ROW+1,$40+COL+1+$80
at.shift        fcb   $1F,$40+ROW+2,$40+COL+$80
at.cnt          fcb   $1F,$40+ROW+3,$40+COL+$80
at.state        fcb   $1F,$40+ROW+4,$40+COL+$80
at.frames       fcb   $1F,$40+ROW+6,$40+COL+$80
at.count        fcb   $1F,$40+ROW+6,$40+COL+19+$80
at.irq          fcb   $1F,$40+ROW+7,$40+COL+$80
at.mode         fcb   $1F,$40+ROW+9,$40+COL+$80
msg.gap         fcs   "  "
msg.yes         fcs   "YES"
msg.no          fcs   "NO "
msg.pressed     fcs   "PRESSED"
msg.repeat      fcs   "REPEAT "
msg.main        fcs   "READ AT EVERY PASS"
msg.irqPoll     fcs   "POLLED IN THE IRQ "

names           fcc   "F2    6     Y     H     UP    RIGHT RAZ   N     " ; $00
                fcc   "F3    5     T     G     =     LEFT  INS   B     " ; $08
                fcc   "F4    4     R     F     ACC   KP 1  EFF   V     " ; $10
                fcc   "F5    3     E     D     KP 7  KP 4  KP 0  C     " ; $18
                fcc   "F1    2     Z     S     KP 8  KP 2  KP .  X     " ; $20
                fcc   "#     1     A     Q     [     KP 5  KP 6  W     " ; $28
                fcc   "STOP  7     U     J     SPACE KP 9  KP ENT,     " ; $30
                fcc   "NONE  8     I     K     $     DOWN  ]     ;     " ; $38
                fcc   "CAPS  9     O     L     -     U GRAVENT   :     " ; $40
                fcc   "NONE  0     P     M     )     ^     KP 3  >     " ; $48
                fcc   "?     "                                           ; $50

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/controller/keyboard.fast.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.print.asm"
