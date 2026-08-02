;*******************************************************************************
; The tables the engine reads back from the loaded stage
;
; Lane 3 of the stage boundary, and the whole exchange mechanism in five lines.
; The engine holds EXTERNAL references to these names ; each stage exports its
; own ; and scene.load re-links every loaded file, so the moment stage 2 lands
; the engine's `ldx #Obj_Index_Page` points at stage 2's table. There is no
; vtable, no convention address, nothing to register at run time.
;
; The boundary analysis counted five such tables in r-type level 1. The two
; below are the ones this stage of the port exercises — the object index that
; RunObjects and the wave spawner walk. The three imageset and animation
; indexes are the same extern16 shape and join when sprite drawing does.
;*******************************************************************************

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; Les deux tables d'animation, indexees par l'identifiant d'objet comme les
; precedentes : la page ou vivent les scripts d'un objet, et le debut de sa
; table de scripts. AnimateSprite les lit a chaque trame.
Ani_Page_Index    EXTERNAL
Ani_Asd_Index     EXTERNAL

; Et la page ou vivent les images d'un objet, que CheckSpritesRefresh monte
; avant de lire la geometrie d'un sprite. Les cinq tables de l'analyse sont
; donc toutes en place.
Img_Page_Index    EXTERNAL
