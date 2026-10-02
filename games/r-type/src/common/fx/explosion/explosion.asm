;*******************************************************************************
; L'explosion — l'objet que tout ce qui meurt fait naître
;
; Un ennemi détruit, un tir qui percute, le boss qui se désagrège : tous
; chargent un objet du pool, lui posent `ObjID_explosion` et un subtype, et
; l'explosion se déroule seule puis se supprime. Elle n'a pas de boîte de
; collision — elle ne fait plus rien qu'afficher.
;
; L'unité est paginée comme un ennemi : RunObjects lit sa page dans l'index
; d'objets du stage, la monte, puis saute à `explosion.Object`. Ses images
; vivent dans le même direntry, donc l'index d'imageset les atteint par la
; page de celui-ci.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite — d'où l'ordre des includes.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

explosion.Object  EXPORT

; ce que l'explosion appelle chez le moteur résident
        INCLUDE "src/common/engine/api.asm"


 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        ; Le bruitage : le macro ecrit la boite aux lettres residente, que le
        ; pilote depile dans l'IRQ. Les constantes de son sont partagees a
        ; l'assemblage, la boite aux lettres traverse le lien.
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"

; V2-DEVIATION: la v1 nommait ses entrées d'imageset Img_<nom>, gfxcomp les
; génère en set_<nom>. Les trois autres objets portés ont renommé leurs
; références dans le code ; ici les tables d'animation citent ces noms
; quarante-six fois, et obj.asm en dérive lui-même trois alias sous IFNDEF t2.
; Une table de liaison en tête coûte treize lignes et laisse obj.asm au 1:1 —
; c'est exactement le rôle que jouait le fichier d'imageset généré de la v1.
;
; Ce qui est déclaré ici est ce que la cible DISQUETTE compile
; (objects/explosion/obj.d7.properties) : une image sur deux manque, et le
; bloc IFNDEF t2 d'obj.asm rattache les manquantes à la suivante.
Img_expSmall_0 equ set_expSmall_0
Img_expSmall_1 equ set_expSmall_1
Img_expSmall_3 equ set_expSmall_3
Img_expSmall_5 equ set_expSmall_5

Img_expFwk_0   equ set_expFwk_0
Img_expFwk_1   equ set_expFwk_1
Img_expFwk_3   equ set_expFwk_3
Img_expFwk_5   equ set_expFwk_5

Img_expBig_0   equ set_expBig_0
Img_expBig_1   equ set_expBig_1
Img_expBig_3   equ set_expBig_3
Img_expBig_5   equ set_expBig_5
Img_expBig_7   equ set_expBig_7
        INCLUDE "engine/collision/struct_AABB.equ"

; LE FLASH DE COUP partage l'objet (11/09/2026, doc/inventaire-flash-de-coup
; -2026-09.md) : sous-type a bit 7. L'entree reste le premier octet de l'unite
; et tombe dans le code v1 (obj.asm commence par des equates puis `Onject`).
explosion.Object
        lda   subtype,u
        lbmi  hitflash.Object          ; (obj.asm est long : branchement long)
        INCLUDE "src/common/fx/explosion/obj.asm"

; -----------------------------------------------------------------------------
; hitflash — le manager du flash de coup, greffe sur Collision_OnLoose (engine)
;
; L'arcade echange la palette de tout acteur a PV multiples au coup encaisse
; ([+0x3d] = 5, palette 0x55 une trame sur deux). Notre palette est globale :
; ici UNE trame de blanc, une image par TAILLE DE BOITE (hitflash.Sizes,
; generee par tools/gen_hitflash_manager.py : une ellipse ajustee aux poses de la
; famille, ou la silhouette d'une pose unique), dessinee devant tout, centree
; sur la boite relue AU DESSIN — l'objet est ajoute en queue de liste, il
; tourne apres l'ennemi qui a deja fait son pas de la trame. Une taille
; inconnue (les 27 sous-parties de coque, le noyau qui a son propre flash)
; ne dessine rien.
; -----------------------------------------------------------------------------
hitflash.Object
        lda   routine,u
        bne   hitflash.Delete          ; le rendu suivant : deja vu une fois
        ldx   hitflash.box,u
        ldd   AABB.rx,x                ; D = rx:ry, la cle
        ldy   #hitflash.Sizes
@find   cmpd  ,y
        beq   @found
        leay  4,y
        tst   ,y
        bne   @find
hitflash.Delete
        jmp   DeleteObject             ; taille inconnue : pas de flash
@found  ldd   2,y
        std   image_set,u
        clr   render_flags,u           ; coordonnees ECRAN, celles de la boite
        lda   #1
        sta   priority,u               ; devant tout, comme l'explosion
        inc   routine,u
        lda   AABB.cx,x
        adda  #screen_left
        ldb   AABB.cy,x
        addb  #screen_top
        std   xy_pixel,u
        jmp   DisplaySprite

        INCLUDE "src/common/fx/explosion/hitflash.tables.asm"
 ENDSECTION
