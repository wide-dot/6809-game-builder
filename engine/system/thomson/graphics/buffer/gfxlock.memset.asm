;-----------------------------------------------------------------
; gfxlock.memset
;
; input REG : [x] : word that will be copied in video ram
;-----------------------------------------------------------------
; Set memory in gfx buffer (1x or 2x8000 bytes)
; Compatible with irq, 12 bytes of overhead
; S stack must be relocated in irq
;
; video memory is splitted in 2 parts:
; color 8000 bytes + 192 unused bytes
; text  8000 bytes + 192 unused bytes
;
; This routine :
; - Does not clean the 2x192 unused bytes
; - Does not use DIRECT PAGE for vars as dp is used in stack blast
;-----------------------------------------------------------------

gfxlock.memset       EXPORT
gfxlock.color.memset EXPORT
gfxlock.text.memset  EXPORT

 SECTION code

gfxlock.memset.overhead   equ 12
gfxlock.color.memset.addr equ map.ram.DATA_START+gfxlock.memset.overhead
gfxlock.text.memset.addr  equ gfxlock.color.memset.addr+gfxlock.memset.overhead+8192

gfxlock.memset
        bsr   gfxlock.color.memset
        ; continue ...

gfxlock.text.memset
        pshs  u,dp
        sts   >glb.DP
        lds   #gfxlock.text.memset.addr
        bra   @common
gfxlock.color.memset
        pshs  u,dp
        sts   >glb.DP
        lds   #gfxlock.color.memset.addr
@common
        sts   >glb.DP+2
        leas  8000-gfxlock.memset.overhead,s
        leau  ,x
        leay  ,x
        tfr   x,d
        tfr   a,dp
        pshs  u,y,x,dp,b,a ; last 32 bytes
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  x,dp,b,a
!
        pshs  u,y,x,dp,b,a ; 9 bytes
        pshs  u,y,x,dp,b,a ; x 13 times
        pshs  u,y,x,dp,b,a ; x 68 loops
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        pshs  u,y,x,dp,b,a
        cmps  >glb.DP+2
        bne   <
        leau  ,s             
        lds   >glb.DP
        pshu  d,x,y        ; first 12 bytes overhead
        pshu  d,x,y
        puls  dp,u,pc

 ENDSECTION