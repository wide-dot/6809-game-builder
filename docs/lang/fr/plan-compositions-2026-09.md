# La composition comme unité de chargement — plan

Statut : **plan arrêté le 01/09/2026** (décision auteur). La phase 0 est en
cours ; les suivantes sont à réaliser dans l'ordre donné. Le mécanisme de
déclaration (`<composition>`) et ses contrôles au build sont **déjà en place** —
voir [`scenes.md`](../en/scenes.md), section « The composition ».

## 1. Ce qu'on vise

Le jeu cesse de nommer des scènes et nomme un **état de RAM**. Le loader fait
converger la mémoire vers cet état : il décharge ce qui n'en fait pas partie,
charge ce qui manque, garde l'intersection telle quelle.

L'enjeu n'est pas le confort d'écriture. Aujourd'hui la même vérité est écrite
à trois endroits — les masques de `src/common/cast.const.asm`, la table
`cast.lots` de l'unité résidente, et les `<composition>` du config.xml — et rien
ne les tient ensemble. Qu'elles dérivent, et le builder vérifie un état que le
jeu n'a pas : le contrôle passe pendant que la RAM se recouvre. C'est le trou
« une composition qui ment par omission », le seul que le verrou actuel ne
ferme pas.

Charger des compositions le ferme, non par génération de code, mais parce
qu'il ne reste **qu'un seul artefact** à mentir. Tout l'appareil de cast
(sept bits, masques, table ordonnée, `cast.converge`) n'est qu'un diff de
composition écrit à la main pour un sous-ensemble de scènes.

## 2. Les faits mesurés qui rendent la chose possible

| fait | mesure (01/09/2026) |
|---|---|
| Les scènes partitionnent les fichiers | r-type : 17 scènes, 189 fichiers chargés, **0 partagé**. Corpus entier : une seule exception, `loader-ut` |
| Le diff peut donc être **par scène** | le loader n'a besoin que d'une liste d'ids de scènes résidentes (~32 octets), pas d'un index de résidence par fichier — ce qui évite d'avoir à combler le trou de son index actuel, qui ne connaît que les fichiers porteurs de link data |
| Les briques existent | `loader.scene.apply` est un marcheur générique (X = routine, appliquée à chaque fichier de la table) ; `scene.load` = trois passes d'apply + un `file.link` ; `scene.unload` sait relire une table absente du cache |
| L'ABI est extensible | « l'entrée s'AJOUTE en fin de table » — prochain index libre : **36** |
| Marge du loader | assemblé à **4 204 octets** ; INDEX commence face 1 secteur 4, d'où **386 octets** de marge |

L'exception `loader-ut` est délibérée : `data.marker.bb` est chargé par
`scenes.main` **et** `scenes.trap`, ce qui arme le piège `LOAD_OVERLAP` du
test T18. C'est la raison pour laquelle l'invariant de la phase 0 ne vaut que
pour les configurations qui déclarent des compositions.

## 3. Les phases

### Phase 0 — l'invariant de disjonction

Un contrôle de build : quand une configuration déclare des compositions, aucun
fichier ne peut être chargé par deux scènes. C'est la condition qui rend le
diff par scène correct — décharger une scène ne doit jamais retirer un fichier
qu'une autre scène résidente utilise encore.

Portée : les seules configurations qui déclarent des compositions. Lieu :
`CompositionChecks`, à côté des trois contrôles existants.

*Preuve* : corpus inchangé ; un test unitaire du cas fautif.

### Phase 1 — la composition devient un objet chargeable

`<composition>` gagne `section` et `gensource`, comme `<scene>` : le builder
génère une table qui passe par le pipeline direntry standard, et son nom
devient un équate d'id de fichier.

La table porte, par scène, son id de fichier **et son id de répertoire** — le
builder connaît les deux. Le jeu cesse ainsi de trimballer `scenes.title.dir`,
et le loader peut grouper ses lectures par répertoire. Scènes ordonnées selon
l'ordre disque déjà calculé pour le rapport de déplacements de tête.

*Preuve* : la table apparaît dans la vue Média du rapport ; les images des
configurations sans composition restent identiques à l'octet près.

### Phase 2 — `loader.composition.load`, index 36

En entrée : X = id de la composition.

1. charger sa table (malloc + read, comme une table de scène) ;
2. **diff** contre la liste des scènes résidentes ;
3. scènes partantes : `scene.unload` ;
4. scènes arrivantes : les trois passes `scene.apply` — `file.load`,
   `decompress`, `linkData.load` — **sans relier** ;
5. **un seul** `loader.file.link` à la fin ;
6. mettre à jour la liste résidente, libérer la table.

Ce qui justifie une entrée dédiée plutôt qu'une boucle côté jeu : le re-link
coûte de l'ordre de `références × exports`. Boucler paierait N re-links ; ici
on en paie un.

État du loader : `composition.current` et une liste bornée d'ids de scènes
résidentes (16 entrées suffisent — r-type culmine à 7).

Budget : le diff est une boucle par-dessus des routines existantes, estimée à
120-200 octets plus l'état. Ça tient dans les 386 octets de marge, sans
confort. **Repli** si ça déborde : déplacer INDEX du secteur 4 au 5 (+255
octets), geste déjà fait une fois, couplé à `DIR_DEFAULT_SECTOR` dans
`loader.asm` et à `storage.xml`.

*Preuve* : `loader-ut` gagne ses tests T19+ — converger de l'état A vers B,
vérifier que l'intersection n'est pas relue (compteur de lectures), que la
différence est déchargée (`linkData.count`), et qu'un seul re-link a lieu.

### Phase 3 — r-type passe aux compositions

`game.stage.switch` se réduit à converger vers la composition cible puis
sauter dans `stage.main`.

Disparaissent : `cast.converge` et l'unité résidente `common.cast` (**101
octets rendus à la page 1**), les sept bits et masques de `cast.const.asm`, la
table `cast.lots`, le `STAGE_SCENE` de chaque main et le `game.stage.unload`
qui va avec. Le relais de boot devient « converge vers `compositions.title` ».

Propriété à énoncer, pas à corriger : l'intersection est gardée **telle
quelle**, mutations comprises. C'est déjà le cas (la déduplication ne recharge
pas) et c'est ce sur quoi repose l'état persistant qui traverse l'échange. Le
checkpoint sans disque en devient automatique — converger vers l'état courant
est un no-op.

*Preuve* : `rtype_bench` au vert (7/7, chaîne 1→2→3), plus une sonde par état
comparant la RAM à la composition déclarée.

### Phase 4 — le `pool-map` devient un pic

Sommer le link data par **composition** au lieu de par scène, et rapporter le
pic face à `loader.DEFAULT_DYNAMIC_MEMORY_SIZE`. Le rapport prévient
aujourd'hui que « le total est un plancher, pas le pic » ; avec les états, le
plancher devient le vrai chiffre. Un dépassement TLSF ne montre rien à
l'écran : le loader ne rend simplement jamais la main.

Indépendante des autres, réalisable dès la phase 1.

### Phase 5 — le packer place contre les compositions

La co-tenance d'`ArenaPacker` vient des compositions et non des scènes :
l'ensemble interdit d'un fichier est celui des fichiers co-résidents dans une
composition qui le contient. Le builder cesse de **refuser** une collision
pour l'**éviter**.

Les dix collisions du lot cancer n'auraient jamais existé, et le lot G n'aurait
pas eu à être inventé. Test d'acceptation : remettre les quatre libs dans le
lot cancer et vérifier que le builder les place seul, correctement.

Risque : c'est la phase la plus profonde. Le premier ajustement par arène
devient une contrainte par fichier, proche d'une coloration de graphe, et les
placements bougent — donc toutes les images de r-type. Le harnais
`build-corpus.sh` est fait pour ça.

### Phase 6 — la marge des répertoires

Une colonne dans un rapport existant : entrées utilisées et libres par
répertoire, octets restants avant la section suivante. Un build a été refusé
parce qu'ajouter un fichier faisait déborder le répertoire 0 de sa piste ; le
verrou a fonctionné, mais rien ne le disait avant.

## 4. Compatibilité avec les tests et les exemples

**Les 17 configurations à scène unique** (collection, hscroll, mscroll,
objects, overlay, pscroll, sprites, tlsf-ut, vscroll, mplus,
stacked-overflow, halfpage, tilescroll…) : une composition y serait triviale.
Elles n'en déclarent pas, donc les phases 0, 1, 4 et 5 ne les touchent pas et
elles continuent d'appeler `scene.load`.

**`loader-ut`** est le cas sensible, et il est protégé : la disjonction n'est
exigée que des configurations déclarant des compositions, et l'ABI existante
ne bouge pas. Ses 17 tests et son piège T18 passent inchangés. Il devient en
plus le banc naturel de la phase 2.

**`examples/sound`** (2 scènes, disjointes) est le premier candidat à déclarer
ses deux états : il avertit aujourd'hui pour deux paires — les musiques
title/level1, alternatives légitimes — que le contrôle confirmerait.

**Le point de vigilance réel** : la phase 2 fait grossir le loader, et toute
image du corpus change dès qu'un octet s'y ajoute. Le précédent est documenté
(rendre le décompresseur relogeable a coûté ~14 octets et changé les 8 images
d'exemples). Conséquence de méthode : après la phase 2, la comparaison de
hachages n'est plus un test d'identité mais un relevé de ce qui a bougé, et
c'est `loader-ut` sous toje qui redevient la preuve. Les images MO6 restent
validées au build seul, faute d'émulateur.

## 5. Ordre

Phases 0 → 1 → 2 → 3 en séquence : c'est le chemin critique. Les phases 4 et 6
sont indépendantes (4 dès la phase 1, 6 tout de suite). La phase 5 vient en
dernier : elle veut des données honnêtes, donc après la 3.

## 6. Hors périmètre, gardé pour plus tard

**Le point d'entrée porté par la composition**, qui supprimerait le symbole
`stage.main` à fournisseurs multiples — relié au chargement à chaque échange
parce que neuf mains l'exportent. À reprendre seulement si le coût de liaison
devient un sujet : ça change la façon dont un écran est atteint.
