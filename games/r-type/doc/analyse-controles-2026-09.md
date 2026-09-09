# Les contrôles à neuf images par seconde : plafond de frame drop et verrou de tir

Étude du 09/09/2026, sur le relevé de cadence du stage 2
(`tools/fps/stage2-2026-09-09.csv`). Question posée par l'auteur : quel
plafond de frame drop pour le jeu le plus maniable, et l'entrée est-elle
appliquée au pas fin enregistré par l'IRQ.

## 1. Ce que l'entrée fait déjà, et ce qu'elle ne faisait pas

**Les directions sont intégrées par trame de jeu depuis la v1.**
`stage.userIRQ` appelle `joypad.buffer.addDirection` à 50 Hz : le dpad
brut de `$E7CC` va dans un anneau de seize entrées. `ApplyJoypadInput`
(player1.asm) consomme tout l'arrière à chaque rendu et applique UN PAS
PAR ENTRÉE, vitesse du preset par direction, en remplissant au passage
l'anneau de positions que le force pod suit. Le vaisseau bouge donc de
la somme exacte des pas de chaque trame, même à neuf images par seconde.

**Le tir, lui, n'était lu qu'une fois par rendu.** `joypad.readKbd` en
tête de boucle lisait le port et détectait le front contre la lecture
précédente. À 100-120 ms par rendu, un appui relâché entre deux lectures
était perdu et tout appui était vu jusqu'à un rendu plus tard. Le force
pod (boutons A et B), les bits et le menu « continue » lisent les mêmes
octets.

## 2. Le plafond de frame drop

Le pas réel par rendu au stage 2, plafond 8 en vigueur :

| pas (trames de jeu par rendu) | part des rendus |
|---|---|
| 4 | 8 % |
| 5 | 47 % |
| 6 | 31 % |
| 7 | 12,5 % |
| 8 | 0,5 % |

Le plafond 8 ne mord jamais. Un plafond ne peut que ralentir le jeu
(trames de jeu jouées sur trames machine) pour raccourcir le pas :

| plafond | vitesse du jeu | rendus bridés | pas maximal |
|---|---|---|---|
| 8 | 99 % | 0 % | 160 ms |
| 7 | 99 % | 0,5 % | 140 ms |
| 6 | 97 % | 13 % | 120 ms |
| 5 | 89 % | 44 % | 100 ms |
| 4 | 72 % | 92 % | 80 ms |

**Décision auteur : 6.** Trois pour cent de vitesse rendus dans les
creux seulement, le pire pas ramené de 160 à 120 ms. En dessous le jeu
ralentit presque tout le temps, et la wave, horodatée en trames de jeu,
dérive de la musique qui joue en temps réel (la fanfare du boss
décalée de plusieurs secondes à 5). Posé dans `stage-main.asm` à
l'entrée de stage ; le title garde 3.

Ce que le plafond ne change pas : la fenêtre de décision du joueur reste
le pas courant, 100 à 120 ms. Le seul levier qui la raccourcit sans
ralentir est la cadence de rendu elle-même.

## 3. Le verrou de tir sous IRQ

`engine/system/to8/controller/joypad.latch.asm`, fichier sans section
inclus par `stage-main.asm` — pas dans le moteur résident, qui n'a plus un
octet devant le lecteur YMM (5 855 octets de `$6100` à `$77DF`, la
première version l'a fait déborder de 54 octets, et l'erreur du builder
parlait de tout autre chose) :

- `joypad.latch.sample`, appelé de `stage.userIRQ` à côté
  d'`addDirection` : lit le port à 50 Hz, injecte KTEST en bouton B
  comme `readKbd`, et ACCUMULE les fronts montants des boutons dans
  `joypad.latch.pressed` (front = état ∧ ¬précédent), état gardé dans
  `joypad.latch.prev`.
- `joypad.latch.read`, à la place de `readKbd` en tête de boucle : pose
  `joypad.state`, `held` (le dernier état échantillonné) et `pressed`
  (dpad : fronts contre `held.dpad` comme avant ; tir : le verrou, pris
  IRQ masquée puis effacé). Les consommateurs ne changent pas.
- `joypad.latch.init` à l'entrée de stage, amorcé sur l'état de repos du
  port — les lignes DAC se lisent à zéro et, complémentées, feraient un
  front fantôme (le piège du 05/09).

**Mesure**, `tools/fire_latch_probe.py` : au stage 2, trente appuis sur A
de deux trames vidéo (40 ms) à des instants quelconques, le pool scruté
toutes les deux trames pendant seize trames après chaque appui :

| build | appuis de 40 ms (2 trames) | appuis de 80 ms (4 trames) |
|---|---|---|
| lecture par rendu (avant) | 15 sur 30 | 25 sur 30 |
| verrou sous IRQ | 30 sur 30 | 29 sur 30 |

Le 29 sur 30 est reproductible et c'est toujours le PREMIER appui de la
série, juste après l'appui de chauffe ; les séries à deux et trois trames
n'en manquent aucun. Un artefact de la sonde (la chauffe) plus qu'un
front perdu : le verrou l'a vu, le joueur n'a pas tiré à ce rendu-là.

Trois pièges de mesure, tous du côté de toje : le premier
`press_joystick` branche la manette (le bit 2 de `$E7CD` bascule) sans
front sur le bouton, d'où un appui de chauffe ; un appui d'UNE trame
vidéo tombe entre deux échantillons de l'IRQ et n'est vu par personne ;
et un tir vit six trames à l'écran depuis le point de ralliement du
vaisseau, compter les slots quinze trames plus tard ratait tout.

## 4. Chiffres avant/après

Même sonde, même image de disquette, seul l'engine diffère (les trois
fichiers remis de côté par `git stash`, rebuild, mesure, retour). Avant :
un appui de 40 ms passait une fois sur deux, un appui de 80 ms cinq fois
sur six — la probabilité que l'instant de lecture tombe dans l'appui, à
un pas moyen de 5,5 trames. Après : 30 sur 30 à 40 ms.

## 5. Un tir par appui, à sa place (09/09/2026, décision auteur)

Le bit fondait tous les appuis d'une fenêtre en un tir, né au rendu à la
position courante du vaisseau, sans rattrapage. « L'idée est de traiter
le tir simple en ne pénalisant pas le joueur quand le jeu ralentit. »

**L'algorithme.** L'IRQ note la trame de chaque front sur A (l'octet bas
de `gfxlock.frame.count`, déjà incrémenté pour cette trame quand l'IRQ
appelle `joypad.latch.sample`), huit au plus par fenêtre. À la lecture,
la liste passe au joueur (`joypad.taps`, exportée par le stage, EXTERNAL
du joueur). `@testFire` produit un tir par appui :

- **né où était le vaisseau à cette trame** : `ApplyJoypadInput` écrit
  déjà une entrée (x écran, y) par trame de jeu dans l'anneau que le
  force pod suit ; l'entrée de la trame F est à 4 × (maintenant − F)
  octets sous le pointeur ;
- **en retard de lastCount − F trames** : `lastCount` est la trame de la
  bascule de tampons, l'horloge sur laquelle le pas suivant du tir
  ajoutera 6 × drop ; borné à drop − 1 (le plafond compresse les trames
  réelles) et à zéro. `weapon.Init` avance de 6 px par trame de retard
  avant de calculer son impact mur.

Compter le retard depuis la lecture du verrou, comme la première
version, laissait une trame d'ambiguïté : une IRQ peut tomber entre la
bascule et la lecture, et cette trame était comptée deux fois — des
tirs à 18 px au lieu de 12.

**Mesure**, `tools/fire_burst_probe.py` : vaisseau poussé à gauche (près
du point de ralliement un tir sort de l'écran en deux trames), rafales
de trois appuis, pool scruté chaque trame. Piège toje : `press_joystick
hold_frames=N` dure 2N trames, N enfoncées puis N relâchées, mesuré sur
`gfxlock.frame.count`. Résultats :

| rafale | tirs | écarts mesurés |
|---|---|---|
| 3 appuis toutes les 4 trames, 6 rafales | 18 sur 18 | 24 px dans la plupart des paires, 18 ou 30 quand l'appui de toje lui-même est tombé une trame plus tôt ou plus tard (les trames F relevées dans `joypad.taps` le montrent : 45 puis 50) |
| 3 appuis toutes les 3 trames (hold 1) | 14 sur 18 | les appuis d'une trame ne sont pas tous vus par l'IRQ de toje, limite de la sonde |
| 30 appuis isolés de deux trames | 30 sur 30 | |

Le compte est exact et l'espacement suit la trame de l'appui à une trame
près, ce qui est aussi la précision de la sonde. rtype_bench 7/7.

Ce qui n'est pas fait : les missiles gardent une paire par rendu (leur
règle « une paire en vol » rend le compte inutile), et le beam lit
`held`, inchangé.

**Le flush** (remarque auteur) : pendant le menu « continue » et la
réapparition, la boucle ne lit plus le verrou mais l'IRQ y accumule
toujours, et l'appui qui valide le continue devenait un tir à la
première trame de jeu. `joypad.latch.init` est rappelé au rechargement
de checkpoint, IRQ coupée, juste avant `IrqOn` : il réamorce sur l'état
du port, donc un bouton encore tenu ne fait pas de front, et vide fronts
et appuis. À l'entrée de stage l'IRQ est coupée pendant le chargement,
rien ne s'y accumule ; pendant la séquence d'ouverture la liste est
recopiée à chaque rendu, seuls les appuis du dernier rendu avant la
reprise des commandes survivent, comme un appui réel à cet instant.
