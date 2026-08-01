# Ne pas exporter ce que le builder sait déjà placer

Étude, pas d'implémentation. Question posée : les tuiles d'une tilemap ne sont
jamais appelées nommément depuis du code — leurs références vivent dans une
table générée. Pourquoi payer, en place et en CPU au chargement, un mécanisme
de liaison conçu pour des symboles d'API ?

## 1. Ce que le schéma actuel coûte, mesuré

Formats émis par le builder (constatés dans `LwObject.java`, confirmés côté
loader dans les STRUCT de `loader.asm`) :

| entrée | taille | résolution au chargement |
|---|---|---|
| export (abs ou rel) | 4 o — id numérique + offset | — (c'est la table qu'on parcourt) |
| `intern` | 4 o — offset dest + offset val | O(1) : base + valeur |
| `extern16` | 6 o — offset dest + opérande + id symbole | **recherche linéaire** sur les exports de tous les fichiers chargés |
| `externPg` | 6 o — offset dest + opérande + id fichier | recherche linéaire sur l'index des fichiers chargés |

Cas `examples/tilescroll` : 384 entrées de carte (24×8 tuiles × 2 cartes),
chacune `fcb page` + `fdb adresse`, soit **384 extern16 + 384 externPg =
4608 octets** de link data pour la seule carte (5340 avec le reste de l'unité).
Conséquences concrètes : la section LINK a dû prendre une piste entière, le
pool TLSF a triplé (le buffer de link data y transite), et le chargement coûte
**~87 000 instructions de plus** que le banc sprites (883 096 contre 796 240
du boot à la première instruction du game mode), soit ~113 instructions par
relocation avec une trentaine d'exports en portée. Le coût de liaison d'une
scène est en `références × exports` : quadratique.

La v1 ne payait rien : `INCLUDEGEN` injectait la carte **après** le placement
global, adresses absolues en dur. Le confort v2 (déclaratif, relogeable) a été
payé au prix fort précisément là où il ne sert à rien — ces adresses ne
bougent jamais.

## 2. Le fond : trois rôles de symboles, un seul mécanisme

Le corpus mélange trois usages sous le même `EXPORT`/`EXTERNAL` :

1. **API nommée, écrite à la main** — `set_glyph`, `Ani_glyph`,
   `obj.paged.run`, `irq.on`. Peu nombreux, référencés par du code, et le
   dynamisme du linker leur est essentiel (références en avant, scènes
   échangées à chaud). *C'est pour eux que le linker existe.*
2. **Tables générées en masse** — les `adr_*` d'un index d'imageset, les
   pointeurs d'une carte de tuiles, les 2667 étiquettes d'échantillons de
   `mplus`. Générés par le builder, consommés par des tables que le builder
   génère aussi ou pourrait générer. Le générateur *connaît* les valeurs ; le
   linker refait au chargement un travail déjà fait au build.
3. **Pages** — `<direntry>$PAGE`, mécanisme dédié (`externPg`), même
   observation : quand la scène est `PLACED`, la page est un littéral connu.

L'audit chiffre le mélange : **1948 exports pour 46 imports** sur les
exemples. La règle d'hygiène (« n'exporter que ce qui franchit une frontière
de direntry ») ne suffit pas : les `adr_*` de tilescroll *franchissent* une
frontière et sont pourtant du rôle 2.

Principe directeur proposé : **le linker de chargement est réservé au rôle 1 ;
ce que le builder génère et place, le builder le résout.**

## 3. Les options

### A. Co-localiser la carte avec les tuiles (même unité lwasm)

Les `fdb adr_*` deviennent des références internes → `intern`, 4 o, O(1).

- Gain : link data de la carte 4608 → 3840 o (les 384 `externPg` restent) ;
  CPU ~87k → ~10k.
- Limites : la carte doit tenir dans la même page de 16 Ko que les tuiles ;
  couple des données que R-Type sépare (cartes par niveau, tuiles partagées
  entre niveaux) ; ne traite ni les pages ni le cas général.
- Verdict : palliatif localisé, pas un mécanisme. **Non retenue** comme
  réponse de fond.

### B. Résolution statique au build contre les régions `PLACED` (« prelink »)

L'idée centrale. La scène déclare `<load name="assets.tiles" region="tiles"/>`
et la région donne page `$06`, adresse `$0000` : le builder connaît l'adresse
finale de **chaque symbole** de l'unité au moment où il émet la link data de
l'unité référençante. Il peut appliquer la relocation lui-même — extern16
*et* externPg — et n'émettre **aucune** entrée.

- Gain sur tilescroll : link data de la carte = 0, CPU = 0, pool TLSF revient
  à sa taille normale, et les exports `adr_*` deviennent élagables (option C).
- Conditions de sûreté, toutes vérifiables par ce que `SceneChecks` sait déjà :
  - le fournisseur est chargé à une région `PLACED` dans **toutes** les scènes
    où le référençant est chargé, à la même destination ;
  - pas d'instance multiple du fournisseur à des adresses différentes ;
  - sinon, repli silencieux sur la link data classique (le mécanisme reste).
- Ce qu'on perd, et pourquoi c'est acceptable ici : la correction différée des
  références en avant (« résolu à 0 puis corrigé au prochain `scene.load` »)
  ne s'applique plus aux références cuites — sans objet, puisqu'on ne cuit que
  ce qui est prouvé constant.
- Interaction `loadDelta` (futur) : les régions étant fixes par unité, un
  delta-reload ne déplace rien ; les adresses cuites restent vraies.
- Périmètre : purement builder. **Aucune modification du runtime v1 importé,
  aucune du loader** — zéro écart au manifeste.
- Surface de commande : soit automatique-avec-preuve (le builder cuit ce qu'il
  peut prouver et journalise « N références résolues statiquement »), soit
  opt-in explicite (`link="static"` sur le `<load>` ou le `<direntry>`) qui
  échoue si la preuve manque. La seconde est plus lisible ; la première ne
  demande rien à l'auteur. Les deux peuvent coexister (auto + attribut pour
  forcer l'erreur si la preuve casse).

### C. Élagage des exports jamais importés (tree-shaking)

Le builder voit toutes les unités d'un target et toutes les références
`EXTERNAL` : il peut filtrer `getExportAbs`/`getExportRel` sur les seuls
symboles effectivement importés ailleurs.

- Gain : 4 o/export sur disque (≈ 7,6 Ko sur le corpus actuel) et — plus
  important — **des tables de recherche plus courtes pour toutes les
  résolutions restantes**, celles du rôle 1 comprises.
- Sûreté : les ids de symboles sont attribués par target (`LinkSymbols` remis
  à zéro), le builder a la vision complète, y compris multi-disquette. wddebug
  lit les `.lst`/`.glb`, pas la link data : le débogage ne perd rien.
- C'est l'option gratuite : automatique, sans changement de format, sans
  toucher au runtime.

### D. Regrouper les extern16 par symbole (évolution de format)

Aujourd'hui chaque référence porte son id et déclenche sa propre recherche.
Trier/regrouper — `[id symbole][opérande][n][offset]×n` — donne **une
recherche par symbole distinct** puis n patchs O(1).

- Gain sur tilescroll : 9 recherches au lieu de 384 (~87k → ~12k
  instructions) ; link data ≈ 4608 → ~1700 o.
- Coût : évolution conjointe builder + loader (format des link data), donc un
  écart runtime à tracer, et une passe de test loader-ut complète.
- Intérêt : c'est la seule option qui aide le cas où le dynamisme est
  *réellement requis* en masse (une table vers une unité échangée à chaud).
  Ce cas n'existe pas aujourd'hui dans le corpus.

### E. Le pipeline (point 7) génère les tables en absolu

Cas particulier de B vu du générateur : quand le builder générera lui-même
cartes et index (l'équivalent des `.glb` v1), il émettra des littéraux
puisqu'il connaît le placement. B est plus général (profite aussi à l'asm
écrit à la main) ; E en est la conséquence naturelle une fois B en place.

## 4. Recommandation, en phases

1. **C d'abord** — gratuit, sans risque, améliore tout le monde. À faire dès
   la prochaine session builder.
2. **B ensuite** — c'est la réponse de fond à la question posée, et l'argument
   est double : tilescroll aujourd'hui, le pipeline du point 7 demain. Le
   garde-fou est déjà en place (`SceneChecks` connaît compositions et
   placements). Commencer en automatique-avec-preuve + ligne de rapport, ajouter
   l'attribut si le besoin de forcer apparaît.
3. **D seulement si** un usage légitime de tables massives *dynamiques*
   apparaît (instances multiples d'un même contenu à des adresses variables).
   Ne pas le faire par anticipation : c'est un format de plus à maintenir des
   deux côtés.
4. **A et E** : non retenues comme mécanismes (A palliatif, E découle de B).

Ce que ça donnerait sur tilescroll une fois B en place : link data de la carte
0 octet, ~87 000 instructions de chargement rendues, pool TLSF et piste LINK
revenus à la normale, et les `adr_*` élagués par C. Le linker de chargement
retrouve son périmètre de conception : les symboles d'API, quelques dizaines
par scène.
