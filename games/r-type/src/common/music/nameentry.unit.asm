;*******************************************************************************
; La musique de la saisie des initiales — données seules
;
; Elle NE PEUT PAS rejoindre `common.music.ymm` (le bloc des quatre morceaux
; communs) : ce bloc va de $20BC à $2C08 et il est plein à l'octet près, la
; piste suivante commençant à $2C09. Même compressée (1 218 octets) celle-ci
; n'y tiendrait pas.
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
