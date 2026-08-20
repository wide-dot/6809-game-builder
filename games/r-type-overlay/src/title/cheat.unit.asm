;*******************************************************************************
; Le cheat de selection de stage — unite paginee du title
;
; Sequences, JOYPAD SEULEMENT (les directions ne declenchent jamais un
; depart, les cheats sont indevinables au bouton). Prefixe commun : haut,
; bas, gauche, droite. Puis la premiere direction choisit le cheat, et le
; depart NORMAL (A, B ou n'importe quelle touche clavier, le declencheur
; d'origine du title) l'applique :
;   N x haut   -> depart au stage N (1..8), un FireSound par haut ;
;   bas        -> invincible, ExplosionSound (redite : le son rejoue) ;
;   N x gauche -> N vies en plus, un BonusSound par gauche ;
;   droite     -> reset silencieux.
; Sequence incomplete, compte nul ou stage > 8 : depart stage 1 normal, et
; les effets sont TOUJOURS reecrits au depart — un depart sans cheat les
; remet a zero. Pendant le prefixe, une mauvaise direction remet a zero —
; haut rouvre.
;
; Tout vit ICI, dans la page (la carte residente est pleine) : l'etat, la
; machine et la table des cibles. Le title appelle title.cheat.tick une fois
; par trame (paged.call) apres joypad.readKbd ; title.launchGame, apres son
; game.stage.unload RESIDENT (l'unload peut toucher la fenetre cartouche,
; on n'y retourne pas pendant), appelle title.cheat.launch qui choisit la
; cible et saute dans game.stage.switch — resident, sans retour ici.
;
; L'unite est rechargee du disque a chaque retour au title : l'etat repart
; a zero tout seul.
;*******************************************************************************

title.cheat.tick   EXPORT
title.cheat.launch EXPORT

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "src/common/cast.const.asm"
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"

STAGE_SCENE equ scenes.title

 SECTION code

; --- un front dpad par trame nourrit la machine ---------------------------
title.cheat.tick
        ldb   joypad.pressed.dpad
        andb  #$0F                     ; port 0 seulement
        beq   tct.rts
        clra
tct.scan
        inca                           ; 1..4 = haut, bas, gauche, droite
        lsrb
        bcc   tct.scan
        ldb   tct.step
        cmpb  #4
        bhs   tct.armed
        inc   tct.step                 ; l'attendue est l'ancienne etape +1
        cmpa  tct.step
        beq   tct.rts                  ; bonne direction : step est avance
        clr   tct.step                 ; mauvaise : reset, haut rouvre
        cmpa  #1
        bne   tct.rts
        inc   tct.step
tct.rts rts
tct.armed                              ; A = la direction, B libre
        ldb   tct.mode
        cmpa  #4
        beq   tct.reset                ; droite : reset silencieux
        cmpa  #1
        bne   tct.notUp
        cmpb  #1                       ; haut : le comptage de stage
        bhi   tct.reset                ; un autre cheat etait choisi
        ldb   #1
        stb   tct.mode
        inc   tct.count
        ldd   #(soundFX.FireSound<<8)|1 ; un FireSound par haut — la
        std   soundFX.newSound         ; validation sonore du comptage
        rts
tct.notUp
        cmpa  #2
        bne   tct.left
        cmpb  #2                       ; bas : invincible
        beq   tct.dingInv              ; redite : le son rejoue
        tstb
        bne   tct.reset
        ldb   #2
        stb   tct.mode
tct.dingInv
        ldd   #(soundFX.ExplosionSound<<8)|1
        std   soundFX.newSound
        rts
tct.left
        cmpb  #3                       ; gauche : le comptage de vies
        beq   tct.oneUp
        tstb
        bne   tct.reset
        ldb   #3
        stb   tct.mode
tct.oneUp
        inc   tct.count
        ldd   #(soundFX.BonusSound<<8)|1
        std   soundFX.newSound
        rts
tct.reset
        clr   tct.step                 ; une autre direction casse tout
        clr   tct.mode
        clr   tct.count
        rts

; --- la cible du depart : X scene, Y repertoire, U lots — jmp switch ------
title.cheat.launch
        ; le title rend sa scene — d'ICI : l'unload ne fait aucune E/S disque
        ; et ne touche pas la fenetre cartouche (le piege loader connu vise la
        ; fenetre DONNEES, pour les appels disque) ; ces 6 octets manquaient
        ; au title resident
        ldx   #STAGE_SCENE
        jsr   game.stage.unload
        ; les effets, TOUJOURS reecrits : un depart sans cheat les efface
        clr   cheat.invincible
        clr   cheat.extraLives
        clrb                           ; stage 1 par defaut
        lda   tct.step
        cmpa  #4
        blo   tcl.go                   ; sequence incomplete : depart normal
        lda   tct.mode
        cmpa  #2
        beq   tcl.inv
        cmpa  #3
        beq   tcl.lives
        lda   tct.count                ; mode stage : le compte est la cible
        beq   tcl.go                   ; arme sans compte : depart normal
        cmpa  #9
        bhs   tcl.go                   ; plus de 8 hauts : depart normal
        tfr   a,b
        decb                           ; l'index de stage 0..7
        bra   tcl.go
tcl.inv
        inc   cheat.invincible
        bra   tcl.go
tcl.lives
        lda   tct.count                ; N gauches = N vies en plus
        sta   cheat.extraLives
tcl.go
        stb   game.stage
        aslb                           ; stride 4 : scene, lots
        aslb
        ldx   #tcl.table
        abx
        ldu   2,x                      ; les lots d'ennemis de la cible
        ldy   ,x                       ; l'id de scene, garde pour X
        lda   game.stage
        inca                           ; repertoire N = stage N
        tfr   y,x
        tfr   a,b
        clra
        tfr   d,y
        jmp   game.stage.switch        ; resident — on ne revient jamais ici

; l'etat (la page est de la RAM, et l'unite revient du disque a chaque
; entree au title)
tct.step  fcb 0                        ; 0..4 : progression du prefixe
tct.mode  fcb 0                        ; 0 rien, 1 stage, 2 invincible, 3 vies
tct.count fcb 0                        ; le compte (hauts ou gauches) une fois arme

; la table des cibles (une ligne par stage) : les ids de scene viennent des
; entries.asm des repertoires 1..8, inclus par l'unite
tcl.table
        fdb   scenes.stage1,cast.stage1
        fdb   scenes.stage2,cast.stage2
        fdb   scenes.stage3,cast.stage3
        fdb   scenes.stage4,cast.stage4
        fdb   scenes.stage5,cast.stage5
        fdb   scenes.stage6,cast.stage6
        fdb   scenes.stage7,cast.stage7
        fdb   scenes.stage8,cast.stage8

 ENDSECTION
