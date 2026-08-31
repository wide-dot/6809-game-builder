;*******************************************************************************
; La collision terrain du stage 2 — unite paginee, gabarit du stage 1
;
; La moitie RESIDENTE (terrainCollision.main + init.do) est au moteur ; cette
; unite est la moitie MONTEE : le code de consultation, ses tables
; dimensionnees par lvlMapWidth, et les cartes du niveau — un seul plan servi deux fois, comme la v1
; (vérité : le terrain.asm v1 du stage, dans src/stages/02/terrain/).
;
; L'entree est le PREMIER octet : quatre jmp en tete du moteur inclus, que
; terrainCollision.init.do adresse par l'index d'objets a +0/+3/+6/+9.
;*******************************************************************************

terrainCollision.unit EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

lvlMapWidth equ 48 ; stage 02 width (terrain.asm v1)
; La borne d'impact, en px : la largeur de la carte de CE stage.
map_width   equ 96*12

terrainCollision.unit
        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   collisionMapBackground
        fdb   collisionMapForeground

;*******************************************************************************
; LA PORTE DE L'ORBE (31/08/2026). L'arcade rend NON-SOLIDES les tuiles de
; l'oeil quand il s'ouvre (verifie sous MAME, plan de solidite : la grille
; disparait sur l'oeil ouvert) — le couloir de tir vers l'orbe n'existe que
; fenetre ouverte, et les tirs meurent sur la chair le reste du temps. Ici :
; le rectangle de la boite de l'orbe (ecran 80±6, 103±6 — les constantes du
; gomander), 5 cellules de 3 px x 3 rangees de 6 px, bits effaces a
; l'ouverture, reposes a la fermeture. La carte est UNIQUE (fg = bg) : la
; porte vaut pour les tirs ET le vaisseau, comme en arcade. Les routines
; vivent ICI, dans la page de la carte : ecriture directe, et loadMap.fg
; fait tout le calcul octet+masque. Atteintes par RunPgSubRoutine depuis le
; gomander (Expose/Shield), sans parametre.
;*******************************************************************************
collision.orbGate.open  EXPORT
collision.orbGate.close EXPORT

collision.EYE_X equ 80                 ; le centre ecran de l'orbe
collision.EYE_Y equ 103                ; (= gomander/obj.asm, boite de l'orbe)
; LA PORTE ARCADE EXACTE : 4 cellules d'UNE rangee, juste AU-DESSUS de la
; boite de l'oeil (verifie sous MAME, plan de solidite : seuls ces 4 bits
; changent entre oeil ferme et oeil ouvert). La technique arcade est la
; plongee dans la gueule du tube et le tir a bout portant par cette breche
; — pas un couloir horizontal. 4 tuiles arcade de 8 px = 32 px arcade
; = 12 px v2 = 4 cellules de 3 px. La rangee : l'arcade ouvre les 8 px
; au-dessus de la boite et son tir descend de 4 px — le contact se fait au
; raccord. Nos rangees font 6 px et le tir n'a qu'1 px de demi-hauteur : la
; rangee STRICTEMENT au-dessus (90-95) laisserait passer le tir 1 px trop
; haut pour mordre la boite (97+). La porte s'ouvre donc sur la rangee du
; HAUT de la boite (96-101) : la breche par laquelle le tir CLIPPE l'orbe.
collision.GATE_X0 equ collision.EYE_X-6
collision.GATE_X1 equ collision.EYE_X+5
collision.GATE_Y  equ collision.EYE_Y-7

collision.orbGate.open
        ldb   #1
        bra   collision.orbGate
collision.orbGate.close
        clrb
collision.orbGate
        pshs  b                        ; 0 = refermer, 1 = ouvrir
        ldd   #collision.GATE_Y
        std   terrainCollision.sensor.y
        ldd   glb_camera_x_pos
        addd  #collision.GATE_X0
        std   terrainCollision.sensor.x
@cell   ldb   #1                       ; B = LE PLAN (1 = avant-plan) : loadMap
        jsr   terrainCollision.loadMap ;   charge Y lui-meme depuis .maps (un B
                                       ;   residuel y lisait un pointeur de
                                       ;   carte sauvage — gel de l'Init).
                                       ; Sortie : A = colonne, B = masque,
                                       ;   Y = rangee de la carte
        tst   ,s
        beq   @close
        comb
        leay  a,y                      ; ouvrir : le bit s'efface (traversable)
        andb  ,y
        stb   ,y
        bra   @next
@close  leau  collisionMapPristine-collisionMapForeground,y
        ldb   a,u                      ; refermer : l'octet d'ORIGINE revient,
        leay  a,y                      ; recopie depuis l'exemplaire vierge
        stb   ,y
@next   ldd   terrainCollision.sensor.x
        addd  #3                       ; la cellule suivante
        std   terrainCollision.sensor.x
        subd  glb_camera_x_pos
        cmpd  #collision.GATE_X1
        ble   @cell
        puls  b,pc

; La v1 pointe le MEME bin pour les deux plans de ce stage — le
; level2_bc.bin du dossier terrain est un orphelin qu'elle ne
; consomme jamais (son pas de ligne ne correspond d'ailleurs pas).
collisionMapBackground
collisionMapForeground
        INCLUDEBIN "src/stages/02/terrain/level2_fc.bin"

; L'EXEMPLAIRE VIERGE — la reference de la fermeture de porte : refermer,
; c'est recopier les octets d'origine, cellule par cellule. Idempotent dans
; les deux sens, aucun tampon de sauvegarde, aucun drapeau d'etat.
collisionMapPristine
        INCLUDEBIN "src/stages/02/terrain/level2_fc.bin"

 ENDSECTION
