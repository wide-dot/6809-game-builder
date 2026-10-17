* ---------------------------------------------------------------------------
* ObjectWave-subtype
* ------------------
* Routine to instanciate objects based on a 16bit meter
* expected data sequence :
* AAAA (timestamp) BB (id objet) CCCC (subtype)
* end marker : $FFFF
*
* store missed frames to wave_frame_drop/anim_frame_duration value
*
* V2-DEVIATION 2026-10-17 : IFDEF OBJECTWAVE_ONE_PER_FRAME, at most one entry
* per frame, like the R-Type arcade (tick_object_wave 40:1BA7 consumes one
* record per tick) : an entry fires on frame max(timestamp, previous fire + 1)
* and its wave_frame_drop counts from that frame. Simultaneous entries are
* spread one frame apart, in table order. Without the define, the file is the
* v1 one byte for byte.
* WARNING : subtype is stored as a 16 bit value, thus overlapping render_flags
* ---------
* !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
* !!! YOU MUST READ subtype_w lower byte before setting the render_flags !!!
* !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
* ---------------------------------------------------------------------------

ObjectWave
        lda   #0
object_wave_data_page equ *-1          ; wave data page
        _SetCartPageA
        ldy   #0
object_wave_data equ *-2               ; current position in wave data
        ldx   gfxlock.frame.gameCount
!       cmpx  ,y
        blo   @rts
 IFDEF OBJECTWAVE_ONE_PER_FRAME
        ldd   #-1                      ; the frame the previous entry fired on
object_wave_last equ *-2
        addd  #1                       ; this entry fires on
        cmpd  ,y                       ; max(timestamp, previous fire + 1)
        bhs   @due
        ldd   ,y
@due    cmpd  gfxlock.frame.gameCount
        bhi   @rts                     ; queued behind an earlier entry
        std   object_wave_last
 ENDC
        pshs  x,y
        jsr   LoadObject_u
        puls  x,y                      ; puls does not change zero
        beq   @bypass
        lda   2,y
        sta   id,u
        ldd   3,y
        std   subtype_w,u
        ldd   gfxlock.frame.gameCount
 IFDEF OBJECTWAVE_ONE_PER_FRAME
        subd  object_wave_last
 ELSE
        subd  ,y
 ENDC
        stb   wave_frame_drop,u
@bypass leay  5,y
        bra   <
@rts    sty   object_wave_data
        rts

ObjectWave_Init
        pshs  a,x,y
        lda   object_wave_data_page
        _SetCartPageA
        ldy   object_wave_data_start
        ldx   gfxlock.frame.gameCount
!       cmpx  ,y
        blo   @end
        leay  5,y
        bra   <
@end    sty   object_wave_data
 IFDEF OBJECTWAVE_ONE_PER_FRAME
        stx   object_wave_last         ; the next entry is later : on time
 ENDC
        puls  a,x,y,pc

object_wave_data_start fdb 0