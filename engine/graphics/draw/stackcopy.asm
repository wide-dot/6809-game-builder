*******************************************************************************
* stack copy
* -----------------------------------------------------------------------------
*
* stackcopy.run : D bytes from U to Y, 7 at a time, pulled by U and pushed by
* S, from the last byte down : a destination above an overlapping source is
* copied right. 4.44 cycles a byte for 8 000 (toje) : 29 every 7 bytes, about
* 60 every 252, about 210 a call (pulu d,x / std ,y / stx 2,y : about 5.4).
*
* S points into the destination while it pushes : the interrupts are masked
* for each 252 bytes (about 1 100 cycles), and back as the caller had them
* between two, with the caller's S and DP. The destination must not hold the
* caller's stack.
*
* input  REG : [u] source, [y] destination, [d] bytes (0 : none)
* trashes    : a, b, x, y, u ; dp and cc kept
*******************************************************************************

STACKCOPY.CHUNKS equ 36                 ; a block's 7 bytes, the interrupts masked

stackcopy.left  fdb   0                 ; the bytes left for the blocks
stackcopy.s     fdb   0                 ; the copy's S
stackcopy.bytes fcb   0                 ; the bytes left past the chunks, 0 to 6

stackcopy.run
        pshs  cc,dp
        std   stackcopy.left
        leau  d,u
        leau  -7,u                      ; the last 7 bytes
        leay  d,y
        sty   stackcopy.s               ; S pushes below the last byte
        sts   stackcopy.sys+2
        tfr   dp,a
        sta   stackcopy.dp+1
        lda   ,s
        ora   #$AF                      ; the caller's masks : kept by the andcc between blocks
        sta   stackcopy.cc+1
        ldx   #stackcopy.next
        stx   stackcopy.end+1
        jmp   stackcopy.loop

stackcopy.block
        pulu  a,b,dp,x,y                ; 36 times : 6 bytes of code each
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
        pulu  a,b,dp,x,y
        pshs  a,b,dp,x,y
        leau  -14,u
stackcopy.end
        jmp   stackcopy.next            ; (dynamic) stackcopy.tail past the last chunks

stackcopy.next
        sts   stackcopy.s
stackcopy.sys
        lds   #$0000                    ; (dynamic) the caller's S
stackcopy.dp
        lda   #$00                      ; (dynamic) the caller's DP
        tfr   a,dp
stackcopy.cc
        andcc #$FF                      ; (dynamic) the masks back as the caller had them
stackcopy.loop
        ldd   stackcopy.left
        subd  #STACKCOPY.CHUNKS*7
        blo   stackcopy.last
        std   stackcopy.left
        orcc  #$50
        lds   stackcopy.s
        jmp   stackcopy.block

stackcopy.last                          ; the rest, 0 to 251 bytes : its chunks, then its bytes
        addd  #STACKCOPY.CHUNKS*7
        clra
!       subb  #7
        blo   >
        inca
        bra   <
!       addb  #7
        stb   stackcopy.bytes
        nega                            ; the body entered past the chunks not needed
        adda  #STACKCOPY.CHUNKS
        ldb   #6                        ; a chunk's code : pulu, pshs, leau (5-bit offset)
        mul
        addd  #stackcopy.block
        std   stackcopy.go+1
        ldx   #stackcopy.tail
        stx   stackcopy.end+1
        orcc  #$50
        lds   stackcopy.s
stackcopy.go
        jmp   stackcopy.block           ; (dynamic)

stackcopy.tail                          ; the bytes below the chunks, from U+7 and S down
        leax  7,u
        tfr   s,y
        lds   stackcopy.sys+2
        ldb   stackcopy.bytes
        beq   stackcopy.done
stackcopy.byte
        lda   ,-x
        sta   ,-y
        decb
        bne   stackcopy.byte
stackcopy.done
        puls  cc,dp,pc
