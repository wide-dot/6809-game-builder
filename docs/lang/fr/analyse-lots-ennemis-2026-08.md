# Lots d'ennemis modulaires : charger dans un stage exactement son cast

Statut : ANALYSE — à valider avant toute réalisation.
Source des données : la matrice routine×stage du repo d'extraction arcade
(`re.arcade.r-type`, `data/routines.yaml` + les waves extraites, qui sont
reprises verbatim dans `src/stages/*/wave.asm`). Les tailles viennent du
rapport d'occupation du build courant.

## 1. Le besoin

Les six ennemis « de bibliothèque » (bink, patapata, cancer, bug, pstaff,
scant) sont implémentés et tournent dans le stage 1. Les waves des stages
3 à 7 les citent aussi (224 lignes, aujourd'hui commentées). Il faut les
faire apparaître dans ces stages **sans dupliquer les données sur disque**
(une copie par stage a été écartée) **et sans charger d'inutile en RAM**
(un « tout résident » garderait bink en mémoire pendant le stage 5 qui ne
l'utilise pas, et confisquerait pour toujours 59 Ko d'arène dont les casts
spécifiques des stages auront besoin).

## 2. La matrice, réduite à ce qui décide

Croisement des 51 routines arcade avec les 8 waves (lignes actives et
commentées confondues — c'est l'extraction arcade telle quelle).

### Les partagées implémentées (l'objet de ce chantier)

| routine | stages | lignes de wave | taille RAM (o) |
|---|---|---|---|
| bink | 1, 3, 4, 6, 7 | 95 | 12 672 |
| patapata | 1, 3, 4, 7 | 119 | 3 758 |
| cancer | 1, 4, 5, 7 | 68 | 6 699 |
| bug | 1, 4, 7 | 10 | 6 791 |
| pstaff | 1, 4, 7 | 17 | 12 082 |
| scant (+ scantfire, son tir) | 1, 7 | 2 | 10 657 + 6 047 |

### Les partagées PAS encore implémentées (à anticiper, pas à faire)

| routine | stages | remarque |
|---|---|---|
| mid (19) | 5, 7 | deviendra un lot le jour où elle existera |
| (sans nom) 39 | 2, 4, 5, 6, 7 | une ligne par stage — probablement un effet système |
| cyclingPalette (32) | 1, 4, 6, 7, 8 | citée 44 fois ; candidate au COMMUN résident, pas à un lot |
| palette_blackout (26) | 1, 7 | même famille que ci-dessus |
| 33wave | 4, 8 | à identifier |
| stageInit, 1, 2 | quasi tous | système arcade — la v2 a déjà son équivalent (openingSequence) |

### Les spécifiques d'un seul stage (chantiers ultérieurs, ordre naturel)

stage 2 : gouger, wick, brood, outslay, gomander (squelettes posés) ·
stage 3 : warship-core · stage 4 : cytron, Geld, compiler · stage 5 :
pursuer, bellmite, cheetah, slither · stage 6 : newt, dop · stage 7 :
city-panel, fast, boldo, bronco · stage 8 : mikun, bydo, 46, 47.
Elles vivront chacune dans le répertoire de leur stage — rien de nouveau.

## 3. Les lots : la signature d'usage fait la découpe

Un lot = un direntry (données + link data une seule fois sur disque),
regroupant les ennemis qui ont exactement la même liste de stages :

| lot | contenu | stages | taille RAM (o) |
|---|---|---|---|
| A | bink | 1, 3, 4, 6, 7 | 12 672 |
| B | patapata | 1, 3, 4, 7 | 3 758 |
| C | cancer | 1, 4, 5, 7 | 6 699 |
| D | bug + pstaff | 1, 4, 7 | 18 873 |
| E | scant + scantfire | 1, 7 | 16 704 |

Ce qu'un stage charge, et rien d'autre :

| stage | lots | RAM cast commun (o) |
|---|---|---|
| 1 | A B C D E | 58 706 (comme aujourd'hui) |
| 3 | A B | 16 430 |
| 4 | A B C D | 42 002 |
| 5 | C | 6 699 |
| 6 | A | 12 672 |
| 7 | A B C D E | 58 706 |
| 2, 8 | aucun | 0 |

Une routine qui rejoint la bibliothèque plus tard (mid, 39…) devient un
lot de plus ; un lot dont la signature évolue à l'implémentation réelle
des stages se redécoupe — la matrice reste la source de vérité.

## 4. Où vivent les lots, et comment un stage les charge

Contrainte structurelle héritée de la partition : une scène se charge
depuis UN répertoire (celui en cache). Un lot partagé par les stages 3 et
7 ne peut donc pas être cité par leurs scènes s'il ne vit que dans le
répertoire commun. Deux mécanismes possibles :

### Option retenue (proposée) : scènes de cast dans le répertoire 0

Les 5 lots vivent dans le répertoire commun (données sur disque UNE fois),
avec **une petite « scène de cast » par stage** (quelques octets chacune :
la liste des lots de ce stage). L'échange de stage devient symétrique en
deux temps :

1. décharger la scène du stage sortant (son répertoire est en cache),
2. monter le répertoire 0 : décharger la scène de cast sortante, charger
   celle du stage entrant,
3. monter le répertoire du stage entrant, charger sa scène.

Coût : une lecture de répertoire de plus par échange (~1,5 Ko, une fois
par changement de stage) et un paramètre de plus à `game.stage.switch` /
`game.stage.unload`. Gain décisif : **un lot garde son identité de
fichier unique**. La déduplication du loader fait le reste : au passage
3→4, bink est déjà en RAM à la bonne adresse — il n'est PAS relu du
disque. Un stage sans cast commun (2, 8) a une scène de cast vide : le
chemin de code reste uniforme.

### Option écartée : direntries de renvoi dans chaque répertoire de stage

Un élément builder « direntry qui référence les données d'un autre
fichier » éviterait tout changement engine (chaque scène de stage cite
ses lots via son propre répertoire). Écarté : deux ids de fichier pour
les mêmes octets cassent le modèle d'identité (un fichier = un id) que la
campagne vient d'unifier — la déduplication ne joue plus (relecture
disque à chaque échange), et l'exclusivité des exports devient un cas
particulier de plus à raisonner.

## 5. La RAM : adresses fixes, réutilisation exprimée

Les lots gardent des adresses fixes dans l'arène des ennemis, mesurées au
placement (comme la frontière commun/ennemis de la page $0C aujourd'hui).
La zone « union des lots » (58 706 o) est réservée telle quelle — ça ne
coûte RIEN de plus qu'aujourd'hui, le stage 1 la remplit déjà entière.

Le dividende arrive avec les casts spécifiques futurs : pendant le
stage 5, seuls 6 699 o de la zone sont occupés (cancer) — les emplacements
de bink, patapata, bug, pstaff, scant sont VIDES. Le builder sait déjà
exprimer qu'un contenu peut occuper la place d'un autre s'ils ne sont
jamais co-chargés (exclusivité par ensembles). Le jour où le cast du
stage 5 (pursuer, bellmite, cheetah, slither) déborde de l'arène, il
pourra se déclarer exclusif des lots que le stage 5 ne charge pas, et
récupérer cette place. Rien à construire aujourd'hui, mais la découpe en
lots est ce qui rend cette porte ouvrable — le « tout résident » l'aurait
murée.

## 6. Ce que ça change concrètement

- **Builder / config** : les 5 lots deviennent des direntries du
  répertoire 0 (déplacées du répertoire 1) ; 8 scènes de cast (dont deux
  vides) dans le répertoire 0 ; le répertoire 1 maigrit de 7 entrées, le
  0 grossit d'environ 13 — les secteurs de INDEX1/INDEX2 se décalent si
  le contrôle d'occupation le demande.
- **Engine (games/r-type)** : `game.stage.switch` et `game.stage.unload`
  portent la scène de cast en plus de la scène de stage ; les handOvers
  des 8 mains passent les deux identifiants.
- **Stages 3-7** : `objid.const` gagne les ids (03 : +2 → 34 ; 04 : +5 →
  37 ; 05 : +1 → 33 ; 06 : +1 → 33 ; 07 : +6 et scantfire est déjà dans
  le préfixe commun → 38) — loin du plafond 127 ; `objid.index` gagne les
  lignes (pages des lots, adresses EXTERNAL) ; les 224 lignes de waves se
  décommentent.
- **Stage 1** : sa scène cesse de charger les 7 fichiers (sa scène de
  cast le fait) ; ses lignes d'index pointent les mêmes symboles — rien
  d'autre ne bouge.

## 7. La preuve

1. Lane tour complet : les compteurs d'apparitions doivent monter
   d'exactement le nombre de lignes réactivées par stage (03 : +5, 04 :
   +59, 05 : +3, 06 : +35, 07 : +122, 08 : +0), et le stage 1 rester
   identique (mêmes ennemis, mêmes 9 objets à l'ouverture).
2. À l'échange 3→4, vérifier en RAM que bink n'a pas bougé et que le
   compteur de fichiers indexés ne montre ni fuite ni relecture.
3. Le contrôle d'occupation du média et le contrôle de scène tranchent le
   placement (répertoires décalés, arène) — un refus au build est une
   information, pas un contretemps.
4. Corpus : seules les images r-type changent (le loader ne bouge pas ;
   si l'engine commun de jeu bouge, c'est confiné à games/r-type).

## 8. Différés explicites

- Récupération de la place des lots non chargés par les casts spécifiques
  (l'exclusivité existe, on l'activera quand un stage débordera).
- Lots futurs : mid (5,7), la routine 39 (2,4,5,6,7) à identifier,
  cyclingPalette au commun résident.
- L'identification des routines encore sans nom (33wave, 46, 47, 34…).
