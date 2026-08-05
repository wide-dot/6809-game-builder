;*******************************************************************************
; La boîte à option — ce qui arme le kit du joueur
;
; C'est l'objet v1 `objects/player1/pow/pow_optionbox.asm`, que le POW détruit
; fait naître. Ramassée, elle pose `player1+forcepodtype`, monte
; `player1+forcepodlevel`, la vitesse, ou débloque les missiles — et surtout
; c'est elle qui RÉVEILLE le force pod : l'OST statique `forcepodOST` dort en
; routine Dormant, elle y écrit Init et la boucle le fait naître à la trame
; suivante.
;
; Le force pod n'est pas encore monté. Écrire dans son OST reste sans danger :
; le bloc statique est mis à zéro à l'ouverture du stage, et personne ne le fait
; tourner tant que son identifiant n'est pas dans l'index d'objets. Le jour où
; il y entrera, la boîte à option l'armera sans qu'on y revienne.
;
; Unité séparée du POW, bien que les deux tiennent sur une page : cf. l'en-tête
; de `pow.unit.asm` — les deux fichiers v1 partagent les mêmes noms internes.
;
; C'est du COMMUN : les sept game modes de la v1 le déclarent.
;*******************************************************************************

powOptionbox.Object EXPORT

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
        INCLUDE "src/common/player/player1.equ"
        INCLUDE "src/common/weapons/forcepods/forcepod.equ"
        ; Le bruitage : le macro écrit la boîte aux lettres résidente, que le
        ; pilote dépile dans l'IRQ.
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"

; V2-DEVIATION : cf. pow.unit.asm — gfxcomp génère `set_<nom>`.
Img_pow_optionbox_0 equ set_pow_optionbox_0
Img_pow_optionbox_1 equ set_pow_optionbox_1
Img_pow_optionbox_3 equ set_pow_optionbox_3
Img_pow_optionbox_4 equ set_pow_optionbox_4
Img_pow_optionbox_7 equ set_pow_optionbox_7

; V2-DEVIATION : l'entrée v1 s'appelle `Object`.
powOptionbox.Object
        INCLUDE "src/common/pickups/pow/pow_optionbox.asm"

 ENDSECTION
