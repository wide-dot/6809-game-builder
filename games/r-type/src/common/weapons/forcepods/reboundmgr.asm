;*******************************************************************************
; Le laser rebond — LE RENDERER GROUPE de ses passagers
;
; Un laser rebond est une chaine : une tete, qui vole et porte la boite de
; collision, et des passagers qui n'ont aucune logique — ils lisent leur
; position dans l'anneau d'historique de la tete et se dessinent. Chaque
; passager coutait donc un OBJET GRAPHIQUE au moteur, et le plafond
; nb_graphical_objects (64) est ce qui a fait couper la longueur du laser a
; quatre segments au lieu des huit de la borne.
;
; Ici les passagers ne se dessinent plus eux-memes : ils PUBLIENT leur position
; dans un slot, et UN SEUL objet — la routine Render du laser, la septieme —
; les dessine tous en une passe. Vingt-et-un passagers pour un objet graphique.
;
; Modele : bugmgr (src/enemies/bug/mgr.asm), y compris son piege documente —
; le slot se prend AVANT de charger l'imageset, parce que les aides ecrasent X.
;
; PAS DE NOUVEL IDENTIFIANT D'OBJET : l'espace commun est plein (29 sur 29, le
; garde-fou d'objid-common.const.asm refuse le trentieme). Le renderer est donc
; une ROUTINE de plus du laser lui-meme, ce qui a un avantage : Img_Page_Index
; designe deja sa page, il n'y a rien a rapiecer.
;*******************************************************************************

RB.MAXSEG   equ 8       ; la borne s'arrete la, et NOTRE ANNEAU AUSSI : un
                        ; passager lit a bufferIndex - (childId*4 + 6), donc le
                        ; septieme (childId 6) recule de 30 octets dans un
                        ; anneau de 32. Le huitieme lirait une position PLUS
                        ; RECENTE que la tete et se collerait devant elle.
RB.NPASS    equ RB.MAXSEG-1        ; passagers par chaine (la tete est un OST)
RB.NCHAIN   equ 3                  ; haut, centre, bas
RB.SLOTSZ   equ 5                  ; [vivant, x_pixel, y_pixel, routine(2)]
RB.NSLOT    equ RB.NCHAIN*RB.NPASS

; slotMask (1, 2, 4) -> index de chaine (0, 1, 2). Une table de cinq octets
; coute moins qu'un decalage teste.
reboundmgr.chain.tbl
        fcb   0,0,1,0,2

reboundmgr.slots
        fill  0,RB.NSLOT*RB.SLOTSZ

;-------------------------------------------------------------------------------
; reboundmgr.reset — eteindre tous les slots
; Appele par l'orchestrateur au depart d'une volee : les trois chaines
; precedentes sont mortes, leurs slots n'ont plus a etre dessines.
;-------------------------------------------------------------------------------
reboundmgr.reset
        ldx   #reboundmgr.slots
        ldb   #RB.NSLOT
reboundmgr.reset.loop
        clr   ,x
        leax  RB.SLOTSZ,x
        decb
        bne   reboundmgr.reset.loop
        rts

;-------------------------------------------------------------------------------
; reboundmgr.SlotPtr — [y] = le slot du passager courant
; input REG : [u] l'OST du passager
; X PRESERVE : le site d'appel tient deja quelque chose dedans.
;-------------------------------------------------------------------------------
reboundmgr.SlotPtr
        pshs  x
        ldb   slotMask,u
        ldx   #reboundmgr.chain.tbl
        abx
        ldb   ,x                       ; 0, 1 ou 2
        lda   #RB.NPASS
        mul
        addb  childId,u
        adca  #0
        pshs  b
        lda   #RB.SLOTSZ
        ldb   ,s+
        mul
        addd  #reboundmgr.slots
        tfr   d,y
        puls  x,pc

;-------------------------------------------------------------------------------
; reboundmgr.publish — un passager se depose dans son slot au lieu de se dessiner
; input REG : [u] l'OST du passager, position et image_set deja poses
;
; C'est le remplacant de `jmp DisplaySprite` dans le tick des passagers. Le
; cadre est celui de DRS : x ecran + screen_left, y ecran + screen_top.
;-------------------------------------------------------------------------------
reboundmgr.publish
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  #screen_left
        tsta                           ; hors du cadre en octet : on cache
        bne   reboundmgr.publish.hide
        stb   reboundmgr.sx
        ; LE SLOT D'ABORD. SlotPtr preserve X, mais l'ordre reste celui de
        ; bugmgr : charger l'imageset ensuite, jamais avant (piege du 22/08 —
        ; un set charge trop tot partait ecrase et BuildSprites sautait dans le
        ; bloc d'instance).
        bsr   reboundmgr.SlotPtr       ; Y = le slot
        ldx   image_set,u
        beq   reboundmgr.publish.hide2 ; pas d'image : rien a publier
        lda   reboundmgr.sx
        ldb   y_pos+1,u
        addb  #screen_top
        bra   reboundmgr.RecPublish
reboundmgr.publish.hide
        bsr   reboundmgr.SlotPtr
reboundmgr.publish.hide2
        clr   ,y
        rts

;-------------------------------------------------------------------------------
; reboundmgr.RecPublish — remplir un slot, avec le meme cull que le moteur
; entree : [a] x ecran, [b] y ecran (cadre DRS), [x] l'imageset, [y] le slot
; L'imageset donne sa geometrie : +4 x_size, +5 y_size, +6 centre pair/impair,
; +11 x1, +12 y1, +14 la routine compilee.
;-------------------------------------------------------------------------------
reboundmgr.RecPublish
        pshs  a,b
        lda   ,s
        adda  11,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   reboundmgr.RecPublish.off
        adda  4,x
        cmpa  #screen_right-screen_left+1
        bhi   reboundmgr.RecPublish.off
        lda   1,s
        adda  12,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   reboundmgr.RecPublish.off
        adda  5,x
        cmpa  #screen_bottom-screen_top+1
        bhi   reboundmgr.RecPublish.off
        lda   ,s
        suba  6,x                      ; le centre pair/impair, comme le moteur
        sta   1,y
        lda   1,s
        sta   2,y
        ldd   14,x
        std   3,y
        lda   #1
        sta   ,y
        puls  a,b,pc
reboundmgr.RecPublish.off
        clr   ,y
        puls  a,b,pc

reboundmgr.sx   fcb 0
reboundmgr.di   fcb 0

;*******************************************************************************
; LE FAUX IMAGESET — ce que BuildSprites croit dessiner. Son entree compilee
; pointe sur DrawAll, qui dessine les vingt-et-un slots. La page n'a pas a etre
; rapiecee : le renderer porte l'identifiant du laser, donc Img_Page_Index le
; designe deja.
;*******************************************************************************
reboundmgr.FakeImg
        fcb   reboundmgr.FakeSub-reboundmgr.FakeImg,reboundmgr.FakeSub-reboundmgr.FakeImg
        fcb   reboundmgr.FakeSub-reboundmgr.FakeImg,reboundmgr.FakeSub-reboundmgr.FakeImg
        fcb   8,8,0
reboundmgr.FakeSub
        fcb   0
        fcb   reboundmgr.FakeMf-reboundmgr.FakeSub
        fcb   0
        fcb   reboundmgr.FakeMf-reboundmgr.FakeSub
        fcb   0,0
reboundmgr.FakeMf
        fcb   0                        ; page, posee a l'init du renderer
        fdb   reboundmgr.DrawAll

;-------------------------------------------------------------------------------
; reboundmgr.DrawAll — la passe de dessin, appelee par BuildSprites SANS OST
; A rebours, comme bugmgr : le plus ancien recouvre.
;-------------------------------------------------------------------------------
reboundmgr.DrawAll
        lda   #RB.NSLOT
        sta   reboundmgr.di
reboundmgr.DrawAll.loop
        dec   reboundmgr.di
        lda   reboundmgr.di
        ldb   #RB.SLOTSZ
        mul
        addd  #reboundmgr.slots
        tfr   d,x
        lda   ,x
        beq   reboundmgr.DrawAll.next
        ldd   1,x                      ; A = x_pixel, B = y_pixel
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine compilee consomme U
reboundmgr.DrawAll.next
        tst   reboundmgr.di
        bne   reboundmgr.DrawAll.loop
        rts

;-------------------------------------------------------------------------------
; Render — la septieme routine du laser : l'objet qui dessine tous les passagers
; Il ne bouge pas, ne touche rien, et vit tant qu'un slot reste allume.
;-------------------------------------------------------------------------------
Render
        lda   routine_secondary,u
        bne   reboundmgr.RenderLive
        inc   routine_secondary,u
        _GetCartPageA
        sta   reboundmgr.FakeMf        ; la page ou vit DrawAll
        ldd   #reboundmgr.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran : la boite est parquee
        lda   #120                     ; au centre, jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #7                       ; la priorite des segments
        stb   priority,u
        jmp   DisplaySprite
reboundmgr.RenderLive
        ldx   #reboundmgr.slots
        ldb   #RB.NSLOT
reboundmgr.RenderLive.loop
        lda   ,x
        bne   reboundmgr.RenderLive.seen
        leax  RB.SLOTSZ,x
        decb
        bne   reboundmgr.RenderLive.loop
        jmp   DeleteObject             ; plus personne : le renderer s'en va
reboundmgr.RenderLive.seen
        jmp   DisplaySprite
