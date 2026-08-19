;*******************************************************************************
; Les musiques COMMUNES aux huit stages — données seules, résidentes
;
; Quatre morceaux qu'aucun stage ne possède en propre : le boss, le jingle de
; fin de niveau, le continue et le game over. Ils vivaient recopiés dans les
; sept unités `src/stages/NN/music/ymm.unit.asm` — 1 722 octets de boss et de
; clearstage dupliqués sept fois sur la disquette, et la fenêtre musicale du
; stage 1 pleine à l'octet près, ce qui interdisait d'y ajouter quoi que ce
; soit. Un seul exemplaire, chargé au boot, jamais échangé.
;
; La place : le lecteur YMM ne monte QU'UNE page (`_ymm.frame.play`), donc
; toute donnée musicale vit en page $1A avec lui. Le bloc s'installe juste
; après le lecteur ($1C9B+1057 = $20BC) et les pistes propres à un stage
; commencent après lui ($2C09) — un stage et le title sont des alternatives à
; cette adresse-là, ce bloc-ci n'est l'alternative de personne.
;
; Dialecte v2 (docs/lang/en/migration/kept-v2-api.md) : le symbole nomme les
; données, la table Snd_index de la v1 disparaît.
;*******************************************************************************

sounds.boss.ymm       EXPORT
sounds.clearstage.ymm EXPORT
sounds.continue.ymm   EXPORT
sounds.gameover.ymm   EXPORT

 SECTION code

sounds.boss.ymm
        INCLUDEBIN "src/common/flow/bossmusic/music/ymm/music.ymm"
sounds.clearstage.ymm
        INCLUDEBIN "src/common/flow/clearstage/music/ymm/music.ymm"
sounds.continue.ymm
        INCLUDEBIN "src/common/music/adnz/ymm/continue.ymm"
sounds.gameover.ymm
        INCLUDEBIN "src/common/music/adnz/ymm/gameover.ymm"

 ENDSECTION
