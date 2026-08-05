;*******************************************************************************
; L'initialisation du niveau 1 — objet monté
;
; C'est la séquence d'ouverture du niveau : elle place le joueur, déroule ses
; phases, puis se supprime. La v1 en fait un OBJET (`_Obj_Run ObjID_LevelInit`,
; game-mode/01/main.asm:133) et le range dans une page à lui ; notre portage
; l'avait laissé résident dans la région du stage, où ses 136 octets sont chers.
;
; Elle est propre au niveau — d'où une région dans la page du terrain, qui est
; déjà la page échangée par stage.
;
; L'entrée doit être le premier octet de l'unité.
;*******************************************************************************

initlevel1.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/object-management/Obj_Run.macro.asm"
        INCLUDE "engine/objects/palette/fade/fade.equ"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "src/stages/01/map/intro/map.const.asm"

STAGE_ID equ 1

; Ce que l'init emprunte au STAGE, repointe a chaque chargement de scene.
Pal_black            EXTERNAL
stage.paletteFadeIn  EXTERNAL
stage.userIRQ        EXTERNAL
stage.setup          EXTERNAL   ; reste dans le stage, cf. main.asm
sounds.level1.ymm    EXTERNAL
stage.music          equ sounds.level1.ymm
starfield.init       EXTERNAL
ymm.obj.play         EXTERNAL
        INCLUDE "gen/layout.asm"
        INCLUDE "gen/stages/01/pages.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"
        INCLUDE "src/stages/01/objid.const.asm"

        INCLUDE "src/stages/01/init.asm"





 ENDSECTION
