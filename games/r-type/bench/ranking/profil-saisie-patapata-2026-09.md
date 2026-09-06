# La saisie avec les Pata-Pata : profil et axes d'amélioration (05/09/2026)

Mesures sur le banc : `tools/profile.py` (200 trames, 4 000 000 de cycles,
symbolisé par `tools/symbolize.py`, préfixe p3), `tools/fps.py` (10,6 fps
moyens, soit 42 boucles dans la fenêtre) et `tools/patacount.py` (le pool
d'objets sondé toutes les 10 trames pendant 600 trames).

## Combien de Pata-Pata

| | |
|---|---|
| émission (arcade 0xFAE1, portée telle quelle) | un tirage toutes les 8 trames, une chance sur deux : **3,1 naissances/s** |
| vivants à la fois | **12 en moyenne, 17 au plus** (4 au départ, palier vers 15-16 après 5 s) |
| durée de vie déduite | 12 / 3,1 ≈ **3,9 s** par Pata-Pata (son script de vol) |
| plafond du pool | 60 objets : aucun risque d'épuisement |

## Le budget d'une boucle (95 000 cycles = 5 trames)

| poste | cycles | part | détail |
|---|---:|---:|---|
| trois blasts d'effacement | 27 500 | 29 % | 22 500 pour 9-188, ~2 500 pour les deux bandes, ~2 500 de pose des fenêtres et d'appels paginés |
| repeindre le texte (`ranking.in.paint`) | 30 000 | 31 % | titre 5 800 (21 cases), lignes 8 200 (32 cases + 2 conversions), bas 7 300 (32 cases), lettres et curseur ~1 700, le reste en boucles de cases |
| scripts des Pata-Pata (`RunObjects` → `moveByScript`) | 11 500 | 12 % | **≈ 950 par Pata-Pata** : l'interprète déroule 2 commandes × frame-drop, avec ses montages de page |
| sprites des Pata-Pata (`BuildSprites`) | 5 700 | 6 % | **≈ 480 par Pata-Pata** |
| attente de la trame (oisif) | 10 500 | 11 % | la quantification : 5 trames font 100 000 |
| divers (manette, émetteur, verrou) | ~10 000 | 10 % | |

Un glyphe compilé vaut ~125 cycles ; une case du texte en coûte ~250 :
**la moitié du texte est de la comptabilité** (boucle de cases, `mul` du
slot, chaînes d'appels), pas du dessin.

Les fps sont quantifiés : 50/n. Marches : 4 trames = 80 000 (12,5 fps),
3 trames = 60 000 (16,7 fps, la saisie sans Pata-Pata).

## Les axes, chiffrés

| axe | gain par boucle | effet | fidélité |
|---|---:|---|---|
| **A. Moins de Pata-Pata** — tirage à une chance sur quatre (`bitb #%01100000` ou un cran de plus) : 6 vivants au lieu de 12 | −8 500 | 95 → 86 k : **aucune marche franchie seul** | densité arcade divisée par deux |
| **B. Peintre de texte à plat** — ancres écran précalculées par case, une chaîne = un `jsr` par glyphe sans `mul` ni chaîne d'appels, chiffres convertis à l'entrée (le score ne change plus) | −15 000 à −18 000 | 95 → 77-80 k : **4 trames, 12,5 fps** | aucune |
| A + B | −25 000 | 70 k : 4 trames, marge pour les pics à 17 Pata-Pata | densité /2 |
| **C. Écran statique + effacement ciblé** — le texte peint une fois par tampon ; par trame, seuls les rectangles quittés par les Pata-Pata sont effacés (12 × ~200 octets ≈ 14 k) et les cases de texte qu'ils couvrent repeintes | −38 000 | 57 k : **3 trames, 16,7 fps** | aucune |
| D. Bandes 0-8 et 189-199 rendues au blast unique — ordonnées bornées à 9-188 | −3 000 | rien seul | 9 px de haut et de bas perdus |
| E. Script des Pata-Pata moins cher (moteur : `moveByScript` sans remontage de page par commande) | −5 000 ? | rien seul | aucune, mais c'est l'engine |

Lecture : **B est le levier sans coût de fidélité**, et il suffit pour la
marche des 4 trames ; C est celui qui rend la saisie aussi fluide que sans
Pata-Pata, mais il remplace « effacer tout, repeindre tout » par un
effacement ciblé — c'est un changement de modèle pour cet écran, à
décider. A n'apporte rien sans B ; avec B il donne la marge quand la
densité monte à 17.

Rappel : le plafond de ces écrans reste le blast (25 fps).

## Expérience : la saisie sans son texte (même jour)

`python3 gen-config.py --no-text` pose `RANKING_TEXT_OFF` : `ranking.in.paint`
ne peint rien, restent les trois blasts et les Pata-Pata. Relevé
(`fps-notext.png`) : **15,5 fps en moyenne, de 26 à 4 Pata-Pata jusqu'à
10 à 17**. Le texte coûte donc bien une marche et demie (10,6 → 15,5), et
la densité des Pata-Pata fait varier le reste du simple au double : c'est
elle qui fixe le plancher, le texte la moyenne. Film : `dist/ranking-notext.mp4`.

Précision demandée par l'auteur : oui, le score est reconverti à CHAQUE
trame aujourd'hui (deux `ranking.digits7` par trame sur cet écran, dix sur
le tableau) — c'est ce que l'axe B corrige en convertissant à l'entrée.

## Périmètre banc : un seul blast de 200 lignes (même jour, décision auteur)

`CLEARBLAST_200` (bench uniquement) porte le déroulé à 889 poussées, posées
depuis $BF41 pour que l'octet en trop tombe après le tampon : un appel
efface tout, la pose de fenêtre est unique. Gain mesuré : ~1 500
cycles par boucle, pas de marche franchie (saisie 10,1-10,6 fps selon la
densité). L'axe D disparaît du tableau. Bug attrapé au passage : mon
`ranking.clear.at` pose la fenêtre PUIS enchaîne dans le blast — l'appeler
puis rappeler le blast faisait deux effacements par trame (7,6 fps).
