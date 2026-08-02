;*******************************************************************************
; Le champ d'etoiles — unite paginee, trois routines sans point d'entree unique
;
; Ce n'est PAS un objet. Les etoiles n'ont pas d'etat par entite (leurs adresses
; VRAM sont precalculees dans stardata.asm), il n'y a pas d'OST, et rien dans la
; vague ne le nomme : ses trois routines sont donc des symboles de lien que le
; stage vise directement par paged.call. La v1 devait passer par un ObjID et une
; commande dans B faute d'autre moyen d'atteindre du code paginé.
;
; L'unite partage la page des overlays avec le masque : une seule montee de page
; couvre toute la phase de dessin.
;*******************************************************************************

; Ce que l'unite emprunte au moteur resident. glb_camera_x_pos, lui, est une
; equate absolue de engine/constants.asm : il ne franchit pas le lien.
gfxlock.backBuffer.id   EXTERNAL
gfxlock.frameDrop.count EXTERNAL

starfield.init   EXPORT
starfield.erase  EXPORT
starfield.draw   EXPORT

 SECTION code

        INCLUDE "src/common/fx/starfield/ram.data.asm"
        INCLUDE "src/common/fx/starfield/obj.asm"

starfield.init   equ StarfieldInit
starfield.erase  equ StarfieldErase
starfield.draw   equ StarfieldDraw

 ENDSECTION
