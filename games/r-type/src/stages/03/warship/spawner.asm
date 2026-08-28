;*******************************************************************************
; LE PARCOURS DU SCRIPT DE SPAWN (warship_scrolling_spawner, 40:c61f)
;
; Une entree echoit quand la COURSE DU VAISSEAU atteint son seuil — l'arcade
; compare a `-warship.X`, et son maitre nait a X=0 APRES l'autoscroll d'entree
; (~192 px arcade de camera deja consommes) : le seuil se mesure donc DEPUIS
; LA NAISSANCE DU PILOTE, jamais sur la camera absolue. C'est
; `camera.x - pilot.camX0`, qui couvre bien les seuils 6..240.
; L'ordonnee de ponte suit la meme logique : les dy sont des ecarts de COQUE
; relatifs au maitre, qui derive verticalement avec la couche — la derive
; `camera.y - pilot.camY0` (repliee : la couche boucle) s'y soustrait.
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
mscroll.camera.y EXTERNAL

; l'etat du pilote que ce parcours touche — meme rang que dans pilot.asm
pilot.spawn    equ ext_variables+8
pilot.camX0    equ ext_variables+10
pilot.camY0    equ ext_variables+12
warship.BASEY  equ 117
warship.spawn
        ; la course et la derive du tour, relatives a la naissance du pilote
        ldd   mscroll.camera.x
        subd  pilot.camX0,u
        std   warship.travel
        ldd   mscroll.camera.y
        subd  pilot.camY0,u
        cmpd  #192                     ; la couche boucle sur 384 : replier
        blt   @d1
        subd  #384
        bra   @d2
@d1     cmpd  #-192
        bge   @d2
        addd  #384
@d2     std   warship.drift
        ldx   pilot.spawn,u
        bne   >                        ; premier appel : armer le curseur ici,
        ldx   #warship.spawn.script    ; ou l'etiquette est locale
!
@loop   ldd   ,x
        cmpd  #-1
        beq   @done                    ; sentinelle : le script est fini
        cmpd  warship.travel
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
        addd  #warship.BASEY           ; l'ancre du maitre + l'ecart de coque,
        subd  warship.drift            ; suivis de la derive de la couche
        std   y_pos,x
        clr   y_pos+2,x
@plein  puls  x                        ; le curseur revient
        leas  6,s
@next   leax  8,x
        bra   @loop
@done   stx   pilot.spawn,u
        rts

warship.travel  fdb 0                  ; la course du tour, en px de couche
warship.drift   fdb 0                  ; la derive verticale du tour, repliee

; La table elle-meme, a la suite : le parcours et ses donnees dans le meme
; direntry, une seule page a monter.
warship.spawn.script
        INCLUDE "src/stages/03/warship/spawn-script.asm"

 ENDSECTION
