;*******************************************************************************
; FD Boot loader
; Original code from Prehisto
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

        INCLUDE "engine/constants.asm"
        INCLUDE "new-engine/system/mo6/map.const.asm"
        INCLUDE "new-engine/system/mo6/bootloader/loader.const.asm"

; Disk boot
        org    $2200
        setdp  $20

; Freeze interrupts
        orcc  #$50

; Check computer type
        leax  <mess1,pcr          ; Error message
        lda   #$01                ; Load code
        cmpa  >$FFF0              ; Check machine code
        bne   err                 ; Error if not MO6

; Load loader sectors
 IFGE loader.ADDRESS-$B000        ; Skip if not RAM over cartridge space
        ldb   #loader.PAGE        ; Load RAM page
        orb   #$60                ; Set RAM over cartridge space
        stb   >map.CF74021.CART   ; Switch RAM page
 ELSE
  IFGE loader.ADDRESS-$6000       ; Skip if not data space
        lda   #$10
        ora   <map.CF74021.SYS1.R ; Set RAM
        sta   <map.CF74021.SYS1.R ; over data
        sta   >map.CF74021.SYS1   ; space
        ldb   #loader.PAGE        ; Load RAM page
        stb   >map.CF74021.DATA   ; Switch RAM page
  ELSE
   IFGE loader.ADDRESS-$2000      ; Skip if not resident space
   ELSE
        ldb   #loader.PAGE        ; Load RAM page
        andb  #$01                ; Keep only half page A or B
        orb   >map.MC6846.PRC     ; Merge register value
        stb   >map.MC6846.PRC     ; Set desired half page in video space
   ENDC
  ENDC
 ENDC
        ldd   #loader.ADDRESS    ; Loading
        std   <map.DK.BUF        ; address
        IFGT loader.ADDRESS-((loader.ADDRESS/256)*256)
        ERROR "loader.ADDRESS is expected to be a multiple of 256 bytes. Ex: $6000, $2100, ..."
        ENDC                     ; b register is always 0
        stb   <$20ff             ; Cold reset
        lda   #$02               ; >read code
        std   <map.DK.OPC        ; Read/Head 0
        ldu   #blist             ; Interleave list
        ldx   #mess3             ; Error message
boot2   lda   b,u                ; Get sector
        sta   <map.DK.SEC        ; number
        jsr   >map.DKCONT        ; Load sector
        bcc   boot3              ; Skip if no error
        jsr   >map.DKCONT        ; Reload sector
        bcs   err                ; Skip if error
boot3   inc   <map.DK.BUF        ; Move sector ptr
        incb                     ; Sector+1
        dec   >secnbr            ; Next
        bne   boot2              ; sector
        lds   #$5F00             ; Set system stack
        jmp   >loader.ADDRESS

; Display error message
err     leau  <mess0,pcr         ; Location
        bsr   err2               ; Display location
        leau  ,x                 ; Message pointer
        bsr   err2               ; Display message
err0    bra   err0               ; Infinite loop

; Display message
err1    bsr   err3               ; Display char
err2    ldb   ,u+                ; Read char
        bpl   err1               ; Next if not last
        andb  #$7f               ; Mask char
err3    tfr   dp,a               ; Read DP
        asla                     ; Check if MO or TO
        lbmi  map.PUTC           ; Display for TO - PUTC
        swi                      ; Display for MO
        fcb   $82                ; Display for MO - PUTC parameter

        IFGT *-$2278
        ERROR "boot code part 1 is too large !"
        ENDC

        align $2278
@magicNumber
        fcn   "BASIC2"
        fcb   $00                               ; checksum (set at build stage)
secnbr  fcb   (builder.lwasm.size.loader/256)+1 ; number of sectors to read

; Error messages
mess1   fcs   "Only for MO6/PC128"
mess3   fcs   "     I/O|Error"

; Location message
mess0   fcb   $1f,$21,$21
        fcb   $1f,$11,$13        ; 3 lines (11-13)
        fcb   $1b,$47            ; font : white
        fcb   $1b,$51            ; background : red
        fcb   $0c                ; cls
        fcb   $1f,$4c,$4b+$80    ; locate for MO

; Interleave table
blist   fcb   $0f,$0d,$0b        ; first value is omitted ($01 : boot sector)
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a

        IFGT *-$2300
        ERROR "boot code part 2 is too large !"
        ENDC
