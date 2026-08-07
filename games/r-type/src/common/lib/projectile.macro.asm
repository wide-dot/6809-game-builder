* Garde d'inclusion : un membre de pageset porte plusieurs units qui
* incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
* fois — c'est vrai independamment du pageset.
 IFNDEF PROJECTILE_MACRO
PROJECTILE_MACRO equ 1

_loadFirePreset MACRO
        lda   Obj_Index_Page+ObjID_loadFirePreset
        sta   PSR_Page   
        ldx   Obj_Index_Address+2*ObjID_loadFirePreset
        stx   PSR_Address   
        lda   #0                       
        sta   PSR_Param
        jsr   RunPgSubRoutine
 ENDM    

_loadFirePresetBug MACRO
        lda   Obj_Index_Page+ObjID_loadFirePreset
        sta   PSR_Page   
        ldy   Obj_Index_Address+2*ObjID_loadFirePreset
        sty   PSR_Address                  
        lda   #2              
        sta   PSR_Param
        jsr   RunPgSubRoutine
 ENDM    

 ENDC
