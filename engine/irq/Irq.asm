
* ---------------------------------------------------------------------------
* IRQ Manager
* ---------------------------------------------------------------------------
*
* IrqSet50Hz
* -----------------------------------
* input REG : [none]
* reset REG : [d]
*
* IrqOn
* -----------------------------------
* reset REG : [a]
*
* IrqOff
* -----------------------------------
* reset REG : [a]
*
* IrqSync
* -----------------------------------
* This routine sync irq timer with a desired screen line refresh
* The timer (irq duration) is an input parameter (usually Irq_one_frame)
* input REG : [a] screen line (0-255)
*             [x] timer value
* reset REG : [d]
* feature request - implement a screen line range of 0-311
*
* IrqManager (irq call)
* -----------------------------------
* This routine run all requested engine code before and after the user irq
* routine (in Irq_user_routine)
* input REG : [dp] $E7 (set by the monitor)
* reset REG : [none]
*
* Special mode (glb_Page==0) is when page switching does not need to test
* if RAM or ROM is in use. In this case RAM is always expected as page type.
* This allows the use of <$E6 register without calling engine macro for
* page switch, thus it reduces the cycles cost. Used in tile rendering.
*
* Example of user routines (may be grouped in a subroutine) :
* - PalUpdateNow
* - PalCycling
* - PalRaster_1c
* - MusicFrame
* - PSGFrame
* - IrqObjSmps
* - IrqTimer
*
* ---------------------------------------------------------------------------

Irq_user_routine fdb 0                 ; user irq routine called by IrqManager
; V2-DEVIATION: Irq_one_frame et Irq_one_line sont definis dans
; engine/constants.asm. Ce sont des CONSTANTES ABSOLUES, pas des adresses : une
; unite paginee qui arme l'IRQ doit les voir a l'assemblage. Les faire passer
; par la frontiere de lien les fait rebaser ($4DFF -> $AEFF, soit une periode
; d'IRQ 2,24 fois trop longue).
; Cas de migration : docs/lang/en/migration/equates-link-boundary.md
       
IrqInit
        ldd   #IrqManager
        std   TIMERPT
	rts

IrqSet50Hz
        ldb   #$42
        stb   MC6846.TCR               ; timer precision x8
        ldd   #Irq_one_frame           ; on every frame
        std   MC6846.TMSB
        jsr   IrqOn   
        rts
       
IrqOn         
        lda   $6019                           
        ora   #$20
        sta   $6019                    ; STATUS register
        andcc #$EF                     ; tell 6809 to activate irq
        rts
        
IrqOff 
        lda   $6019                           
        anda  #$DF
        sta   $6019                    ; STATUS register
        orcc  #$10                     ; tell 6809 to inactivate irq
        rts

IrqPause
        pshs  a
        lda   $6019
        anda  #$20
        bne   @irqoff
        lda   #0
        sta   @irqst
        bra   >
@irqoff lda   #1
        sta   @irqst
        jsr   IrqOff
!       puls  a,pc
IrqUnpause
        pshs  a
        lda   #0
@irqst  equ   *-1
        beq   >
        jsr   IrqOn
!       clr   @irqst
        puls  a,pc

IrqSync 
        ldb   #$42
        stb   MC6846.TCR
        
        ldb   #8                       ; ligne * 64 (cycles per line) / 8 (nb tempo loop cycles)
        mul
        tfr   d,y
        leay  -32,y                    ; manual adjustment
!
        tst   $E7E7                    ;
        bmi   <                        ; while spot is in a visible screen line        
!       tst   $E7E7                    ;
        bpl   <                        ; while spot is not in a visible screen line
!       leay  -1,y                     ;
        bne   <                        ; wait until desired line
       
        stx   MC6846.TMSB              ; spot is at the end of desired line
        rts  

        ;setdp $E7 ; V2-DEVIATION: setdp neutralized (not permitted in lwasm obj target ; runtime DP is untouched, implicit-direct operands assemble extended)
IrqManager
        sts   @stack                   ; backup system stack
        lds   #Irq_sys_stack           ; set tmp system stack for IRQ 
        inc   gfxlock.frame.count+1
        bne   >
        inc   gfxlock.frame.count
!
        tst   glb_Page                 ; test special mode (glb_Page==0)
        beq   @smode                   ; branch if rendering tiles - force RAM use instead of testing ROM or RAM
        _GetCartPageB
        stb   @page                    ; backup data page normally
 IFDEF OverlayMode
        ; OVERLAY : la demi-page $4000-$5FFF n'est pas forcement sur l'OST (0)
        ; quand l'IRQ tombe — le mainline peut etre EN TRAIN de tourner sur la
        ; 1 (ex. pscroll.half.on, le temps d'un jsr). Irq_user_routine
        ; (PalUpdateNow, le son) a besoin de l'OST : on n'a pas a SAVOIR
        ; quelle moitie etait montee, on la LIT et on la remet EXACTEMENT —
        ; meme principe que _GetCartPageB/_SetCartPageA juste au-dessus,
        ; jamais un toggle relatif (voir docs/lang/en/migration/
        ; relative-toggles-on-shared-registers.md : un E7C3 stale corrompt un
        ; toggle, pas un backup/restore absolu).
        lda   map.HALFPAGE
        anda  #%00000001
        sta   @half                    ; 0 ou 1 : la demi-page EXACTE en cours
        lda   map.HALFPAGE
        anda  #%11111110
        sta   map.HALFPAGE                ; demi-page 0 : l'OST, pour la duree de l'IRQ
 ENDC
        jsr   [Irq_user_routine]
 IFDEF OverlayMode
        lda   map.HALFPAGE                ; RELU, pas rejoue : les bits 1-7 sont
        anda  #%11111110                ; de l'I/O vivante (timer, clavier,
        ora   #0                        ; (dynamic) disque)
@half   equ   *-1
        sta   map.HALFPAGE
 ENDC
        lda   #0                       ; (dynamic)
@page   equ   *-1
        _SetCartPageA                  ; restore data page
@end    lds   #0                       ; (dynamic) restore system stack
@stack  equ   *-2
        jmp   $E830                    ; return to caller
@smode
        ldb   <$E6
        stb   @page2                   ; backup data page
 IFDEF OverlayMode
        lda   map.HALFPAGE
        anda  #%00000001
        sta   @half2
        lda   map.HALFPAGE
        anda  #%11111110
        sta   map.HALFPAGE
 ENDC
        jsr   [Irq_user_routine]
 IFDEF OverlayMode
        pshs  a                        ; @smode reutilise A pour glb_Page :
        lda   map.HALFPAGE                ; ne pas lui voler avant d'avoir lu
        anda  #%11111110
        ora   #0                        ; (dynamic)
@half2  equ   *-1
        sta   map.HALFPAGE
        puls  a
 ENDC
        anda  #0
        sta   glb_Page                 ; restore special page mode
        lda   #0                       ; (dynamic)
@page2  equ   *-1
        sta   <$E6                     ; restore data page
        bra   @end

; This space allow the use of system stack inside IRQ calls
; otherwise the writes in sys stack will erase data when S is in use
; (outside of IRQ) for another task than sys stack, ex: stack blast copy 
        fill  0,32
Irq_sys_stack

        ;setdp dp/256 ; V2-DEVIATION: setdp neutralized (not permitted in lwasm obj target ; runtime DP is untouched, implicit-direct operands assemble extended)