;-----------------------------------------------------------------
; gfx.memset
;
; input REG : [x] : word that will be copied in video ram
;-----------------------------------------------------------------
; set memory in gfx buffer (16Ko)
; compatible with irq, 16 bytes of overhead :
; - 12 bytes for irq pshs
; - 4 bytes for stack pshs (jsr, ...) inside irq
; best practice is to relocate s once entered in a irq
;-----------------------------------------------------------------

gfx.memset 
        pshs  u,dp
        sts   @s
        lds   #map.ram.DATA_END
        leau  ,x
        leay  ,x
        tfr   x,d
        tfr   a,dp
!
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp
        cmps  #map.ram.DATA_END-(186*88) ; set 16368 bytes
        bne   <
        leau  ,s             
        lds   #$0000
@s      equ   *-2
        pshu  d,x,y ; set remaining 16 bytes
        pshu  d,x,y
        pshu  d,x
        puls  dp,u,pc
