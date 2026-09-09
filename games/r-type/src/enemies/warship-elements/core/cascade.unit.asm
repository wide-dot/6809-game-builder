;*******************************************************************************
; stage3.cascade — la cascade de mort du NOYAU du vaisseau, dans SON unite
;
; Le marcheur est commun (src/common/fx/bosscascade/obj.asm) ; la table est
; celle de ce boss (explosions.asm, GENEREE par tools/gen_core_death.py depuis
; 0x1000:80CE). Son propre direntry, comme celle du gomander : aucun couplage
; de label avec le cast — le noyau la fait naitre par l'index
; (ObjID_bosscascade, le slot commun 29), qui porte SA page.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, la table
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
bosscascade.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"      ; globals.tilesDrop (0 ici)

        INCLUDE "src/common/fx/bosscascade/obj.asm"
        INCLUDE "src/enemies/warship-elements/core/explosions.asm"

 ENDSECTION
