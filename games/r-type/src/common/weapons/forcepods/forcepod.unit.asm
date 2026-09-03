;*******************************************************************************
; Le force pod — le module blindé qui se colle au vaisseau
;
; C'est l'objet v1 `objects/player1/forcepods/forcepod.asm`. Ramassé par une
; boîte à option, il flotte, s'attache à l'avant ou à l'arrière du vaisseau,
; s'éjecte, encaisse les tirs et rend le feu selon le cristal acquis.
;
; IL NE VIT PAS DANS LE POOL : son OST est le slot statique `forcepodOST` de la
; zone réservée. La boîte à option le réveille en poussant sa routine de
; Dormant à Init ; le corps commun du stage l'amorce en Dormant à l'ouverture
; et au rechargement de checkpoint, comme la v1.
;
; Unité séparée de ses trois armes, bien qu'elles forment un tout : les quatre
; fichiers v1 nomment leur entrée `Object`, leurs tables `Routines`, et posent
; tous `AABB_0 equ ext_variables`. Les réunir demanderait de renommer, donc de
; perdre le 1:1. La v1 en fait quatre objets ; nous en faisons quatre unités.
;
; C'est du COMMUN : les sept game modes de la v1 le déclarent.
;
; L'entrée doit être le premier octet de l'unité.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

forcepod.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "src/common/player/player1.equ"
        INCLUDE "src/common/weapons/forcepods/forcepod.equ"
        INCLUDE "src/common/weapons/bitdevice/bitdevice.equ"  ; bitdev.rtnid.ActiveTick (reflets)
        ; Les offsets d'OST de l'éclat d'émission : le force pod le fait naître
        ; en s'attachant, et renseigne ses trois champs.
        INCLUDE "src/common/player/emitter-flash.equ"
        ; Le bruitage : le macro écrit la boîte aux lettres résidente, que le
        ; pilote dépile dans l'IRQ.
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"
        INCLUDE "src/stages/01/objid.const.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
Img_forcepod_0_0                 equ set_forcepod_0_0
Img_forcepod_0_1                 equ set_forcepod_0_1
Img_forcepod_0_2                 equ set_forcepod_0_2
Img_forcepod_0_3                 equ set_forcepod_0_3
Img_forcepod_0_4                 equ set_forcepod_0_4
Img_forcepod_0_5                 equ set_forcepod_0_5
Img_forcepod_1_0                 equ set_forcepod_1_0
Img_forcepod_1_1                 equ set_forcepod_1_1
Img_forcepod_1_2                 equ set_forcepod_1_2
Img_forcepod_1_3                 equ set_forcepod_1_3
Img_forcepod_1_4                 equ set_forcepod_1_4
Img_forcepod_1_5                 equ set_forcepod_1_5
Img_forcepod_2_0                 equ set_forcepod_2_0
Img_forcepod_2_1                 equ set_forcepod_2_1
Img_forcepod_2_2                 equ set_forcepod_2_2
Img_forcepod_2_3                 equ set_forcepod_2_3

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission et loadFirePreset.
forcepod.Object
        INCLUDE "src/common/weapons/forcepods/forcepod.asm"

 ENDSECTION
