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

terrainCollision.do
        lda   terrainCollision.disabled    ; tilemap "efface" (boss tue) ?
        beq   @active
        clrb                               ; -> aucune collision (B=0)
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
        beq   @active
        ldd   #0                           ; -> pas de mur (impact.x=0, cf @noImpact impl)
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
        beq   @active
        ldd   #0                           ; -> pas de mur (impact.x=0, cf @noImpact impl)
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

