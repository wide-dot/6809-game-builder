* ---------------------------------------------------------------------------
* spritestream : the equates a caller of the manager needs (spritestream.asm)
* ---------------------------------------------------------------------------
* The game declares spritestream.dp : 8 bytes of the direct page (DP $9F).
* ---------------------------------------------------------------------------

 IFNDEF spritestream.const.asm
spritestream.const.asm equ 1

 IFNDEF spritestream.dp
        ERROR "spritestream : the game declares spritestream.dp, 8 bytes of the direct page"
 ENDC

spritestream.top0       equ spritestream.dp     ; word - save stack top, half 0
spritestream.top1       equ spritestream.dp+2   ; word - save stack top, half 1
spritestream.clipLeft   equ spritestream.dp+4   ; byte - first visible screen byte (drawClip)
spritestream.clipRight  equ spritestream.dp+5   ; byte - first screen byte past the visible ones
spritestream.clipTop    equ spritestream.dp+6   ; byte - first visible line
spritestream.clipBottom equ spritestream.dp+7   ; byte - first line past the visible ones

 ENDC
