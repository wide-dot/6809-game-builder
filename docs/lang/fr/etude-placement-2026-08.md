---
date: 2026-08-05
sujet: Placement automatique — régions multipages et rangement algorithmique
statut: étude — rien n'est implémenté
---

# Ranger les pages par algorithme : ce qui manque, et ce qui manque vraiment

## 1. D'où vient la question

Le cast d'ennemis du stage 1 pèse **195 368 octets** (mesuré dans les binaires
v1, 291 variantes). En le plaçant à la main, région par région, on arrive à
court de pages — alors que la v1 loge le même contenu dans la même machine.

La mesure a tranché : **il n'y a aucun écart de contenu entre v1 et v2.**

| | v1 | v2 | écart |
|---|---|---|---|
| tuiles du niveau 1 | 107 748 | 107 575 | 173 o |
| bug | 6 786 | 6 325 | −461 |
| bink | 12 664 | 12 672 | +8 |
| blaster | 6 744 | 6 749 | +5 |

L'écart est ailleurs, et il est énorme : **105 060 octets perdus dans les queues
de régions taillées à la main**, contre 2 560 octets de trous non déclarés et
32 768 de pages libres. Autrement dit, les trois quarts de la place manquante
sont déjà là — mal découpés.

| région | déclaré | utilisé | perdu |
|---|---|---|---|
| `explosion.images` | 16 384 | 2 501 | 13 883 |
| `tiles.odd` (5ᵉ page) | 16 384 | 2 503 | 13 881 |
| `ymm.data` | 14 848 | 5 754 | 9 094 |
| `tiles.even` (3ᵉ page) | 16 384 | 7 323 | 9 061 |
| `anim` | 16 384 | 7 934 | 8 450 |
| `collision` | 12 288 | 4 975 | 7 313 |
| 9 autres | | | 43 378 |
| **total** | | | **105 060** |

La proposition — régions multipages + rangement algorithmique — vise juste.
Voici où je pense qu'elle se trompe, et ce que je propose à la place.

## 2. Ce qui existe déjà (et qu'il ne faut pas réinventer)

**Les régions multipages existent** : `<region pages="3">`. `tiles.even` en
occupe 3, `tiles.odd` 5, `explosion.images` 2.

**Le rangement automatique existe aussi** : `<pageset region="X">` mesure son
contenu, le range **first-fit en ordre de déclaration — la politique même de
l'allocateur v1** (c'est écrit dans le plugin), émet un direntry par page et
publie la page de chaque symbole. `<block>` y loge une unité indivisible et
reçoit son équate de page.

C'est déjà ce qui remplit la queue des tilesets avec la wave du stage. Le
mécanisme n'est donc pas à créer ; il est à **généraliser**.

Trois limites, précises :

- **Un pageset ne prend qu'un seul type de contenu par élément.** `<block>`
  n'accepte que `<asm>` : une unité d'objet avec ses images ne peut pas y
  entrer d'un bloc.
- **Il est adossé à UNE région.** On ne peut pas laisser le builder répartir
  sur l'ensemble des pages libres du jeu.
- **Les régions ordinaires, elles, ne sont pas rangées du tout** : leur taille
  est une déclaration d'auteur, jamais confrontée au contenu autrement que par
  un refus quand ça déborde. C'est là que dorment les 105 Ko.

## 3. Où je pense que tu as tort : ce n'est pas un sac à dos

Le problème posé n'est pas le **sac à dos** (knapsack) mais le **rangement en
boîtes** (bin packing). La différence n'est pas académique :

- Sac à dos : *un* contenant, des objets qui ont chacun une valeur, on
  **choisit** lesquels emporter pour maximiser la valeur. On a le droit d'en
  laisser.
- Rangement en boîtes : des contenants de taille fixe, **tous** les objets
  doivent être placés, on minimise le nombre de boîtes.

Ici on n'a rien à laisser derrière : chaque ennemi doit être en mémoire. C'est
du bin packing.

« Remplir chaque page au mieux par un sac à dos, puis passer à la suivante »
est *une heuristique* de bin packing, et ce n'est pas la meilleure. Deux
raisons de ne pas la retenir :

**Le gain est marginal.** First-Fit Decreasing (trier par taille décroissante,
premier emplacement qui convient) est garanti à moins de 11/9 de l'optimum, et
en pratique à 1-2 %. Le sac à dos par page ne fera pas mieux de façon
significative — alors que le passage du découpage manuel à *n'importe quel*
rangement automatique rend 105 Ko, soit 6,4 pages.

**La stabilité coûte plus cher que l'optimalité.** Un sac à dos réarrange
globalement dès qu'un octet bouge : une image retouchée et toutes les pages
changent, donc toutes les adresses cuites, donc toute l'image disque. Sur un
build qu'on compare d'une fois sur l'autre, qu'on débogue à l'adresse et dont
on mesure les régressions, c'est un vrai coût. FFD en ordre de déclaration
garde les premiers items en place et n'agite que la queue.

Ce n'est donc pas l'algorithme qui manque. **Ce qui manque, c'est que le
rangement s'applique à tout le contenu, pas seulement à l'intérieur d'un
pageset.**

## 4. Les contraintes qu'un rangeur doit respecter (et qu'aucun manuel ne modélise)

C'est la partie qui décide de la faisabilité, et elle est plus intéressante que
le choix d'heuristique.

**Une unité ne se coupe pas.** Un direntry est un fichier, un fichier ne
dépasse pas une page. Le boss le montre : ses 50 867 octets de sprites ne
peuvent pas être un direntry. Il faut donc distinguer le contenu **divisible**
(un jeu d'images, un tileset : le rangeur choisit où couper) de l'**indivisible**
(le code d'un objet). Le pageset fait déjà exactement cette distinction.

**Le code d'un objet et ses images peuvent vivre sur des pages différentes** —
vérifié dans le moteur. `RunObjects` monte `Obj_Index_Page[id]` pour sauter au
code ; `CheckSpritesRefresh` monte `Img_Page_Index[id]` pour lire l'index
d'images ; `AnimateSprite` monte `Ani_Page_Index[id]`. Trois tables
indépendantes, une page chacune. Et chaque descripteur d'image porte déjà la
page de SON sprite. Le rangeur a donc beaucoup plus de liberté qu'il n'y
paraît : seuls trois liens sont contraints, et ils sont exprimés par des tables
que le builder génère.

**L'alignement se déclare.** Le laser à rebond veut ses tampons sur un multiple
de 32 : son unité ne peut atterrir qu'à une adresse alignée. Un rangeur doit
porter une contrainte d'alignement par item, sinon il casse silencieusement ce
que `ALIGN` promet.

**Les scènes ne chargent pas le même ensemble.** C'est la vraie difficulté, et
elle n'a rien de classique : ce n'est pas *un* problème de rangement mais
**plusieurs, qui doivent s'accorder sur les items communs**. Le moteur, le
joueur, les ennemis sont chargés une fois au boot et restent ; le stage est
échangé. Un item chargé par deux scènes doit atterrir **à la même adresse dans
les deux**, sinon les références cuites pointent à côté et le lien de
chargement ne rattrape rien.

**Les régions `interface` sont un contrat d'adresse.** `stage1` et `stage2`
doivent se charger au même endroit, et la place réservée doit valoir pour la
plus grosse des alternatives. Un rangeur qui l'ignore casse l'échange de stage
— la seule chose que le lien au chargement existe encore pour faire.

## 5. Ce que je propose

Trois étapes, du plus rentable au plus ambitieux. La première suffit
probablement à débloquer le cast.

### P1 — `size="auto"` sur une région

Le builder mesure le contenu, en déduit la taille, et **empile les régions
d'une même page** dans l'ordre de déclaration. L'auteur garde le choix de la
page ; il abandonne le calcul de la taille, qu'il fait mal.

```xml
<region name="explosion.images" page="$15" address="$0000" size="auto" pages="2"/>
<region name="anim"             page="$0F" address="auto" size="auto"/>
```

Ce que ça rend, tout de suite : les **105 060 octets** du tableau du §1, sans
toucher à un seul octet de contenu ni à aucune adresse cuite au-delà du
décalage naturel. Le déficit de 25 Ko disparaît, et il reste 80 Ko d'avance
pour la suite du portage.

Le risque est faible et connu : une région qui rétrécit décale ce qui suit sur
sa page, donc toutes les adresses cuites de cette page. Le build le fait déjà à
chaque changement de contenu ; c'est mesuré à chaque fois par le pool-map et le
ram-map.

**Coût** : la taille d'une région n'est aujourd'hui connue qu'après build de son
contenu, alors que les placements sont collectés AVANT (`PlacementScan`) pour
le bake. Il faut donc soit une passe de mesure préalable — la passe de
découverte existe déjà et pourrait la porter —, soit restreindre `auto` aux
régions dont aucune référence cuite ne dépend. La première voie est la bonne et
elle est peu coûteuse : la découverte assemble déjà tout.

### P2 — le pageset accepte une unité complète

Lever la limite « `<block>` ne prend que `<asm>` » : un bloc doit pouvoir
contenir ce qu'un `<direntry>` contient — `<asm>`, `<gfxcomp>`, `<imageset>`.
Alors un ennemi entier devient un item du rangeur, et le cast s'écrit :

```xml
<pageset name="enemies" region="enemies" gensymbols="gen/enemies/pages.asm">
    <block name="bug"     symbol="bug.Object">…</block>
    <block name="bink"    symbol="bink.Object">…</block>
    <block name="tabrok"  symbol="tabrok.Object">…</block>
</pageset>
```

`gen_objid.py` lit `bug.page` au lieu de `<region>.page` — les équates sont
déjà générées. Plus aucune taille à arbitrer, et l'ajout d'un ennemi ne demande
plus de re-découper une page.

Pour le boss, le pattern existe déjà et est éprouvé : ses images en contenu
divisible du pageset (comme `explosion.images`), son code et son index dans un
bloc. C'est **la seule façon** de le loger, quelle que soit la suite.

### P3 — le rangement global, si un jour il le faut

Un pool de pages déclaré une fois, tous les direntries dedans, le builder
répartit. C'est là que les contraintes du §4 deviennent structurantes :
alignement par item, co-résidence par scène, adresse partagée entre scènes,
régions d'interface dimensionnées sur la plus grosse alternative.

Mon avis : **à ne pas faire maintenant.** P1 rend 105 Ko et P2 supprime
l'arbitrage manuel là où il fait mal. P3 ne rendrait, en plus, que ce que le
placement par page laisse encore perdre — quelques kilo-octets — au prix d'un
modèle de contraintes que personne ne saura déboguer quand il refusera un
placement. On y viendra si le jeu complet (huit stages) ne rentre pas, et à ce
moment-là on aura des chiffres pour le justifier.

Et si on y vient, l'algorithme sera **First-Fit Decreasing avec contraintes**,
pas un sac à dos : même qualité de remplissage, résultat stable d'un build à
l'autre, et une explication tenable quand il échoue (« l'item X de N octets n'a
trouvé aucune page avec N octets libres et l'alignement demandé »).

## 6. Réponse courte

Tu as raison sur le fond : **le placement à la main est ce qui nous coûte des
pages**, et 105 Ko dorment dans les queues de régions. La v1 ne fait pas mieux
parce qu'elle est plus compacte — son contenu est identique au nôtre à 173
octets près sur les tuiles — mais parce que son allocateur remplit et que le
nôtre attend qu'on lui dise.

Tu te trompes sur deux points, et ils changent le plan :

1. **Ce n'est pas un sac à dos mais un rangement en boîtes**, et l'heuristique
   simple (FFD, ou même le first-fit déjà implémenté) prend l'essentiel du
   gain. L'optimalité vaut ici moins que la stabilité du résultat.
2. **Les régions multipages existent déjà**, et le rangement automatique aussi.
   Ce qui manque n'est pas une nouvelle fonction mais la **levée de deux
   limites** : les tailles de région restent manuelles (P1), et un pageset ne
   sait pas prendre une unité complète (P2).

Le chemin le plus court vers « le cast entre, boss compris » est P1 seul.
