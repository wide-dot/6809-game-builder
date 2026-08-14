# Répertoires partitionnés : un répertoire par unité de chargement

Spécification détaillée, écrite AVANT toute réalisation (décision auteur,
14/08/2026). Rien de ce document n'est codé au moment où il est écrit.

Le déclencheur : l'ajout de cinq petits fichiers au disque de r-type a gelé
la machine au premier changement de scène (retour au titre après un game
over). L'instruction complète du gel est au chantier 3 du
`plan-portage-rtype-2026-08.md` ; ce document en reprend les faits utiles,
pose le modèle décidé — un répertoire par unité de chargement, au lieu d'un
répertoire unique pour tout le disque — et décrit chaque changement à faire,
un par un.

## 1. Le problème, avec ses chiffres

### Ce qu'est le répertoire

Sur une disquette produite par le builder, le **répertoire** est la table
qui dit, pour chaque fichier : sa taille, sa position sur la disquette
(piste, secteur), s'il est compressé, et s'il transporte des données de
liaison. C'est l'équivalent de la table des matières d'un livre. Le loader
(le programme 6809 qui charge les scènes en cours de jeu) lit ce répertoire
au démarrage et le garde **en permanence en mémoire** : il en a besoin à
chaque chargement de fichier, et aussi pour vérifier qu'un chargement
n'écrase pas un fichier encore utilisé.

Chaque fichier occupe dans le répertoire un ou plusieurs **blocs de 8
octets** :

- 1 bloc principal, toujours (taille, position sur disquette) ;
- 1 bloc de plus si le fichier est déclaré compressé ;
- 1 bloc de plus s'il est déclaré porteur de données de liaison.

L'identifiant d'un fichier (son « file id ») est l'index de son premier
bloc dans le répertoire. C'est pour cela qu'un fichier compressé et lié
« consomme » trois ids : les deux suivants sont ses blocs supplémentaires.

### Où vit le répertoire en mémoire

Le loader vit dans la moitié haute de la page 4, avec une réserve de
mémoire de travail de **4060 octets** (l'autre moitié de la page appartient
à l'arène des objets communs — on ne peut pas pousser le mur). Cette
réserve porte, en même temps :

- le répertoire, en permanence ;
- les données de liaison de chaque fichier chargé, tant qu'il est chargé ;
- le fichier de scène en cours de traitement ;
- la table de suivi des fichiers chargés ;
- et pendant un échange de scène, les besoins des DEUX scènes à la fois.

### Le gel du 14/08

Le disque de r-type compte aujourd'hui 110 fichiers nommés, soit 319 blocs
de répertoire = 2559 octets = 10 secteurs de disquette. La réserve de 4060
octets absorbait tout juste cet ensemble. En ajoutant cinq fichiers, le
répertoire est passé à 11 secteurs (2816 octets) : au premier échange de
scène, la réserve a manqué de place, et le loader s'est arrêté sur son
piège d'erreur (code « plus de mémoire »). Bissection faite : n'importe
quels cinq fichiers produisent le gel — le contenu n'y est pour rien,
c'est un problème de place.

Or le portage doit encore ajouter les stages 3 à 8 (cartes, plans de
défilement, waves, musiques) : plusieurs dizaines de fichiers. Continuer
avec un répertoire unique est sans issue.

## 2. Comment ça marche aujourd'hui (l'existant sur lequel on s'appuie)

Quatre mécanismes existent déjà et ne changent pas ; le modèle proposé ne
fait que les composer autrement.

**Un seul répertoire en mémoire à la fois.** La variable `loader.dir`
pointe le répertoire couramment chargé. `loader.dir.load` (l'appel qui
charge un répertoire) commence par libérer l'ancien s'il y en a un, puis
alloue et lit le nouveau. Le loader ne sait PAS garder deux répertoires.
C'est déjà exactement le comportement voulu pour la partition.

**Les ids de fichiers sont globaux.** Depuis le correctif multi-disquettes
du 30/07, la numérotation des fichiers ne repart pas à zéro à chaque
répertoire : chaque répertoire enregistre dans son en-tête l'id de son
premier fichier (`baseId`), et continue la numérotation du précédent. Un
fichier est identifié par son id seul, sans ambiguïté. Rien à changer.

**Le changement de répertoire est à la charge de l'appelant.** Le loader
ne change jamais de répertoire de lui-même : il n'y a que deux appels à
`dir.load` dans tout le code — celui du démarrage, et l'entrée de la table
de saut que le code de jeu peut appeler. C'est ainsi que le banc du loader
(`examples/loader-ut`) fait ses changements de disquette : le game mode
appelle `dir.load` avec le numéro voulu, puis charge ses fichiers. Le code
de jeu de r-type fera pareil, avec des numéros de répertoire au lieu de
numéros de disquette.

**La vérification de recouvrement ignore déjà ce qui est hors du
répertoire courant.** Quand un chargement va écrire sur les octets d'un
fichier encore suivi, le loader fige avec un code d'erreur — mais depuis
le correctif du 10/08, un fichier suivi qui appartient à un AUTRE
répertoire est ignoré par cette vérification, parce que ses étendues ne
sont pas lisibles depuis le répertoire en mémoire. La partition hérite de
cette règle telle quelle (voir §6).

Le seul point rigide aujourd'hui : **tous les répertoires vivent au même
endroit de la disquette** (face 1, piste 0, secteur 4 — des constantes
assemblées dans le loader). Demander le répertoire n°1 signifie donc
forcément « insérez la disquette n°1 », puisque c'est le seul moyen que
cet emplacement contienne autre chose. C'est LE verrou à lever : sur une
même disquette, plusieurs répertoires doivent pouvoir vivre à des
emplacements différents, connus du loader.

## 3. Le modèle : un répertoire par unité de chargement

Le jeu charge par unités : le commun (moteur résident + titre) une fois,
puis un stage à la fois. Le répertoire suit cette découpe :

| Répertoire | Contenu | Mesuré aujourd'hui |
|---|---|---|
| n°0 | commun + titre + scènes de boot et du titre | 47 fichiers, 136 blocs, **5 secteurs** |
| n°1 | tout le stage 1 + sa scène | 50 fichiers, 148 blocs, **5 secteurs** |
| n°2 | tout le stage 2 + sa scène | 13 fichiers, 35 blocs, **2 secteurs** |
| n°3..8 | chaque stage à venir + sa scène | ~2-3 secteurs chacun, à leur rythme |

La réserve du loader ne porte plus que le répertoire **courant** : au pire
5 secteurs (1280 octets) au lieu de 10 aujourd'hui — et ce pire ne bouge
plus quand on ajoute des stages, chaque stage ne grossissant que SON
répertoire. C'est le point décisif : la place en réserve redevient une
constante du jeu, plus une fonction du nombre total de fichiers.

À chaque instant du jeu, le répertoire en mémoire est :

- au boot et au titre : le n°0 ;
- pendant un stage : celui du stage ;
- pendant un échange (title→stage, stage→stage, stage→title) : l'ancien
  d'abord (pour décharger l'ancienne scène), puis le nouveau (pour charger
  la nouvelle). Jamais les deux à la fois.

Pas d'ajustement de découpe pour le moment (décision auteur) : le titre
reste dans le répertoire n°0.

## 4. Les changements, un par un

### 4.1 Loader : une table des emplacements de répertoires

Aujourd'hui, l'emplacement du répertoire est trois constantes
(`DIR_DEFAULT_FACE/TRACK/SECTOR`). À la place, le loader embarque une
**table des répertoires**, générée par le builder, avec une entrée de 4
octets par répertoire :

```
[disquette physique] [face] [piste] [secteur]
```

`dir.load` change ainsi : au lieu de lire l'emplacement fixe, il consulte
la table à l'index du répertoire demandé.

- Si la **disquette physique** de l'entrée est celle qui est déjà dans le
  lecteur : lecture directe, sans invite. C'est le cas permanent d'un jeu
  mono-disquette — l'invite ne se montre jamais.
- Si c'est une autre disquette : l'invite « Insert disk N » s'affiche,
  avec le numéro de **disquette physique** (plus le numéro de répertoire —
  c'est le seul changement visible du message), et la boucle de relecture
  actuelle fait le reste, y compris la vérification de l'en-tête (tag
  `IDX` + numéro de répertoire) qui protège déjà contre une mauvaise
  disquette.

Le loader tient une nouvelle variable : la disquette physique couramment
dans le lecteur, mise à jour à chaque lecture d'en-tête réussie,
initialisée à celle du répertoire n°0.

Ce qui ne change pas dans `dir.load` : la libération de l'ancien
répertoire, l'allocation du nouveau à sa taille exacte (nombre de secteurs
lu dans l'en-tête), la relecture multi-secteurs, les protections
existantes (registre B rechargé après l'invite, etc.).

Taille de la table : une entrée par répertoire déclaré, nombre connu à
l'assemblage (le builder la génère). Un jeu existant à répertoire unique a
une table à une entrée et se comporte à l'octet près comme avant — sauf le
binaire du loader lui-même, qui change pour tout le monde (voir §8).

### 4.2 Builder : plusieurs `<directory>` par disquette

Aujourd'hui une disquette a un `<directory>` ; le format de configuration
en accepte plusieurs (le multi-disquettes en déclare déjà un par
disquette). Ce qui manque :

1. **Un emplacement par répertoire.** Chaque `<directory>` référence sa
   section de disquette (`section="INDEX"` aujourd'hui). Les sections des
   répertoires supplémentaires sont déclarées dans la configuration du
   jeu, à des emplacements explicites (piste/face/secteur), comme le sont
   déjà SCENE, LINK et DATA chez r-type. Le builder refuse deux sections
   qui se chevauchent — contrôle déjà en place pour les autres sections.
   Contrainte assumée : l'emplacement d'un répertoire est déclaré en dur,
   pas placé automatiquement — il FAUT le connaître avant d'assembler le
   loader, puisque la table y est gravée.

2. **La génération de la table du loader.** Un fichier généré
   (`gen/directories/locations.asm`) donne le nombre de répertoires et la
   table `[disquette][face][piste][secteur]`, dans l'ordre des numéros de
   répertoire. Le bloc `<data section="LOADER">` de la configuration
   l'inclut, comme il inclut déjà les equates de scène par défaut. La
   disquette physique d'un répertoire est le rang de son `<floppydisk>`
   dans le média.

3. **Les equates pour le code de jeu.** Chaque `<directory>` garde son
   fichier d'equates (`gensymbols`) avec les ids de SES fichiers. S'y
   ajoute, par scène, l'equate du répertoire qui la contient :
   `scenes.stage1.dir equ 1` — c'est ce que le code de jeu passe à
   `dir.load` avant de charger la scène. Une unité qui cite des fichiers
   de plusieurs répertoires inclut plusieurs fichiers d'equates ; les
   valeurs étant des constantes distinctes, rien ne se marche dessus.

4. **Ce qui ne change pas** : la numérotation globale continue d'un
   répertoire à l'autre (mécanisme `baseId` en place), le format des blocs
   de 8 octets, l'assertion « ids réservés == blocs émis », l'écriture des
   entrées. Le découpage par blocs déclarés (compressé/lié) reste tel
   quel : le levier « ne plus émettre les blocs vides » (85 blocs morts
   mesurés) reste au TODO comme confort futur, il n'est PLUS nécessaire à
   la tenue du pool.

### 4.3 r-type : la découpe et les deux appels

1. **Configuration** : trois `<directory>` (puis un de plus par stage
   ajouté), sections d'INDEX supplémentaires déclarées sur une piste
   dédiée aux répertoires (proposition : piste 3 de la face 0, libre entre
   LINK piste 2 et DATA piste 4 ; à raison de 2 à 5 secteurs par
   répertoire, une piste de 16 secteurs porte les 9 répertoires du jeu
   complet). Chaque fichier va dans le répertoire de son unité de
   chargement — la configuration l'exprime en déplaçant les déclarations
   `<file>` dans le bon `<directory>`, sans toucher au contenu des
   fichiers eux-mêmes.

2. **Code de jeu** : `game.stage.switch` reçoit déjà la scène cible ; il
   appelle désormais `dir.load` avec l'equate `.dir` de cette scène AVANT
   `scene.load`. L'ordre à l'échange devient : décharger l'ancienne scène
   (l'ancien répertoire est encore en mémoire — c'est lui qui connaît les
   étendues à décharger), puis `dir.load` du répertoire cible, puis
   `scene.load`. Même chose dans `title.launchGame`. Le rechargement de
   checkpoint ne change pas : il recharge la scène du stage courant, dont
   le répertoire est déjà en mémoire.

## 5. Ce qui ne change pas du tout

Le format des entrées de répertoire sur disquette. Les ids globaux et tout
ce qui s'y adosse (`getPageID`, `isLoaded`, relocations, recherche de
symboles). La déduplication au rechargement. Le re-link global après
chaque chargement. Le multi-disquettes physique (l'invite et sa
vérification d'en-tête). Les images des autres jeux et exemples, à la
seule exception près du binaire du loader (§8).

## 6. Recouvrements entre répertoires : la règle, dite clairement

La vérification « ce chargement écrase un fichier encore suivi » ne voit
que les fichiers du répertoire en mémoire. Deux fichiers de répertoires
différents peuvent donc s'écraser sans que le loader fige. Est-ce un
trou ? Non, pour deux raisons :

- c'est déjà la règle entre disquettes depuis le 10/08 (garde diskId), et
  le banc T18 la couvre ;
- la partition suit la frontière d'échange : ce qui se recouvre entre deux
  répertoires est précisément ce que l'échange de scène remplace, et
  l'échange DÉCLARE ce qu'il lâche (`scene.unload` de l'ancienne scène,
  faite pendant que l'ancien répertoire est encore en mémoire).

En clair : la protection reste entière À L'INTÉRIEUR d'une unité de
chargement, là où les erreurs d'adresse involontaires se produisent ; elle
n'a jamais couvert, et ne couvre toujours pas, ce que deux unités
échangées volontairement se disputent.

## 7. Cas limites relevés à l'avance

- **Boot** : le démarrage charge le répertoire n°0 via la table (entrée 0
  = l'emplacement historique). Aucun changement de comportement.
- **Alternance titre↔stage** : chaque échange libère un répertoire et en
  alloue un autre (jusqu'à 1280 octets). L'allocateur de la réserve fait
  déjà ce va-et-vient pour les données de liaison ; pas de fuite possible,
  le répertoire est libéré avant l'allocation du suivant.
- **Message d'invite** : affiche désormais la disquette physique. Sur un
  jeu mono-disquette il ne peut plus s'afficher du tout (aucune entrée de
  table ne désigne une autre disquette).
- **Table figée à l'assemblage** : si une section de répertoire bouge dans
  la configuration, le loader est réassemblé au build suivant — même
  dépendance que les constantes actuelles, mais désormais générée au lieu
  d'être écrite à la main.
- **Un id de fichier hors du répertoire courant** : `getFile` ne fait
  aucune vérification d'appartenance (il soustrait `baseId` et indexe).
  C'était déjà le contrat — l'appelant choisit le bon répertoire. La
  partition ne l'aggrave ni ne l'améliore ; le contrôle d'appartenance
  reste un différé connu.

## 8. Validation prévue

Dans l'ordre, chaque étape avec sa preuve :

1. **Builder seul, un répertoire** : reconstruire le corpus complet — les
   images doivent être identiques à l'octet près SAUF le binaire du loader
   (la table à une entrée remplace les constantes). Précédent accepté du
   10/08 : « le binaire du loader change : les images bootables changent
   toutes ». Le contenu utile (fichiers, répertoires, scènes) doit être
   identique, ce qui se vérifie en comparant les images secteur par
   secteur hors zone loader.
2. **loader-ut au complet** : 17/17 + T18, y compris les scénarios
   multi-disquettes T15 (l'invite doit toujours se déclencher entre
   disquettes physiques, et jamais ailleurs).
3. **r-type partitionné** : lane C1..C7 7/7 — elle traverse toutes les
   bascules de répertoire (boot→titre, titre→stage 1, game over→titre,
   titre→stage 1, stage 1→stage 2, stage 2→titre).
4. **La preuve du gain** : relire dans l'image le nombre de secteurs de
   chaque répertoire (5+5+2 attendus), et vérifier sur machine, après
   plusieurs échanges, que `tlsf.err` reste à zéro avec la place attendue.
5. **Casser le filet une fois** (règle du CLAUDE.md) : provoquer un
   `dir.load` vers une disquette physique absente et constater l'invite ;
   déclarer deux sections de répertoire qui se chevauchent et constater le
   refus du build.

## 9. Différés, dits explicitement

- Les **blocs vides** du répertoire (85 blocs de liaison morts, ~680
  octets) : plus nécessaire pour la place, reste au TODO comme économie.
- Le **contrôle d'appartenance** d'un id au répertoire courant dans
  `getFile` (aujourd'hui contrat d'appelant, comme avant).
- Le **suivi des tailles** dans l'index des fichiers chargés (différé
  loader préexistant, sans rapport direct mais voisin).
- La découpe du titre dans son propre répertoire : « au pire, pas
  nécessaire je pense » (auteur) — à rouvrir seulement si le répertoire
  n°0 grossit au point de redevenir le pire cas.

## 10. Ordre de réalisation proposé (après validation de cette spec)

1. Builder : multi-`<directory>` + table générée + equates `.dir` —
   corpus identique hors loader (preuve 8.1).
2. Loader : table des emplacements + disquette physique courante —
   loader-ut complet (preuve 8.2), y compris les images d'exemples
   reconstruites.
3. r-type : découpe en trois répertoires + les deux appels `dir.load` —
   lane 7/7 + preuves 8.4 et 8.5.
4. Alors seulement : les stages 3 à 8 avec leurs tilemaps, chacun
   apportant son répertoire (l'objet de la demande d'origine).
