* ---------------------------------------------------------------------------
* InitGlobals - a game mode's first call : the direct page cleared, the
* camera offsets (DrawSprites), glb_alphaTiles at 1
* V2-DEVIATION (OverlayMode) : half page 0 ($4000-$5FFF) holds the object
* pool : pinned here, before any object is touched (_gfxlock.init pins it
* too, but after the objects' init in a title).
* ---------------------------------------------------------------------------
InitGlobals
 ifdef OverlayMode
        ldb   MC6846.PRC
        andb  #%11111110
        stb   MC6846.PRC               ; half page 0
 endc
        ldx   #dp
        clra
!       sta   ,x+
        cmpx  #dp+256
        bne   <

 ifdef DrawSprites
        ldd   #screen_left
        std   <glb_camera_x_offset
        ldd   #screen_top
        std   <glb_camera_y_offset
 endc

        lda   #1
        sta   glb_alphaTiles
        rts