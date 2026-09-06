# Le banc des écrans de classement

Un game mode réduit à l'os, à la place du title, qui enchaîne en boucle la
séquence de fin de partie — STAGE SCORE, saisie des initiales, RANKING —
sur un crédit fictif (100 000 points au stage 1). Rien d'autre n'est
chargé : le résident et la musique de saisie, ce que `scenes.boot` apporte.
Le build prend **2 secondes** au lieu de 35, et l'écran est atteint dès le
boot, sans title ni mort à jouer.

- `main.asm` : le game mode du banc (ouverture comme le title, puis
  `game.ranking.run` en boucle, une seconde de noir entre deux tours).
- `gen-config.py` : le `to8.config.xml` du banc est **dérivé** de celui du
  jeu (même carte mémoire, mêmes fichiers communs, neuf compositions
  identiques parce que le moteur les nomme). Le rejouer après tout
  changement du config du jeu : `python3 gen-config.py`.
- `engine`, `src`, `reference` : des liens vers les sources du jeu
  (gitignorés, à recréer dans un clone : `ln -s ../../../../engine engine ;
  ln -s ../../src src ; ln -s ../../reference reference`).

Build, depuis ce répertoire :

    java -Dbasedir=<racine du repo> -cp "../../../../repo/*" \
         com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml

Témoins (`bench.const.asm`) : `bench.magic` = $CA une fois le banc
démarré, `bench.frames` = le numéro du tour en cours. Le pool d'objets est
VIDE ici — ce que le jeu y laisse à la mort (ennemis, tirs) n'est pas
reproduit : c'est précisément ce que la sonde in situ doit couvrir.

## Le relevé de fps — la référence de travail

`python3 tools/fps.py` (banc construit, toje lancé) échantillonne toutes
les 5 trames les compteurs du verrou graphique (`gfxlock.frame.count`,
`gfxlock.bufferSwap.count`), le peintre en cours et le témoin d'attente du
banc, puis écrit `fps-reference.csv` et `fps-reference.png` (PIL, pas de
matplotlib). fps = échanges de tampons / trames 50 Hz × 50, fenêtre de 25
trames. Les adresses sont lues dans les cartes lwasm et `gen/layout.asm`.

Référence du 05/09/2026, **avec les Pata-Pata** (première mise au point,
aucune optimisation) :

| phase | fps moyen | ce que la trame paie |
|---|---:|---:|
| noir entre deux tours | 25 | le blast seul (22 455 cycles, plus d'une trame) |
| révélation | 24,5 | le blast + les cases dues (peintres à plat, 06/09) |
| saisie | 13,2 | un blast de 200 lignes (25,5 k) + le texte (~15 k depuis le 06/09) + les Pata-Pata au générateur arcade (9 en moyenne) |
| tableau | 8,8 | le blast + ~200 glyphes + une ligne recoloriée |

Sans Pata-Pata (relevé précédent) la saisie tenait 16,7 et la révélation
22,5. Le plafond est 25 : le blast à lui seul prend deux trames. Les fps
sont quantifiés à 50/n : la saisie est à 5 trames (95 k cycles), la marche
des 4 est à 80 k.

## Les Pata-Pata de l'écran de saisie

`ranking.emit` porte l'émetteur arcade (0xFAE1) à l'instruction, générateur `random_ax` et réensemencement compris (`tools/patapata.py` n'existe pas : `tools/patacount.py [taille] [n]` compte les vivants) ; `lib.patapata` est commun (scenes.boot) et l'émetteur armé par défaut. L'index d'objets du
banc (`main.asm`) suit la numérotation du stage 1 et ne sert que quatre
lignes : animation, explosion, préréglage de tir, Pata-Pata. Le blast à deux entrées fixes (889 poussées, `playfield.clearBlastFull`
pour les écrans du classement, `playfield.clearBlast` 11-190 pour le stage)
est passé dans le jeu le 06/09 avec le Pata-Pata en commun : le banc n'a
plus de define ni de lot à lui, son config est le sous-ensemble commun du
jeu, tel quel. Piège
trouvé ici : `playfield.clearLines` boucle 800 fois pour convertir des lignes en
opérandes — trois appels par trame coûtaient un quart de la boucle ; les
fenêtres sont précalculées à l'assemblage et seules les quatre écritures de
`clearWindow` restent par trame.

## Piège relevé : le front de tir fantôme — corrigé dans l'engine

À la première lecture manette, les six lignes DAC du port $E7CD (en entrée,
sans rappel) se lisaient à 0 et le complément les rendait « pressées » —
dont le bit du bouton B, que `joypad.0.FIRE` inclut. `held` étant nul, cette
lecture faisait un front : au banc il tombait sur la saisie et posait un
« A » (le title le consommait dans le jeu). Depuis le 05/09/2026
`joypad.init` (TO8 et MO6) amorce `held` avec l'état de repos du port : la
première lecture est muette. Vérifié ici : case 0 vide au boot (5 456 px).

## Filmer un tour

`python3 tools/film.py [nom]` boote le banc, filme depuis la trame 1240
(le témoin tombe vers 1280 : la révélation est prise), saisit D, C, RUB,
END sous les Pata-Pata, laisse venir le tableau, puis encode en **H.264**
(`dist/<nom>.mp4`, lisible sur iPhone ; l'AVI sans perte reste à côté).
Piège relevé le 05/09 : un déclencheur de départ par adresse (`pc`) n'a
filmé que 46 trames ; un départ par numéro de trame filme tout, au prix du
turbo coupé dès l'armement (le boot tourne en temps réel, ~30 s).
