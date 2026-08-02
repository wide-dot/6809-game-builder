;*******************************************************************************
; The resident engine — loaded once, never swapped
;
; This is the "common" half of the stage boundary. It holds the mechanisms
; (frame loop, scroll, object manager, waves, collision) and the state that has
; to outlive a stage change (score, lives). It does NOT hold the main loop :
; policy belongs to the stage, which is what lets the boundary be drawn without
; guessing at hooks.
;
; Two directions cross the boundary here :
;   - out : api.asm, included with ENGINE_RESIDENT set, so every name in it is
;           EXPORTed. A stage includes the same file and gets EXTERNALs.
;   - in  : stage-tables.asm, the tables the engine reads back from whichever
;           stage is loaded. They are EXTERNAL references, and the loader's
;           global relink repoints them at every scene.load — that repointing
;           is the whole stage exchange mechanism.
;*******************************************************************************

ENGINE_RESIDENT equ 1

 SECTION code

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "src/common/engine/stage-tables.asm"

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "gen/layout.asm"

; The scroll reads these two when InitScroll works out its default camera cap.
; A stage overrides the cap by writing scroll_max afterwards, which is how a
; per stage map width escapes an engine assembled once (the boss already used
; that door in v1, to freeze the camera at bossStopX).
tile_size       equ 12
viewport_width  equ 12*tile_size
map_width       equ 24*tile_size

 opt c,ct

;*******************************************************************************
; State that outlives a stage
;
; It lives here rather than in a stage precisely because a stage is swapped :
; anything the stage unit held would be overwritten by the next one. No
; ceremony is needed beyond that — the engine's region is never a load
; destination after boot, so these bytes are simply never written again.
;*******************************************************************************
game.score      fdb   0
game.lives      fcb   0
game.stage      fcb   0

; Le score du jeu, sur 24 bits par centaines de points comme en v1, et sa
; table de recompenses. AwardScore vit ici parce que le score survit aux
; stages, exactement comme les vies.
globals.score   fcb   0
                fdb   0
        INCLUDE "src/common/state/score.asm"

; Les listes de boites de collision. Elles sont resideNtes : un objet s'y
; inscrit a sa creation et s'en retire a sa mort, et le jeu en entier partage
; les memes quatre listes.
AABB_list_friend             fdb   0,0
AABB_list_ennemy             fdb   0,0
AABB_list_ennemy_unkillable  fdb   0,0
AABB_list_player             fdb   0,0
AABB_list_bonus              fdb   0,0

;*******************************************************************************
; L'échange de stage
;
; Cette routine DOIT être résidente : elle est appelée par le stage sortant,
; et le chargement de scène écrase précisément la région où ce stage vit. Le
; retour du scene.load se fait donc dans du code qui n'existe plus si on le
; laisse au stage. Depuis le moteur, il ne se passe rien de particulier.
;
; x = identifiant de fichier de la scène à charger.
;*******************************************************************************
game.stage.switch
        jsr   IrqOff                       ; le chargement parle au contrôleur disque
        ; Le loader vit dans une page commutée de la fenêtre DATA : il faut la
        ; monter pour l'atteindre. Le stage vient d'y effacer ses tampons
        ; d'écran, donc c'est une autre page qui est en place.
        _ram.data.set #loader.PAGE
        jsr   loader.ADDRESS+loader.scene.load.IDX
        jmp   stage.address                ; le premier octet du stage fraîchement chargé

;*******************************************************************************
; Terrain collision : mounting the per stage map
;
; The resident half reaches the mounted unit through self modified operands.
; v1 patched them from a macro expanded in the game mode ; here the patching
; is a resident routine, so those operands stay private to the engine and the
; interface keeps four names instead of a dozen.
;
; b = object id of the terrain unit in the stage's object index.
;*******************************************************************************
terrainCollision.init.do
        ldx   #Obj_Index_Page
        abx
        lda   ,x
        sta   terrainCollision.main.page
        sta   terrainCollision.main.xAxis.doRight.page
        sta   terrainCollision.main.xAxis.doLeft.page
        sta   terrainCollision.main.update.page
        ldx   #Obj_Index_Address
        aslb
        abx
        ldd   ,x
        std   terrainCollision.main.address
        addd  #3
        std   terrainCollision.main.xAxis.doRight.address
        addd  #3
        std   terrainCollision.main.xAxis.doLeft.address
        addd  #3
        std   terrainCollision.main.update.address
        rts

;*******************************************************************************
; The engine proper
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm"
        INCLUDE "engine/objects/collision/terrainCollision.main.asm"
        INCLUDE "engine/object-management/RunObjects.asm"
        INCLUDE "engine/object-management/ObjectWave-subtype.asm"
        ; L'appel d'objet factorise : un stage lance un objet nomme par son
        ; identifiant (le joueur, le HUD, la carte…) sans que chaque site
        ; d'appel reexpanse le montage de page.
        INCLUDE "engine/object-management/Obj_Run.asm"
        ; L'espace utilisateur de la page directe, ou vit l'OST du joueur :
        ; ObjectDp_Clear le remet a zero de dp a dp_extreg.
        INCLUDE "engine/object-management/ObjectDp.asm"
        INCLUDE "engine/object-management/ObjectMoveSync.asm"
        ; L'appel de sous-routine paginee, dont depend toute la chaine de tir
        ; (loadFirePreset, createFoeFire).
        INCLUDE "engine/object-management/RunPgSubRoutine.asm"
        INCLUDE "engine/math/RandomNumber.asm"
        INCLUDE "engine/graphics/animation/AnimateSprite.asm"
        INCLUDE "engine/graphics/animation/AnimateSpriteSync.asm"
        INCLUDE "engine/graphics/animation/moveByScript.asm"
        INCLUDE "engine/collision/collision.asm"
        INCLUDE "engine/graphics/codec/zx0_mega.asm"
        INCLUDE "engine/graphics/sprite/sprite-background-erase-ext-pack.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
