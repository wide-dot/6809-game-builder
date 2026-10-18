; ---------------------------------------------------------------------------
; zx0_6809_mega_wrap - an image compressed in two parts (gfxcomp's ZX0
; encoder) : X the first part, decompressed to glb_screen_location_1, U the
; second, to glb_screen_location_2 (0 : none)
; ---------------------------------------------------------------------------

zx0_6809_mega_wrap
        stu   @x
        ldu   <glb_screen_location_1
        cmpx  #0
        beq   >                        ; branch if no data part 1
        jsr   zx0_decompress
!
        ldx   #0                       ; (dynamic) load next data ptr
@x      equ   *-2
        beq   @rts
        ldd   #0
        std   @x                       ; clear exit flag for second pass
        ldu   <glb_screen_location_2
        jmp   zx0_decompress
@rts    rts

; V2-DEVIATION : the two loads take an explicit < (v1's setdp, forbidden in
; the obj target) ; no padding to the next page : the decompressor's own
; bytes live in the caller's direct page, ZX0_DP.
ZX0_DP equ dp_engine                   ; 4 bytes of the engine's scratch : a game holding
                                       ; them across a draw draws no compressed image there

ZX0_DISABLE_DISABLING_INTERRUPTS equ 1
        INCLUDE "./engine/compression/zx0/zx0_6809_mega.asm"
