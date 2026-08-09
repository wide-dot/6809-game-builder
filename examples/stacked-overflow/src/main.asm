; -----------------------------------------------------------------------------
; Does a list of files survive crossing a page boundary ?
;
; Historically the loader laid a stacked list out at run time and restarted the
; next page at address ZERO instead of where the window opens — invisible on
; TO8 ($0000), destructive on MO6 ($B000, 45 KB written over system RAM).
; That bug is fixed and proved on both machines. Since the removal of
; stacked="true", the BUILDER decides the layout : an arena of two zones,
; filled in declaration order, the overflow going to the second zone. The
; expected addresses are the same ; who decides them changed.
;
; This program checks every marker where it is supposed to be, and says so
; with the screen border :
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

; ram.set logs a fatal probe on an unmappable destination since the common
; log system landed : the unit that carries ram.asm carries the log contract
        INCLUDE "engine/log/log.const.asm"
        INCLUDE "engine/log/log.macro.asm"

MARKER_COUNT    equ 10
MARKER_SIZE     equ $0800          ; 2 KB each : ten of them cross two pages
; Thomson default palette : 0 black, 1 red, 2 green, 3 yellow, 4 blue…
; (3 and 6 showed yellow and cyan — measured on machine, not what their
; names promised)
BORDER_GREEN    equ 2
BORDER_RED      equ 1


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
        INCLUDE "engine/log/log.asm"

 ENDSECTION
