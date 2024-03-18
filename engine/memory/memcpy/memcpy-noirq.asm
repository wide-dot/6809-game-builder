;-----------------------------------------------------------------
; memcpy.uyd
; input  REG : [U] source
; input  REG : [Y] destination
; input  REG : [D] nb of bytes to copy
;-----------------------------------------------------------------
; copy bytes from a memory location to another one
;----------------------------------------------------------------- 

memcpy.uyd
        pshs  cc,d,x,y,u

        ; setup dynamic code for 8 bytes copy mode
        ldd   7,s     ; u   : load source
        subd  5,s     ; u-y : minus dest
        std   @offset1
        coma
        comb          ; -(u-y)-1
        addd  #9      ; 8+y-u
        std   @offset2
;
        ; setup system stack
        sts   @s      ; backup s register
        orcc  #$50    ; deactivate interrupt
        leas  ,u      ; use s as source for copy
;
        ; setup end of src data cmp
        leau  d,u     ; trash u by computing end position for read
        stu   @cmps+2
;
        ; is nb of bytes to copy an odd value ?
        lsrb
        bcc   >
        lda   ,s+
        sta   ,y+
!
        ; is nb of bytes to copy a multiple of 2 ?
        lsrb
        bcc   >
        puls  x
        stx   ,y++
!
        ; is nb of bytes to copy a multiple of 4 ?
        lsrb
        bcc   @cmps
        puls  x,d
        stx   ,y
        std   2,y
        bra   @cmps
;
        ; process bytes by multiple of 8
!       puls  d,x,y,u    ; read 8 bytes (s->y+8)
        leas  1234,s     ; set stack to write location (s+=u-y, gives s=u+8)
@offset1 set *-2
        pshs  d,x,y,u    ; write 8 bytes (s=u)
        leas  1234,s     ; set stack to read location (s+=8+y-u, gives s=y+8)
@offset2 set *-2
@cmps
        cmps  #0         ; end ?
        bne   <          ; not yet ...
;
        lds   #0
@s      equ   *-2
@rts    puls  cc,d,x,y,u,pc
