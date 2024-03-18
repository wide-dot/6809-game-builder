;-----------------------------------------------------------------
; gfxlock.memset
;
; input REG : [x] : word that will be copied in video ram
;-----------------------------------------------------------------
; Set memory in gfx buffer (16Ko)
; Compatible with irq, 12 bytes of overhead
; S stack must be relocated in irq
;
; video memory is splitted in 2 parts:
; 8000 bytes + 192 unused bytes
; 8000 bytes + 192 unused bytes
;
; This routine does not clean the upper 172 bytes
;-----------------------------------------------------------------

gfxlock.memset EXPORT

 SECTION code

gfxlock.memset.endAddr equ map.ram.DATA_END-172

gfxlock.memset
        pshs  u,dp
        sts   @s
        lds   #gfxlock.memset.endAddr
        leau  ,x
        leay  ,x
        tfr   x,d
        tfr   a,dp
!
        pshs  u,y,x,dp,b,a ; 9 bytes
        pshs  u,y,x,dp,b,a ; x 10 times
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        cmps  #gfxlock.memset.endAddr-(180*9*10) ; memset of 16200 bytes
        bne   <
        leau  ,s             
        lds   #$0000
@s      equ   *-2
        pshu  d,x,y ; memset of remaining 12 bytes
        pshu  d,x,y
        puls  dp,u,pc

 ENDSECTION