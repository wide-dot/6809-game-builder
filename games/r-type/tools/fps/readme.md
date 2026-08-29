# Les relevés de cadence

Les mesures elles-mêmes, gardées ici parce que `dist/` est gitignoré : le
relevé du stage 3 du 20/08/2026 a été perdu de cette façon, et la seule
trace qu'il en restait était les chiffres recopiés dans un message de
commit. Un relevé coûte plusieurs minutes d'émulation ; une comparaison
avant/après n'a de sens que si le « avant » existe encore.

Un fichier par relevé, nommé `stage<N>-<date>.csv`. Une ligne par fenêtre
de 50 trames vidéo (1 seconde) : `trame, seconde, camera, boucles, fps`.

## Refaire un relevé

```bash
TOJE_FAST=1 STAGE=1 STAGE_FRAMES=14000 python3 tools/warship_fps.py dist/to8.fd
```

Sortie dans `dist/stage<N>-fps/` (csv + svg + resume.json). Copier le csv
ici pour le garder. `STAGE_FRAMES` doit couvrir le niveau entier — la
valeur par défaut (8000) tronque le stage 1, qui en demande ~13 500.

## Retracer un graphe sans remesurer

```bash
python3 tools/fps_plot.py tools/fps/stage1-2026-08-22.csv "titre" --vs tools/fps/<ancien>.csv
```

## Les conditions, à garder identiques des deux côtés d'une comparaison

- `cheat.invincible` armé (le relevé le vérifie et refuse de tourner sans) ;
- aucune entrée manette ;
- `bench.SCROLL_VEL` inchangé : les horodatages des vagues sont des trames
  d'arcade calées sur cette vitesse ;
- turbo (`TOJE_FAST=1`) : il ne change ni les instructions ni les cycles.

## Lire les chiffres sans se tromper

La moyenne globale imprimée par l'outil **mélange trois régimes** et ne veut
rien dire telle quelle :

| Régime | Comment le reconnaître |
|---|---|
| jeu réel | 6 à 12 fps |
| boucle à vide (fin de niveau) | ~50 fps — rien à rendre |
| chargement / passation | 0 fps |

Le chiffre à comparer est celui du **jeu réel**, et de préférence phase par
phase. La découpe en phases du traceur repose sur un plateau de caméra
*avant* la borne du niveau : elle fonctionne au stage 1 (plateau du boss à
1396, borne à 1440), pas aux stages 3 et 7 dont le plateau est *sur* la
borne — là, le graphe rend une phase unique et son encadré « creux
soutenu » vise la cadence ordinaire.

## Le témoin ne s'écrit pas en dur

`warship_fps.py` lisait `bench` à l'adresse littérale `$87DB`, périmée de 23
octets depuis que l'unité résidente du stage 3 a changé de taille. Corrigé le
29/08 : l'adresse vient de `gen/stages/NN/build/stageNN-main.lwmap`, comme
dans `warship_video.py`. Un relevé antérieur à cette date peut avoir mesuré
autre chose que ce qu'il annonce — les trois CSV du 22/08 ont été pris quand
`$87DB` était encore juste.

## L'état au 29/08/2026 — stage 3, vaisseau complet

| Régime | 22/08 (coque seule) | 29/08 (67 pièces) |
|---|---|---|
| **jeu réel** | **9,60** fps (116 fenêtres) | **6,62** fps (117 fenêtres) |
| médiane | 10,0 | 7,0 |
| min | 8,0 | 5,0 |

La chute de ~3 fps n'est pas une régression : c'est le prix des **67 pièces du
vaisseau**, qui n'existaient pas le 22/08 (la coque défilait seule). Le pic
mesuré est de 44 pièces vivantes simultanément, dont 28 dessinent.

C'est ce relevé qui sert de **référence avant le manager de tirs**
(`doc/analyse-bullet-manager.md`) : `stage3-2026-08-29.csv`, tracé dans
`stage3-2026-08-29.svg`.

## Le manager de tirs, mesuré (29/08/2026)

| Régime jeu réel | avant (`stage3-2026-08-29`) | avec manager (`-mgr`) |
|---|---|---|
| moyenne | 6,62 fps | **6,73 fps** |
| médiane | 7,0 | 7,0 |

Par tranche de caméra (le seul rapprochement honnête), le delta va de −0,1 à
+0,36 fps : **un gain réel mais marginal**, dans l'épaisseur du trait. C'est
conforme à l'analyse (`doc/analyse-bullet-manager.md`) : le gain est
proportionnel au nombre de balles vivantes, et le stage 3 n'en tient que 8 à
16 aux pics — son goulot est le blast de la couche mscroll, pas les tirs.

Ce que le manager rapporte vraiment sur ce stage n'est pas de la cadence :
c'est **24 slots d'objets rendus au pool** (une balle ne coûte plus un OST de
117 octets mais 21 octets résidents), sur un stage dont le vaisseau seul
culmine à 44 pièces sur 60 slots. Le verdict cadence se rejouera sur un stage
saturé de tirs.

## L'état au 22/08/2026

| Stage | Jeu réel | Traversée | Boss | Durée |
|---|---|---|---|---|
| 1 | 9,29 | 9,55 | 7,71 | 265 s (caméra 0→1440) |
| 3 | 9,59 | 9,59 | 9,69 | 142 s |
| 7 | 8,94 | 8,63 | — | 139 s |

Comparaison avec le 19/08 (commit 3253c387, chiffres du message, outil
`ci/toje-bench/fps_curve.py`) sur le stage 1 : ouverture 15,2 → 16,6,
défilement 9,2 → 9,55, boss 7,7 → 7,71. Le creux du niveau 1 est à
6,0 fps vers la caméra 582-618, la même zone qu'à l'époque.

Note : la passation stage 1 → stage 2 prend ~20 s de chargement, ce qui
déclenche à tort le détecteur d'arrêt de `warship_fps.py` (20 fenêtres
muettes). Le stage n'est pas bloqué — vérifié, il bascule à la trame 13 500.
