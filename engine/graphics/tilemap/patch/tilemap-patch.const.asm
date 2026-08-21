* ---------------------------------------------------------------------------
* tilemap.patch — la disposition des donnees, partagee
* ---------------------------------------------------------------------------
* Le descripteur est emis par <tilepatch> et l'etat est porte par l'appelant,
* qui vit dans un AUTRE direntry que le moteur : ces equates doivent donc etre
* incluses des deux cotes. Les equates ne franchissent pas une frontiere de
* direntry — seuls les symboles le font, et au prix d'une donnee de lien.
*
* Garde d'inclusion : le moteur et le consommateur peuvent tous deux
* l'inclure, directement ou par un en-tete commun.
* ---------------------------------------------------------------------------
 IFNDEF TILEMAP_PATCH_CONST
TILEMAP_PATCH_CONST equ 1

; dans le descripteur
tilemap.desc.cols       equ   0
tilemap.desc.rows       equ   1
tilemap.desc.frames     equ   2
tilemap.desc.col        equ   3
tilemap.desc.row        equ   4
tilemap.desc.hold       equ   5
tilemap.desc.table      equ   6
tilemap.desc.SIZE       equ   8

; dans l'etat
tilemap.anim.descEven   equ   0        ; descripteur du plan pair
tilemap.anim.descOdd    equ   2        ; descripteur du plan impair, 0 si aucun
tilemap.anim.frame      equ   4        ; image courante
tilemap.anim.timer      equ   5        ; maintien restant, en trames video
tilemap.anim.dir        equ   6        ; 0 en avant, non nul en arriere
tilemap.anim.flags      equ   7
tilemap.anim.SIZE       equ   8

tilemap.anim.DONE       equ   %00000001

 ENDC
