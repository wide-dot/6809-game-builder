;*******************************************************************************
; gomander_cascade — la cascade de mort du Gomander, dans SON unite
;
; Le marcheur est commun (src/common/fx/bosscascade/obj.asm) ; la table est
; celle de ce boss (explosions.asm, GENEREE par tools/gen_gomander_death.py
; depuis 0x1000:5602). Son propre direntry : la page du cast est pleine (38
; octets libres au 08/09/2026), et l'objet n'a aucun couplage de label avec
; le reste du cast — le boss le fait naitre par l'index (ObjID_bosscascade),
; qui porte SA page.
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
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par decalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/02/objid.const.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"      ; globals.tilesDrop

        INCLUDE "src/common/fx/bosscascade/obj.asm"
        INCLUDE "src/enemies/gomander/explosions.asm"

 ENDSECTION
