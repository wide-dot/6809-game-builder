;*******************************************************************************
; bossmusic — le marqueur qui declenche la musique du boss, porte de la v1
;
; La wave le seme a l'endroit du niveau ou la musique doit changer. Il ne fait
; qu'une chose : poser le drapeau que la boucle du stage releve, puis se
; supprimer. Le changement de morceau, lui, appartient au stage — le lecteur ne
; peut pas etre monte depuis un objet pagine.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
bossmusic.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
bossmusic.Object
        INCLUDE "src/common/flow/bossmusic/obj_bossmusic.asm"

 ENDSECTION
