* ---------------------------------------------------------------------------
* ClearDataMem - fills the data window ($A000-$DFFF) with the word X, by
* stack blasts ; trashes d, y
* V2-DEVIATION : 8 byte pushes, the word kept whole (v1's pushed DP too,
* 9 bytes : a word of two different bytes came out shifted every 9).
* ---------------------------------------------------------------------------

ClearDataMem
        pshs  u
        sts   ClearDataMem.sys
        lds   #$E000
        leau  ,x
        leay  ,x
        tfr   x,d
!       pshs  u,y,x,d                  ; 88 bytes a loop
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        pshs  u,y,x,d
        cmps  #$A010
        bne   <
        leau  ,s
        lds   #$0000
ClearDataMem.sys equ *-2               ; (dynamic) the caller's stack : the window's
        pshu  d,x,y                    ; first 16 bytes by U, an IRQ landing on S
        pshu  d,x,y                    ; there would push 12 bytes and more
        pshu  d,x
        puls  u,pc
