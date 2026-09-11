# Le coût d'une boucle de jeu au milieu du stage 3 (10/09/2026)

Mesure sous toje, `tools/frame_steps_probe.py` : le CPU conduit de frontière
en frontière par `run_until_pc` (les `jsr` de la boucle de `stage-main.asm`),
le compteur de cycles lu dans l'anneau de trace, six boucles moyennées. La
scène : le ventre du vaisseau, quatre réacteurs vivants, une cinquantaine
d'objets, le vaisseau du joueur invincible qui ne tire pas
(`doc/images/profil-boucle-stage3-scene.png`).

Ce stage n'a **aucune attente** : la boucle ne passe pas un cycle dans
`gfxlock.bufferSwap.wait`. Le budget n'est donc pas un reste de trame, c'est
la période de rendu elle-même : 185 600 cycles, 9 à 10 trames par rendu.

| étape | cycles | part |
|---|---:|---:|
| tête de boucle (banc, état) | 23 | 0,0 % |
| `joypad.latch.read` | 118 | 0,1 % |
| `ScrollCols` (défilement avant-plan) | 462 | 0,2 % |
| `tilemap.flush` | 21 | 0,0 % |
| `ObjectWave` | 48 | 0,0 % |
| `Collision_Run` (passe AABB + contact pod) | 3 857 | 2,1 % |
| fondu, joueur, pod, bits | 3 337 | 1,8 % |
| **`RunObjects`** (tous les objets) | **42 960** | **23,1 %** |
| `gfxlock.on` | 54 | 0,0 % |
| **`mscroll.do`** (blast de la couche battleship) | **56 945** | **30,7 %** |
| `mscroll.move` (feed de la couche) | 1 265 | 0,7 % |
| `bship.patch.drain` | 32 | 0,0 % |
| `bship.collisionFollow` | 366 | 0,2 % |
| `stage.frameBlit` (effacement) | 124 | 0,1 % |
| **`BuildSprites`** (sprites, pièces wsmgr comprises) | **56 668** | **30,5 %** |
| `stage.frame.tiles` (décor avant-plan) | 7 677 | 4,1 % |
| masque du champ (overlay) | 9 056 | 4,9 % |
| `hud.normal` | 2 315 | 1,2 % |
| `gfxlock.off` | 39 | 0,0 % |
| `stage.endTick`, `gfxlock.loop`, retour | 271 | 0,1 % |
| **boucle entière** | **185 638** | |

L'IRQ 50 Hz (`stage.userIRQ` : bascule, palette, manette, lecteur YMM,
soundfx) coûte 320 cycles par trame, 1 500 sur une trame où le lecteur
écrit beaucoup — 3 000 à 5 000 par boucle, comptés dans les étapes qu'elle
interrompt.

## Ce qu'il faut en lire

- **Trois postes font 85 %** : le blast de la couche (31 %), les sprites
  (31 %) et les objets (23 %). Tout le reste, collision, décor avant-plan,
  masque, HUD, tient dans 15 %.
- **Le blast est un coût fixe** : il repeint la bande entière de 160 × 180 à
  chaque rendu, quoi que montre l'écran. C'est le prix de la couche mobile,
  incompressible sans changer son principe.
- **Les sprites et les objets varient avec la scène** : ici quatre réacteurs,
  leurs jets, les tourelles, la capsule, le réacteur arrière. C'est là que
  se jouent les arbitrages de coût par pièce (le plan des sprites par
  tranches, les épaves en patch de carte plutôt qu'en sprite : 1 700 cycles
  par épave et par rendu de ce poste).
- **Le décor avant-plan est bon marché à cet endroit** : 7 700 cycles, le
  terrain du ventre est surtout du ciel. Au stage 1 il pèse 12 000 à 17 000.
- Rien d'anormal dans le reste : la passe de collision à 3 900 pour une
  cinquantaine de boîtes, la manette et la wave négligeables.

## `BuildSprites` et `RunObjects`, objet par objet

Même scène, même méthode à l'intérieur des deux postes
(`tools/obj_steps_probe.py`) : arrêt au `jsr [,x]` de `RunObjects` et au
`jsr ,y` de `BuildSprites`, retour, l'écart cumulé par identifiant et
sous-type, trois boucles moyennées.

**`BuildSprites`, 56 700 cycles** : 44 700 dans les routines de dessin,
12 000 dans le tour des objets lui-même (élimination, page, adresse :
environ 230 cycles par objet pour une cinquantaine d'objets).

| ce qui est dessiné | n | cycles | chacun |
|---|---:|---:|---:|
| **wsmgr, les pièces mobiles par tranches** (les quatre jets de ventre, la capsule…) | 1 | **29 779** | |
| les tirs ennemis (`bullet.DrawAll`, un objet pour tous) | 1 | 3 896 | |
| les petites tourelles | 12 | 3 697 | 308 |
| les grosses tourelles | 2 | 1 260 | 630 |
| les quatre réacteurs de ventre | 4 | 2 216 | 554 |
| les tourelles multiples | 3 | 1 819 | 606 |
| le POW | 1 | 702 | |
| un Pata-Pata en vol | 1 | 413 | |
| le vaisseau du joueur | 1 | 409 | |

Deux tiers du dessin sont les tranches de wsmgr. Une tranche de 16 × 12
coûte 250 à 400 cycles de code compilé et à peu près autant de tour
(montage de deux pages, `DRS_XYToAddress`, le test de bande) : c'est le
tour qui se compresse, pas le code.

### Les pièces mobiles, tranche par tranche

Sonde `tools/wsmgr_steps_probe.py`, trois rendus consécutifs de la même
scène (`wsmgr.DrawAll` à 30 319, 40 079 et 36 865 cycles pour 9, 11 et 11
slots), moyennes par rendu. « Routines » est le code compilé des tranches,
« tour » tout le reste du manager (slot compris), « tour/tr » le tour
rapporté à la tranche, rejetées comprises.

| pièce | slots | tranches dessinées | rejetées | routines | tour | total | tour/tr |
|---|---:|---:|---:|---:|---:|---:|---:|
| les gerbes des réacteurs de ventre (`flame.sl.*`) | 4,3 | 27,3 | 5,3 | 8 932 | 7 850 | **16 782** | 240 |
| la capsule de survie | 1 | 8 | 0 | 4 401 | 2 059 | 6 460 | 257 |
| le réacteur arrière | 1 | 6 | 0 | 2 333 | 1 575 | 3 908 | 262 |
| la petite capsule | 1 | 4 | 0 | 1 571 | 1 091 | 2 662 | 273 |
| le noyau (animation) | 1 | 4 | 0 | 1 565 | 1 091 | 2 656 | 273 |
| le triangle | 1 | 4 | 0 | 1 441 | 1 091 | 2 532 | 273 |
| le cache du noyau | 1 | 0 | 6 | 0 | 713 | 713 | 119 |
| **total** | 10,3 | 53,3 | 11,3 | **20 243** | **15 470** | **35 713** | 239 |

Ce qu'il faut en lire :

- **Une tranche dessinée coûte 380 de routine et 265 de tour** ; une
  tranche rejetée coûte 119 (le test de bande, la lecture de la liste, le
  retour de boucle). Le tour est 43 % du poste : 15 500 cycles par rendu.
- **Les gerbes sont la moitié du poste** : 27 tranches dessinées par
  rendu sur quatre slots. C'est le nombre de tranches, pas leur prix — la
  gerbe est grande et animée à chaque rendu.
- **Le tour d'une tranche dessinée se décompose** (cycles 6809 comptés) :
  lecture de la liste et sauvegarde de xy ~25, test de bande ~55,
  `DRS_XYToAddress` ~55 (un `mul`, deux adresses écrites dont une
  inutile ici), deux montages de page ~20, appel et retour ~15, queue de
  boucle ~25, plus ~30 de slot amortis (copie de la liste en RAM, deux
  montages, huit octets de contexte).
- **Les leviers**, par rendement : (1) le cache du noyau — six tranches
  toujours rejetées à cette position, 713 cycles pour rien : faire le test
  au niveau du slot (boîte de la pose entière avant les tranches) supprime
  aussi les rejets des gerbes qui sortent par le bas ; (2) ne calculer
  l'adresse écran qu'une fois par slot et dériver celle des tranches par
  leur décalage dans le canevas (les tranches d'une pose partagent l'ancre),
  ce qui retire `DRS_XYToAddress` et la parité par tranche, ~60 cycles ×
  53 ; (3) ne pas remonter la page des descripteurs après chaque routine
  quand la routine vit dans la même page (cas le plus fréquent hors
  pageset), ~10 × 53. Ensemble, 5 000 à 6 000 cycles sur les 15 500 de
  tour ; le code compilé, 20 000, ne bouge qu'en dessinant moins.

### Les trois leviers, appliqués (10/09/2026)

Même scène, même sonde, et cette fois **l'IRQ est retirée des mesures** :
la sonde relit l'anneau de trace entre deux arrêts et ne compte que le
manager, `DRS_XYToAddress` et la fenêtre cartouche (les routines). Les
chiffres d'avant portaient l'IRQ au hasard des slots, environ 700 cycles
par rendu — c'est ce qui rendait le « tour » du cache du noyau différent
d'un rendu à l'autre.

| pièce | slots | dessinées | rejetées | slots rejetés | routines | tour | total | tour/tr |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| les gerbes des réacteurs de ventre | 4 | 21 | 4,7 | 0,7 | 6 804 | 4 301 | **11 105** | 168 |
| la capsule de survie | 1 | 8 | 0 | 0 | 4 038 | 1 392 | 5 430 | 174 |
| le réacteur arrière | 1 | 6 | 0 | 0 | 2 333 | 1 112 | 3 445 | 185 |
| la petite capsule | 1 | 4 | 0 | 0 | 1 607 | 832 | 2 439 | 208 |
| le noyau (animation) | 1 | 4 | 0 | 0 | 1 570 | 832 | 2 402 | 208 |
| le triangle | 1 | 4 | 0 | 0 | 1 441 | 832 | 2 273 | 208 |
| le cache du noyau | 1 | 0 | 0 | 1 | 0 | 108 | 108 | |
| **total** | 10 | 47 | 4,7 | 1,7 | **17 793** | **9 409** | **27 202** | 182 |

Le tour passe de 15 500 à 9 400 cycles par rendu (14 800 à IRQ égale :
**−37 %**), le poste de 35 700 à 27 200 — les gerbes dessinent quelques
tranches de moins dans cette prise, le code compilé suit. Ce qui a changé :

- **L'adresse écran une fois par pose.** Les tranches gardent le canevas de
  leur pose, donc son ancre et sa parité de centre (celle de la largeur du
  canevas, `Image.getCenterOffset`) : `DRS_XYToAddress` tourne une fois par
  slot et ses deux globales servent à toutes les tranches, les routines ne
  font que les lire. Plus de sauvegarde de xy sur la pile par tranche.
- **La page des descripteurs remontée par un immédiat** auto-modifié après
  chaque routine (7 cycles au lieu de 15).
- **La boîte de pose avant les tranches.** Première version, la boîte du
  canevas contre la fenêtre : elle ne rejetait RIEN ici — le cache du noyau
  n'est pas hors champ, il est **à cheval sur le bord droit** (x écran 178,
  32 px de large), et chaque tranche de 16 px échoue au containment sans que
  le canevas cesse de toucher la fenêtre. La version gardée est **exacte** :
  le générateur écrit six octets par pose (`tools/wsmgr_box.py` : le bord
  gauche le plus à gauche, le bord droit le plus à gauche, le bord gauche le
  plus à droite, et de même en y), et le slot est rejeté quand aucune
  tranche ne peut tenir, toutes sortant du même côté. Le cache tombe à 108
  cycles ; une gerbe sur six par rendu est rejetée entière. Coût du test :
  une cinquantaine de cycles par slot dessiné.

Ce qui reste dans le tour d'un slot de 4 tranches (832 cycles) : ~340 de
slot — la copie de la liste en RAM (26 cycles par tranche, la liste vit
dans la page de la pièce, pas dans celle de ses images), le test de boîte,
`DRS_XYToAddress`, les montages — et ~120 par tranche (lecture de la liste,
test de bande, deux montages, appel). Le code compilé, 380 par tranche, est
désormais les deux tiers du poste : le manager ne se compresse plus
qu'en dessinant moins.

**`RunObjects`, 43 000 cycles** : 39 800 dans les routines, 3 200 dans la
boucle.

| ce qui tourne | n | cycles | chacun |
|---|---:|---:|---:|
| **le manager des tirs ennemis** (`foefire`, tous les tirs en vol) | 1 | **9 672** | |
| les petites tourelles | 12 | 8 838 | 737 |
| les sous-parties de coque | 14 | 4 040 | 289 |
| un Pata-Pata en vol (script de mouvement pas à pas) | 1 | 2 739 | |
| le manager des gerbes | 1 | 2 005 | |
| les quatre réacteurs de ventre | 4 | 1 792 | 448 |
| le POW | 1 | 1 495 | |
| les grosses tourelles | 2 | 1 458 | 729 |
| les tourelles multiples | 3 | 2 378 | 793 |
| le pilote de la couche | 1 | 934 | |
| le noyau | 1 | 669 | |
| le réacteur arrière, la capsule, les détachables | 5 | 1 780 | |

Deux choses à retenir. Le manager des tirs est l'objet le plus cher de
la scène, tir par tir dans un seul tick. Les tourelles pèsent par le
nombre, 14 fois 740 à la course et 14 fois 310 au dessin, un tiers du poste
objets à elles seules. (Le Pata-Pata à 2 700 est un vrai Pata-Pata en vol :
son script de mouvement est stepé trame par trame, c'est sa sémantique.)

### Le tick d'une petite tourelle, en quatre

Six ticks mesurés, 710 cycles chacun, stables au cycle près :

| morceau | cycles |
|---|---:|
| le suivi de couche (`layer.evenX`, `layer.followY`, la fenêtre, la boîte) | 258 |
| `setDirectionTo` (viser le joueur) | 142 |
| `tryFoeFire` (décider du tir, à chaque tick) | 243 |
| `DisplaySprite` (l'inscription dans la liste de priorité) | 67 |

Rien d'aberrant, mais deux leviers si la course des tourelles devait
baisser : la décision de tir est évaluée en entier à chaque tick alors que
son horloge dit d'avance qu'il ne tirera pas, et le suivi de couche refait
pour chaque pièce le même repli de caméra, que le pilote pourrait faire une
fois par rendu. À 14 tourelles, ces deux-là valent 4 000 à 5 000 cycles.

## Les boucles par trame, remplacées (10/09/2026)

La v1 compense le frame-drop en **rejouant** le travail d'une trame autant
de fois que de trames écoulées. C'est exact, et c'est ce que payait le tick
d'une tourelle : 243 cycles dans `tryFoeFire` pour une décision de tir de
douze instructions, le reste dans la boucle qui avançait son horloge trame
par trame. Décision auteur : calculer d'un coup et retirer ces boucles
partout où le corps n'a pas d'effet de bord par trame. Cas de migration :
`docs/lang/en/migration/frame-drop-loops-are-multiplies.md`.

- **L'horloge de tir** (`tryFoeFireCommon`, ses quatorze appelants, et le
  double du manager des Bugs) : le compteur avance du tick, le seuil tire
  s'il tombe dans l'intervalle franchi, sinon la remise à zéro. Mesuré sur
  la tourelle : `tryFoeFire` 243 → 96, le tick 710 → 562 ; à la course
  des objets, 737 → 600 par tourelle.
- **L'intégrateur de mouvement** (`ObjectMoveSync`, moteur, treize
  appelants : missiles, POW, Scant, P-Staff, Cancer, canon du Tabrok…) :
  deux `mul` par axe au lieu d'une boucle de quarante cycles par trame, les
  mêmes positions au bit près. Aucun de ses appelants n'est dans cette
  scène ; le gain se lit sur les stages 1 et 2.
- **Restent en boucle, par sémantique** : le force pod (bornes par trame),
  `mscroll.move` (caméra bornée), les scripts de mouvement (`moveByScript`,
  un pas par trame), les missiles du joueur.

Après ces deux changements, même scène : `RunObjects` 42 960 → 41 100,
les routines des objets 39 800 → 38 000. Banc r-type 7/7.
