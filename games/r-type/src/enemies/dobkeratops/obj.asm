; ---------------------------------------------------------------------------
; Object
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (dobkeratops.unit.asm), comme pour tout fichier v1 enveloppe.
;
; V2-DEVIATION (chantier nerfs-overlay, 31/08/2026) : cet objet ne porte plus
; que le CORPS — l'apparition en bandes (subtypes 9-12), la passation a la
; face entiere, l'avance et le gel. Les nerfs optiques, leurs boites, leurs
; sequences d'effacement et les elements d'oeil sont partis dans eyemgr
; (un objet, quatre systemes) : IntroEye/RunEyes/DeleteEye, les 55 images
; d'effaceurs et les copies double-buffer n'existent plus — en overlay, ne
; plus dessiner EST l'effacement. Les bandes d'apparition affichent la face
; SANS nerfs (images/bands/, redecoupees de 00-dk-alien.png) ; les nerfs qui
; les accompagnent sont dessines par le manager, au meme canevas.

rtnid.MoveAlien equ 4
rtnid.DeleteAlien equ 5
rtnid.FreezeAlien equ 7        ; (6 = DeleteAlienEnd) clean double-buffer stop on boss death

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Init
        fdb   Run
        fdb   Rtn_rts              ; (2) ex RunEyes -> eyemgr
        fdb   Rtn_rts              ; (3) ex DeleteEye -> eyemgr
        fdb   MoveAlien
        fdb   DeleteAlien
        fdb   DeleteAlienEnd
        fdb   FreezeAlien
        fdb   FreezeAlienStop
        fdb   Rtn_rts              ; (9) ex IntroEye -> eyemgr
        fdb   Rtn_rts              ; (10) ex EyeDeleted -> eyemgr

Init
        ; init sprite position
        ldd   #1507
        std   x_pos,u
        ldd   #100
        std   y_pos,u

        ; reinit wave frame drop that share the same position as anim_frame_duration
        clr   anim_frame_duration,u

        ; display priority and setup image
        ldd   subtype,u
        stb   priority,u
        ldx   #SubImages
        asla
        ldx   a,x
        stx   image_set,u

        ; display settings
        lda   #render_playfieldcoord_mask|render_xloop_mask
        sta   render_flags,u
        inc   routine,u
        ; le corps (subtype 8) n'a pas d'image avant la passation : la
        ; colonne 0-15 de la face est vide (le bout du nerf du haut qui y
        ; vivait est au manager)
        ldd   image_set,u
        beq   Rtn_rts
        jmp   DisplaySprite

Rtn_rts rts

SubImages
        fdb   0,0,0,0              ; (0-3) ex nerfs-hitbox -> eyemgr
        fdb   0,0,0,0              ; (4-7) ex elements d'oeil -> eyemgr
        fdb   0                    ; (8) le corps : rien avant DELETE_ALIEN_BODY
        fdb   Img_dobkeratops_band0
        fdb   Img_dobkeratops_band1
        fdb   Img_dobkeratops_band2
        fdb   Img_dobkeratops_band3

Run
        ldb   subtype,u
        cmpb  #8
        beq   @alienN0
        bhi   @alienNx
        rts                        ; subtypes 0-7 : plus jamais spawnes
@alienNx
        ldx   gfxlock.frame.gameCount
        cmpx  #timestamp.DELETE_ALIEN_BODY
        blo   >
        jsr   DeleteObject
!       jmp   DisplaySprite
@alienN0
        lda   globals.bossDefeated
        bne   @frozen          ; boss killed: stop repainting, the overlay paint
        ldx   gfxlock.frame.gameCount ; persists and the tile-erase blits eat it
        ; LA PASSATION DES BANDES AU CORPS ENTIER. Les bandes d'apparition
        ; (subtypes 9-12) se suppriment a DELETE_ALIEN_BODY, camera a l'arret ;
        ; a partir de la, c'est CET objet qui repeint la face complete a chaque
        ; trame (le clear efface tout le champ, ce qui n'est pas repeint
        ; disparait). Avant : l'image pleine n'arrivait qu'a la reprise du
        ; scroll (MoveAlien) et le corps s'evanouissait pendant tout le combat.
        cmpx  #timestamp.DELETE_ALIEN_BODY
        blo   @checkEyes
        ldd   #Img_dobkeratops_alien
        std   image_set,u
@checkEyes
        ; le compte des nerfs vivants est RESIDENT (main), tenu par eyemgr —
        ; le timeout free-life et les morts fortes y vivent aussi
        lda   main.eyemgr.eyesAlive
        bne   >
        ; all nerves gone: alien moves out (arcade: background scroll resumes)
        lda   #rtnid.MoveAlien
        sta   routine,u
        ldd   #-$0018
        std   x_vel,u
!
        ; pas d'image avant la passation : rien a afficher
        ldd   image_set,u
        beq   @norender
        jmp   DisplaySprite
@norender
        rts
@frozen rts

MoveAlien
        lda   globals.bossDefeated
        bne   @frozen          ; boss killed: stop repainting, the overlay paint
        ldx   gfxlock.frame.gameCount ; persists and the tile-erase blits eat it
        cmpx  main.timestamp.moveAlienStart
        blo   >
        ldd   #Img_dobkeratops_alien
        std   image_set,u
        jsr   main.followDobkeratops
        ldd   main.dobkeratops.move.left      ; butee reached at the pixel? (frame-drop safe)
        bne   >
        ; butee : GEL affiche (les deux pages), pas de suppression — en
        ; overlay l'objet supprime disparait de l'ecran ; la v1 comptait sur
        ; la peinture persistante du bg-erase. Le corps fige reste jusqu'au
        ; nettoyage de fin de stage (MonsterKill part la meme trame).
        lda   #rtnid.FreezeAlien
        sta   routine,u
!       jmp   DisplaySprite
@frozen
        ; the alien was moving, so the two video pages hold positions ~1px apart. Redraw at the
        ; frozen position on BOTH pages before stopping, else it flickers until the boss-erase
        ; covers it (clean double-buffer stop, same idea as DeleteAlien at the butee).
        lda   #rtnid.FreezeAlien
        sta   routine,u
        jmp   DisplaySprite                  ; page 1 at the frozen position

DeleteAlien
        inc   routine,u
        jmp   DisplaySprite ; print last frame at the same location for double buffering
DeleteAlienEnd
        jmp   DeleteObject
FreezeAlien
        inc   routine,u                      ; -> FreezeAlienStop
        jmp   DisplaySprite                  ; page 2 at the same position -> both pages reconciled
FreezeAlienStop
        ; le corps gele CONTINUE de se peindre jusqu'au signal d'explosion —
        ; en overlay le clearBlast efface chaque trame ce qui ne se dessine
        ; plus (le wipe rectangle qui masquait tout est retire, 31/08) ; la
        ; machoire et la queue tiennent deja leur peinture sur ce meme signal
        lda   main.dobkeratops.explode
        bne   >
        jmp   DisplaySprite
!       rts                                  ; les explosions du corps prennent le relais
