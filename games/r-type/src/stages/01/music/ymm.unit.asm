;*******************************************************************************
; La musique YM2413 — lecteur v2 et données, dans la même page
;
; Le lecteur est un module v2 conservé (KEPT-V2), donc l'appelant parle son
; dialecte : `_ymm.obj.play page,données,boucle,rappel` pour armer un morceau,
; `_ymm.frame.play page` une fois par trame. La v1 passait un INDEX dans une
; table `Snd_index` après avoir monté la page de l'objet ; la v2 nomme le
; symbole directement, donc la table disparaît.
; Cas de migration : docs/lang/en/migration/kept-v2-api.md
;
; Lecteur et données partagent la page : le macro n'en monte qu'une.
;
; La musique du niveau 1 est celle de l'arcade (« adnz »), portée telle quelle
; en .ymm ; les deux autres sont le boss et le jingle de fin de niveau, chargées
; avec elle parce que rien ne les rechargera au moment où elles serviront.
;*******************************************************************************

sounds.level1.ymm     EXPORT
sounds.boss.ymm       EXPORT
sounds.clearstage.ymm EXPORT

 SECTION code

sounds.level1.ymm
        INCLUDEBIN "src/stages/01/music/adnz/ymm/music.ymm"
sounds.boss.ymm
        INCLUDEBIN "src/common/flow/bossmusic/music/ymm/music.ymm"
sounds.clearstage.ymm
        INCLUDEBIN "src/common/flow/clearstage/music/ymm/music.ymm"

 ENDSECTION
