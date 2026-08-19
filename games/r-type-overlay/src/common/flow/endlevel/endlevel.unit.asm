;*******************************************************************************
; endlevel — le séquenceur de fin générique, monté une fois pour tous les
; stages sans vrai boss
;
; Objet MONTE, pas créé : le stage l'appelle avec une commande en B (INIT,
; TICK ou BLIT) et il rend un statut — le protocole du stage 1, dont l'objet
; endstage reste le modèle (et le futur de chaque stage : un vrai boss
; remplacera ce séquenceur stage par stage, comme le Dobkeratops l'a fait).
;
; L'état qu'il partage vit dans le main du stage courant (main.endstage.*,
; noms du stage 1 — les mains sont des alternatives à la même destination,
; leurs exports partagent les noms) ; le re-link de chaque échange le
; repointe sur le stage fraîchement chargé.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
endlevel.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'etat resident du sequencement, dans le main du stage courant : l'objet
; le remet a zero (commande INIT) a l'ouverture du niveau et au rechargement
; de checkpoint.
main.endstage.counter          EXTERNAL
main.endstage.phase            EXTERNAL
main.endstage.scoreArmed       EXTERNAL
main.endstage.scoreDone        EXTERNAL

; La palette de noir, dans le main du stage avec celle du jeu : la sequence
; l'installe avant de rendre la main, pour que la coupure ne se voie pas.
Pal_black                      EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/flow/endlevel/endlevel.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8 : l'autopilote s'en sert.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour
; la frontiere de lien.
endlevel.Object
        INCLUDE "src/common/flow/endlevel/obj_endlevel.asm"

 ENDSECTION
