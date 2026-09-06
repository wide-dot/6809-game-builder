# Réécrire les écrans de classement sur le modèle de la boucle de jeu

Plan rédigé le 05/09/2026 à la demande de l'auteur, après deux migrations
mécaniques qui ont toutes deux donné un écran noir. Rien n'est implémenté ;
l'arbre est à l'état commité.

**Cadrage donné par l'auteur, et qui commande tout le reste :**

- le modèle est **la boucle de jeu du stage**, pas une boucle inventée ;
- l'effacement plein écran passe par **`playfield.clearBlast`**, la routine
  déjà en place ;
- les **transitions entre séquences** doivent être propres, tampon graphique
  ET musique ;
- on vise **le stage 1 qui tourne**. Le placement transverse multi-stage vient
  après ;
- la mise au point apportera des gains de place et de vitesse : **on ne les
  cherche pas maintenant**, un lièvre à la fois ;
- **on ne tiendra pas les 50 trames par seconde, et ce n'est pas un
  problème** : le moteur est adaptatif. Cela SIMPLIFIE beaucoup le plan, voir
  la section 3.

## 1. Pourquoi la réécriture est nécessaire

Les deux écrans (STAGE SCORE + saisie, puis le tableau des dix) peignent **en
absolu dans les deux tampons**, en basculant eux-mêmes `$E7E5` par
`_SwitchScreenBuffer`. Dix bascules, dans cinq routines :

| Routine | Rôle |
|---|---|
| `ranking.scr.clear2` | efface les deux tampons |
| `ranking.scr.cell` | peint une cellule de texte dans les deux |
| `ranking.in.paintCursor` | peint le caractère du curseur dans les deux |
| `ranking.in.blink` | recolorie ce caractère dans les deux |
| `ranking.tableScreen` | peint le tableau dans les deux |

C'est un contournement du double buffering, pas son emploi : au lieu de
construire une image par trame dans le tampon arrière, ils écrivent la même
image dans les deux et comptent sur sa rémanence. Dès qu'une boucle `gfxlock`
tourne, c'est elle qui possède ce registre : elle désigne le tampon arrière à
chaque `_gfxlock.on` et échange à chaque `_gfxlock.loop`. Le contournement et
le principe ne cohabitent pas. Mesuré : peinture
hors verrou, écrasée ; peinture dans le verrou avec bascules manuelles, le
compte de `gfxlock` se désynchronise. Écran noir dans les deux cas, séquence
par ailleurs intacte (banc 7/7, retour au title normal).

## 2. Le modèle : la boucle de jeu, dans son ordre

La boucle du stage, telle qu'elle est écrite :

```
        _Obj_RunU ...            ; les objets à OST fixe
        jsr   RunObjects         ; le pool
        jsr   gfxlock.on         ; le verrou s'ouvre APRÈS la logique
        ...                      ; le fond : scroll, ou clearBlast
        jsr   BuildSprites       ; la passe unique overlay
        ...                      ; les surcouches (HUD)
        jsr   gfxlock.off
        jsr   gfxlock.loop       ; attente de trame
```

Deux choses à retenir, et c'est ce que les deux tentatives ont raté :

- **la logique tourne AVANT le verrou**, le dessin après ;
- **le fond est repeint à chaque trame**, il n'est jamais supposé rémanent.
  Ce n'est pas une contrainte subie, c'est **le principe même du double
  buffering sur lequel le framework est bâti** : on construit une image
  complète dans le tampon arrière, `gfxlock` l'échange, et on recommence dans
  l'autre. Un tampon n'est jamais la suite de l'autre.

Nos écrans font l'inverse : ils peignent une fois et supposent que ça reste.
La réécriture consiste à les mettre dans le premier modèle.

## 3. Le fond : `playfield.clearBlast`

C'est un stack-blast entièrement déroulé, pleine largeur, du bas vers le haut,
piloté par deux opérandes auto-modifiés (la borne basse par le `LDS`, la borne
haute par le `JMP` dans le déroulé). Fenêtre maximale : lignes 11 à 190,
7 200 octets par plan, 800 poussées, **22 455 cycles**. Il vit dans
`common.overlay.page` et s'appelle par `paged.call`.

Un effacement plein écran coûte donc **plus d'une trame** : 22 455 cycles pour
19 968 disponibles. Avec le repeint complet du texte par-dessus (environ 320
cellules à ~70 cycles, soit 22 400 de plus), une trame d'écran plein coûte
autour de 45 000 cycles, soit **deux trames et quart, environ 22 images par
seconde**.

**C'est accepté** (décision auteur) : le moteur est adaptatif, `gfxlock`
compte les trames écoulées depuis le dernier tour et les expose par
`gfxlock.frameDrop.count`. Rien ne casse, l'image se contente d'être moins
fluide sur des écrans qui ne sont pas du jeu.

**Et cela simplifie radicalement le reste du plan, en revenant au double
buffering tel qu'il est prévu.** Le framework est bâti dessus : chaque trame
construit une image complète dans le tampon arrière. Nos écrans en peignant
une fois les deux tampons contournaient ce principe ; c'est ce contournement,
et lui seul, qui rendait la migration impossible. En reconstruisant l'image
entière à chaque trame, les béquilles tombent : plus de peinture en deux
passes, plus d'effacement de la case du curseur, plus de drapeau pour les
lettres validées. Les écrans cessent d'être des peintres incrémentaux pour
devenir une **fonction de leur état**, ce qui est exactement le modèle de la
boucle de jeu.

Une seule contrepartie : **le calendrier doit compter des trames de JEU, pas
des tours de boucle**. Le rythme de la borne (chaînes fixes à trois cases par
trame, ligne i après 32+8i trames) se dérègle si le compteur avance d'une
unité par tour alors que deux ou trois trames se sont écoulées. Il faut donc
l'avancer de `gfxlock.frameDrop.count`, comme le font `ObjectMoveSync`,
`AnimateSpriteSync` et `moveByScript` — c'est la convention du moteur, et
CLAUDE.md rappelle que tout le timing du jeu en dépend.

## 4. Les transitions, tampon et musique

C'est le point que l'auteur signale et que les deux tentatives n'ont pas
traité. Trois coutures :

**a. Stage → écrans de classement.** Le stage laisse : un pool d'objets
peuplé, une timeline d'effacement en cours, un verrou dans un état
quelconque, et sa musique. Il faut donc, dans cet ordre : faire taire la puce
(`game.music.stop`, déjà en place), purger le pool
(`DisplaySprite_ClearAll`, `EraseSprites_ClearAll`, `InitDrawSprites`, puis
une passe `RunObjects` à vide), reposer la fenêtre d'effacement en pleine
largeur si on s'en sert, puis `_gfxlock.init` et le plafond de frame-drop.
La purge n'est pas facultative : `RunObjects` lit la table d'index du
**stage**, tout objet resté monté tournerait ici avec ses sprites.

**b. Entre les trois écrans** (révélation → saisie → tableau). Même verrou,
même boucle : il n'y a pas de rupture à gérer, seulement le contenu qui
change. La musique ne change pas non plus, elle est armée une fois avant la
révélation et tient jusqu'au continue.

**c. Écrans → CONTINUE, puis reprise ou title.** Le continue peint hors
boucle, dans les deux tampons (corrigé le 05/09). Il faut donc **fermer la
boucle proprement** avant de l'appeler : dernière trame, verrou fermé, et
laisser les deux tampons dans le même état. Symétriquement, si le joueur
reprend, le stage réarme sa propre boucle et sa musique — c'est déjà le
chemin actuel, il ne doit pas être perturbé.

## 5. Le découpage en étapes

### Étape 1 — la boucle et la purge

`ranking.loop.init` : purge du pool, `_gfxlock.init`, plafond de frame-drop
à 3, puis `_gfxlock.on` + `RunObjects` pour que la première peinture soit dans
le verrou.

`ranking.loop.frame` : **un appel par tour**, qui ferme la trame précédente et
ouvre la suivante (`BuildSprites`, `_gfxlock.off`, `_gfxlock.loop`,
`_gfxlock.on`, `RunObjects`). Le verrou est donc ouvert quand il rend la main,
et tout ce que l'écran peint ensuite se fait dedans, quel que soit le nombre
de chemins qui rebouclent. `ranking.loop.done` ferme la dernière.

Déjà écrit et mesuré lors de la tentative : **+187 octets** (l'unité passe de
2 489 à 2 676, sur 3 648 d'arène). L'inclusion de `src/common/engine/api.asm`
règle la déclaration des symboles du verrou, que la liste à la main ne pouvait
plus suivre. **Ne pas** inclure `gfxlock.macro.asm` en plus : l'interface
l'apporte, le double include casse l'assemblage.

### Étape 2 — la peinture ne peint plus qu'un tampon

Retirer les dix `_SwitchScreenBuffer` ; chaque routine peint une fois, dans le
tampon courant. `ranking.scr.clear2` devient `clear1`.

### Étape 3 — les écrans deviennent une fonction de leur état

C'est le cœur de la réécriture, et le point où le travail se simplifie au lieu
de se compliquer. Chaque trame :

1. `playfield.clearBlast` par `paged.call` — le fond, comme le stage ;
2. le repeint COMPLET de ce qui doit être visible à cette trame ;
3. `BuildSprites`.

Les émetteurs actuels changent à peine, parce qu'ils dérivent déjà tout du
numéro de trame. Ils passent d'une plage à un préfixe :

| Aujourd'hui | Après |
|---|---|
| le titre émet les cases `3f` à `3f+2` | il émet les cases `0` à `min(3f+2, 20)` |
| la ligne i émet sa case `k = f − (32+8i)` | elle émet ses cases `0` à `min(k, 15)` |
| le bas émet trois cases | il émet toutes celles dues |

Le curseur, les lettres déjà validées et la ligne « NO.n » sont peints à
chaque trame depuis la table, sans état supplémentaire. La recoloration
blanc/rouge et le surlignage de la ligne du rang suivent le même chemin : une
passe par trame, sur le tampon courant.

Ce qui disparaît : le double appel de peinture, l'effacement de la case du
curseur, le drapeau des lettres validées, et probablement quelques octets de
code — mais on ne compte pas là-dessus, la mise au point le dira.

### Étape 4 — le calendrier sur les trames de jeu

Le compteur de la révélation et celui de la saisie avancent de
`gfxlock.frameDrop.count` au lieu de 1. C'est la seule chose qui préserve le
rythme relevé sur la borne quand la boucle tourne à 20 images par seconde. La
limite de saisie (2 048 trames) et la tenue du tableau (256) comptent elles
aussi des trames de jeu.

## 6. Ce qu'on vérifie, et comment

1. **À comportement identique d'abord** : aucun sprite, aucun Pata. Densité de
   pixels par capture comparée à la référence — écran de saisie à 5 456,
   tableau à 14 824, révélation montant par paliers (928, 1 744, 3 152,
   3 264, 4 968, 5 456).
2. **Le clignotement** : une seule couleur par phase dans la case du curseur,
   (251,251,247) puis (251,0,0), 112 pixels dans les deux cas.
3. **Le surlignage** : la ligne du rang obtenu en index 7 à 10.
4. **Les deux tampons** : lire les octets d'un texte fixe sur la page 2 ET la
   page 3, identiques une fois la révélation finie.
5. **Les transitions** : musique coupée à l'entrée, écran CONTINUE visible
   derrière, READY visible après un continue accepté, reprise du stage avec sa
   musique.
6. **Le rythme malgré la lenteur** : la révélation doit durer le même temps
   de jeu qu'aujourd'hui. Contrôle : le nombre de trames de jeu écoulées entre
   le début et la fin de la révélation, lu sur `gfxlock.frame.gameCount`, et
   non le nombre de tours de boucle.
7. **Le banc 7/7** à chaque étape, et **stage 1 d'abord**.

## 7. Ce qui reste hors de ce plan

- **Le placement transverse** : le code vise le stage 1. Le rendre commun aux
  huit stages est un chantier à part.
- **Les Pata-Pata** : la boucle les rend possibles, mais l'effacement des
  sprites (pas de sauvegarde de fond en OverlayMode), la palette (l'index 12
  du Pata écrasé par le rouge du curseur, à déplacer vers 13 et 14) et la
  disponibilité (`lib.patapata`, 3 897 octets, chargé sur les stages 1, 3, 4
  et 7 seulement) sont trois décisions séparées.
- **Les optimisations de place et de vitesse** : elles viendront de la mise au
  point, on ne les cherche pas maintenant.

## 8. Ce que la tentative du 05/09 a appris

Étapes 1 à 3 écrites et assemblées, puis **annulées** : écran corrompu, CPU
figé dans une boucle de deux instructions. L'arbre est revenu à l'état
commité. Ce qui a été établi en chemin, et qui ne sera pas à repayer :

- **Le bon `gfxlock` est `engine/graphics/buffer/`**, pas celui de
  `engine/system/thomson/graphics/buffer/`. Le second a un `bufferSwap.do` qui
  bascule la demi-page ; celui qui est lié ne le fait pas, il n'écrit que la
  page visible (`$E7DD`). J'ai perdu du temps sur le mauvais fichier.
- **`_gfxlock.loop` n'attend PAS la trame.** Il ne calcule que le frame-drop.
  L'attente est dans `_gfxlock.on`, qui appelle `gfxlock.bufferSwap.wait` — un
  spin sur `gfxlock.bufferSwap.status`, que **seul l'IRQ** met à jour via
  `gfxlock.bufferSwap.check`. Une boucle qui enchaîne `off` puis `on` sans
  laisser respirer l'IRQ passe donc son temps dans ce spin.
- **C'est exactement là que la machine s'est figée** : deux instructions en
  boucle, page cartouche inattendue, DP à `$E7`. La piste à instruire en
  premier est donc l'état de l'IRQ pendant ces écrans, et l'ordre exact
  `on`/`off` par rapport à celui du stage — le stage ouvre le verrou APRÈS sa
  logique et le ferme avant l'attente, notre boucle doit l'imiter à la lettre
  plutôt que fusionner fermeture et ouverture dans un seul appel.
- **Les macros du verrou doivent être incluses explicitement**
  (`engine/graphics/buffer/gfxlock.macro.asm`) : `api.asm` déclare les
  symboles mais n'apporte pas les macros.
- **`playfield.clearBlast` n'est pas en cause** : la corruption est identique
  sans lui.
- Coût mesuré des trois étapes : l'unité passe de 2 489 à 2 587 octets.

## 9. FAIT le 05/09/2026 — sur un banc dédié

Réécriture terminée et vérifiée, d'abord sur `bench/ranking/` (un config
dérivé de celui du jeu, sans stage ni title : build en 2 s, l'écran dès le
boot — idée de l'auteur), puis dans le jeu. Le banc a rendu la mise au point
triviale ; il a aussi montré ses limites, instructives :

- **Trois causes ne se voyaient que dans le jeu**, parce que le pool du banc
  est vide : (1) `RunObjects` faisait tourner les objets du stage laissés par
  la mort — d'où la purge `ManagedObjects_ClearAll` à l'entrée (le continue
  recharge un checkpoint, qui repart lui aussi d'un pool vide) ; (2) chaque
  objet monte SA page cartouche, la police se remonte donc après
  `RunObjects`, avant de peindre ; (3) le HUD du stage, hors de la fenêtre du
  blast, survivait dans le tampon que la mort n'avait pas effacé — d'où deux
  trames de noir complet à l'entrée, par la boucle elle-même.
- **La fenêtre du blast** est 3-182 pendant ces écrans (le titre RANKING est
  en ligne 6, la saisie en 179 ; 180 lignes au plus), et le stage retrouve
  11-190 en sortie.
- Vérifié : densités de référence retrouvées à l'identique (saisie 5 456,
  tableau 14 824, révélation 928 → 3 264 → 4 968 aux trames de la borne),
  curseur plein 112 px blanc/rouge à 8-10 trames par couleur, saisie
  scriptée (D, C, RUB, END, tableau surligné « AD »), et dans le jeu la
  chaîne mort → STAGE SCORE → RANKING → CONTINUE (invite rouge) → READY →
  reprise du stage. Unité : 2 529 octets (+40).

## 10. Risques connus

- **Le double include de `gfxlock.macro.asm`** casse l'assemblage.
- **La place** : l'unité passe à environ 2 700 octets sur 3 648. La marge se
  réduit.
- **La parité d'affichage** : `toje` rend la page **visible**, celle de
  `$E7DD`. Un défaut de tampon ne se voit qu'une fois sur deux selon la trame
  où le stage s'est arrêté, et les scripts déterministes tombent souvent du bon
  côté. Vérifier en lisant les deux pages, pas seulement en capturant.
- **La lenteur est assumée, le dérèglement du rythme ne l'est pas.** Si un
  compteur avance d'une unité par tour au lieu de `frameDrop.count`, la
  révélation ralentit d'autant et la saisie voit sa limite s'allonger. C'est le
  piège le plus probable de cette réécriture.
- **`playfield.clearWindow` reste disponible** si la mise au point montre que
  la pleine fenêtre coûte trop : chaque rangée zappée rend environ 747 cycles.
  À ne regarder qu'une fois le reste juste.
