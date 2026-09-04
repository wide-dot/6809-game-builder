;*******************************************************************************
; Le cheat de selection de stage — unite paginee du title
;
; Sequences, JOYPAD SEULEMENT (les directions ne declenchent jamais un
; depart, les cheats sont indevinables au bouton). Prefixe commun : haut,
; bas, gauche, droite. Puis la premiere direction choisit le cheat, et le
; depart NORMAL (A, B ou n'importe quelle touche clavier, le declencheur
; d'origine du title) l'applique :
;   N x haut   -> depart au stage N (1..8), un bip par haut ;
;   bas        -> invincible ;
;   gauche     -> continue infini (le quota de l'ecran de continue saute) ;
;   droite     -> depart a 100 000 points, pour eprouver le classement.
; Un seul bruitage pour les quatre (BonusSound) : c'est un accuse de reception.
; Il n'y a plus d'abandon par direction — DEUX SECONDES sans presser efface
; tout, prefixe et cheats acceptes (04/09/2026). L'ancien comptage de vies par
; `gauche` est retire : sans plafond, il debordait son octet a la 254e pression,
; et le continue infini rend mieux le meme service.
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
; LE COMPTE A REBOURS (04/09/2026, decision auteur). Deux secondes sans
; direction et tout retombe — le prefixe comme les cheats deja acceptes. Il
; remplace l'abandon par `droite`, dont la direction sert desormais le cheat de
; score. Casser la sequence ne suffisait pas : ca ne remet que l'etape a zero,
; les cheats acceptes survivaient (c'est ce qui permet de les combiner) sans
; aucun moyen de les retirer.
CHEAT_TIMEOUT equ 100                  ; 2 s a 50 Hz

title.cheat.tick
        lda   tct.timer
        beq   >                        ; rien en cours : pas de compte a tenir
        deca
        sta   tct.timer
        lbeq  tct.wipe                 ; expire : on efface tout et on sort
!
        ldb   joypad.pressed.dpad
        andb  #$0F                     ; port 0 seulement
        beq   tct.rts
        lda   #CHEAT_TIMEOUT
        sta   tct.timer                ; toute direction relance le compte
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

tct.armed                              ; A = la direction, B = le mode courant
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
        inc   tct.pstage
        bra   tct.ding
tct.notUp
        cmpa  #2
        bne   tct.notDown
        cmpb  #2                       ; bas : invincible
        beq   tct.dingInv              ; redite : le son rejoue
        tstb
        bne   tct.rearm
        ldb   #2
        stb   tct.mode
tct.dingInv
        lda   #1
        sta   tct.pinv
        bra   tct.ding
tct.notDown
        cmpa  #3
        bne   tct.right
        cmpb  #3                       ; gauche : le continue infini
        beq   tct.dingCont
        tstb
        bne   tct.rearm
        ldb   #3
        stb   tct.mode
tct.dingCont
        lda   #1
        sta   tct.pcont
        bra   tct.ding
tct.right
        cmpb  #4                       ; droite : cent mille points au depart
        beq   tct.dingScore
        tstb
        bne   tct.rearm
        ldb   #4
        stb   tct.mode
tct.dingScore
        lda   #1
        sta   tct.pscore
; UN SEUL BRUITAGE pour les quatre cheats (decision auteur, 04/09/2026) : c'est
; un accuse de reception, pas une signature. Trois sons differents coutaient
; trois ecritures de la boite aux lettres pour la meme information.
tct.ding
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
        clr   tct.step                 ; le delai a expire : on efface TOUT,
        clr   tct.mode                 ; y compris les cheats deja acceptes
        clr   tct.pstage
        clr   tct.pinv
        clr   tct.pcont
        clr   tct.pscore
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
        lda   tct.pcont
        sta   cheat.freeContinue
        lda   tct.pscore
        sta   cheat.startScore
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
tct.mode   fcb 0                       ; 0 rien, 1 stage, 2 invincible,
                                       ;   3 continue infini, 4 score
tct.timer  fcb 0                       ; trames avant l'effacement general
; les cheats ACCEPTES (survivent au rearmement, effaces par le delai ou au depart)
tct.pstage fcb 0                       ; 0 aucun, 1..8 le stage compte
tct.pinv   fcb 0                       ; 1 = invincible accepte
tct.pcont  fcb 0                       ; 1 = continue infini accepte
tct.pscore fcb 0                       ; 1 = depart a 100 000 points

; la table des cibles (une ligne par stage) : les ids de scene viennent des
; entries.asm des repertoires 1..8, inclus par l'unite

 ENDSECTION
