* Garde d'inclusion : un membre de pageset porte plusieurs units qui
* incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
* fois — c'est vrai independamment du pageset.
 IFNDEF ENGINE_MACROS
ENGINE_MACROS equ 1

_ldd MACRO
        ldd   #((\1)*256)+\2
 ENDM
 
_ldx MACRO
        ldx   #((\1)*256)+\2
 ENDM
 
_ldy MACRO
        ldy   #((\1)*256)+\2
 ENDM
 
_ldu MACRO
        ldu   #((\1)*256)+\2
 ENDM  
 
_lds MACRO
        lds   #((\1)*256)+\2
 ENDM   
 
_SetCartPageA MACRO
 IFDEF T2
        jsr   SetCartPageA
 ELSE
        sta   $E7E6                    ; selection de la page RAM en zone cartouche
 ENDC
 ENDM      
 
_GetCartPageA MACRO
 IFDEF T2
        jsr   GetCartPageA
 ELSE
        lda   $E7E6
 ENDC
 ENDM

_SetCartPageB MACRO
 IFDEF T2
        jsr   SetCartPageB
 ELSE
        stb   $E7E6                    ; selection de la page RAM en zone cartouche
 ENDC
 ENDM      
 
_GetCartPageB MACRO
 IFDEF T2
        jsr   GetCartPageB
 ELSE
        ldb   $E7E6
 ENDC
 ENDM     

_RunObjectSwap MACRO
        ; param 1 : ObjID_
        ; param 2 : Object data RAM address
        ; manual launch of an object from a different dynamic memory page and not from the resident page 1
        lda   Obj_Index_Page+\1
        sta   PSR_Page   
        ldd   Obj_Index_Address+2*\1
        std   PSR_Address       
        ldu   \2             
        jsr   RunPgSubRoutine
 ENDM    

_RunObjectSwapRoutine MACRO
        ; param 1 : ObjID_
        ; param 2 : Object routine
        ; manual launch of an object from a different dynamic memory page and not from the resident page 1
        lda   Obj_Index_Page+\1   
        sta   PSR_Page   
        ldd   Obj_Index_Address+2*\1
        std   PSR_Address       
        ldb   \2        
        jsr   RunPgSubRoutine
 ENDM 
 
_MountObject MACRO 
        ; param 1 : ObjID_
        ; manual mount of an object from the resident page 1
        lda   Obj_Index_Page+\1
        _SetCartPageA
        ldx   Obj_Index_Address+2*\1
 ENDM

_RunObject MACRO 
        ; param 1 : ObjID_
        ; param 2 : Object data RAM address
        ; manual launch of an object from the resident page 1
        _MountObject \1
        ldu   \2        
        jsr   ,x
 ENDM

_RunObjectRoutineA MACRO 
        ; param 1 : ObjID_
        ; param 2 : Object routine
        ; manual launch of an object from the resident page 1
	; this object does not need or have a data structure for this routine
        _MountObject \1
        lda   \2        
        jsr   ,x
 ENDM

_RunObjectRoutineB MACRO 
        ; param 1 : ObjID_
        ; param 2 : Object routine
        ; manual launch of an object from the resident page 1
	; this object does not need or have a data structure for this routine
        _MountObject \1
        ldb   \2        
        jsr   ,x
 ENDM

_SwitchScreenBuffer MACRO
        ldb   $E7E5
        eorb  #1                       ; switch btw page 2 and 3
        orb   #$02
        stb   $E7E5
 ENDM

_asld MACRO
        aslb
        rola
 ENDM        
 
_asrd MACRO
        asra
        rorb
 ENDM      
 
_lsld MACRO
        lslb
        rola
 ENDM        
 
_lsrd MACRO
        lsra
        rorb
 ENDM
 
_rold MACRO
        rolb
        rola
 ENDM    
 
_rord MACRO
        rora
        rorb
 ENDM

_negd MACRO
        nega
        negb
        sbca  #0
 ENDM

_cba MACRO
        pshs  b
        cmpa  ,s+
 ENDM

_aba MACRO
        pshs  b
        adda  ,s+
 ENDM

_sba MACRO
        pshs  b
        suba  ,s+
 ENDM

_cab MACRO
        pshs  a
        cmpb  ,s+
 ENDM

_aab MACRO
        pshs  a
        addb  ,s+
 ENDM

_sab MACRO
        pshs  a
        subb  ,s+
 ENDM

_breakpoint MACRO
 IFDEF DEBUG
        pshs  CC
        sta   >$ffff
        puls  CC
 ENDC
 ENDM

_waitFrames MACRO
       lda   \1
@l1    tst   $E7E7 ; beam is not in the screen
       bpl   @l1   ; until the bit is 0 loop
@l2    tst   $E7E7 ; beam is in the screen
       bmi   @l2   ; until the bit is 1 loop
       deca
       bne   @l1
 ENDM
 


* ---------------------------------------------------------------------------
* _sprite.cull — le containment d'un sprite blitte en direct
* ---------------------------------------------------------------------------
* CheckSpritesRefresh (et son jumeau overlay BuildSprites) refuse de dessiner
* un sprite qui n'est pas ENTIEREMENT a l'ecran : il teste les DEUX bords sur
* les DEUX axes. Un manager qui blitte lui-meme n'en beneficie pas — sa
* boite-proxy est garee au centre de l'ecran expres, pour que BuildSprites
* l'appelle toujours — donc il doit refaire ce test, sprite par sprite.
*
* L'oublier ne fait pas qu'afficher de travers : une pose qui deborde par le
* HAUT ecrit sous $A000, sur la queue de la page directe ou vivent les
* globales de camera. C'est ainsi que le vaisseau disparaissait au stage 1.
*
* La geometrie vient de l'imageset pointe par X — les valeurs generees, donc
* justes par construction et incapables de deriver avec l'art.
*
* La convention est fixe et non parametrable : lwasm ne sait pas passer un
* operande contenant une virgule a une macro, donc x et y se lisent sur la
* PILE, la ou trois des quatre managers les mettaient deja.
*
* entree : X = l'imageset, et `pshs a,b` fait par l'appelant avec A = x ecran
*          et B = y ecran (donc x en ,s et y en 1,s — la pile reste a lui)
* sortie : \1 si le sprite n'est pas entierement dedans ; A ecrase, la pile
*          intacte dans les deux cas
* ---------------------------------------------------------------------------
_sprite.cull MACRO
        lda   ,s
        adda  imgset.x1,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   \1
        adda  imgset.xsize,x
        cmpa  #screen_right-screen_left+1
        bhi   \1
        lda   1,s
        adda  imgset.y1,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   \1
        adda  imgset.ysize,x
        cmpa  #screen_bottom-screen_top+1
        bhi   \1
 ENDM

 ENDC
