terrainCollision.sensor.x fdb 0
terrainCollision.sensor.y fdb 0
terrainCollision.impact.x fdb 0

; --- terrain "efface" : court-circuite toutes les requetes de collision ---
; quand != 0, .do renvoie B=0 (aucun mur) et .xAxis renvoie impact.x=0 (sentinelle
; "pas de mur", identique au cas "aucune tuile solide" de l'impl) -> tout le jeu
; (force pod, armes, vaisseau) joue son code normal libere du terrain, comme si le
; tilemap etait vide. Pose par le jeu a la mort du boss (cf MonsterKill), remis a 0
; au debut de niveau (cf obj_endstage INIT). Simule le nettoyage arcade des tilemaps.
terrainCollision.disabled fcb 0

; --- LES PLANS SE COUPENT SEPAREMENT (28/08/2026, demande auteur) ---
; Un octet par plan : != 0 = ce plan ne repond plus, .do rend B=0 et les
; balayages d'axe rendent impact.x=0 — la meme sentinelle « pas de mur » que
; le cas « aucune tuile solide », donc AUCUN appelant n'a a le savoir.
;
; Le test est CENTRALISE aux trois portes du moteur (.do, .xAxis.doRight,
; .xAxis.doLeft), qui recoivent toutes le numero de plan dans B : c'est le
; seul endroit ou l'on connait a la fois le plan demande et l'intention. Le
; mettre chez les appelants, c'est le recopier des dizaines de fois — la
; lecon de doFoe.
;
; Coût : trois instructions (abx/tst/bne, ~10 cycles) sur un chemin qui en
; vaut deja plusieurs centaines. Et quand un plan est coupe, c'est TOUT son
; parcours de carte qui est economise.
;
; A quoi ca sert : le stage 4 coupe le plan des gommes (0) quand le boss
; prend la main — le champ n'est plus a l'ecran, ses collisions n'ont plus
; de sens et sa lecture est du temps perdu. terrainCollision.disabled, lui,
; garde son role : couper les DEUX d'un coup (mort du boss du stage 1).
terrainCollision.planeOff fill 0,2     ; index = numero de plan (0 et 1)

; --- background lookup boss-follow offset (loadMap) ---
; while the camera/foreground scroll is held during the boss advance, the BACKGROUND
; collision (boss solid silhouette) is shifted right by the boss travel so it tracks
; the moving boss. 0 the rest of the time -> no effect. Set by main.followDobkeratops.
terrainCollision.bgFlag     fcb 0   ; 0 = background lookup, 2 = foreground (set per loadMap call)
terrainCollision.bgByteOff  fcb 0   ; boss advance, whole map bytes (24px each)
terrainCollision.bgBitShift fcb 0   ; boss advance, sub-byte tiles (0..7, 3px each)
terrainCollision.bgColTmp   fcb 0   ; loadMap scratch (column carry during the bit shift)

; --- background plane with its OWN camera (BG_OWN_CAMERA units) ---
; La couche battleship du stage 3 : son plan de collision ne defile PAS avec
; l'avant-plan, il a sa camera sur les deux axes. Ces quatre registres sont
; l'equivalent, pour ce plan, de scroll_tile_pos/scroll_tile_pos_offset24 que
; le moteur de scroll tient pour l'avant-plan — base et reste sous-tuile, sur
; les deux axes. Entretenus une fois par trame par le stage, inertes ailleurs
; (le chemin qui les lit n'est meme pas assemble). Doc :
; games/r-type/doc/bship-collision-plan.md
terrainCollision.bgColBase  fcb 0   ; camera.x / 24 : base de colonne, en octets
terrainCollision.bgSubX     fcb 0   ; camera.x mod 24 : le reste, en px (0..23)
terrainCollision.bgRowBase  fdb 0   ; (camera.y / 6 + pad) * lvlMapWidth, signe
terrainCollision.bgSubY     fcb 0   ; camera.y mod 6 : le reste, en px (0..5)
; L'ecart des deux reperes, en px : glb_camera_x_pos - camera.x de la couche.
; checkXaxis rend un impact.x que l'appelant compare a sensor.x, donc en
; coordonnees MONDE ; la lecture du plan 0 se fait, elle, dans le repere de la
; couche. Cet ecart fait le pont. (Le module en depend : forcepod.asm sonde
; l'axe X sur le plan de fond quand backgroundSolid est arme.)
terrainCollision.bgWorldAdj fdb 0

; ---------------------------------------------------------------------------
; terrainCollision.doFoe — le sol tel que le voit un ennemi TERRESTRE
; ---------------------------------------------------------------------------
; sortie : [b] != 0 si solide. A est detruite, comme apres .do.
;
; « Solide » veut dire DUR OU GOMME. En arcade la question ne se pose pas : une
; gomme y est une tuile d'avant-plan, et run_cancer / run_pow_armor / le bink
; ne sondent QUE l'avant-plan (probe_foreground_tile, seuil 0xDFC — verifie :
; sur les 48 appelants de la sonde a deux plans de la borne, aucun n'est dans
; leurs plages). C'est notre rangement en deux plans qui demande le double
; test, et les deux plans du stage 4 sont DISJOINTS (1025 cellules dures,
; 1618 de gommes, zero commune) : inverser leur declaration echangerait
; simplement « traverse les gommes » contre « traverse le sol ».
;
; La routine vit ICI, une fois, plutot que recopiee dans chaque ennemi
; (remarque auteur, 28/08/2026) : trois copies du meme geste etaient trois
; occasions de deriver.
;
; Le second test est garde par globals.foeBgSolid — le drapeau des ennemis
; terrestres, arme par le seul stage 4. PAS backgroundSolid : celui-la vaut 1
; des l'init du stage 1, dont le plan de fond porte la silhouette du boss ;
; y faire marcher un cancer serait faux, et le sonder tout le niveau serait
; paye pour rien.
; ---------------------------------------------------------------------------
terrainCollision.doFoe
        ldb   #1                           ; l'avant-plan : le decor dur
        jsr   terrainCollision.do
        tstb
        bne   @solid
        lda   globals.foeBgSolid           ; le fond est-il du SOL ici ?
        beq   @solid                       ; non : B = 0, une seule sonde payee
        clrb                               ; l'arriere-plan : les gommes
        jmp   terrainCollision.do
@solid  rts

terrainCollision.do
        lda   terrainCollision.disabled    ; tilemap "efface" (boss tue) ?
        bne   @off
        ldx   #terrainCollision.planeOff   ; ...ou CE plan seul est coupe ?
        abx
        tst   ,x
        beq   @active
@off    clrb                               ; -> aucune collision (B=0)
        rts
@active _GetCartPageA
        sta   @page
        lda   #0
terrainCollision.main.page equ *-1
        _SetCartPageA
        jsr   >0
terrainCollision.main.address equ *-2
        lda   #0
@page   equ *-1
        _SetCartPageA
        rts

terrainCollision.xAxis.doRight
        lda   terrainCollision.disabled    ; tilemap "efface" (boss tue) ?
        bne   @off
        ldx   #terrainCollision.planeOff   ; ...ou CE plan seul est coupe ?
        abx
        tst   ,x
        beq   @active
@off    ldd   #0                           ; -> pas de mur (impact.x=0, cf @noImpact impl)
        std   terrainCollision.impact.x
        rts
@active _GetCartPageA
        sta   @page
        lda   #0
terrainCollision.main.xAxis.doRight.page equ *-1
        _SetCartPageA
        jsr   >0
terrainCollision.main.xAxis.doRight.address equ *-2
        lda   #0
@page   equ *-1
        _SetCartPageA
        rts

terrainCollision.xAxis.doLeft
        lda   terrainCollision.disabled    ; tilemap "efface" (boss tue) ?
        bne   @off
        ldx   #terrainCollision.planeOff   ; ...ou CE plan seul est coupe ?
        abx
        tst   ,x
        beq   @active
@off    ldd   #0                           ; -> pas de mur (impact.x=0, cf @noImpact impl)
        std   terrainCollision.impact.x
        rts
@active _GetCartPageA
        sta   @page
        lda   #0
terrainCollision.main.xAxis.doLeft.page equ *-1
        _SetCartPageA
        jsr   >0
terrainCollision.main.xAxis.doLeft.address equ *-2
        lda   #0
@page   equ *-1
        _SetCartPageA
        rts

terrainCollision.update
        sta   @a
        _GetCartPageA
        sta   @page
        lda   #0
terrainCollision.main.update.page equ *-1
        _SetCartPageA
        lda   #0
@a   equ *-1
        jsr   >0
terrainCollision.main.update.address equ *-2
        lda   #0
@page   equ *-1
        _SetCartPageA
        rts

