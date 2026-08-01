; wrapper for zx0 mega

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

; V2-DEVIATION: the two loads above carry an explicit '<'. v1 wrote them plain
; and let the ambient 'setdp dp/256' pick direct mode; the obj target forbids
; SETDP, so plain would assemble extended. Forcing direct emits v1's bytes.
;
; V2-DEVIATION: v1 padded to the next page here, because the decompressor read
; its self modified bytes through a DP fixed at assembly time. It now derives
; that page from the program counter, so it lands wherever it lands and the
; builder checks the span. Dropped with it: the trailing 'setdp dp/256' that
; only existed to undo the decompressor's own — there is no longer one to undo.

ZX0_DISABLE_DISABLING_INTERRUPTS equ 1
        INCLUDE "./engine/compression/zx0/zx0_6809_mega.asm"
