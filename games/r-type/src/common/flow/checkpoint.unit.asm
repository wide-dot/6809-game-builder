;*******************************************************************************
; Le checkpoint — unité montée
;
; Portage 1:1 de l'objet checkpoint de la v1 (`objects/checkpoint/checkpoint.asm`).
; UNE routine, DEUX appelants, exactement comme la v1 :
;
;   - l'ouverture du stage   : `_Obj_Run ObjID_checkpoint` juste après InitScroll
;                              (game-mode/01/main.asm:145) ;
;   - le rechargement après  : `_Obj_Run ObjID_checkpoint` après le fondu du
;     la mort                  message READY (game-mode/01/main.asm:380).
;
; Elle ne prend AUCUN paramètre : la position de reprise, elle la cherche
; elle-même dans `checkpoint.positions` à partir de `scroll_tile_pos`. À
; l'ouverture ce dernier vaut zéro, donc la recherche rend le premier point —
; c'est ainsi que la v1 obtient son pré-scroll d'ouverture sans code dédié.
;
; Notre portage avait commencé par en écrire la MOITIÉ sous le nom `preScroll`,
; à un moment où le checkpoint n'était pas encore porté, puis l'autre moitié
; ensuite : deux routines, deux effacements différents ($0000 entrelacé à
; l'init, $FFFF ici), un paramètre inventé. C'est la divergence de fond que ce
; fichier referme. Cas de migration : docs/lang/en/migration/checkpoint-is-one-routine.md
;
; C'est déplaçable hors du résident, et pour une raison qui se vérifie appel par
; appel : `ManagedObjects_ClearAll`, `EraseSprites_ClearAll` et
; `DisplaySprite_ClearAll` sont PAGE-NEUTRES, `ClearDataMem` et
; `_SwitchScreenBuffer` ne touchent que la fenêtre DONNÉES ($E7E5), `DrawTiles`
; RESTAURE la page de son appelant (`DrawTiles.restoredPage`), et
; `ObjectWave_Init` — le seul qui commute sans rendre — est appelé en `jmp`
; terminal, donc rien ne s'exécute après lui dans cette page.
;*******************************************************************************

CHECKPOINT_UNIT equ 1           ; api.asm ne doit pas m'en donner l'EXTERNAL
checkpoint.load      EXPORT
checkpoint.clearData EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "gen/layout.asm"

; Ce que le stage fournit, repointé à chaque chargement de scène.
checkpoint.positions EXTERNAL
stage.paletteFadeIn  EXTERNAL

;*******************************************************************************
; checkpoint.load — v1 `checkpoint.load`
;
; Trouve le dernier point de reprise <= la position atteinte, nettoie tout ce
; qui vit (objets, sprites, listes de collision, les deux tampons), rejoue le
; défilement jusqu'à cette position, ressort le joueur, arme le fondu d'entrée
; et RECALE LA VAGUE : l'horloge de niveau redevient position x 128 — 128 trames
; par tuile de 24 px, l'inverse exact de la vitesse de scroll (24 / 0,1875).
;*******************************************************************************
checkpoint.load
        clrb
        ldx   #checkpoint.positions
@loop   lda   b,x
        cmpa  scroll_tile_pos
        bhi   >
        incb
        bra   @loop
!       decb
        lda   b,x
        sta   checkpoint.load.a        ; V2-DEVIATION : la v1 nomme ces deux
        sta   checkpoint.load.b        ; opérandes @a et @b. Les deux expansions
                                       ; de macro intercalées plus bas rompent
                                       ; la portée des labels locaux de lwasm ;
                                       ; noms explicites, code identique.

        ; l'état objet
        jsr   ObjectDp_Clear
        jsr   ManagedObjects_ClearAll
        jsr   InitStack
        jsr   DisplaySprite_ClearAll
        jsr   EraseSprites_ClearAll
        jsr   Collision_ClearLists

        ; LES DEUX TAMPONS AU NOIR — en nibble 0. Les tuiles vides (le ciel)
        ; sont SAUTÉES par DrawTiles : ce qu'on efface ici EST le ciel pour tout
        ; le reste du niveau, et le champ d'étoiles ne dessine que sur les pixels
        ; de « ciel vierge », c'est-à-dire de nibble 0 (cf. starfield/obj.asm).
        ;
        ; L'ancienne palette avait DEUX noirs et le ciel occupait le second
        ; (index 15) : on effaçait alors à $FFFF, ce qui distinguait le ciel du
        ; noir du décor. La nouvelle palette n'en a qu'un — l'index 15 porte un
        ; vert clair réservé aux sprites propres au stage 1 (décision auteur,
        ; 16/08) — donc le ciel est le noir tout court.
        ;
        ; V2-DEVIATION : ancrage ABSOLU de la fenêtre données avant le premier
        ; effacement. `_SwitchScreenBuffer` est un toggle RELATIF (eor #1 /
        ; or #2) : il ne rend 2 ou 3 que si le registre porte déjà 2 ou 3. En v1
        ; c'était acquis — `gfxlock.bufferSwap.do` y écrivait $E7E5 à chaque
        ; trame. En v2 cette routine n'écrit que la page AFFICHÉE ($E7DD), et la
        ; fenêtre données est montée en absolu par `_gfxlock.on`. À l'entrée du
        ; stage elle porte encore la page du LOADER (game.stage.switch la monte
        ; et ne la rend pas) : le toggle donnait alors 7 puis 6, on effaçait deux
        ; pages étrangères et le pré-scroll partait dans le décor.
        ; C'est la leçon déjà écrite dans `_gfxlock.on` pour le PRC : sur un
        ; registre matériel dont on n'est pas propriétaire, on pose, on ne
        ; bascule pas.
        _ram.data.set #2
        ldx   #$0000
        jsr   ClearDataMem
        _SwitchScreenBuffer
        ldx   #$0000
        jsr   ClearDataMem
        _SwitchScreenBuffer

        ; le défilement rejoué jusqu'à la position de reprise
        lda   #0
checkpoint.load.a equ *-1
        jsr   checkpoint.scroll

        lda   #ObjID_Player1
        sta   player1+id

        jsr   stage.paletteFadeIn

        ; la vague sur l'horloge de la position retrouvée
        ldd   #$0000
        std   gfxlock.frameDrop.count_w
        lda   #128
        ldb   #0
checkpoint.load.b equ *-1
        mul
        std   gfxlock.frame.count
        std   gfxlock.frame.lastCount
        std   gfxlock.frame.gameCount
        jmp   ObjectWave_Init

;*******************************************************************************
; checkpoint.clearData — les 16 Ko de la fenêtre données d'un coup
;
; La v1 l'appelle en RÉSIDENT (`jsr ClearDataMem`) au rechargement de
; checkpoint, juste avant d'afficher READY / GAME OVER (main.asm:319) : sans lui
; le décor du stage reste visible derrière le message — la v1 ne compte pas sur
; la palette pour l'éteindre, elle efface.
;
; V2-DEVIATION : la routine vit ici et non dans le résident (les trois seuls
; appelants sont dans cette page ou la visent), et la couleur passe par U — X
; est pris par `paged.call` pour l'adresse d'entrée.
;*******************************************************************************
checkpoint.clearData
        tfr   u,x
        jmp   ClearDataMem

;*******************************************************************************
; checkpoint.scroll — v1 `checkpoint.scroll`
;
; Rejoue le défilement jusqu'à la position demandée, de sorte que le viewport
; soit peint EN ENTIER dans LES DEUX tampons. Le premier DrawTiles ordinaire ne
; trace que les colonnes de la position courante ; sans ce rejeu, la rangée
; verticale de fond — celle qui porte le ciel — n'atteint jamais l'écran, et le
; champ d'étoiles, dont tout le test tient sur « ce pixel est-il du ciel »,
; ne dessine rien.
;
; Le principe : on part d'un viewport large de zéro colonne, calé à droite, et
; on avance de 4 px vers la gauche en élargissant d'une colonne tous les trois
; pas. Chaque colonne est donc peinte à chacune de ses sous-positions,
; exactement comme si elle était entrée par la droite.
;
; A = position d'entrée, en tuiles de collision (24 px)
;*******************************************************************************
checkpoint.scroll
        sta   scroll_tile_pos              ; les tuiles de collision font 24 px
        asla                               ; les tuiles tracées en font 12
        sta   @a
        ldb   scroll_vp_v_tiles
        aslb
        addb  scroll_vp_v_tiles            ; position x hauteur x 3 o (page, adresse)
        mul
        std   scroll_map_pos
        lda   #0
@a      equ   *-1
        ldb   scroll_tile_width
        mul
        std   glb_camera_x_pos
        std   glb_camera_x_pos_old
        subd  #1
        std   buffer_x_pos
        std   buffer_x_pos+2

        lda   scroll_vp_h_tiles            ; on emprunte les deux paramètres de
        ldb   scroll_vp_x_pos              ; viewport, rendus à la fin
        std   @d
        lda   #0
        sta   scroll_vp_h_tiles
        sta   scroll_tile_pos_offset
        sta   scroll_tile_pos_offset24
        lda   #8+144-4                     ; calé à droite du viewport
        sta   scroll_vp_x_pos
        lda   scroll_map_page_even
        sta   tile_buffer_page
        ldx   scroll_map_even
        stx   tile_buffer
@loop1
        lda   #3
        sta   @cpt
        inc   scroll_vp_h_tiles
@loop2
        lda   #1
        sta   glb_camera_move
        jsr   DrawTiles
        _SwitchScreenBuffer
        jsr   DrawTiles
        _SwitchScreenBuffer
        lda   scroll_vp_x_pos
        suba  #4
        sta   scroll_vp_x_pos
        dec   @cpt
        bne   @loop2
        cmpa  #4
        bne   @loop1
        ldd   #0
@d      equ   *-2
        sta   scroll_vp_h_tiles
        stb   scroll_vp_x_pos
        rts
@cpt    fcb   0

        INCLUDE "engine/ram/ClearDataMemory.asm"

 ENDSECTION
