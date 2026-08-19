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
; en .ymm.
;
; Le boss, le jingle de fin, le continue et le game over ne sont PLUS ici :
; ils vivent dans `common.music.ymm`, chargé une fois au boot en $20BC et
; jamais échangé. Ce bloc-ci ne porte que la piste du stage — d'où l'adresse
; $2C09, qui commence après le bloc commun.
;*******************************************************************************

sounds.level1.ymm     EXPORT

 SECTION code

sounds.level1.ymm
        INCLUDEBIN "src/stages/01/music/adnz/ymm/music.ymm"

 ENDSECTION
