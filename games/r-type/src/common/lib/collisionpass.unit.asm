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
        ; Le contact arme lit les trois OST statiques et leurs identifiants de
        ; routine : le force pod et les deux bit devices.
        INCLUDE "src/common/weapons/forcepods/forcepod.equ"
        INCLUDE "src/common/weapons/bitdevice/bitdevice.equ"

;*******************************************************************************
; La passe complete de la v1 (obj_mainext.asm:47-58) : les six paires de listes,
; puis le contact arme. Les deux dernieres lignes sont arrivees le 2026-08-05
; avec le force pod et les bit devices — jusque-la, ni la liste ni les OST
; qu'elles lisent n'existaient.
;*******************************************************************************
Collision_Run
        _Collision_Do AABB_list_friend,AABB_list_ennemy
        _Collision_Do AABB_list_friend,AABB_list_target ; points faibles : armes seulement
        _Collision_Do AABB_list_player,AABB_list_bonus
        _Collision_Do AABB_list_player,AABB_list_foefire
        _Collision_Do AABB_list_player,AABB_list_ennemy_unkillable
        _Collision_Do AABB_list_player,AABB_list_ennemy
        _Collision_Do AABB_list_forcepod,AABB_list_foefire ; le pod arrete les tirs
        ; Contact arme (force pod + deux bit devices) contre les ennemis : ce
        ; n'est PAS generique — une porte globale au 1/16e de trame pour les
        ; ennemis a points de vie, contact immediat pour ceux qui tombent d'un
        ; coup, et les armes ne sont jamais consommees.
        jsr   WeaponContactTick
        rts

; V2-DEVIATION : la v1 declare cet octet dans le ram_data de son game mode ;
; ici il appartient a l'unite qui l'ecrit — WeaponContactTick est son seul
; lecteur. Une unite est CHARGEE, donc ce `fcb 0` arrive vraiment a zero,
; contrairement a un bloc reserve.
weaponGateAccum fcb 0            ; +frameDrop.count par trame, tire tous les 16

        INCLUDE "src/common/lib/weaponcollide.asm"

 ENDSECTION
