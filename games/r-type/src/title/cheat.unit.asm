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
;   droite     -> abandon TOTAL, silencieux (cheats acceptes compris).
; Les cheats sont ACCEPTES a la pression (le son est l'accuse de reception),
; fire ne fait que lancer — et ils se COMBINENT : une direction hors mode
; laisse les cheats acceptes en place et repart en prefixe (haut le rouvre).
; Exemple : h,b,g,d,bas (invincible) puis h,b,g,d,h,h,h (stage 3) puis fire.
; Compte de stage nul ou > 8 : le depart reste stage 1 (les autres cheats
; acceptes s'appliquent). Les effets sont TOUJOURS reecrits au depart — un
; depart sans cheat les remet a zero.
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
tct.armed                              ; A = la direction
        cmpa  #4
        beq   tct.wipe                 ; droite : abandon total, silencieux
        ldb   tct.mode
        cmpa  #1
        bne   tct.notUp
        cmpb  #1                       ; haut : le comptage de stage
        beq   tct.moreStage
        tstb
        bne   tct.rearm                ; un autre cheat est deja accepte :
        ldb   #1                       ; il RESTE, la sequence repart
        stb   tct.mode
        clr   tct.pstage               ; nouvelle selection : compte a zero
tct.moreStage
        inc   tct.pstage               ; accepte a la pression — le son est
        ldd   #(soundFX.FireSound<<8)|1 ; l'accuse de reception
        std   soundFX.newSound
        rts
tct.notUp
        cmpa  #2
        bne   tct.left
        cmpb  #2                       ; bas : invincible
        beq   tct.dingInv              ; redite : le son rejoue
        tstb
        bne   tct.rearm
        ldb   #2
        stb   tct.mode
tct.dingInv
        lda   #1
        sta   tct.pinv
        ldd   #(soundFX.ExplosionSound<<8)|1
        std   soundFX.newSound
        rts
tct.left
        cmpb  #3                       ; gauche : le comptage de vies
        beq   tct.oneUp
        tstb
        bne   tct.rearm
        ldb   #3
        stb   tct.mode
        clr   tct.plives
tct.oneUp
        inc   tct.plives
        ldd   #(soundFX.BonusSound<<8)|1
        std   soundFX.newSound
        rts
tct.rearm
        clr   tct.mode                 ; les cheats acceptes restent : seule
        clr   tct.step                 ; la sequence repart — haut la rouvre
        cmpa  #1
        bne   tct.rts2
        inc   tct.step
tct.rts2
        rts
tct.wipe
        clr   tct.step                 ; droite : on efface TOUT, y compris
        clr   tct.mode                 ; les cheats deja acceptes
        clr   tct.pstage
        clr   tct.pinv
        clr   tct.plives
        rts

; --- la cible du depart : X scene, Y repertoire, U lots — jmp switch ------
title.cheat.launch
        ; le title rend sa scene — d'ICI : l'unload ne fait aucune E/S disque
        ; et ne touche pas la fenetre cartouche (le piege loader connu vise la
        ; fenetre DONNEES, pour les appels disque) ; ces 6 octets manquaient
        ; au title resident
        ; les effets acceptes s'appliquent, TOUJOURS reecrits : un depart
        ; sans cheat remet tout a zero
        lda   tct.pinv
        sta   cheat.invincible
        lda   tct.plives
        sta   cheat.extraLives
        lda   #1                       ; tout depart du title est une partie
        sta   game.fresh               ; fraiche : le stage semera vies/score
        clrb                           ; stage 1 par defaut
        lda   tct.pstage
        beq   tcl.go                   ; pas de comptage de stage
        cmpa  #9
        bhs   tcl.go                   ; plus de 8 hauts : depart stage 1
        tfr   a,b
        decb                           ; l'index de stage 0..7
tcl.go
        stb   game.stage               ; l'index de stage, 0-base
        incb                           ; l'ecran cible : 1..8 = le stage N
        jmp   game.stage.switch        ; resident — on ne revient jamais ici

; l'etat (la page est de la RAM, et l'unite revient du disque a chaque
; entree au title)
tct.step   fcb 0                       ; 0..4 : progression du prefixe
tct.mode   fcb 0                       ; 0 rien, 1 stage, 2 invincible, 3 vies
; les cheats ACCEPTES (survivent au rearmement, effaces par droite ou au depart)
tct.pstage fcb 0                       ; 0 aucun, 1..8 le stage compte
tct.pinv   fcb 0                       ; 1 = invincible accepte
tct.plives fcb 0                       ; les vies en plus acceptees

; la table des cibles (une ligne par stage) : les ids de scene viennent des
; entries.asm des repertoires 1..8, inclus par l'unite

 ENDSECTION
