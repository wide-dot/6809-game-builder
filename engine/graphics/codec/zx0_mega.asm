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
; its self modified bytes through a DP fixed at assembly time. Those bytes now
; live in the direct page the caller already runs on, named by ZX0_DP below,
; so the padding is gone and so is the trailing 'setdp dp/256' that only
; existed to undo the decompressor's own.

; Four bytes of the engine's scratch. Every dp_engine user starts at +0, but
; none of them keeps those bytes across a compiled sprite call : the ones that
; call a draw routine (BuildSprites) rewrite them per sprite, and the sprite
; pack this codec serves reaches its draw routine through the object, not
; through DP. Games that hold a counter here across a draw — r-type's hud and
; text do — must not draw a compressed image from that loop.
ZX0_DP equ dp_engine

ZX0_DISABLE_DISABLING_INTERRUPTS equ 1
        INCLUDE "./engine/compression/zx0/zx0_6809_mega.asm"
