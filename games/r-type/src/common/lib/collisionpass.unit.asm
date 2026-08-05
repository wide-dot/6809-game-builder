;*******************************************************************************
; La passe de collision — unité montée
;
; C'est le `obj_mainext` de la v1 : la liste des paires de listes AABB à
; confronter, et rien d'autre. Du calcul pur sur des listes RÉSIDENTES, donc
; page-neutre — le seul appelant est la boucle de stage, une fois par trame,
; par `paged.call`.
;
; Elle était résidente ; ses 184 octets sont rendus au pool d'objets. Voir
; docs/lang/fr/analyse-residente-2026-08.md, étape 5 du chemin vers 50 slots.
;
; L'entrée doit être le premier octet de l'unité.
;*******************************************************************************

COLLISION_PASS_UNIT equ 1       ; api.asm ne doit pas m'en donner l'EXTERNAL
Collision_Run EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"

;*******************************************************************************
; V2-DEVIATION vs v1 : deux passes manquent, faute des objets qui les peuplent.
; La liste AABB_list_forcepod n'est meme pas declaree (le force pod n'est pas
; porte) et WeaponContactTick est le contact force pod / bit device. Les lignes
; v1 restantes, dans l'ordre, pour le jour ou elles arrivent :
;       _Collision_Do AABB_list_forcepod,AABB_list_foefire
;       jsr   WeaponContactTick
;*******************************************************************************
Collision_Run
        _Collision_Do AABB_list_friend,AABB_list_ennemy
        _Collision_Do AABB_list_player,AABB_list_bonus
        _Collision_Do AABB_list_player,AABB_list_foefire
        _Collision_Do AABB_list_player,AABB_list_ennemy_unkillable
        _Collision_Do AABB_list_player,AABB_list_ennemy
        rts

 ENDSECTION
