;*******************************************************************************
; bink — ennemi porté de la v1
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

bink.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

bink.Object
        INCLUDE "src/enemies/bink/bink.body.asm"

 ENDSECTION
