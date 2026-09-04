
; ---------------------------------------------------------------------------
; Object - Weapon
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les entrees d'imageset passent de Img_<nom> a set_<nom>,
; le nom que gfxcomp genere (meme ecart que pata-pata et le joueur).
; V2-DEVIATION: les en-tetes v1 sont retires — l'unite enveloppe les
; porte (macros, collision, equates), et le son n'est pas porte.
; Includes v1 retires :
;   INCLUDE "./engine/macros.asm"
;           INCLUDE "./engine/collision/macros.asm"
;           INCLUDE "./engine/collision/struct_AABB.equ"
;           INCLUDE "./objects/soundFX/soundFX.const.asm"
;           INCLUDE "./engine/sound/soundFX.macro.asm"

AABB_0  equ ext_variables ; AABB struct (9 bytes)
impactX equ ext_variables+9  ; impact x position (mur OU gomme : LE destin)
gumHit  equ ext_variables+11 ; != 0 si ce destin est une gomme a manger

Weapon
        lda   routine,u
        asla
        ldx   #Weapon_Routines
        jmp   [a,x]

; L'ARRIERE de la boite balayee du tick courant (monde), garde le temps d'un
; tick : la frontiere avant d'avant le pas — ou, a la naissance, le bord
; arriere du tir lui-meme, sinon un trou de 6 px reste entre le vaisseau et
; la premiere boite (04/09/2026). Un seul tir a la fois dans Live : un
; scratch partage suffit.
weapon.sweepFrom fdb 0

Weapon_Routines
        fdb   Init
        fdb   Live
        fdb   Impact
        fdb   Delete
        fdb   AlreadyDeleted

Init
        _soundFX.play soundFX.FireSound,0
        ldd   x_pos,u
        addd  #8+3
        std   x_pos,u
        ldd   y_pos,u
        addd  #2
        std   y_pos,u
        ldd   #set_weapon
        std   image_set,u
        ldb   #2
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u

        _Collision_AddAABB AABB_0,AABB_list_friend
        
        lda   #1                       ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        ; rx = 3, la demi-largeur REELLE du projectile. L'ancien 15 etait une
        ; compensation de frame rate (boite grasse pour boucher les trous
        ; entre deux echantillons) ; depuis le 31/08/2026 la boite est BALAYEE
        ; par Live — elle couvre tout le segment parcouru dans la trame — et
        ; la compensation statique n'a plus de raison d'etre.
        _ldd  3,1                      ; set hitbox xy radius
        std   AABB_0+AABB.rx,u

        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        ; (cx n'est pas pose ici : l'Init tombe dans Live — voir plus bas —
        ; et le premier tick ecrit la boite balayee de la trame de naissance)

        ; --- LE DESTIN DU TIR, calcule UNE FOIS a la naissance
        ; La sonde de ligne rend le bord gauche de la premiere cellule 3x6
        ; pleine a droite. On la joue DEUX FOIS sur le meme senseur : le decor
        ; dur (plan 1), puis la couche destructible du stage par le crochet
        ; (plan 0 — les gommes du stage 4). Le plus proche des deux gagne :
        ; le tir meurt sur le premier obstacle, et on sait lequel.
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        std   impactX,u
        clr   gumHit,u

        ; le senseur est toujours pose : le crochet rebalaie LA MEME ligne
        ldx   stage.gum.hook
        jsr   3,x                      ; +3 : chercher (cf. state/variables.asm)
        cmpd  #0
        beq   @destiny                 ; pas de couche destructible, ou rien devant
        ldx   impactX,u
        beq   @gum                     ; pas de mur : la gomme decide seule
        cmpd  impactX,u
        bhs   @destiny                 ; le mur vient avant, le tir n'ira pas plus loin
@gum    std   impactX,u                ; UN seul destin, et c'est une gomme
        inc   gumHit,u
@destiny
        inc   routine,u
        ; ET LE PREMIER TICK TOUT DE SUITE — on entre dans Live par son pas,
        ; pas par sa queue. L'arcade fait exactement ca (create_force_pod_
        ; simple_fire $3EA7 « falls through for an immediate first tick ») :
        ; le tir rattrape son frame drop des la trame de naissance, et la
        ; boite balayee s'etire de la position INITIALE (bouche du canon,
        ; sondee pour le destin ci-dessus) a la position rattrapee. L'ancien
        ; `bra >` sautait le deplacement : le tir restait une trame a la
        ; bouche, et le balayage y partait meme a l'envers (centre - demi-pas).
        ; L'arriere de cette premiere boite est le bord arriere du tir, pas une
        ; frontiere d'avant le pas qui n'existe pas encore.
        ldd   x_pos,u
        subd  #3
        std   weapon.sweepFrom
        bra   weapon.step

Live
        ; LE COUP ENCAISSE S'AFFICHE. Quand un ennemi consomme le tir (p=0 a
        ; la passe de collision), l'arcade pose un impact immediat
        ; (create_fire_impact_yellow) ; ici le tir mourait en silence et le
        ; joueur ne voyait jamais son coup porter — le ressenti « ca lag »
        ; sur l'orbe du gomander (31/08/2026). Meme sequence d'images que
        ; l'impact mur, a la position courante ; p reste a 0, la boite est
        ; inerte et Delete la retirera en fin d'anim.
        lda   AABB_0+AABB.p,u
        lbeq  weapon.HitFeedback

        ; update weapon position
        ldd   x_pos,u
        addd  #3
        std   weapon.sweepFrom         ; la frontiere avant d'avant le pas :
                                       ; l'arriere de la boite balayee
weapon.step
        lda   #6
        ldb   gfxlock.frameDrop.count
        mul
        addd  x_pos,u
        addd  glb_camera_x_pos
        subd  glb_camera_x_pos_old
        std   x_pos,u
!
        ; check wall collision — LE MEME CHEMIN POUR LE MUR ET POUR LA GOMME.
        ; impactX porte le destin choisi a la naissance ; il ne reste qu'a
        ; guetter l'arrivee. Il n'y a PLUS de sonde par trame : elle ne pouvait
        ; pas suivre a bas regime (6*frameDrop = 24 px d'un coup a 12 img/s,
        ; huit cellules enjambees) et mangeait une gomme loin devant le sprite
        ; d'impact. Cf. src/common/state/variables.asm.
        ldd   impactX,u
        beq   >
        subd  #3 ; half width of the weapon, to check collision on the right side
        cmpd  x_pos,u
        bhi   >

        ; LA COUCHE DESTRUCTIBLE (24/08/2026) : le tir mange UNE cellule de
        ; gomme et meurt dessus. Ici la cellule est celle que la sonde a
        ; designee, au pixel — pas celle sur laquelle le tir est retombe.
        ;
        ; ET IL MEURT SANS IMAGE D'IMPACT (decision auteur, 25/08/2026) : ce
        ; qu'on doit voir, c'est la gomme qui disparait, pas une gerbe blanche
        ; par-dessus. L'impact reste pour le decor dur, qui lui ne cede pas.
        tst   gumHit,u
        beq   @wall
        ldx   impactX,u
        ldb   y_pos+1,u
        jsr   [stage.gum.hook]         ; +0 : effacer
        lbra  Delete
@wall
        jsr   RandomNumber
        clra
        andb  #%00000011
        _negd
        subd  #3 ; half width of the weapon
        addd  impactX,u
        std   x_pos,u
        ; LA TRAME D'IMPACT GARDE SA BOITE BALAYEE — du depart du pas au point
        ; d'impact. La branche court-circuitait la pose de boite : un tir qui
        ; atteignait le mur mourait avec un point sur le mur, et tout ce qu'il
        ; avait TRAVERSE dans le pas (l'orbe du gomander, posee devant le
        ; decor du corps) ne voyait jamais sa boite. Avec le rattrapage de
        ; naissance, un tir parti a moins d'un pas du mur ne pouvait plus
        ; RIEN toucher (31/08/2026). p reste arme : la passe de collision de
        ; la trame suivante teste ce segment, puis Impact/Delete le retire.
        ; LA BOITE PAR SES BORDS (04/09/2026) — voir le site en vol plus bas.
        ; L'avant est le point d'impact ; l'aleas du recul peut le mettre un
        ; ou deux pixels derriere l'arriere : AABB.spanX sert les deux sens,
        ; la boite couvre alors ce petit segment.
        ldd   weapon.sweepFrom
        subd  glb_camera_x_pos         ; l'arriere
        tfr   d,x
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  #3                       ; l'avant : le point d'impact
        leay  AABB_0,u
        jsr   AABB.spanX
        ldd   #set_weapon_impact0
        std   image_set,u
        inc   routine,u
        jmp   DisplaySprite
!
        ; update hitbox position — LA BOITE BALAYEE, PAR SES BORDS. Un seul
        ; echantillon par trame et un pas de 6*frameDrop : une boite posee sur
        ; la seule position courante laisse des trous des que le pas depasse
        ; sa largeur. La boite couvre donc le segment parcouru, de la
        ; FRONTIERE AVANT DE LA TRAME PRECEDENTE (x d'avant le pas + 3) a la
        ; frontiere courante (x + 3) : contigue d'une trame a l'autre, sans
        ; recouvrement — a 50 img/s c'est la largeur du tir (6 px), a 7 img/s
        ; elle s'etire a 48 px. Aucun ennemi ne passe entre deux trames, et le
        ; bout portant est couvert par la position de naissance posee par Init.
        ; Les deux bords sont cales dans [0,255] par AABB.spanX AVANT la
        ; conversion en centre + rayon : le noyau compare modulo 256, et caler
        ; le seul centre laissait le rayon (jusqu'a 27) deborder a gauche et
        ; reapparaitre a droite (04/09/2026, doc/analyse-wrap-boites.md).
        ldd   weapon.sweepFrom
        subd  glb_camera_x_pos         ; l'arriere
        tfr   d,x
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #160-8/2                 ; delete weapon if out of screen range
        bhs   Delete
        addd  #3                       ; l'avant : la frontiere courante
        leay  AABB_0,u
        jsr   AABB.spanX
        jmp   DisplaySprite

weapon.HitFeedback
        ldd   #set_weapon_impact0
        std   image_set,u
        inc   routine,u                ; Live -> Impact : la fin d'anim commune
        jmp   DisplaySprite

Impact
        inc   routine,u
        ldd   #set_weapon_impact3
        std   image_set,u
        jmp   DisplaySprite

Delete 
        lda   #4 ; do not use inc here, it will lead to a bug.
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        jmp   DeleteObject

AlreadyDeleted
        rts ; once deleted, the object can be called again for double buffering update.

