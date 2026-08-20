;*******************************************************************************
; Le cheat de selection de stage — unite paginee du title
;
; Sequence, JOYPAD SEULEMENT (les directions ne declenchent jamais un depart,
; le cheat est indevinable au bouton) : haut, bas, gauche, droite, puis N
; fois haut — N = le numero du stage (1..8) — et le depart NORMAL (A, B ou
; n'importe quelle touche clavier, le declencheur d'origine du title) lance
; le stage compte. Sequence incomplete, compte a zero ou plus de 8 hauts :
; le depart reste un depart stage 1. Une mauvaise direction remet la
; sequence a zero — haut la rouvre.
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
tct.armed
        cmpa  #1                       ; prefixe arme : haut compte le stage
        bne   tct.reset
        inc   tct.count
        ldd   #(soundFX.FireSound<<8)|1 ; le bip de comptage : un FireSound par
        std   soundFX.newSound         ; haut — la validation sonore du cheat
        rts
tct.reset
        clr   tct.step                 ; une autre direction casse tout
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
        clrb                           ; stage 1 par defaut
        lda   tct.step
        cmpa  #4
        blo   tcl.go                   ; sequence incomplete : depart normal
        lda   tct.count
        beq   tcl.go                   ; armee sans compte : depart normal
        cmpa  #9
        bhs   tcl.go                   ; plus de 8 hauts : depart normal
        tfr   a,b
        decb                           ; l'index de stage 0..7
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
tct.count fcb 0                        ; le nombre de hauts une fois arme

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
