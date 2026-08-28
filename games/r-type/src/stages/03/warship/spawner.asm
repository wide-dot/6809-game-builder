;*******************************************************************************
; LE PARCOURS DU SCRIPT DE SPAWN (warship_scrolling_spawner, 40:c61f)
;
; Une entree echoit quand la COURSE DE LA COUCHE atteint son seuil — l'arcade
; compare a `-warship.X`, la distance parcourue vers la gauche ; chez nous
; c'est mscroll.camera.x, qui va de 0 a 285 et couvre les seuils 6..240.
; Le curseur n'avance QUE : les entrees sont triees par seuil, et une fois
; franchie une entree ne revient pas.
;
; Une entree dont l'identifiant est NUL n'est pas encore portee : on la saute
; sans rien allouer. C'est ce qui rend la campagne livrable par tranches.
;
; LE PARCOURS VIT AVEC SES DONNEES, dans ce direntry paginé : l'unite du stage
; est en page residente et n'avait plus la place (elle debordait sur le bloc
; du banc). L'appelant monte la page et saute ici ; U reste son OST, ou vit le
; curseur. LoadObject_x ne touche pas a la fenetre cartouche — c'est ce qui
; permet de revenir ici apres l'allocation.
; Doc : doc/warship-parts-plan.md
;*******************************************************************************
warship.spawn   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"

mscroll.camera.x EXTERNAL

; l'etat du pilote que ce parcours touche — meme rang que dans pilot.asm
pilot.spawn    equ ext_variables+8
warship.BASEY  equ 117
warship.spawn
        ldx   pilot.spawn,u
        bne   >                        ; premier appel : armer le curseur ici,
        ldx   #warship.spawn.script    ; ou l'etiquette est locale
!
@loop   ldd   ,x
        cmpd  #-1
        beq   @done                    ; sentinelle : le script est fini
        cmpd  mscroll.camera.x
        bhi   @done                    ; seuil pas encore atteint — et les
                                       ; suivants non plus, la table est triee
        ldb   6,x
        beq   @next                    ; piece pas encore portee
        ; les champs de l'entree passent par la pile : l'allocation remonte
        ; une autre page et le curseur ne serait plus lisible
        ldd   6,x
        pshs  d                        ; 6,s identifiant + sous-type
        ldd   4,x
        pshs  d                        ; 4,s dy
        ldd   2,x
        pshs  d                        ; 2,s x ecran de naissance
        pshs  x                        ;  ,s le curseur
        jsr   LoadObject_x
        beq   @plein
        lda   6,s
        sta   id,x
        lda   7,s
        sta   subtype,x
        clr   routine,x
        ldd   2,s
        addd  glb_camera_x_pos         ; l'ecran devient du monde
        std   x_pos,x
        clr   x_pos+2,x
        ldd   4,s
        addd  #warship.BASEY           ; l'ancre du maitre + l'ecart de l'entree
        std   y_pos,x
        clr   y_pos+2,x
@plein  puls  x                        ; le curseur revient
        leas  6,s
@next   leax  8,x
        bra   @loop
@done   stx   pilot.spawn,u
        rts

; La table elle-meme, a la suite : le parcours et ses donnees dans le meme
; direntry, une seule page a monter.
warship.spawn.script
        INCLUDE "src/stages/03/warship/spawn-script.asm"

 ENDSECTION
