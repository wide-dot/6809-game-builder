
InitGlobals
        ldd   #0

 ifdef OverlayMode
        ; V2-DEVIATION (OverlayMode) : la demi-page 0 ($4000-$5FFF) est de la
        ; RAM stable qui porte le pool d'objets — epingler PRC bit 0 ICI,
        ; au tout premier geste d'un game mode, avant tout acces aux OST.
        ; _gfxlock.init epingle aussi, mais il arrive APRES les inits objets
        ; dans le title : l'effacement du pool partait dans une moitie et le
        ; jeu lisait l'autre (vecu : gel au boot dans un ocean de $FF).
        ldb   MC6846.PRC
        andb  #%11111110
        stb   MC6846.PRC
 endc

        ; clear direct_page data
        ldx   #dp
        lda   #0
!       sta   ,x+
        cmpx  #dp+256
        bne   <

 ifdef DrawSprites
        ldd   #screen_left
        std   glb_camera_x_offset
        ldd   #screen_top
        std   glb_camera_y_offset
 endc

        lda   #1
        sta   glb_alphaTiles
        rts