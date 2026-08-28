;*******************************************************************************
; LES DEUX GROUPES DE PIECES DU VAISSEAU — un identifiant pour plusieurs objets
;
; POURQUOI. Un identifiant d'objet coute SEPT octets : une ligne dans chacune
; des cinq tables d'index (1 + 2 + 1 + 2 + 1). Ces tables vivent dans l'unite
; RESIDENTE du stage, qui est petite et pleine — dix pieces de plus, c'est
; soixante-dix octets, et le stage deborde sur le bloc du banc.
;
; CE QUI FORCE VRAIMENT UN IDENTIFIANT, ce n'est pas le code : c'est
; Img_Page_Index, qui n'en donne qu'UNE PAGE D'IMAGES par identifiant. Deux
; objets dont les images sont dans le meme direntry peuvent donc partager le
; leur — il suffit d'un aiguilleur qui lise leur famille et saute au bon code.
;
; D'ou les deux groupes, calques sur les deux direntries d'images :
;   fire.Object   -> la tourelle multiple, la boule de feu, l'eclat de bouche
;   react.Object  -> les deux reacteurs, leurs enfants, la capsule et ses amis
; Les trois gerbes des reacteurs de ventre gardent chacune la leur : leurs
; trente poses ne tiennent pas dans une page, et c'est bien la page qui
; commande.
;
; LA FAMILLE VIT DANS `subtype`, et c'est pour cela que les objets groupes
; rangent AILLEURS ce qu'ils y mettaient (l'orientation d'un reacteur de
; ventre, le montage d'une multiple, la pose d'une boule) : le champ est
; desormais pris.
;*******************************************************************************

        INCLUDE "src/enemies/warship-elements/families.equ"

fire.Object
        lda   subtype,u
        anda  #3
        asla
        ldx   #fire.Families
        jmp   [a,x]
fire.Families
        fdb   multi.Object
        fdb   fireball.Object
        fdb   muzzle.Object
        fdb   muzzle.Object

react.Object
        lda   subtype,u
        anda  #7
        asla
        ldx   #react.Families
        jmp   [a,x]
react.Families
        fdb   rreactor.Object
        fdb   rflame.Object
        fdb   wbullet.Object
        fdb   breactor.Object
        fdb   capsule.Object
        fdb   claser.Object
        fdb   detach.Object          ; 6 : la petite capsule
        fdb   detach.Object          ; 7 : le triangle
