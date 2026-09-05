;*******************************************************************************
; La musique de la saisie des initiales — données seules
;
; ELLE EST PERMANENTE, EN PAGE 26 AVEC LES AUTRES MUSIQUES (04/09/2026, plan de
; l'auteur). Le bloc musical de la page est calé en TÊTE : musiques communes
; $0000-$0B4D, créneau de stage $0B4D-$1B0D dimensionné sur la plus grosse
; (stage 1, 4 032 octets), puis cette piste $1B0D-$1FCF ; les tuiles coulent
; dans l'unique zone qui reste, $1FCF-$4000 (8 241 octets, il en reste 18 au
; pire stage). Chargée au boot, jamais échangée : la séquence GAME OVER ->
; classement -> CONTINUE se joue SANS AUCUN CHARGEMENT, comme sur la borne.
;
; Ce qui l'a rendu possible : le lecteur est devenu RÉSIDENT (page 1 fixe).
; Avant, il montait la page de ses données et y lisait son anneau, situé dans
; son propre code — les 1 057 octets du lecteur occupaient le milieu de la page
; et forçaient deux zones de tuiles autour. Partis, le bloc musical se tasse en
; tête et la place manquante (82 octets) est apparue.
;
; ELLE DOIT ÊTRE COMPRESSÉE EN ZX0 — `vgm2ymm -c zx0` — parce que le lecteur
; décompresse TOUJOURS : il n'y a pas de format brut côté 6809. Le codec par
; défaut du convertisseur est `none`, et il saute en silence toute conversion
; dont la sortie est plus récente que l'entrée. Le 04/09/2026 la piste a été
; livrée brute (3 588 octets) : le lecteur y lisait le troisième octet, $EF,
; comme une attente de 182 trames, puis bouclait sur du silence — « pas de
; musique à la saisie », alors que les bruitages, purement sous IRQ, passaient.
; Diagnostiqué sous toje en journalisant l'anneau du lecteur à chaque IRQ.
;
; Elle vit donc DANS ce créneau ($2C09), en alternative aux huit musiques de
; stage et à celle du title — comme elles, une seule à la fois. C'est légitime :
; l'écran de saisie n'existe qu'après le GAME OVER, quand la musique du stage
; s'est tue et que sa place est libre. La composition de classement du stage
; (`compositions.stageN.ranking`) déclare cet état-là, et la convergence du
; loader lâche la piste du stage avant de charger celle-ci.
;
; Source : `src/common/music/adnz/vgm/rtype-name-entry.vgm` (auteur, 04/09/2026),
; 38,7 s en boucle complète, convertie par `vgm2ymm -c zx0`.
;*******************************************************************************

sounds.nameentry.ymm EXPORT

 SECTION code

sounds.nameentry.ymm
        INCLUDEBIN "src/common/music/adnz/ymm/rtype-name-entry.ymm"

 ENDSECTION
