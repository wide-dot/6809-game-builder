* ---------------------------------------------------------------------------
* spritestream : the equates a caller of the manager needs (spritestream.asm)
* ---------------------------------------------------------------------------
* The game declares spritestream.dp : 4 bytes of the direct page (DP $9F).
* ---------------------------------------------------------------------------

 IFNDEF spritestream.const.asm
spritestream.const.asm equ 1

 IFNDEF spritestream.dp
        ERROR "spritestream : the game declares spritestream.dp, 4 bytes of the direct page"
 ENDC

spritestream.top0       equ spritestream.dp     ; word - save stack top, half 0
spritestream.top1       equ spritestream.dp+2   ; word - save stack top, half 1

 ENDC
