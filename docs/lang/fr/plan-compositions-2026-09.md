# La composition comme unité de chargement — plan

Statut : **plan arrêté le 01/09/2026** (décision auteur). **Phases 0, 1 et 2
faites** le même jour ; les suivantes sont à réaliser dans l'ordre donné. Le mécanisme de
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

*Fait le 01/09/2026.* Le corpus reste identique — 80 images, aucun octet
déplacé : c'est un contrôle. Deux tests unitaires (le cas fautif, et une
configuration sans composition qui garde son partage), suite à 9 tests.
Le contrôle a d'ailleurs corrigé une croyance : une réécriture de test montre
qu'un fichier chargé par deux scènes n'est plus « de la déduplication » mais un
refus — la déduplication reste vraie du recouvrement d'octets, pas du partage
de fichier.

### Phase 1 — la composition devient un objet chargeable

`<composition>` gagne `section` et `gensource`, comme `<scene>` : le builder
génère une table qui passe par le pipeline direntry standard, et son nom
devient un équate d'id de fichier.

La table porte, par scène, son id de fichier **et son id de répertoire** — le
builder connaît les deux. Le jeu cesse ainsi de trimballer `scenes.title.dir`,
et le loader peut grouper ses lectures par répertoire. Scènes ordonnées selon
l'ordre disque déjà calculé pour le rapport de déplacements de tête.

**Écart au plan, assumé le 01/09/2026 : la table n'est PAS un fichier du
média.** Elle est émise en source assembleur que le jeu inclut —
`<layout gencompositions="gen/compositions.asm">` — et le jeu passera son
adresse au loader.

La raison est mesurée : le répertoire 0 de r-type est **plein**. Ajouter un
seul fichier l'a fait déborder de sa piste pendant cette campagne (le verrou
de débordement a refusé le build) ; dix tables de composition n'y tiendraient
pas. S'ajoutent deux bénéfices : plus de lecture disque par transition, et le
procédé est déjà l'idiome du dépôt pour ce qui dérive du layout
(`gensymbols`). Le prix est ~106 octets résidents pour r-type — à peu près
rendus par la phase 3, qui supprime `common.cast` et ses 101 octets.

Conséquence sur la phase 2 : `composition.load` reçoit **une adresse de
table**, pas un id de fichier. Plus simple pour le loader — ni malloc, ni
lecture, ni libération — et la table est lisible depuis la fenêtre système
non commutée pendant que le loader tourne dans la fenêtre DATA.

*Fait le 01/09/2026.* Table vérifiée contre les équates des répertoires
(`scenes.boot` = 150 en répertoire 0, `scenes.stage1` = 303 en répertoire 1) ;
10 états, 32 entrées, 106 octets une fois assemblés. Corpus : **80 images
identiques** — rien ne consomme encore la table. 4 tests unitaires.

### Phase 2 — `loader.composition.load`, index 36

En entrée : X = **adresse de la table** de la composition (voir l'écart de la
phase 1).

1. **diff** contre la liste des scènes résidentes ;
2. scènes partantes : `scene.unload` ;
3. scènes arrivantes : monter leur répertoire si besoin, puis les trois passes
   `scene.apply` — `file.load`, `decompress`, `linkData.load` — **sans relier** ;
4. **un seul** `loader.file.link` à la fin ;
5. mettre à jour la liste résidente.

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

*Fait le 01/09/2026.* **140 octets** — dans les 386 de marge, il en reste 246,
INDEX n'a pas eu à bouger. `loader.scene.load` se coupe en deux
(`loader.scene.load.noLink` puis le lien) : la convergence paie un seul
`file.link` quel que soit le nombre de scènes.

L'état courant se garde en **un pointeur** sur la table résidente — ni copie,
ni liste bornée : c'est l'écart de la phase 1 qui le permet, les tables ne
bougeant jamais. Redemander l'état courant ne fait rien du tout.

Preuve : `loader-ut` T19 — converger vers l'état dd, poser une sentinelle dans
le remplissage de la scène commune, converger vers l'état ee, et vérifier que
dd est déchargée, ee indexée, **la sentinelle intacte** (l'intersection n'a
pas été relue) et les mots externes de hub retournés par le lien final.
Redemander le même état ne touche à rien. Banc **18/18 sous toje**, statut
`$0D`, piège T18 toujours armé (`$8301`).

Deux défauts trouvés en chemin, tous deux réels : `scene.unload` et
`scene.apply` n'ont jamais gardé Y (ni `dir.load` X) — le pointeur de parcours
de la convergence partait dans le décor et vidait le pool ; et une ligne vide
ferme la portée des labels `@` de lwasm.

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

*Fait le 01/09/2026.* Le rapport mène par les états, et la plus grosse est le
PIC. Deux propriétés en font un pic et non un autre plancher : le loader garde
un bloc de lien par fichier indexé tant qu'il l'est, donc la demande d'un état
est la somme sur tout ce qu'il tient ; et `composition.load` **décharge avant
de charger**, donc une transition ne tient jamais deux états à la fois. Reste
non compté, et nommé dans le rapport : une table de scène en vol et la table de
slots du loader.

Mesure r-type : pic à **1 074 octets servis, état `stage1`, 22 fichiers
indexés** — contre 448 pour le boot seul. Le budget n'apparaît pas : r-type ne
déclare pas `loader.DEFAULT_DYNAMIC_MEMORY_SIZE`, le loader en calcule un par
défaut. Le déclarer dans le config allumerait le contrôle de dépassement.

### Phase 5 — le packer place contre les compositions

La co-tenance d'`ArenaPacker` vient des compositions et non des scènes :
l'ensemble interdit d'un fichier est celui des fichiers co-résidents dans une
composition qui le contient. Le builder cesse de **refuser** une collision
pour l'**éviter**.

Les dix collisions du lot cancer n'auraient jamais existé, et le lot G n'aurait
pas eu à être inventé. Test d'acceptation : remettre les quatre libs dans le
lot cancer et vérifier que le builder les place seul, correctement.

*Fait le 01/09/2026.* Le changement s'est révélé plus petit que craint : les
deux chemins de placement calculent leur adresse par `at = z.end() - free[i]`,
donc il a suffi d'**initialiser `free[]` en tenant compte de ce qui occupe déjà
la tête de la zone** — un fichier co-résident, et lui seul. Les alternatives se
recouvrent comme avant : c'est à cela qu'une zone partagée sert. Les fichiers à
destination fixe (région, page et adresse littérales) comptent comme occupants —
ce sont précisément ceux dans lesquels une zone d'arène peut grossir sans que
personne ne le voie.

**Les deux tests d'acceptation, tous deux passés :**

La frontière de la page $17, relevée à la main deux heures plus tôt, est
**retirée du config** : le packer démarre la zone du commun à `$1C6D`, juste
après la plus grosse collision co-résidente et l'init de stage qui la suit. Il
a trouvé la borne exacte là où la main avait écrit `$1400` (faux, mesuré quand
la plus grosse était celle du stage 1) puis `$1D00` (juste mais arrondi,
147 octets perdus).

Les quatre bibliothèques remises dans le lot cancer : le build **refuse**, avec
« collection 'stage1.tiles.even' does not fit : 5 603 bytes of elements remain
and every free run is used ». C'est la bonne réponse — il n'y a réellement pas
la place, et le lot G était la vraie correction. Éviter quand c'est possible,
refuser lisiblement quand ça ne l'est pas.

Déclarer aucun état ne change rien : sans composition, aucun fichier n'est
connu comme co-résident, chaque zone démarre à sa tête, et le rangement est
celui qui a produit toutes les images d'avant. Corpus : 80 images, seules les
4 de r-type bougent (le commun remonte de 147 octets). `rtype_bench` 7/7.

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
