;*******************************************************************************
; bootfade — la première scène : le menu TO8 vers le noir, puis le moteur
;
; Le moniteur affiche la page 0 avec sa palette, et tout ce que l'amorçage y
; écrit avant la première bascule du jeu se voit comme du bruit (le classement
; de scenes.boot y loge, l'init du title y efface le pool d'objets). La v1
; réglait ça dans son secteur de boot : un fondu de la palette vers le noir
; AVANT de lire le moindre secteur de jeu. Le secteur v2 n'a plus la place ;
; ceci est la même idée en scène.
;
; Cette unité est la scène par défaut du loader (loader.DEFAULT_SCENE_FILE_ID)
; et vit DANS LA RÉGION DU MOTEUR, à engine.address : elle est le premier code
; chargé et exécuté, et scenes.boot la recouvre entièrement. C'est légal parce
; qu'elle n'est plus exécutée quand le chargement commence — on ne RAPPELLE pas
; scene.load, on y SAUTE, avec l'entrée de la scène SUIVANTE empilée comme
; adresse de retour — même place, engine.address. Le rts du loader tombe sur
; ce qui vient de prendre la nôtre : le splash, qui fera de même vers le moteur.
;
; Cuite au build (bake), sans link data : elle ne nomme que des absolus, elle
; n'a donc aucun slot dans l'index du loader, rien à décharger. Aucune
; composition ne la tient — elle précède l'état « boot ».
;
; Plan : doc/plan-ecran-loading-2026-09.md, §10.
; Cas de migration : docs/lang/en/migration/boot-palette-fade.md.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.const.asm"

bootfade
        ldu   #palette.to8.monitor     ; la palette du menu, telle que la v1 l'a relevée
        ldd   #$0000                   ; vers le noir
        jsr   palette.fade             ; 15 trames, VBL par scrutation : pas d'IRQ ici

        ; Le loader vit dans une page de la fenêtre DATA : la remonter avant
        ; de lui parler (il vient de nous lancer, elle y est encore ; le geste
        ; ne coûte rien et ne suppose rien).
        _ram.data.set #loader.PAGE

        ldx   #engine.address          ; le « retour » de scene.load : l'entrée de
        pshs  x                        ;   la scène suivante, à la même place
        ldx   #scenes.splash           ; « WIDE DOT presents » (splash.unit.asm),
        jmp   loader.ADDRESS+loader.scene.load.IDX   ; qui chargera le moteur

        INCLUDE "engine/palette/palette-fade.asm"

 ENDSECTION
