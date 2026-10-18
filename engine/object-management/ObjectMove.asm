* ---------------------------------------------------------------------------
* ObjectMove
* ----------
* One frame of movement, no gravity : the velocity (s8.8) added to the
* position (16.8).
*
* input REG : [u] the object
* trashes   : d
* ---------------------------------------------------------------------------

ObjectMove
        ldd   x_vel,u
        bpl   >
        dec   x_pos,u                  ; negative : its high byte is $FF
!       addd  x_pos+1,u                ; x_pos must be followed by x_sub in memory
        std   x_pos+1,u
        bcc   >
        inc   x_pos,u
!       ldd   y_vel,u
        bpl   >
        dec   y_pos,u
!       addd  y_pos+1,u                ; y_pos must be followed by y_sub in memory
        std   y_pos+1,u
        bcc   >
        inc   y_pos,u
!       rts
