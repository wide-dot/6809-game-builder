;*******************************************************************************
; splash — « WIDE DOT presents », entre le fondu du boot et le moteur
;
; Deuxième scène de l'amorçage, même place et même mécanique que le fondu
; (bootfade.unit.asm) : alternative de la région du moteur, cuite, sans link
; data, seule dans sa composition, entrée à l'offset zéro. Le fondu l'a chargée
; par-dessus lui-même ; elle sera recouverte à son tour par scenes.boot.
;
; Son image vit en page 3 (boot.splash.a / .b, les deux plans bm16 chargés
; par la fenêtre cartouche), la page que le jeu affichera pendant tout
; chargement. Ici : page 3 à l'écran, fondu d'ENTRÉE du noir vers la palette
; de l'image, puis le saut dans scene.load(scenes.boot) avec boot.entry
; empilé — l'image reste à l'écran pendant tout le chargement du moteur, le
; title la noircit en première instruction et se révèle.
;
; Plan : doc/plan-ecran-loading-2026-09.md, §8 et §10.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.const.asm"

splash
        _gfxmode.setBM16               ; la machine est encore dans le mode du
                                       ;   moniteur : l'image est du BM16
        lda   #%11000000               ; page 3 à l'écran, bordure 0 — la
        sta   map.CF74021.SYS2         ;   palette est encore noire, rien ne se voit
        ldu   #splash.work             ; du noir...
        ldx   #Pal_splash              ; ...vers la palette de l'image
        jsr   palette.fade.to          ; 15 trames au plus, VBL par scrutation

        _ram.data.set #loader.PAGE     ; le loader, dans sa page de la fenêtre DATA

        ; scenes.boot vit dans le répertoire 0 ; l'amorçage (nous, le fondu)
        ; vient du répertoire 9. Le loader ne charge que dans le répertoire
        ; courant : le remonter d'abord.
        lda   #0
        jsr   loader.ADDRESS+loader.dir.load.IDX

        ldx   #engine.address          ; le « retour » de scene.load : boot.entry
        pshs  x
        ldx   #scenes.boot
        jmp   loader.ADDRESS+loader.scene.load.IDX

splash.work
        fill  0,32                     ; la palette de travail : noire au départ

        INCLUDE "engine/palette/palette-fade.asm"

 ENDSECTION
