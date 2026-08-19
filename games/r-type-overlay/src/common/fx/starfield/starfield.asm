;*******************************************************************************
; Le champ d'etoiles — unite paginee, quatre routines sans point d'entree unique
;
; Les etoiles n'ont pas d'etat par entite (leurs adresses VRAM sont
; precalculees dans stardata.asm) et il n'y a pas d'OST ici : les routines
; sont des symboles de lien vises par paged.call. Mais depuis le 18/08 la
; WAVE le nomme, comme dans l'arcade : ObjID_starfield est un objet
; ephemere du stage (stage.starfieldSpawner) qui appelle `init` avec le
; variant de l'entree de wave puis rend son slot. La duree de vie, le fondu
; de sortie et le respawn au checkpoint decoulent tous de ce modele —
; l'analyse arcade est annotee dans le Ghidra (starfield_spawner 0x40:E430,
; wave1_starfield_boot/postintro).
;
; init  : Y = variant 0..3 -> naissance, ou prolongation si le champ vit
; kill  : remise a mort, appelee par toute entree de stage (etat persistant)
; erase / draw : les deux passes de la trame, stage 1 seulement pour l'instant
;
; L'unite a son propre direntry depuis le 18/08 (elle partageait celui du
; masque) : la ou l'arene la range est sa page, gen/layout publie l'equate.
;*******************************************************************************

; Ce que l'unite emprunte au moteur resident.
gfxlock.backBuffer.id   EXTERNAL
gfxlock.frameDrop.count EXTERNAL

starfield.init   EXPORT
starfield.kill   EXPORT
starfield.erase  EXPORT
starfield.draw   EXPORT

 SECTION code

        INCLUDE "src/common/fx/starfield/ram.data.asm"
        INCLUDE "src/common/fx/starfield/obj.asm"

starfield.init   equ StarfieldInit
starfield.kill   equ StarfieldKill
starfield.erase  equ StarfieldErase
starfield.draw   equ StarfieldDraw

 ENDSECTION
