sound.title.ymm EXTERNAL
ymm.init        EXTERNAL
ymm.frame.play  EXTERNAL

 SECTION code

DEBUG                equ 1
SOUND_CARD_PROTOTYPE equ 1

        INCLUDE "new-engine/system/to8/map.const.asm"
        INCLUDE "new-engine/global/glb.const.asm"
        INCLUDE "new-engine/system/to8/irq/irq.const.asm"
        INCLUDE "new-engine/system/to8/palette/palette.const.asm"
        INCLUDE "new-engine/sound/ymm.const.asm"

        INCLUDE "new-engine/6809/macros.asm"
        INCLUDE "new-engine/object/sound/ymm/ymm.macro.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.macro.asm"

;        INCLUDE "./engine/objects/palette/fade/fade.equ"
;
;        INCLUDE "./src/global/variables.asm"

viewport_width  equ 144
viewport_height equ 180

        jsr   glb.init
;        jsr   InitDrawSprites
;        jsr   InitStack
;        jsr   InitJoypads
;        jsr   WaitVBL
        jsr   ym2413.reset

; init user irq

        jsr   irq.init
        ldd   #UserIRQ
        std   irq.userRoutine
        ldd   #255                     ; set sync out of display
        ldx   #irq.ONE_FRAME           ; for palette changes
        jsr   irq.syncScreenLine
        jsr   irq.on 

;        lda   #GmID_title
;        sta   glb_Cur_Game_Mode
;
;
;
;* ---------------------------------------------------------------------------
;* PHASE 0 : Init all objects
;* ---------------------------------------------------------------------------       
;* Logo letters
;* -------------------------
;
;_loadLogo MACRO
;        jsr   LoadObject_x
;	    stx   ,u++
;        lda   #\1
;        sta   id,x
;        lda   #\2
;        sta   subtype,x
; ENDM
;
;	    ldu   #addr_logo
;        _loadLogo ObjID_logo,1 ; Logo R
;        _loadLogo ObjID_logo,2 ; Logo Dot
;        _loadLogo ObjID_logo,3 ; Logo T
;        _loadLogo ObjID_logo,4 ; Logo Y
;        _loadLogo ObjID_logo,5 ; Logo P
;        _loadLogo ObjID_logo,6 ; Logo E
;
;* -------------------------
;* Text Object
;* -------------------------
;
;        _MountObject ObjID_text
;        lda   #$39
;        sta   ,x                        ; Reset the start of the TEXT object to RTS
;
;        jsr   LoadObject_x		; Text
;        stx   addr_text
;        lda   #ObjID_text
;        sta   id,x
;        ldd   #addr_scores
;        std   x_vel,x                   ; Hijacking unused x_vel to store the Score Numbers addr   
;        clr   subtype,x                 ; = Slow text
;
;
;* -------------------------
;* Score Number Objects
;* -------------------------
;
;_loadScore MACRO
;        jsr   LoadObject_x
;        stx   ,u++
;        lda   #\1
;        sta   id,x
;        lda   #\2
;        sta   subtype,x
;        ldd   #\3
;        std   x_pos,x
;        ldd   #\4
;        std   y_pos,x
; ENDM
;
;        ldu   #addr_scores
;
;        _loadScore ObjID_scores,$80,45,35
;        _loadScore ObjID_scores,$81,45,49
;        _loadScore ObjID_scores,$82,45,63
;        _loadScore ObjID_scores,$83,45,77
;        _loadScore ObjID_scores,$84,45,91
;        _loadScore ObjID_scores,$85,45,105
;        _loadScore ObjID_scores,$86,45,119
;        _loadScore ObjID_scores,$87,45,133
;        _loadScore ObjID_scores,$88,45,147
;        _loadScore ObjID_scores,$89,45,161
;
;* ---------------------------------------------------------------------------
;* PHASE 1 : Letters move from right to left
;* ---------------------------------------------------------------------------
;
;Phase1Init
;
;	ldu   #addr_logo
;	ldy   #logo_startx
;	lda   #6
;	sta   @phase1initloopnum
;Phase1InitLoop
;	ldx   ,u++
;	ldd   ,y++
;        std   x_pos,x
;        ldd   #100
;        std   y_pos,x
;	ldd   #-$200
;	std   x_vel,x
;	lda   #0
;@phase1initloopnum equ *-1
;	deca
;	sta   @phase1initloopnum
;	bne   Phase1InitLoop
;Phase1Live
;
;	ldu   #addr_logo
;	ldx   ,u
;	ldd   x_pos,x
;	cmpd  #35
;	ble   Phase2Init
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase1Live
;
;* ---------------------------------------------------------------------------
;* PHASE 2 : Letters expand to the right
;* ---------------------------------------------------------------------------
;
;Phase2Init
;	ldx   ,u
;	ldy   #logo_finalpos
;	ldd   ,y
;	std   x_pos,x
;	ldy   #logo_xvel
;	lda   #6
;	sta   @phase2initloopnum
;Phase2InitLoop
;	ldx   ,u++
;	ldd   ,y++
;	std   x_vel,x
;	lda   #0
;@phase2initloopnum equ *-1
;	deca
;	sta   @phase2initloopnum
;	bne   Phase2InitLoop
;Phase2Live
;
;	ldu   #addr_logo
;	ldx   2,u
;	ldd   x_pos,x
;	cmpd  #50
;	bge   Phase3Init
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase2Live
;
;* ---------------------------------------------------------------------------
;* PHASE 3 : Re-align the logo, move the TM
;* ---------------------------------------------------------------------------
;
;Phase3Init
;	ldu   #addr_logo
;	ldy   #logo_finalpos
;	lda   #6
;	sta   @phase3initloopnum
;Phase3InitLoop
;	ldx   ,u++
;	ldd   #0
;	std   x_vel,x
;	ldd   ,y++
;	std   x_pos,x
;	lda   #0
;@phase3initloopnum equ *-1
;	deca
;	sta   @phase3initloopnum
;	bne   Phase3InitLoop
;
;        jsr   LoadObject_x		; Logo TM
;	stx   addr_tm
;        lda   #ObjID_logo
;        sta   id,x
;	ldd   #0
;        sta   subtype,x
;	std   x_pos,x
;	std   y_pos,x
;	ldd   #690
;	std   x_vel,x
;	ldd   #650
;	std   y_vel,x
;
;Phase3Live
;
;	ldu   #addr_tm
;	ldx   ,u
;	ldd   y_pos,x
;	cmpd  #125
;	bge   Phase4Init
;	ldd   x_pos,x
;	cmpd  #133
;	bge   Phase4Init
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase3Live
;
;* ---------------------------------------------------------------------------
;* PHASE 4 : Move the logo and TM down
;* ---------------------------------------------------------------------------
;
;Phase4Init
;
;	ldu   #addr_logo
;	lda   #6
;	sta   @phase4initloopnum
;Phase4InitLoop
;	ldx   ,u++
;	ldd   #200
;	std   y_vel,x
;	lda   #0
;@phase4initloopnum equ *-1
;	deca
;	sta   @phase4initloopnum
;	bne   Phase4InitLoop
;
;	ldu   #addr_tm
;	ldx   ,u
;	ldd   #0
;	std   x_vel,x
;	ldd   #200
;	std   y_vel,x
;	ldd   #138
;	std   x_pos,x
;	ldd   #130
;	std   y_pos,x
;
;Phase4Live
;
;	ldu   #addr_logo
;	ldx   ,u
;	ldd   y_pos,x
;	cmpd  #126
;	bge   Phase5Init
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase4Live
;
;
;* ---------------------------------------------------------------------------
;* PHASE 5 : Stop the logo and TM. start the music and display the text
;* ---------------------------------------------------------------------------
;
;Phase5Init
;
;	ldu   #addr_logo
;	lda   #6
;	sta   @phase5initloopnum
;Phase5InitLoop
;	ldx   ,u++
;	ldd   #0
;	std   y_vel,x
;	lda   #0
;@phase5initloopnum equ *-1
;	deca
;	sta   @phase5initloopnum
;	bne   Phase5InitLoop
;
;	ldu   #addr_tm
;	ldx   ,u
;	ldd   #0
;	std   y_vel,x
;
;        _MountObject ObjID_text
;        lda   #$12
;        sta   ,x                        ; Reset the start of the TEXT object to NOP
;
        jsr   irq.off
        _MountObject ObjID_ymm00
        _ymm.init #$60+6,#sound.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
;        _MountObject ObjID_vgc00
;        _MusicInit_objvgc #0,#MUSIC_LOOP,#0
        jsr   irq.on
        bra *
;
;
;Phase5Live
;
;        _MountObject ObjID_text
;        lda   ,x                        ; Test if type writer is done
;        cmpa  #$39                      ; Op code for RTS
;        beq   Phase6Init
;
;        ; press fire
;        lda   Fire_Press
;        anda  #c1_button_A_mask
;        lbne  LaunchGame
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase5Live
;
;
;* ---------------------------------------------------------------------------
;* PHASE 6 : Starts "Push button" animation, Wait, and check for fire button
;* ---------------------------------------------------------------------------
;
;Phase6Init
;
;        jsr   LoadObject_x		; Animation for PUSH LIVE BUTTON
;        stx   addr_pushbutton
;        lda   #ObjID_push_button
;        sta   id,x
;	ldd   #110
;	std   x_pos,x
;	ldd   #62
;	std   y_pos,x
;
;
;        ldx   #$100
;        stx   @phase6counter
;Phase6Live
;        ldx   #0
;@phase6counter equ *-2
;        beq   Phase7Init   
;        leax  -1,x
;        stx   @phase6counter
;
;        ; press fire
;        lda   Fire_Press
;        anda  #c1_button_A_mask
;        lbne  LaunchGame
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase6Live
;
;* ---------------------------------------------------------------------------
;* PHASE 7 : Deactivate PUSH BUTTON and LOGO and run a couple of frames
;* ---------------------------------------------------------------------------
;
;Phase7Init
;
;        _MountObject ObjID_logo
;        lda   #$39
;        sta   ,x                        ; Reset the start of the LOGO object to RTS
;
;        _MountObject ObjID_push_button
;        lda   #$39
;        sta   ,x                        ; Reset the start of the PUSH BUTTON object to RTS
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;
;
;
;* ---------------------------------------------------------------------------
;* PHASE 8 : Display scores
;* ---------------------------------------------------------------------------
;
;Phase8Init
;
;        jsr   WaitVBL
;        ldx   #0
;        jsr   ClearDataMem
;        jsr   WaitVBL
;        ldx   #0
;        jsr   ClearDataMem
;
;        ldd   #Pal_scores
;        std   Pal_current
;        clr   PalRefresh
;        jsr   PalUpdateNow
;
;        ldx   addr_text
;        clr   routine,x
;        lda   #2                        ; = Scores
;        sta   subtype,x
;        _MountObject ObjID_text
;        lda   #$12
;        sta   ,x                        ; Reset the start of the TEXT object to NOP
;
;        ldx   #$50
;        stx   @phase8counter
;Phase8Live
;        ldx   #0
;@phase8counter equ *-2
;        beq   Phase9Init   
;        leax  -1,x
;        stx   @phase8counter
;
;        ; press fire
;        lda   Fire_Press
;        anda  #c1_button_A_mask
;        lbne  LaunchGame
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase8Live
;
;* ---------------------------------------------------------------------------
;* PHASE 9 : Display logo and text (high speed)
;* ---------------------------------------------------------------------------
;
;Phase9Init
;        jsr   WaitVBL
;        ldx   #0
;        jsr   ClearDataMem
;        jsr   WaitVBL
;        ldx   #0
;        jsr   ClearDataMem
;
;        ldd   #Pal_game
;        std   Pal_current
;        clr   PalRefresh
;        jsr   PalUpdateNow
;
;
;	ldu   #addr_scores   
;        ldx   ,u++
;        lda   #$80
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$81
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$82
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$83
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$84
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$85
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$86
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$87
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$88
;	sta   subtype,x
;        ldx   ,u++
;        lda   #$89
;	sta   subtype,x
;
;        ldx   addr_text
;        clr   routine,x
;        lda   #1                        ; = Text fast
;        sta   subtype,x
;
;        _MountObject ObjID_logo
;        lda   #$A6
;        sta   ,x                        ; Reset the start of the LOGO object to LDA routine,u
;
;        _MountObject ObjID_push_button
;        lda   #$A6
;        sta   ,x                        ; Reset the start of the PUSH BUTTON object to LDA routine,u
;
;        ldx   #$100
;        stx   @phase9counter
;Phase9Live
;        ldx   #0
;@phase9counter equ *-2
;        lbeq  Phase7Init   
;        leax  -1,x
;        stx   @phase9counter
;
;        ; press fire
;        lda   Fire_Press
;        anda  #c1_button_A_mask
;        lbne  LaunchGame
;
;        jsr   WaitVBL
;        jsr   ReadJoypads
;        jsr   RunObjects
;        jsr   CheckSpritesRefresh
;        jsr   EraseSprites
;        jsr   UnsetDisplayPriority
;        jsr   DrawSprites
;        jmp   Phase9Live
;
;
;
;* ---------------------------------------------------------------------------
;* Launch Level 1
;* ---------------------------------------------------------------------------
;LaunchGame
;        ldd   #Pal_black
;        std   Pal_current
;        clr   PalRefresh
;        jsr   PalUpdateNow
;
;        jsr   irq.off                    
;        jsr   resetsn
        jsr   ym2413.reset
;        lda   #GmID_level01
;        sta   NEXT_GAME_MODE
;        lda   #GmID_title
;        sta   GameMode
;        jsr   LoadGameModeNow
;
;
;addr_logo	    fill 0,2*6
;addr_scores     fill 0,2*10
;addr_tm         fdb 0
;
;addr_pushbutton fdb 0
;addr_text       fdb 0
;
;logo_startx	fdb 150
;		fdb 146
;		fdb 150
;		fdb 150
;		fdb 150
;		fdb 149
;
;logo_xvel	fdb 0
;		fdb 84
;		fdb 132
;		fdb 216
;		fdb 300
;		fdb 384
;
;logo_finalpos	fdb 32
;		fdb 50
;		fdb 67
;		fdb 90
;		fdb 112
;		fdb 134
;
;
;* ---------------------------------------------------------------------------
;* MUSIC - RESET SN
;* ---------------------------------------------------------------------------
;
;resetsn
;        lda   #$9F
;        sta   SN76489.D
;        nop
;        nop
;        lda   #$BF
;        sta   SN76489.D  
;        nop
;        nop
;        lda   #$DF
;        sta   SN76489.D
;        nop
;        nop
;        lda   #$FF
;        sta   SN76489.D  
;        rts
;
;
;* ---------------------------------------------------------------------------
;* MAIN IRQ
;* ---------------------------------------------------------------------------

UserIRQ
	    jsr   palette.update
        _MountObject ObjID_ymm00
        jsr   ymm.frame.play
;        _MountObject ObjID_vgc00
;        _MusicFrame_objvgc
        rts


; ------------------------------------------------------------------------------
; Game Mode RAM variables
; ------------------------------------------------------------------------------

; Object Constants
; ----------------
nb_dynamic_objects           equ 19
nb_graphical_objects         equ 64 ; max 64 total
ext_variables_size           equ 20 ; ext_variables_size is for dynamic objects

; Object Status Table - OST
; ----------------
;palettefade                  fcb   ObjID_fade
;                             fill  0,10-1
Dynamic_Object_RAM           fill  0,(nb_dynamic_objects)*object_size
Dynamic_Object_RAM_End

; ------------------------------------------------------------------------------
; ENGINE routines
; ------------------------------------------------------------------------------

;        ; common utilities
;        INCLUDE "./engine/ram/BankSwitch.asm"
;        INCLUDE "./engine/graphics/vbl/WaitVBL.asm"
;        INCLUDE "./engine/ram/ClearDataMemory.asm"
;
;        ; joystick
;        INCLUDE "./engine/joypad/InitJoypads.asm"
;        INCLUDE "./engine/joypad/ReadJoypads.asm"
;
;        ; object management
;        INCLUDE "./engine/object-management/RunObjects.asm"
;        INCLUDE "./engine/object-management/ObjectMove.asm"
;        INCLUDE "./engine/object-management/ObjectMoveSync.asm"
;        INCLUDE "./engine/object-management/ObjectDp.asm"
;
;        ; animation & image
;        INCLUDE "./engine/graphics/animation/AnimateSpriteSync.asm"
;        #INCLUDE "./engine/graphics/animation/moveByScript.asm"
;
;        ; sprite
;        INCLUDE "./engine/graphics/sprite/sprite-background-erase-ext-pack.asm"  
;
;        INCLUDE "./engine/level-management/LoadGameMode.asm"

; TODO - new engine solution for obj indexes
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

; engine.object.sound.ymm
; assets.obj.snd.title.ymm

ObjID_ymm00 equ 1

Obj_Index_Page
        fcb   0
        fcb   $60+6

Obj_Index_Address
        fdb   $0000
        fdb   $0000

 ENDSECTION

        INCLUDE "new-engine/global/glb.init.asm"
        INCLUDE "new-engine/system/to8/irq/irq.asm"
        INCLUDE "new-engine/system/to8/palette/palette.update.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.asm"
        INCLUDE "new-engine/sound/ym2413.asm"
        ;INCLUDE "new-engine/sound/sn76489.asm"
