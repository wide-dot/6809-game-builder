; -----------------------------------------------------------------------------
; Does a stacked list survive crossing a page boundary ?
;
; The loader lays a stacked list out from a base address and moves to the next
; page when a file no longer fits. It used to restart the next page at address
; ZERO. On a TO8 the cartridge window opens at $0000, so "zero" and "where the
; window opens" were the same number and nothing ever showed. On a MO6 the
; window opens at $B000 : the loader wrote 45 KB below it, over system RAM.
;
; This program checks every marker where the loader was supposed to put it, and
; says so with the screen border :
;
;   GREEN  every marker is where it belongs
;   RED    one is missing — its number is left in $6000 (and on screen)
;
; Run it on both machines. TO8 must be green before and after the fix ; MO6 is
; red before and green after. That difference IS the bug.
; -----------------------------------------------------------------------------

 SECTION code
 opt c,ct

        INCLUDE "engine/constants.asm"

 IFDEF TO8
        INCLUDE "engine/system/to8/map.const.asm"
 ENDC
 IFDEF MO6
        INCLUDE "engine/system/mo6/map.const.asm"
 ENDC

MARKER_COUNT    equ 10
MARKER_SIZE     equ $0800          ; 2 KB each : ten of them cross two pages
BORDER_GREEN    equ 3
BORDER_RED      equ 6


main.init
        orcc  #$50                 ; nothing must run under us while we look

        lda   #$FF
        sta   report

        ; Walk the markers the way the loader was supposed to lay them out :
        ; from the base, moving to the next page — AT THE BASE ADDRESS, not at
        ; zero — as soon as one no longer fits.
        ldb   #stacked.base.page
        ldu   #stacked.base.address
        lda   #1                    ; A = marker number, counted from one

check.next
        pshs  a,b,u
        jsr   ram.set               ; bring that page into view
        puls  a,b,u

        ; a marker holds its own number in its first and last byte, so a
        ; half-written or misplaced one cannot pass for a good one
        cmpa  ,u
        bne   check.faulty
        pshs  u
        leau  MARKER_SIZE-1,u
        cmpa  ,u
        puls  u
        bne   check.faulty

        leau  MARKER_SIZE,u         ; next slot
        pshs  a
        tfr   u,x
        leax  MARKER_SIZE,x         ; would the NEXT one still fit ?
        cmpx  #map.ram.CART_END
        bls   check.samePage
        ldu   #map.ram.CART_START   ; no : next page, at the window's start
        incb
check.samePage
        puls  a
        inca
        cmpa  #MARKER_COUNT+1
        blo   check.next

        ldb   #BORDER_GREEN
        bra   check.show

check.faulty
        sta   report
        ldb   #BORDER_RED

check.show
        ; bits 0-3 are the border colour, bits 6-7 the page being displayed :
        ; writing the whole byte would send the screen somewhere else
        lda   >map.CF74021.SYS2
        anda  #%11110000
        pshs  b
        orb   ,s+
        stb   >map.CF74021.SYS2
        bra   *                     ; hold the colour on screen

report  fcb   $FF                   ; first faulty marker, $FF when all is well

; The page switcher lives here rather than in its own file : it is plain code
; with no section of its own, and this unit is what opens one.
 IFDEF TO8
        INCLUDE "engine/system/to8/ram/ram.asm"
 ENDC
 IFDEF MO6
        INCLUDE "engine/system/mo6/ram/ram.asm"
 ENDC

 ENDSECTION
