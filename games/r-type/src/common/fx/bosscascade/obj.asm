;*******************************************************************************
; bosscascade — la cascade de mort d'un boss, comme objet enfant
;
; LA BORNE fait mourir ses boss (Gomander a6a5, Bellmite b4c9, Compiler b062,
; Bydo c284) avec le MEME acteur : un enfant pose a la position du boss, qui
; egrene pendant sa duree de vie des explosions aux offsets d'une liste —
; une par trame paire, small_x3 par defaut, une chance sur quatre de grosse.
; Le Dobkeratops (9d30) fait presque pareil depuis son propre slot, avec le
; type d'explosion ECRIT dans chaque entree ; sa sequence v1
; (dobkeratops/explosion.asm) est le modele de ce marcheur.
;
; CE QUE LE MARCHEUR FAIT : une entree {dx, dy, subtype} toutes les
; bosscascade.PERIOD trames VIDEO, frame drop compense (le tour de boucle
; consomme autant d'entrees que de trames ecoulees, le reste attend),
; jusqu'au $80 de fin de table. Le hasard de la borne (le type) est PRE-TIRE
; par le generateur de la table ; sa duree de vie, c'est la longueur de la
; table. Il ne dessine rien : c'est l'explosion commune qui vit, avec son
; propre son (bits 4-6 du subtype, explosion.const.asm).
;
; CE QUE L'UNITE HOTE FOURNIT : `bosscascade.table` (les triplets, $80 en
; fin) et `bosscascade.PERIOD` — tous deux ecrits par le generateur du boss
; (tools/gen_<boss>_death.py). Le boss pose l'enfant a sa position, id
; ObjID_bosscascade (le slot commun 29, celui du Dobkeratops au stage 1).
;
; input REG : [u] pointer to Object Status Table (OST)
;*******************************************************************************

bosscascade.cursor equ ext_variables     ; 0,1  l'entree courante de la table
bosscascade.rem    equ ext_variables+2   ; 2    trames video deja comptees vers
                                         ;      la prochaine entree

bosscascade.Object
        lda   routine,u
        asla
        ldx   #bosscascade.Routines
        jmp   [a,x]
bosscascade.Routines
        fdb   bosscascade.Init
        fdb   bosscascade.Live
        fdb   bosscascade.Deleted

bosscascade.Init
        ldd   #bosscascade.table
        std   bosscascade.cursor,u
        clr   bosscascade.rem,u
        clr   priority,u               ; rien a dessiner
        inc   routine,u

bosscascade.Live
        lda   gfxlock.frameDrop.count
        bne   >
        inca                           ; count == 0 (1re boucle apres checkpoint.load)
!       adda  bosscascade.rem,u        ; les trames ecoulees, reste compris
@loop   cmpa  #bosscascade.PERIOD
        blo   @keep
        suba  #bosscascade.PERIOD
        sta   bosscascade.rem,u        ; les aides ont le droit de tout clobber
        ldy   bosscascade.cursor,u
        ldb   ,y
        cmpb  #$80
        beq   bosscascade.Done
        jsr   LoadObject_x             ; Y preserve (le geste de la v1)
        beq   @skip                    ; pool plein : l'entree est perdue, le
        lda   #ObjID_explosion         ; rythme est tenu
        sta   id,x
        ldb   2,y
        stb   subtype,x                ; animation + son, pre-tires
        ldb   ,y
        sex
        addd  x_pos,u
        std   x_pos,x
        ldb   1,y
        sex
        addd  y_pos,u
        std   y_pos,x
        ; l'ancre suit le decor qui coule (a6a8 : l'acteur arcade ajoute le
        ; delta Y du plan avant a son Y) — globals.tilesDrop, en lignes signees
        ldb   globals.tilesDrop
        sex
        addd  y_pos,x
        std   y_pos,x
@skip   leay  3,y
        sty   bosscascade.cursor,u
        lda   bosscascade.rem,u
        bra   @loop
@keep   sta   bosscascade.rem,u
        rts

bosscascade.Done
        lda   #2
        sta   routine,u
        jmp   UnloadObject_u           ; jamais dessine : pas de DeleteObject

bosscascade.Deleted
        rts
