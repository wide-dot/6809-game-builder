;*******************************************************************************
; text — l'objet machine à écrire du title, porté de la v1
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs. Elle est
; paginée dans l'arène title : RunObjects lit sa page dans l'index du title,
; la monte, puis saute à l'entrée.
;
; L'objet dessine ses lettres EN ABSOLU dans la fenêtre données ($C0F0+...) :
; au moment où RunObjects le fait tourner, _gfxlock.on a monté le tampon de
; TRAVAIL — et comme LiveSlow/LiveFast redessinent TOUT le texte à chaque
; trame (une lettre de plus par trame), les deux tampons convergent : le
; dessin direct est compatible double-tampon par construction.
;
; Son entrée est AUTO-MODIFIÉE par le main (l'idiome v1) : $12 (nop) actif,
; $39 (rts) éteint — et l'objet s'éteint LUI-MÊME à la fin de sa frappe,
; c'est le témoin de fin de phase que le main lit.
;*******************************************************************************

title.text.Object EXPORT

; LE TABLEAU DES SCORES EST VIVANT : sa table et la conversion de ses chiffres
; vivent dans l'unite RESIDENTE de classement, ecrite par la fin de partie.
; L'attract du title n'a donc plus sa copie en dur.
ranking.table    EXTERNAL
ranking.digits7  EXTERNAL
ranking.dig      EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"

title.text.Object
        INCLUDE "src/title/text/text.asm"

 ENDSECTION
