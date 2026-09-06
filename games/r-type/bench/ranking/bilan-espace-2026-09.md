# Ce que coûte la version du banc dans le jeu (06/09/2026)

Mesuré sur le jeu reconstruit avec l'unité de classement du jour (rapport
d'occupation, arènes lues dans le config).

## L'état des arènes concernées

| zone | taille | libre | où |
|---|---:|---:|---|
| arène `objects` (le résident paginé : overlay, HUD, joueur, armes…) | 9 pages | **2 879** épars — 165 sur la page de l'overlay ($05), un seul trou utile de 2 157 sur $17 | l'overlay fait 11 125 octets |
| arène `ranking` ($51C0-$6000) | 3 648 | **488** avec l'unité du jour (3 160 ; elle faisait 2 489 au commit) | résident, demi-page vidéo |
| région `stage` (page 1, $7C00 → témoin $87F2) | 3 058 | 809 (stage 3) à 1 172 (stage 8) | le main de chaque stage |
| arène `enemies`, page $0E | 16 384 | 2 357 | où `lib.patapata` (3 897) vit déjà |

## Le bilan de la version, poste par poste

| poste | delta | où |
|---|---:|---|
| déroulé du blast à 889 poussées (200 lignes) | **+356** | overlay, arène `objects` |
| retrait de `clearLines` (la conversion, ~40 o) et de `clearWindow` (~25 o) | −65 | overlay |
| deux points d'entrée fixes (plein écran depuis $BF41 ; champ 11-190 depuis $BDD8, entrée 89 poussées plus loin) | +20 | overlay |
| **net overlay** | **≈ +311** | il ne tient pas dans les 165 de sa page : le packer doit déplacer une petite unité de $05 vers le trou de $17 — 2 879 libres au total, c'est jouable mais c'est au build de le dire |
| unité de classement : émetteur, générateur arcade, tables de texte (glyphes 118, lignes 272, ancres 34) | +671 depuis le commit | arène `ranking`, il reste 488 |
| retrait du chemin « trois fenêtres » du jeu dans l'unité | −70 | arène `ranking` |
| retrait du tick de timeline dans `stage-main` (~35 o) et des tables (`clear.timeline.none` 6 o, stage 1 : 2 entrées × 6) | −50 par stage | région `stage` |
| `lib.patapata` chargé par la composition de classement (option A, décidée le 04/09) | 0 permanent | arène `enemies` |
| une ligne `ObjID_patapata` commune dans les huit index (id 32 partout) | ≈ +8 par stage | région `stage` |

Le seul poste qui pèse est le déroulé : **+311 octets dans l'arène la plus
disputée du jeu**. Tout le reste est neutre ou positif.

## Ce que le retrait de la fenêtre dynamique coûte au jeu

La timeline zappait les rangées de tuiles pleines, ~747 cycles chacune. Seul
le stage 1 en a une, avec **deux entrées** ; les sept autres tournent déjà
sur `clear.timeline.none`, la fenêtre pleine. La perte est donc marginale et
confinée au stage 1 ; le générateur `tools/gen_clear_timeline.py` et
`clear-timeline.asm` partent avec.

Deux points d'entrée suffisent parce que les deux usages sont FIXES : le
stage garde 11-190 (ses lignes de HUD au-dessus et en dessous ne doivent pas
être effacées), les écrans de classement prennent tout. Le title, qui posait
ses bandes par `clearLines`, passe sur l'entrée plein écran (il ne peint que
des sprites, et `clearTop` disparaît avec).

## Si on préfère ne pas payer les 311 octets

Garder 800 poussées et effacer les 20 lignes hors champ des écrans de
classement par le second point d'entrée appliqué… non : 180 lignes d'un
bloc est une limite du déroulé, pas de la fenêtre. L'alternative réelle est
de border les Pata-Pata au champ 11-190 (9 px perdus en haut et en bas) :
zéro octet, une entorse à la borne.

## FAIT le même jour (décision auteur : « Go », Pata-Pata en commun)

Le build a tranché : avec le Pata-Pata (3 897) et le déroulé (+336) l'arène
manquait de 37 octets à la frontière $1A80 ; **frontière à $1C00**, et il
reste 2 998 octets (2 394 sur $17). Le Pata-Pata est sur $0A, les lots se
sont repaquetés (cancer $0C, pstaff + scantfire $0E, scant $0F). L'unité de
classement fait 3 096 octets, l'overlay 11 461. Vérifié dans le jeu :
révélation, Pata-Pata sur la saisie, tableau à 14 824, continue, READY,
reprise ; au banc, révélation 24,6 fps, saisie 13,3.
