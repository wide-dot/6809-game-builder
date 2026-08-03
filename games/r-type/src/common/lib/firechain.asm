;*******************************************************************************
; La chaîne de tir ennemi — les deux sous-routines paginées, et leurs tables
;
; Ce sont les deux objets `global/objects/` de la v1 (createFoeFire,
; loadFirePreset). Ni l'un ni l'autre n'a d'OST : ce sont des sous-routines
; qu'un ennemi atteint par `RunPgSubRoutine`, qui monte leur page et leur passe
; un paramètre dans A. La v1 devait les déclarer « objets » pour que son
; allocateur les place ; en v2 c'est l'index d'objets qui porte leur page et
; leur adresse, et le mécanisme est le même.
;
; Les deux sont dans la MÊME unité, alors que la v1 en faisait deux fichiers de
; propriétés : ce sont deux entrées de la même page, chacune avec son
; identifiant, et le code n'en sait rien. Ce qu'elles pèsent, ce sont surtout
; leurs deux tables — 448 et 512 octets de presets d'arcade.
;
; Ce qu'elles empruntent au moteur résident : `setDirectionTo` (la v1 l'inclut
; dans son main, alors que createFoeFire qui l'appelle est monté — le lien
; remet les deux bouts en face), `FoeFireTarget`, `LoadObject_x`, `RandomNumber`.
;*******************************************************************************

createFoeFire         EXPORT
loadFirePreset.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les champs de tir de l'OST : des alias sur les champs génériques,
        ; propres à r-type.
        INCLUDE "src/common/lib/object.const.asm"
        ; Les variables inter-main, en équates absolues dans la zone réservée
        ; `globals` : loadFirePreset lit la difficulté. Elles ne franchissent
        ; pas le lien, ce sont des adresses fixes partagées à l'assemblage.
        INCLUDE "src/common/state/variables.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes :
        ; createFoeFire pose `ObjID_foefire` dans l'OST qu'il vient d'allouer.
        INCLUDE "src/stages/01/objid.const.asm"

        INCLUDE "src/common/lib/createFoeFire.asm"

; V2-DEVIATION: l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission.
loadFirePreset.Object
        INCLUDE "src/common/lib/loadFirePreset.asm"

 ENDSECTION
