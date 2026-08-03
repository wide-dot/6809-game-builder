;*******************************************************************************
; Le joueur — unite paginee : code, scripts d'animation et images
;
; C'est un OBJET, avec un etat : il a un OST, et cet OST vit en PAGE DIRECTE
; (player1 equ dp), pas dans le pool — il tourne a chaque trame et ses champs
; sont lus sans arret. Le stage le lance par _Obj_RunU, donc Obj_Run monte sa
; page depuis l'index d'objets.
;
; Ses scripts d'animation vivent ici et non dans l'objet d'animation commun :
; AnimateSpriteSync monte la page lue dans Ani_Page_Index[id] avant de
; dereferencer anim,u. L'index du stage designe donc cette page pour les trois
; tables — objet, animation et images.
;
; Le point d'entree doit etre le PREMIER octet : Obj_Run saute a l'adresse que
; l'index d'objets lui donne. Le code d'abord, les donnees ensuite.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

Player            EXPORT

; L'etat de la boucle vit dans le stage : le joueur y ecrit DEAD a la fin de
; son explosion, la boucle bascule sur sa routine de mort.
mainloop.state    EXTERNAL

; Ce que le joueur emprunte au moteur resident : la liste unique du contrat.
        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"
        INCLUDE "engine/objects/palette/fade/fade.equ"
        ; L'etat d'armement, en BOUCHON : la chaine de tir n'est pas portee.
        INCLUDE "src/common/player/pending.stub.asm"
        INCLUDE "src/common/player/emitter-flash.equ"
        ; Les identifiants d'objets sont des CONSTANTES combinees par decalage,
        ; qu'aucune relocation ne sait faire — comme pour les ennemis.
        INCLUDE "src/stages/01/objid.const.asm"

        INCLUDE "src/common/player/player1.asm"
        INCLUDE "src/common/player/animation.asm"

 ENDSECTION
