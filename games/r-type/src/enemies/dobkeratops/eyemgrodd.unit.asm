;*******************************************************************************
; eyemgrodd — les bandes de nerf du dobkeratops, parite IMPAIRE
;
; La moitie decalee du dessin d'eyemgr : les deux jeux de bandes (ND0+ND1)
; depassent 16 Ko ensemble, chaque parite vit donc dans son unite avec le
; MEME hook (eyebands-draw.asm) et sa table. BuildSprites arrive ici par le
; cadre D1 du descripteur EMImg (page et adresse posees par le lien) quand
; l'ancre du boss est impaire — pendant le scroll d'approche uniquement, la
; camera s'arrete sur une ancre paire.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables et les images ensuite. Cf. docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
eyemgrD1.Draw   EXPORT

        INCLUDE "src/common/engine/api.asm"

main.eyemgr.status     EXTERNAL
main.eyemgr.drawPieces EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"

; l'ancre du corps, consommee par la table generee
eyemgr.X equ 1507

eyemgrD1.Draw
        INCLUDE "src/enemies/dobkeratops/eyebands-draw.asm"
        INCLUDE "src/enemies/dobkeratops/images/eyes-bands-nd1.tables.asm"

 ENDSECTION
