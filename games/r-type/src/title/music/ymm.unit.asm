;*******************************************************************************
; La musique YM2413 du title — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui. La place
; attitrée est CELLE DU BLOC MUSICAL DES STAGES ($1A/$20BC) : un title ne
; coexiste jamais avec un stage, les deux fichiers sont des alternatives —
; exactement comme les graphismes du title occupent les pages des tuiles.
;
; Dialecte v2 (docs/lang/en/migration/kept-v2-api.md) : le symbole nomme les
; données, la table Snd_index de la v1 (music/ymm.asm, gardé en référence)
; disparaît.
;*******************************************************************************

sounds.title.ymm EXPORT

 SECTION code

sounds.title.ymm
        INCLUDEBIN "src/title/music/adnz/ymm/music.ymm"

 ENDSECTION
