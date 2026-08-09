---
date: 2026-08-08
sujet: Le dernier héritage v1 du placement — un membre de pageset par zone déclarée —
  et inventaire des mécanismes de placement morts ou en dérive.
statut: analyse, rien d'implémenté
s'appuie sur: modele-zones-2026-08.md, analyse-multipage-2026-08.md
---

# Placement : faire tomber le membre par zone, et ce qui est mort autour

## 1. La question

Un `<pageset>` émet **un membre par zone que sa région déclare**, rempli ou pas
(`PageSets.memberNames(name, region.pages)` dans `DirectoryPlugin`, boucle
d'émission `for p in 0..zoneCount` dans `PageSetPlugin`). Depuis 3ac06de un
membre non rempli est un fichier vide (`$ff00`) : il ne coûte plus ni octet de
données ni secteur. Restent une entrée de répertoire et des identifiants
réservés pour rien. C'est le dernier endroit où une **déclaration** fige une
structure d'émission que le builder sait **mesurer** — partout ailleurs le
modèle est devenu : l'auteur déclare des contraintes, le builder mesure,
décide, publie.

Deux questions traitées ici : ce qu'il faut pour que le compte de membres
devienne le résultat du rangement ; et, en cherchant, quels autres mécanismes
de placement sont morts, redondants ou en dérive.

## 2. Pourquoi les ids sont réservés sur la déclaration

La chaîne complète, telle qu'elle est dans le code :

1. **Un id de fichier est un index structurel du répertoire.** Une entrée
   occupe 1 à 3 blocs de 8 octets (`DirEntryPlugin.blockCount` : 1 + codec +
   linkdata) et l'id est l'index du premier bloc. `loader.dir.getFile` est en
   O(1) : adresse = base + (id − baseId) × 8.
2. **La marche %11 du loader recompte les blocs par les flags.** Un bloc
   séquentiel `%11` ne porte que l'id de départ ; l'id suivant se dérive de
   l'entrée elle-même (`loader.scene.apply.type11` : next = id + 1 + flag
   compression + flag linkdata). C'est ce qui impose que les deux flags
   reflètent le bloc **réservé**, jamais son contenu — d'où les descripteurs
   à zéro conservés (compression qui ne paie pas, linkdata déclarée vide).
3. **`DirectoryPlugin` déduit tous les ids du seul arbre de configuration**,
   avant de rien construire : il écrit les équates `gensymbols` (nom → id)
   dont les tables de scènes et le code du jeu ont besoin pour s'assembler
   **pendant la même passe**. Pour un pageset, le seul nombre disponible à ce
   moment-là est le budget — `region.pages` — donc un membre par zone.
4. **L'assertion `ids réservés == blocs émis`** (fin de `DirectoryPlugin` et
   garde-fou de `DirEntryPlugin`) verrouille l'ensemble : toute divergence
   ferait pointer chaque id suivant sur la mauvaise entrée.

Le point 3 est le seul qui force le budget. Les points 1, 2 et 4 — «
l'arithmétique du type %11 » — sont indifférents à *quand* le compte est connu,
pourvu que réservation et émission restent d'accord.

## 3. Ce que ça coûte aujourd'hui

Sur r-type, un seul membre vide : `stage2.tiles.odd.4` (la région `tiles.odd`
offre 5 zones, le stage 2 en remplit 4). Coût : 24 octets de répertoire
(3 blocs, codec + linkdata déclarés), 3 ids, 5 octets dans la table de
`scenes.stage2` (le triplet %01 du membre), un chargement à vide au boot du
stage ($ff00 → rien), une entrée de plus dans la marche de déchargement. Plus
le warning « fills 4 of the 5 zones » à chaque build, qui dit une chose que
l'auteur a déjà choisie.

C'est peu — tant que les budgets sont serrés à la main. Le jour où les ~149
objets de jeu passent par des pagesets à budgets larges (et un budget se
déclare large, c'est sa fonction), les membres vides se multiplient d'eux-mêmes.
Le vrai coût est ailleurs : trois documents expliquent les membres vides, dont
un déjà faux (§6), et chaque évolution du répertoire doit raisonner sur des
entrées qui n'existent que pour l'arithmétique.

## 4. Comment le faire tomber

Le compte de membres doit devenir le **résultat du rangement**. Le rangement
demande les tailles, les tailles demandent la mesure (lwasm). Deux voies :

**A. Semer le compte depuis la passe de découverte**, comme `measured`,
`fileSizes` et le harvest : la découverte enregistre « ce pageset a rempli n
pages », la passe réelle réserve n membres. C'est le motif établi de
`Target.java` — mais il ajoute un état trans-passe de plus, et la passe de
mesure (la toute première) réserverait encore sur le budget : les ids
différeraient entre passes.

**B. Mesurer et ranger au moment de la réservation.** `DirectoryPlugin`, en
rencontrant un `<pageset>` dans sa boucle de réservation, déclenche la mesure
et le rangement (les deux existent déjà, purs, dans `PageSetPlugin` :
`measure()` + la boucle premier-ajustement), garde le résultat dans le
contexte, et réserve `pages.size()` membres. L'émission le réutilise au lieu
de re-mesurer. Tout ce qu'il faut est disponible à cet endroit : les régions
sont résolues (`PlacementScan` a tourné), lwasm est accessible par le
contexte, et la mesure est cachée — la passe réelle la trouve déjà payée par
la découverte.

Recommandation : **B**. Le compte est vrai par construction, dans la même
passe, sans état semé ; les trois passes réservent le même nombre ; et en
prime la contrainte d'ordre « le pageset doit être déclaré avant la scène qui
le charge » peut tomber, `ctx.pageSets` étant peuplé dès la réservation. Le
prérequis est le déterminisme de la mesure, déjà acquis : `Random` de gfxcomp
graîné, caches lwasm/zx0 purs, et les tailles des parts ne dépendent pas du
placement (la cuisson patche en place, jamais la longueur). Si malgré tout la
mesure divergeait entre réservation et émission, l'assertion réservés==émis
refuse le build — l'échec est bruyant, pas une corruption.

Ce qui ne bouge pas : le format du répertoire, l'arithmétique d'ids (bloc de
8, flags), la marche %11 du loader, l'assertion. Ce qui bouge : la boucle de
réservation de `DirectoryPlugin`, la scission mesure/émission de
`PageSetPlugin`, l'expansion de `ScenePlugin` (membres réels seulement — la
table de scène raccourcit), et le warning « fills n of m » qui reste le seul
témoin d'un budget surdimensionné, information utile et suffisante.

Points vérifiés en amont :

- **Alternatives à comptes différents** (stage1 : 5 membres, stage2 : 4) :
  rien n'exige l'égalité. L'éviction par destination a disparu (9c176a3, le
  recouvrement trappe) ; le déchargement est nommé par la scène sortante, qui
  décharge SES membres. `declareExclusive` porte sur les noms, pas le compte.
- **`interface="true"`** contrôle la liste d'exports émise, pas le nombre
  d'entrées de répertoire.
- **Personne ne référence un membre par son nom hors scènes** (vérifié dans
  `games/` : ni `<load>` de membre individuel, ni équate `set.N` dans l'asm).
- Le `fichier vide $ff00` reste ce qu'il est pour les fichiers export-only ;
  il cesse simplement d'avoir des occurrences « membre non rempli ».

## 5. Inventaire des mécanismes de placement

Le tri : ce qui travaille, ce qui est mort dans le code, ce qui est en dérive.

### Vivants — rien à toucher

`<zone>`/`<region>`, `<arena>`, `<pageset>` + `<block>`, `<reserved>`, la
cuisson `.static`/`bake`, le générateur de scènes (%01 pour tout ce qui a une
destination), les équates `gensymbols` de layout. Chacun a des consommateurs
réels et une phrase qui le justifie (modele-zones §Le modèle).

**Pageset et tranches d'arène ne sont pas redondants**, bien qu'ils étalent
tous deux un ensemble trop gros pour une page. La frontière est double : *qui
choisit les coupes* (un tileset de centaines de tuiles auto-nommées ne peut
pas être coupé à la main — le pageset coupe ; un imageset d'une dizaine
d'images se coupe naturellement par phase — flight/ground/walk, l'auteur
coupe) et *la granularité de l'espace* (le pageset prend des pages entières
d'une région échangée en bloc ; une tranche d'arène se glisse dans un trou de
n'importe quelle taille). C'est la règle gravé/table de modele-zones vue du
côté producteur. À énoncer tel quel dans le manuel le jour où quelqu'un
demande lequel employer.

### Mort dans le code — retrait sûr, images attendues identiques à l'octet

1. **`LayoutResolver`, souches du placement automatique de région** (retiré à
   l'étape 4 de modele-zones, mais incomplètement) : la carte `taken` et
   `occupy()` sont écrites et jamais lues ; `autoPages` et le parsing de
   `sparepages` sont construits et jamais consommés ; `autoPage` est figé à
   `false` (le ternaire qui le lit est mort). Le commentaire de tête décrit
   encore la recherche de trou.
2. **`pages="auto"` et toute sa tuyauterie** : `LayoutResolver` le résout
   encore, `Regions.pagesUsed`/`measuredPages`/`recordPagesUsed`/
   `seedMeasuredPages` le portent, `Target.Discovery.measuredPages` le fait
   voyager entre passes, `PageSetPlugin` l'alimente (`recordPagesUsed`).
   Aucune configuration ne l'utilise ; modele-zones le liste dans « ce qui
   disparaît » (« autant de zones qu'on veut offrir ») ; mais `scenes.md` le
   documente encore comme courant — contradiction à trancher, et la trancher
   dans le sens de modele-zones supprime un aller-retour trans-passe entier.
   Noter : si le point 4 (§4, option B) se fait, ce retrait devient encore
   plus naturel — plus rien ne voyage entre passes pour les pagesets.
3. **`PageSetPlugin.member()`** : méthode privée sans appelant.
4. **`range="a-b"` sur `<image grid>`** (gfxcomp) : la capacité manuelle dont
   `<pageset>` a fourni l'ergonomie (analyse-multipage §3 le disait déjà en
   ces termes). Aucun usage dans le corpus, absente du manuel. Retrait =
   `parseRange` + le filtre de tranchage.

### Mort en pratique côté loader — retrait possible, mais à amortir

**La marche de destination des types %10/%11** (`loader.scene.apply.type10`/
`type11`) : accumulation des tailles, franchissement de page, `ldu
#map.ram.CART_START` (le V2-FIX payé par le bug MO6 des 45 Ko), lectures de
taille et test $ff00. Depuis la migration des empilages vers les arènes, le
générateur n'émet du séquentiel **que** pour l'export-only à (0,0) — des
fichiers vides, qui n'écrivent rien — et plus aucune table manuscrite
n'existe. Toute cette arithmétique tourne donc pour produire (0,0) constant.
Ce qui doit rester : la dérivation d'id par les flags (le cœur du %11) et le
repli %10 quand la chaîne d'ids se brise. Ce qui peut tomber : ~50 lignes de
marche mémoire, et avec elles la dernière trace de « le runtime place ».

À ne faire qu'en le couplant à une autre campagne loader : tout changement du
binaire du loader change les 12+ images et coûte la revalidation complète
(méthode standard + toje). Le gain est de la simplicité, pas des octets — le
loader a de la marge depuis le passage de l'INDEX au secteur 4.

**Le double rôle de `$ff00`** : l'exemption d'éviction par destination est
sans objet depuis que l'éviction n'existe plus (9c176a3). Les commentaires du
loader et le cas d'`examples/sound` (`ym.const`+`sn.const`) qui la racontent
sont de l'histoire — à dépoussiérer à la prochaine passe loader, pas avant.

### En dérive — incohérences latentes à corriger dans le commit qui implémentera

- **`analyse-multipage-2026-08.md` §« Un membre non rempli n'est jamais
  vide »** : inversé par 3ac06de. Le paragraphe décrit l'octet de remplissage
  et l'éviction, deux mécanismes disparus. Une note datée suffit (le document
  garde ses variantes rejetées, c'est son rôle).
- **`scenes.md`** : documente `pages="auto"` (voir ci-dessus) et le « budget
  déclaré = nombre de membres » — les deux à réviser ensemble.
- **`CLAUDE.md`** : « nombre de membres = budget déclaré, les ids étant
  distribués avant construction » — la phrase à mettre à jour le jour venu.
- **L'adresse d'un membre de pageset est `region.address`** — le champ
  scalaire, pas `zone.address` (`PageSetPlugin` : `place(memberName, page,
  region.address, …)` et `Member(…, region.address)`). Tant que toutes les
  zones d'une région de pageset partagent la même adresse ($0000 partout dans
  le corpus), rien ne se voit ; une région à zones d'adresses différentes —
  que le modèle autorise — placerait faux. Soit lire `zone.address`, soit
  refuser explicitement l'hétérogénéité pour un pageset. À traiter avec §4,
  c'est la même boucle d'émission.
- Plus largement, **les champs scalaires `Region.page/address/size/pages`**
  coexistent avec `zones` (« the first zone stands for the region wherever
  the builder still expects a single destination ; nothing reads the rest
  yet » — le commentaire de `LayoutResolver` date d'avant les lecteurs
  multi-zones). Les lecteurs devraient converger sur `zones` ; les scalaires
  restent alors le sucre de la forme compacte, résolus en une zone à l'entrée
  et plus jamais relus.

## 6. Lecture d'ensemble

Le motif est net : chaque mécanisme mort de cette liste est une décision de
placement prise **à l'exécution** (marche %10/%11, éviction par destination)
ou **sur déclaration** (budget = membres, `pages="auto"`, `range=`) que le
modèle actuel prend **au build, sur mesure**. La ligne d'arrivée tient en une
phrase, déjà écrite dans modele-zones : l'auteur déclare des contraintes, le
builder mesure, décide et publie, le runtime ne place rien. Le membre par
zone est le dernier écart à cette ligne — le faire tomber ne demande aucun
nouveau concept, seulement de déplacer la mesure là où la réservation en a
besoin.

Rien ici ne spécialise le builder pour r-type : les retraits enlèvent des
options sans preneur, pas des capacités. La généricité est portée par les
contraintes déclarables (zones, budgets, arènes), pas par les mécanismes que
personne n'appelle — et un mécanisme sans émetteur ni consommateur n'est pas
une réserve de généricité, c'est du code que le prochain lecteur doit
comprendre pour rien.

## 7. Le pageset se réduit-il à région/arène ?

Question posée après coup : les fichiers ciblent déjà une région ou une arène
directement — à quoi sert le pageset ? Deux fonctions ne sont portées par
aucun autre mécanisme.

**Il coupe.** Une entrée de répertoire décrit 16 Ko au plus (taille sur
14 bits) et une page en fait autant : un contenu plus gros DOIT devenir
plusieurs fichiers. Une région ne coupe pas (un fichier par scène) ; une arène
ne coupe pas (elle range des fichiers **que l'auteur a déjà découpés**). Or un
tileset de 245 tuiles auto-nommées n'a pas de frontières de fichiers
authorées — personne ne peut choisir les coupes à la main, et la coupe dépend
des capacités des zones cibles : celui qui coupe doit être celui qui place.
Le cas où l'auteur PEUT couper (un imageset en phases flight/ground/walk) est
précisément celui que les tranches d'arène couvrent (0fe3123) — la partition
est cohérente.

**Il rend les alternatives échangeables légales.** Les tilesets des stages 1
et 2 exportent les MÊMES noms (`tilesEven_*` des deux côtés : les cartes sont
générées contre les ids de la feuille). Le contrôle d'unicité des exports
n'admet des homonymes qu'entre alternatives d'exécution — même destination
exacte, ou ensembles déclarés exclusifs (`declareExclusive`, avec élection par
consommateur pour `pageOf`). Une arène place librement : les paquets du stage 1
et ceux du stage 2 tomberaient à des adresses différentes et le build
refuserait — c'est arrivé en vrai, en rangeant les cartes des deux niveaux
dans une arène (modele-zones, §Ce que le builder refuse). Le couple
pageset+région n'est donc pas un accident : les destinations épinglées et
l'exclusivité par ensemble sont ce qui rend exprimable « un gros contenu par
stage, mêmes noms, échangé en bloc ».

Ce qui est en revanche partageable : la **boucle de rangement**. Pageset
(premier ajustement en ordre de déclaration) et arène (premier ajustement par
taille décroissante) sont deux politiques du même algorithme sur les mêmes
zones. Une convergence de code — un moteur de rangement, deux politiques,
deux appelants — est la vraie simplification disponible ; fusionner les
*concepts* ne l'est pas, leurs sémantiques d'exclusivité diffèrent.

## 8. Le chemin disquette → RAM : ce qui est optimisé, ce qui ne l'est pas

La question : existe-t-il un mécanisme de continuité secteur avec
entrelacement entre le média et les pages arrangées par région/arène ?

**Oui, le chemin intra-fichier est complet et outillé des deux côtés.**
`storage.xml` déclare trois paramètres par géométrie
(`<interleave softskip="2" softskew="4" hardskip="7"/>`) :

- `hardskip` : l'entrelacement physique de formatage (numérotation des
  secteurs sur la piste, 7 en fd640 — celle du moniteur TO8) ;
- `softskip=2` : le builder écrit les données logiquement contiguës, puis
  `FdUtil.interleave()` les dépose un secteur physique sur deux. Le loader lit
  secteur par secteur via le moniteur (pas de chaînage DMA) et convertit
  l'index logique en numéro physique par sa table miroir (`sclist` dans
  `ldsec`) : entre deux lectures, la boucle de copie (`tfrxua`) dispose d'un
  temps de secteur — pas de tour de disque perdu ;
- `softskew=4` : décalage rotatif par piste (`andb #$06` dans `ldsec` : skew
  0,2,4,6 cyclique), pour qu'après un changement de piste le premier secteur
  logique arrive sous la tête après le seek au lieu d'être manqué d'un tour.

Les **quatre sorties** (fd, sap, sd, hfe) consomment l'image entrelacée. Et le
chargement de scène en trois passes (disque groupé → décompression → link
data) sert exactement cet objectif : la passe disque ne fait que copier — la
décompression ZX0 est différée, donc le `softskip` est calibré pour la boucle
de copie, pas pour le décodeur.

**La continuité entre fichiers existe, mais par convention.** `cwrite` colle
les fichiers d'une section à l'octet près (un fichier peut commencer au milieu
du dernier secteur du précédent — l'entrée de répertoire porte l'offset de
départ), et la passe disque d'une scène lit les fichiers dans l'ordre de sa
table. La tête balaie donc la section en avant **si** l'ordre de déclaration
des direntries suit l'ordre des `<load>` — rien ne le vérifie ni ne
l'optimise, et un fichier chargé par deux scènes ne peut être contigu que pour
une seule. Les membres d'un pageset, eux, sont contigus par construction
(émis à la suite, chargés à la suite).

**Ce qui n'existe pas, et n'a pas à exister : un lien RAM ↔ disque.**
L'arrangement des régions et arènes est sans effet sur le temps de
chargement — la RAM est à accès direct, écrire en page $1B ou $05 coûte
pareil. La seule corrélation qui compte est ordre-de-chargement ↔
ordre-sur-média, ci-dessus.

Deux observations pour plus tard :

- **Couplage nu** : les paramètres d'entrelacement vivent en double —
  `storage.xml` côté builder, `sclist` + le masque de skew en dur dans
  `loader.asm`. Changer l'un sans l'autre casse toutes les lectures. Même
  famille que `DIR_DEFAULT_SECTOR`, déjà notée ; à consigner au même endroit.
- **Rapport de seeks par scène, à peu de frais** : `FdUtil` journalise déjà
  chaque écriture avec son nom (`Piece`). Croiser ce journal avec l'ordre des
  loads de chaque scène donnerait « cette scène lit en arrière à tel endroit »
  dans le rapport d'occupation — le contrôle qui manque à la convention
  ci-dessus, sans rien changer au format.

## 9. Réduction conceptuelle (réflexion auteur, 2026-08-08)

Trois questions posées en poursuivant : pourquoi contrôler le couplage de
placement au build ? qui dépend de données continues sur pages consécutives ?
et le pageset ne serait-il pas « une région avec coupe autorisée » ?

### Le couplage contrôlé au build ne sert que la cuisson

Sans bake, la liberté est **déjà totale** : les link data se re-résolvent au
re-link global de chaque `scene.load`, aucun alignement n'est requis, rien à
déclarer. Le contrôle (« alternatives = même destination », `declareExclusive`,
`interface="true"`) n'existe que parce qu'une **adresse cuite doit avoir une
vérité unique au build** — sans lui, un symbole multi-fournisseurs se
résolvait au dernier venu et le jeu sautait dans de la RAM vide (l'historique
des deux passes de découverte le raconte).

Deux conséquences honnêtes :

1. **Le périmètre actuel du contrôle est plus large que sa justification.**
   L'unicité des exports par ensemble co-chargeable s'applique aussi aux
   symboles purement linkés, et l'heuristique « même destination = jamais
   co-chargés » est une inférence d'enchaînement — précisément ce que la
   doctrine refuse de faire pour les recouvrements RAM (« le builder vérifie
   une composition, pas les enchaînements »). La posture cohérente avec
   9c176a3 (trap au runtime plutôt que déduction au build) serait : contrôle
   au build **pour ce qui est cuit**, trap au runtime pour le reste (une
   recherche de symbole qui trouve deux fournisseurs chargés → log + trap,
   même mécanique que `LOAD_OVERLAP`).
2. **La contrepartie à dire à l'utilisateur en une phrase** : la cuisson est
   une optimisation opt-in qui achète du pool et du temps de chargement
   (mesuré : les scripts d'animation, 2 900 pointeurs = 8 Ko de link = les
   deux tiers du pool, cuits = zéro ; la liaison coûte références × exports
   à chaque scène) contre une contrainte : le placement des fournisseurs
   cuits est figé et leur remplacement doit être à l'identique. Un seul axe —
   bake ou link — au lieu de trois notions de surface.

   Nuance à ne pas perdre : le contrôle au build attrape la cuisson fausse
   sur **le chemin qu'on n'a pas testé** ; le trap runtime ne la montre que
   le jour où ce chemin s'exécute. Restreindre le périmètre, oui ; le
   supprimer sur les symboles cuits, non.

### Personne ne dépend de la continuité inter-pages

Vérifié dans l'engine : les players tiennent UNE page de données et lisent
dedans (`ymm.data.page`, `vgc.data.page` ; aucun motif « page suivante » dans
`engine/sound`) ; le scroll monte ses pages discrètement depuis ses tables
(littéraux par tuile) ; zx0 décompresse à l'intérieur d'un fichier ≤ 16 Ko ;
sprites et objets montent leur page par objet. Le **seul** code qui ait jamais
marché octet par octet à travers une frontière de page est la marche %10/%11
du loader — morte en pratique (§5), et c'est elle qui avait coûté le bug MO6
des 45 Ko. Physiquement d'ailleurs, « pages consécutives » n'offre aucune
continuité : les pages se montent dans la même fenêtre, le franchissement est
toujours logiciel.

Conclusion : la consécutivité n'est pas un besoin runtime. C'était une
commodité de déclaration (forme compacte `pages="N"`) et l'hypothèse de la
marche morte. Le modèle zones l'a déjà retirée — une zone nomme sa page ET
son adresse librement — et la note « hors périmètre : pages non consécutives »
d'analyse-multipage est de fait obsolète. Reste le §« En dérive » : l'adresse
de membre lue du scalaire au lieu de la zone.

### Le pageset devient « une région, avec coupe autorisée au niveau file »

La formule de l'auteur tient. Ce qui doit survivre du pageset est sa
mécanique, pas son élément : mesurer, ranger dans les zones, émettre **une
entrée de répertoire par morceau** (le plafond de 16 Ko l'impose), placer
par symbole. Rien de tout ça n'a besoin d'un concept de surface : un
attribut de coupe sur le contenu (`<file>` divisible) ciblant une région à
n zones — ou une arène, pour le contenu chargé une fois — suffit, et avec le
§4 (membres = résultat du rangement) les membres deviennent un détail
d'émission visible seulement dans les rapports. Le vocabulaire utilisateur
retombe à : **région** = destinations convenues (zones libres en pages ET en
adresses), **arène** = rangement libre, **coupe** = propriété du contenu,
**bake** = optimisation opt-in qui fige. Le choix région-ou-arène pour un
contenu coupé découle du premier axe : des consommateurs cuits → région
(remplacement à l'identique) ; tout linké → arène.

Ce paragraphe est la suite naturelle du §7 : le §7 établit que la coupe et
l'exclusivité doivent exister quelque part ; celui-ci constate qu'aucun des
deux n'a besoin d'être un élément que l'utilisateur apprend.

## 10. L'index normalisé — la seconde face de la coupe

Précision d'auteur qui ferme le concept : la coupe ne s'applique qu'aux
données, et il faut un mécanisme normalisé pour atteindre les extraits — une
table d'indexation page/adresse.

**La coupe et l'index sont un seul contrat.** Un morceau coupé n'est jamais un
point d'entrée qu'on appelle ; déclarer un contenu divisible, c'est déclarer
qu'il ne s'atteint QUE par sa table. C'est la règle de modele-zones (« ce qui
est atteint par une table peut être rangé n'importe où ») lue côté
producteur : la table n'est pas une commodité ajoutée à la coupe, elle est ce
qui rend la coupe invisible au runtime — et le placement libre, sain.

**L'état des lieux : cinq formes pour un concept.** Aujourd'hui id → (page,
adresse) existe en :

1. table de tilemap (`<tilemap>`) : entrées **entrelacées** de 3 octets
   `fcb page / fdb adresse`, cuites en `.static`, générées par le builder ;
2. index d'imageset (`<imageset>`) : descripteurs à octet de page par image,
   générés, cuits — page/adresse déjà résolues par `StaticLink.pageOf` ;
3. index d'objets (`Obj_Index_Page`/`Obj_Index_Address`) : tables
   **parallèles**, générées par un script Python **hors builder**
   (`games/r-type/tools/gen_objid.py`) qui relit les équates du layout ;
4. tables d'animation (`Ani_*`) : élément `<animation>` naissant côté builder,
   écrites à la main côté banc sprites ;
5. les équates (`gensymbols` de bloc, publications d'arène) : le cas dégénéré
   à une entrée, résolu à l'assemblage.

Même source de vérité partout (le placement par symbole de `StaticLink`),
cinq émetteurs — dont un script par projet, précisément ce qu'un builder doit
absorber.

**La normalisation : un émetteur, deux layouts.** Un élément (ou attribut)
`index` : en entrée la liste ordonnée des symboles — explicite, ou dérivée du
contenu coupé en ordre de déclaration, l'ordre ÉTANT les ids — en sortie une
table cuite en `.static`, zéro donnée de lien par construction. Deux layouts
suffisent, et les deux existent déjà dans le corpus :

- **parallèle** : `<nom>.page` (1 o/entrée) puis `<nom>.address`
  (2 o/entrée) — l'accès aléatoire par id, l'idiome v1 (`abx` puis `lda b,x`,
  pas de multiplication par 3) ; c'est la forme des cinq tables moteur→stage ;
- **entrelacé** : 3 o/entrée — le parcours séquentiel (`leau 3,u`), la forme
  du tilemap.

Les index à charge utile métier (les descripteurs d'imageset portent la
géométrie) gardent leur élément et délèguent page/adresse à la même source —
c'est déjà le cas. À normaliser aussi : l'entrée 0 réservée (le tilemap émet
3 octets nuls, l'index d'objets un slot jamais exécuté) — même convention
partout. Et l'octet de page émis **fenêtre comprise** (`map.RAM_OVER_CART+p`),
comme les trois générateurs le font déjà chacun de son côté.

**Ce que ça amplifie.** L'index cuit est ce qui fait passer la frontière
moteur→contenu par UNE adresse — celle de la table — au lieu d'une donnée de
lien par entrée (mesuré : 5,3 Ko de link pour une carte de 24×8 avant la
cuisson ; moteur→stage = 5 tables, tout le reste étant dedans). La chaîne
complète devient : contenu déclaré divisible → coupe rangée dans les zones →
index normalisé cuit → le runtime monte la page de l'entrée et lit. Le script
`gen_objid.py` devient une déclaration ; le générateur de tilemap devient un
consommateur du même émetteur.

Côté runtime, l'idiome d'accès (monter la page de l'entrée, lire l'adresse)
existe partout mais s'écrit partout à la main — un pack de macros
`_index.get`/`_index.walk` est le pendant asm de l'émetteur, à condition de
mesurer avant de remplacer les accès v1 chauds (le dessin de sprites lit son
index dans des boucles serrées ; v1 a choisi les tables parallèles pour ça).

## 11. Ce que l'écriture du manuel a révélé

L'esquisse ([esquisse-manuel-placement-2026-08.md](esquisse-manuel-placement-2026-08.md))
est écrite dans le modèle cible, sans jargon, par cas d'usage. Les endroits où
la plume a résisté sont des failles du modèle, pas de la rédaction :

1. **« La coupe ne s'applique qu'aux data » ne survit pas à l'écriture.** Une
   tuile compilée est *appelée* (`jsr` via la carte) — le critère code/données
   ne tient pas. Le critère qui tient : **n'être atteint que par sa table**.
   C'est la phrase du manuel (« votre code n'atteint ce contenu QUE par cette
   table ») et elle doit devenir la définition du contrat de coupe.
2. **Le choix région/arène n'est pas une liberté, et le builder ne le dit
   pas.** Le manuel s'en sort par les cas d'usage (« remplacé → rendez-vous ;
   chargé une fois → rangement »), mais un utilisateur qui range du contenu
   échangé dans une arène n'obtient pas « le contenu échangé va dans une
   région » : il obtient une erreur d'élection d'exports, trois concepts plus
   loin. Le message d'erreur doit parler le langage du manuel.
3. **Région multi-zones hors coupe : la doc et le code se contredisent.**
   modele-zones promet des `<load>` ordonnés dans les zones ; `ScenePlugin`
   refuse une région chargée deux fois. L'esquisse n'a pu employer la région
   multi-zones QUE pour du contenu coupé. Trancher — le plus simple : région
   multi-zones = contenu coupé, point ; sinon implémenter les loads ordonnés.
4. **Le déchargement n'a aucune existence déclarative.** Les chargements sont
   du XML, le déchargement est un appel dans le code asm. Le manuel doit
   écrire « charger n'a jamais déchargé personne » en toutes lettres, et
   aucun rapport ne peut dire « la scène X n'est déchargée nulle part ». Le
   trap runtime est le seul filet — assumé par doctrine, mais l'asymétrie
   déclaré/codé est exactement l'endroit où un utilisateur trébuchera.
5. **« Le builder choisit bien tout seul » (références gravées/chargées) est
   une promesse, pas l'état du code.** `bake=` se déclare fichier par
   fichier ; le manuel sans jargon exige que `auto` soit le défaut partout et
   que le sujet n'apparaisse qu'au chapitre performances, rapport à l'appui.
6. **Le comblement de queue trahit la faille 3.** L'esquisse dit « un fichier
   de plus vers le même rendez-vous » — or une région prend un fichier par
   scène. Aujourd'hui la queue se comble DANS la déclaration coupée
   (`<block>`) ; dans le modèle cible elle doit être un load ordinaire, ce
   qui suppose la faille 3 tranchée dans le sens des loads multiples — ou
   rester un enfant du contenu coupé, et le manuel doit le dire ainsi.
7. **Les numéros d'index naissent de l'ordre de déclaration.** Réordonner le
   contenu renumérote — sans conséquence tant que tout est régénéré ensemble,
   mais un état persistant qui retient un numéro (checkpoint, sauvegarde,
   mot de passe de niveau) devient faux d'un build à l'autre. À écrire noir
   sur blanc dans le manuel, ou à couvrir (numéros nommés, déjà le cas des
   équates `ObjID_*` — c'est l'ordre DES déclarations qui doit être stable).
8. **L'interdit « on ne grave jamais vers une arène » proscrit un cas sain.**
   Du contenu d'arène chargé une fois ne bouge jamais au runtime : graver
   vers lui serait correct. La règle simple achète une phrase de manuel
   limpide (« personne n'a besoin de savoir où ») au prix d'une expressivité —
   choix à faire en connaissance, et si la règle reste, l'erreur doit là
   aussi parler le langage du manuel.
9. **La performance disque n'a nulle part où exister dans le manuel.** Rien
   de déclarable, rien de visible : l'ordre des loads face à l'ordre sur
   média se dégrade en silence. Le rapport de seeks par scène (§8) est ce qui
   donnerait au chapitre « performances » sa matière.

Signal d'ensemble, plutôt rassurant : les cinq notions se sont laissé nommer
sans jargon (emplacement, rendez-vous, rangement, découpage + table d'accès,
liste de chargement) et chaque cas d'usage tient en une dizaine de lignes. La
seule notion qui a exigé un paragraphe de précautions est la paire
gravé/chargé — c'est donc elle que le défaut (`auto` + rapport) doit rendre
invisible, et c'est cohérent avec le §9 : un axe unique, réglé par le
builder, surfacé par les rapports.

## 12. Le modèle « file maître » (proposition auteur, 2026-08-09)

Renversement proposé pour lever les failles du §11 : le **fichier** devient
l'unité maîtresse, le placement en découle.

**Le modèle, tel que proposé :**

- `file` définit un contenu à persister sur le média, produit par des modules
  (générateurs, convertisseurs, assembleur). C'est **l'unité continue sur le
  média** : lue séquentiellement (pas de seek interne), **compressée d'un
  bloc** (meilleur ratio sur les gros blocs), donc **indivisible**. C'est
  aussi l'unité positionnable en RAM, et l'unité qui porte le mode de
  résolution — les données de lien concernent un file.
- **Bake par défaut**, sans rien déclarer. Un bake suppose un placement
  déterministe : l'adresse de départ est un paramètre du file (explicite), ou
  **déterminée automatiquement à l'optimisation** s'il ne dit rien — le cas
  d'un seul usage ne coûte aucune déclaration. Le mode `link` se demande
  explicitement.
- L'optimiseur pose **les bakes d'abord** (contraintes fixes), puis répartit
  **les links par taille** pour minimiser l'espace perdu.
- Conteneurs : **arena et reserved seulement**. La région disparaît.
- Le découpage produit des blocs plus petits pour réduire la perte ; il ne
  s'applique qu'aux éléments à index page/adresse, et l'index est produit par
  le builder — production, positionnement et accès restant à déterminer.

**Ce qui tient, vérifié contre l'existant :**

- « File = unité média continue et compressée » est le concept *group* déjà
  arbitré (groups.md : un direntry multi-asm, flux compressé entier, link
  data fusionnées) — promu au rang de définition du fichier. Cohérent.
- Bake par défaut est soutenu par toutes les mesures (§9) et par le loader :
  une référence cuite vers du contenu pas encore chargé est même PLUS sûre
  qu'un link (pas de fenêtre « résolu à 0 »). Le pool de liens se vide, les
  scènes se chargent plus vite — l'objectif de performance est servi par la
  simplification, pas contre elle.
- L'épinglage automatique donne à chaque file UNE vérité de placement : le
  contrôle d'alternatives du §7 devient une **déclaration** (deux files qui
  fixent la même adresse SONT des alternatives) au lieu d'une inférence — la
  faille 2 se referme par construction.
- Le plafond reste : un file se charge d'une adresse à la fin de sa fenêtre,
  donc ≤ 16 Ko de fait. « Maîtriser l'unité » veut dire pouvoir la faire
  petite, pas grande.

**Quatre incohérences ou raffinements relevés :**

1. **« La région devient inutile » n'est vrai que si la frontière
   permanent→échangé est linkée.** Le texte de la proposition le trahit
   lui-même (« si besoin d'une cible précise on utilise une region dédiée »
   … puis « region devient inutile »). Le cas échangeable : si le moteur
   résident CUIT une référence vers du contenu de stage, les alternatives
   doivent partager une adresse épinglée — et un nom pour cette adresse
   ressuscite la région. Mais la frontière mesurée est minuscule
   (moteur→stage = **5 tables**) : la règle qui dissout la région est «
   une référence du permanent vers l'échangé se déclare `link` » — cinq
   références linkées, tout le reste cuit, aucune ancre nommée. Le garde-fou
   existant (élection de fournisseur) détecte la violation et son message
   peut enseigner la règle. Résidu acceptable si la répétition d'adresse
   gêne : une ancre nommée minimale — mais c'est un confort, plus un concept.
2. **« Seule la page peut varier au load » casse les références de page
   cuites.** Les interns et extern16 sont indifférents à la page ; les
   externPg et les octets de page des index (`fcb RAM_OVER_CART+p`) ne le
   sont pas. Un file dont la page varie par scène ne peut pas être pointé
   par un index cuit unique. Raffinement : le défaut est l'épinglage COMPLET
   (page + adresse) ; la variance de page est l'exception, réservée au
   contenu prouvé page-neutre — et le builder peut le prouver (aucun
   externPg, aucun index ne cite sa page).
3. **« L'adresse auto se fixe à la première scène qui l'utilise » : préférer
   la résolution globale.** Le builder voit toutes les scènes ; épingler sur
   la première (ordre de déclaration) peut choisir une place qui collisionne
   dans la deuxième et forcer un retour à l'adresse manuelle. Épingler en
   résolvant l'intersection des compositions qui chargent le file donne le
   même confort déclaratif sans ce piège. Même coût : c'est la passe de
   découverte qui fait déjà ce travail pour les mesures.
4. **Le découpage fin a un prix que le pageset n'avait pas : la compression
   et le répertoire.** Des blocs plus petits remplissent mieux la RAM, mais
   compressent moins bien (zx0 sur petits blocs) et coûtent chacun leur
   entrée de répertoire (8-24 o) et leur lecture. La granularité de coupe
   devient un **réglage** (une taille visée, pas « la page ») avec le rapport
   d'occupation et le ratio de compression comme juges — c'est un progrès sur
   le pageset, qui coupait aveuglément à la page, à condition de montrer les
   deux coûts.

**L'index : la question ouverte, résolue en principe.**

- *Production* : après placement. La taille d'un index ne dépend que de son
  nombre d'entrées (3 o/entrée + en-tête), donc l'optimiseur peut le placer
  AVANT que son contenu soit généré, et l'émission le cuit ensuite — c'est
  exactement la danse des passes de découverte actuelles ; rien de neuf à
  inventer, seulement à ordonner.
- *Positionnement* : l'index hérite du **cycle de vie de son contenu** — la
  règle « graveur et cible rechargés ensemble ». L'index d'un stage vit dans
  les pages du stage (le cas tilemap actuel) ; l'index d'un commun chargé une
  fois vit n'importe où. Il est lui-même un file ordinaire de l'arène.
- *Accès* : l'index est **la porte unique** du contenu coupé, et l'adresse de
  la porte est la seule chose qui traverse la frontière de cycle de vie —
  linkée si la porte est échangée (les 5 tables), cuite sinon. La récursion
  se termine là, et les deux layouts + macros du §10 restent valables tels
  quels.

**Bilan.** Le modèle est cohérent une fois les quatre points raffinés, et il
referme les failles 1, 2, 5 et 8 du §11 par construction (contrat = atteint
par sa table ; alternatives déclarées ; bake par défaut ; plus d'interdit
d'arène — graver vers un file épinglé est sain par définition). Restent
ouvertes : la 3/6 (la queue et les loads multiples — probablement dissoutes
aussi : sans région, tout load est un file de l'arène), la 4 (déchargement
sans syntaxe), la 7 (numéros vs état persistant), la 9 (rapport de seeks).
Le vocabulaire final : **file** (l'unité), **zone/arena/reserved** (l'espace),
**scene** (la liste), **coupe + index** (le contrat des collections),
**link** (l'exception déclarée). La région et le bake disparaissent du
vocabulaire — le premier comme concept, le second comme mot, en devenant le
silence par défaut.

## 13. Ce que le manuel complet a révélé (2026-08-09)

Le manuel du modèle « file maître », média compris, est écrit :
[manuel-cible-2026-08.md](manuel-cible-2026-08.md) (il remplace l'esquisse du
§11). Deux découvertes structurantes, quatre confirmations, un détail.

**1. La coupe ne peut pas être un attribut de `file` — l'élément collection
est une conséquence, pas un choix.** Dans le modèle §12, le file est
indivisible *par définition* (l'unité média continue et compressée). Un
contenu découpable ne peut donc pas ÊTRE un file : c'est une déclaration qui
en **produit** plusieurs, plus leur table. D'où l'élément `<set>` du manuel
(§3.5) : le pageset meurt comme mécanique « un membre par zone » et renaît
comme déclaration de collection — cette fois dérivé de la définition du
fichier, avec la granularité en réglage (`blocks="~4k"`) au lieu de la page
imposée.

**2. Le `link` explicite disparaît aussi — il se dérive.** En écrivant le
§3.3, la règle s'est simplifiée d'elle-même : un nom à fournisseur unique se
cuit ; un nom que plusieurs fichiers proposent à des places différentes est
résolu au chargement, automatiquement. La frontière moteur↔stage (§4.6 du
manuel) se déclare alors TOUTE SEULE : les deux stages exportent
`stage.wave`, donc la référence du moteur est linkée, sans un mot de
configuration. Les failles 1 (résidu de région) et 5 (défaut de bake) se
referment ensemble ; le garde-fou d'élection devient un aiguillage au lieu
d'un refus. **Le prix, à outiller** : un export dupliqué par erreur devient
un link silencieux au lieu d'une erreur de build — le rapport doit lister
chaque référence résolue au chargement AVEC sa cause, et le manuel enseigne
que cette liste courte se relit (« une ligne surprenante est un nom exporté
deux fois par erreur »).

**Confirmations :**

3. **L'ordre disquette peut se dériver des scènes** (§2.4 du manuel) : le
   builder connaît l'ordre des loads et `cwrite` est le seul écrivain —
   ranger les fichiers d'un quartier par première utilisation ferme la
   faille 9 par construction, le rapport ne montrant plus que les retours de
   tête résiduels (fichiers partagés entre écrans).
4. **La compression perd son mot** : défaut avec repli brut — déjà
   l'implémentation depuis 3318c07 ; le manuel n'en parle qu'au chapitre
   disquette, comme un fait.
5. **La sémantique du conteneur restant est la durée de vie**, pas la
   géométrie : c'est la seule façon dont le manuel a réussi à expliquer
   pourquoi on déclare plusieurs arènes (« on décharge un rangement d'un
   coup, on ne mélange pas les durées »). À porter tel quel dans le modèle.
6. **Les flux multi-pages sont hors contrat, en toutes lettres** (§4.10) :
   verrouille côté manuel le constat du §9 (aucune lib ne lit à cheval).

**Restes, inchangés mais assumés par le manuel :** le déchargement sans
syntaxe (faille 4 — la phrase rituelle « charger n'a jamais déchargé
personne » et le trap) ; les numéros vs l'état persistant (faille 7 — écrit
noir sur blanc au §3.5). **Nouveauté à outiller** : le rapport multi-disquette
(« une liste qui demanderait un échange au milieu d'un niveau », §4.9).
**Détail à trancher** : le « plus petit programme » (§4.1) suppose une zone
par défaut quand aucun layout n'est déclaré — commodité à confirmer ou à
retirer du manuel.

## 14. Deux contraintes runtime soulevées, vérifiées dans le code (2026-08-09)

Objections d'auteur sur le manuel : le chargement groupé supposerait un
tampon de 16 Ko et un lotissement des fichiers ; et un code paginé qui lit un
index d'une autre page a besoin d'un mécanisme de bascule résident. Les deux
mécanismes existent — c'est le manuel qui ne les disait pas.

**1. Pas de tampon, pas de lotissement : le compressé est chargé dans son
empreinte finale.** `loader.file.load` avance la destination de `coffset`
pour un fichier compressé (le flux est lu du disque directement dans la
QUEUE de l'emplacement final, page de destination montée pendant la
lecture) ; `loader.file.decompress` déplie ensuite SUR PLACE (X =
destination+offset → zx0 vers destination, les 6 octets de queue recopiés
depuis `cdataz` du répertoire). L'enchaînement des n décompressions est la
marche de scène elle-même (passe 1 : tous les loads ; passe 2 : tous les
déplis). Il n'y a donc aucune limite de lot — la seule limite est par
fichier (compressé ≤ original, garanti par le repli brut à offset zéro). Le
manuel dit désormais où atterrissent les octets (§2.3) et l'exemple le
montre (§5).

**2. La bascule de page a son contrat, il faut l'écrire et le décliner pour
l'index.** Le trampoline résident existe et est validé :
`RunPgSubRoutine` (`_GetCartPageA` → sauvegarde → monte → appelle →
restaure), `Obj_Run` qui remonte la page de chaque objet, et les services du
moteur (dessin, animation) qui sont résidents et font la bascule pour le
code paginé — le code paginé leur passe des NUMÉROS. La règle, maintenant
écrite au manuel (§3.5) : **les numéros voyagent, les adresses non** — le
code résident monte et lit ; le code paginé passe des ids à des services
résidents. Conséquence pour l'émetteur d'index du §10 : les macros d'accès
existent en deux formes — inline pour appelant résident (quelques cycles),
routine résidente pour appelant paginé (sauve/monte/lit/restaure, le coût
d'un `RunPgSubRoutine`) — et une lecture d'index inline ne doit jamais être
expansée dans du code destiné à la fenêtre. C'est un point de génération
(où la macro est autorisée), pas seulement de documentation.

## 15. La collection est un fichier, et les creux décident de la coupe (2026-08-09)

Deux questions d'auteur : pourquoi un mot `set` alors qu'au final ce sont des
fichiers ? et comment limiter le nombre de fichiers tout en favorisant les
petits éléments qui bouchent les trous ?

**`set` disparaît : une collection est un fichier qui déclare son index.**
Le §13.1 objectait que la coupe ne peut pas être un attribut de `file`, le
file étant l'unité média indivisible. La résolution est un déplacement de
définition : `file` redevient **l'unité qu'on nomme et qu'on charge** ; sur
le média, il devient un **morceau** — ou plusieurs, quand c'est une
collection. L'indivisibilité descend d'un cran : c'est le morceau qui est
continu et compressé d'un tenant, et l'élément qui ne se coupe jamais. La
déclaration n'a pas de mot nouveau : `<file index="…">` — et c'est cohérent
au fond, puisque le contrat de la coupe EST l'index (§10) : déclarer l'index,
c'est déclarer la divisibilité. Le vocabulaire utilisateur perd encore un
mot ; « morceau » n'apparaît que dans les rapports.

**La granularité disparaît aussi : les creux décident.** La réponse à « quel
nombre de fichiers ? » n'est pas un réglage, c'est un ordre de placement.
Les fichiers **rigides** (sans index) se posent d'abord, du plus gros au plus
petit ; les collections — **fluides** — coulent ensuite dans ce qui reste, en
ordre d'éléments. Un morceau naît par creux utilisé, aussi gros que son creux
le permet. Conséquences mesurables sur l'exemple du manuel : le rangement
`stage` produit **2 morceaux au lieu de 5** (l'ancien `blocks="~4k"`), la
compression y gagne (morceaux de 9 Ko au lieu de 4), le répertoire aussi
(5 entrées au lieu de 8), et les queues se comblent sans le moindre concept —
le cas 4.7 du manuel devient « il n'y a rien à faire ». La distinction qui
résout la tension de l'auteur est **élément vs morceau** : on favorise les
petits ÉLÉMENTS (ils coulent dans n'importe quel creux), et le nombre de
MORCEAUX reste minimal parce qu'il est dérivé, jamais choisi.

**Les deux garde-fous qui restent :**

1. **L'élément est plafonné** — plus gros qu'une page (ou que le plus grand
   creux offert), c'est une erreur qui le nomme. C'est la règle « une taille
   maximum, au-delà erreur » de l'auteur, appliquée à l'élément plutôt qu'au
   bloc — le bloc n'existant plus comme réglage.
2. **Un seuil de creux** : un morceau coûte une entrée de répertoire
   (8-24 o), une entrée de table de scène (5 o), un appel de chargement, et
   un petit bloc compresse mal. Un creux plus petit que le seuil n'est pas
   offert aux collections — mieux vaut le laisser vide que d'émietter. Le
   seuil a un défaut raisonnable (quelques centaines d'octets) et le rapport
   montre ce qu'il laisse, pour qu'on puisse le juger.

**Ce que ça coûte : l'ordre de placement devient un algorithme à deux
phases** (rigide posé, fluide coulé) au lieu d'un tri simple — c'est le
premier ajustement du pageset généralisé de « pages entières » à « creux
quelconques », et il hérite de son invariant (on regroupe des éléments, on ne
coupe jamais dans un binaire assemblé). À surveiller à l'implémentation : la
stabilité (un élément qui grossit peut déplacer une frontière de morceau —
sans conséquence puisque tables et cartes sont régénérées, mais le rapport
doit montrer ce qui a bougé, comme pour l'arène) ; et l'interaction avec les
fichiers épinglés (un creux peut être ENTRE deux fichiers à adresse déclarée
— c'est même son intérêt).

Le manuel est aligné : §3.5 réécrit (rigide/fluide, morceaux, seuil), exemple
§5 refait (2 morceaux, page $1A rendue), cas 4.7 réduit à « rien à faire »,
§7 performance sur le seuil de creux.

## 16. Les index du moteur : formats spécifiques contre système de placement (2026-08-09)

Question d'auteur : l'imageset et les données d'animation SONT des index —
mais l'imageset référence pages et images dans un format spécifique,
incompatible avec l'émetteur normalisé du §10. Comment gérer ça au mieux ?

### L'incompatibilité, précisément

Le descripteur d'imageset (v1, importé 1:1, `sprites.md` § The imageset
index) n'est pas une table id → (page, adresse) : c'est un enregistrement
riche qui ENTRELACE géométrie et placements —

```
set_<name>  fcb n,x,y,xy            ; offsets des sous-ensembles miroir
            fcb x_size,y_size,center_offset
            ; puis par variante :
            fcb page                 ; valeur du registre fenêtre
            fdb adr_<variante>       ; code de dessin
            fcb page
            fdb adr_<variante>_erase
            fcb nb_cell
```

Trois écarts au gabarit normalisé : plusieurs couples (page, adresse) par
entrée, au milieu de charges utiles métier ; un layout optimisé pour les
boucles chaudes du runtime (chaque octet et son ordre sont le contrat de
`DrawSprites`/`CheckSpritesRefresh`, intouchables avant la phase finale de
migration) ; et DEUX chemins d'émission qui coexistent — `genindex` (page en
relocation `externPg` sur `<file>$PAGE`, donnée de lien par image) et
`<imageset>` (page demandée par image, littéral cuit, `code.static`, zéro
lien). S'y ajoute l'étage au-dessus : `Img_Page_Index[id]` donne la page du
descripteur lui-même, que le runtime monte avant de le déréférencer — les
descripteurs d'un jeu restent groupés.

### Les options

**A. Statu quo par générateur.** Chaque générateur (imageset, tilemap,
animation, objets) résout ses placements et émet son format. C'est l'état
actuel et ça marche — mais les conventions (entrée 0, octet fenêtre,
génération post-placement, règle d'accès résident) se réimplémentent à
chaque fois, et la classe de bugs « chaque générateur les siens » est
documentée (center_offset, adresses en fcb, pages inventées).

**B. Normaliser le format runtime** — séparer géométrie et placements en
deux tables que le moteur lirait. Rejeté : ça casse le 1:1 sur la boucle la
plus chaude du moteur, ça coûte des cycles par sprite et par trame, et la
doctrine de migration l'interdit avant la phase finale. Le format v1 a une
raison d'être : il est déroulé par le dessin, pas parcouru par une recherche.

**C. L'émetteur normalisé est un SERVICE, pas un format.** Ce que le §10
normalise vraiment se sépare en trois étages : (1) la **résolution** —
symbole → page + adresse post-placement, octet fenêtre compris (c'est
`StaticLink`, déjà unique) ; (2) les **conventions** — entrée 0 réservée,
ids = ordre de déclaration, table générée après placement, table rigide,
accès résident seulement ; (3) des **gabarits**. Les deux layouts standards
(parallèle, entrelacé) sont deux gabarits fournis ; un domaine qui a son
format v1 garde son gabarit et consomme (1) + (2). Le descripteur d'imageset
devient « le gabarit sprites » : ses `fcb page / fdb adr` sont des appels au
même service de résolution, son layout ne bouge pas d'un octet.

**D. Un méta-format déclaratif** (décrire les gabarits dans une petite
langue). Écarté : quatre gabarits ne justifient pas une DSL — le dépôt a
déjà rendu cet arbitrage (analyse-dsl-2026-07) ; le gabarit est du code Java
qui appelle la bibliothèque, c'est l'option C.

### Recommandation : C, avec quatre conséquences

1. **Le chemin `genindex`/`externPg` meurt.** Dans le modèle cible (tout
   épinglé, bake par défaut), la page d'une image est un littéral connu au
   build — la relocation par donnée de lien est l'anomalie. Un seul chemin
   d'émission, celui de `<imageset>` : pages et adresses cuites, zéro lien.
   C'est aussi une simplification du présent : deux chemins pour la même
   table est exactement le genre de doublon que cette analyse traque.
2. **Animation et objets rejoignent les gabarits standards tels quels.**
   `Ani_Page_Index`, `Ani_Asd_Index`, `Obj_Index_Page/Address` SONT déjà le
   layout parallèle — aucun gabarit métier à écrire, le script
   `gen_objid.py` et les tables manuscrites du banc sprites sont remplacés
   par l'émetteur standard. Seul l'imageset garde un gabarit à lui, parce
   que seul son format transporte de la géométrie.
3. **L'étagement se décompose proprement** : `Img_Page_Index` (gabarit
   parallèle standard, pointant les descripteurs) → descripteurs (gabarit
   sprites, rigides et groupés) → routines de dessin (éléments d'une
   collection, fluides). Chaque variante portant SON octet de page dans le
   descripteur, les routines coulent librement — l'atome de la collection
   sprites peut descendre à la variante ; par prudence de migration, il
   reste l'image entière tant que le banc n'a pas prouvé le contraire.
4. **Les consommateurs sont résidents** (`DrawSprites` monte les pages
   depuis l'index), conforme à la règle du §14 — rien à ajouter.

Le manuel n'a besoin que d'une phrase (les tables du moteur ont leur propre
gabarit — même source, mêmes règles) : l'utilisateur ne voit pas la
différence, et c'est le critère de réussite de l'option C.

## 17. L'index en mémoire fixe (2026-08-09)

Trou relevé par l'auteur : certains index sont attendus en zone résidente,
et le modèle ne traitait pas leur positionnement optionnel au fixe pour
limiter les alternances de pages.

**Le coût évité, chiffré en bascules.** Une table qui vit dans une page
coûte double à chaque accès depuis le code : monter la page de la table pour
lire l'entrée, puis monter la page de l'élément pour y aller (et pour un
appelant paginé, restaurer ensuite — trois mouvements de fenêtre). La même
table en mémoire fixe — toujours visible — ne coûte qu'une bascule : celle
vers l'élément. Pour une table lue à chaque trame par sprite ou par objet,
la différence est structurelle, pas marginale.

**Le précédent v1 valide le besoin, vérifié dans le code.** Les cinq tables
moteur→stage (`Obj_Index_Page/Address`, `Img_Page_Index`, `Ani_Page_Index`,
`Ani_Asd_Index`) sont exportées par le main de stage, chargé en page $01 à
$8000 — la RAM résidente. La v1 fait exactement la partition qu'on cherche :
**tables chaudes au fixe, descripteurs riches en pages** (les `set_*` de
l'imageset sont paginés, montés via `Img_Page_Index` avant déréférencement).
Le modèle cible ne doit pas l'inventer, seulement l'exprimer.

**Il l'exprime déjà — il manquait le crochet et le défaut.** La mémoire fixe
n'est pas un concept de plus : c'est une zone comme une autre (`page="$01"`,
adresses hautes), qu'une arène peut porter. La table d'une collection étant
un fichier, son placement se pilote comme celui d'un fichier : un attribut
`arena` sur l'élément `<index>`, dont le défaut est l'arène de la
collection. Manuel mis à jour en conséquence : `<index name="…"
arena="stage.fixe"/>`, l'exemple §5 place la table en $01:$8000 (une bascule
au lieu de deux, dit en toutes lettres), et §3.5 donne la règle simple —
**lue à chaque trame → au fixe ; lue au chargement → en page**. La mémoire
fixe étant la ressource la plus rare (le moteur y vit), le fixe reste un
choix, jamais un défaut global, et le rapport d'occupation en montre la
charge.

Nuance de cohérence avec le §16 : la partition chaud/froid traverse les
étages — `Img_Page_Index` (chaud, fixe, gabarit standard) pointe des
descripteurs (froids, paginés, gabarit sprites) qui pointent des routines
(paginées, fluides). Le modèle n'impose pas un étage : chaque table choisit
son rangement, et la durée de vie reste portée par l'arène (une arène fixe
« du stage » se décharge avec le stage, comme `region stage` le fait
aujourd'hui à $01:$8000).

## 18. Le principe de destination : défaut au fichier, surcharge à l'élément (2026-08-09)

Distillation d'auteur à partir du §17 : la destination — un rangement ou une
place précise — se déclare au fichier et vaut pour tout son contenu ; **tout
élément nommé peut la surcharger**. L'index en mémoire fixe n'était qu'une
instance.

**Ce que le principe unifie.** Quatre mécanismes distincts deviennent un :
la table d'une collection placée au fixe (§17) ; une routine chaude extraite
au fixe pendant que ses données restent en page ; un tampon à adresse
matérielle imposée au milieu d'un contenu libre ; et l'ancien `<block>` du
pageset / le comblement de queues — un élément déclaré, une destination.
C'est aussi l'idiome maison : la cascade défaut → surcharge est déjà celle
des attributs de configuration (`<default>` scopés), le placement parle
désormais la même grammaire.

**La conséquence mécanique : surcharger, c'est se détacher.** Un fichier est
continu sur le média ; un élément qui déclare une autre destination ne peut
pas rester dans le morceau de ses voisins — il devient SON morceau (sa
lecture, sa compression, son entrée de répertoire à 8-24 o). Le coût est
borné et visible au rapport. Corollaire de définition qui simplifie encore :
« rigide » n'est plus une nature de fichier mais un cas — un fichier dont
aucun élément ne surcharge tient en un morceau. Et la contiguïté cesse
d'être un absolu du fichier pour devenir celle du morceau, ce qui était déjà
la définition depuis le §15.

**Les limites, pour que le principe reste sain :**

1. **La surcharge porte sur les éléments DÉCLARÉS**, pas sur les essaims
   générés : les 244 tuiles d'une grille héritent en bloc — surcharger une
   tuile n'a pas de sens (elle est atteinte par l'index, qui absorbe
   n'importe quel placement). Les candidats sont ce qui a un nom dans la
   configuration : l'index, une unité, un tampon, une routine désignée.
2. **La durée de vie reste celle du fichier.** L'élément surchargé est
   chargé et déchargé avec son fichier, où que ses octets vivent. Une
   surcharge vers l'espace d'une AUTRE durée de vie (un élément de stage
   posé dans les zones du commun) est légale pour le placement — les
   vérifications par scène s'appliquent — mais c'est le cas à montrer du
   doigt dans le rapport : l'espace se libère au déchargement du fichier,
   pas de son arène d'accueil. Le cas nominal est la surcharge vers une
   arène de MÊME durée de vie (`stage` → `stage.fixe`).
3. **Un élément à adresse imposée** entre dans la phase « rigide » du
   placement (§15) : il se pose avant que le fluide coule, comme n'importe
   quel fichier épinglé.

Manuel aligné : le principe est énoncé au §3.2 (là où vivent les
destinations), et le §3.5 renvoie vers lui — la table n'est plus un cas
particulier, c'est la première application.

## 19. Correction du §18, et l'invariant des générations multiples (2026-08-09)

Deux objections d'auteur, toutes deux fondées : « surcharger, c'est se
détacher » confondait les unités, et le cas de plusieurs index générés dans
un même fichier n'était pas traité. Reprise du problème à la racine.

### Les trois unités, enfin séparées

Le mot « morceau » recouvrait deux choses distinctes, et la confusion vient
de là :

| unité | ce qui la définit | ce qui la dérive |
|---|---|---|
| **le fichier** | déclaration, nom, chargement, durée de vie | l'auteur |
| **le morceau** | UNE destination RAM contiguë = UNE unité de compression | les destinations × les creux |
| **l'étendue disque** | des secteurs consécutifs, lus d'un balayage | l'ordre d'émission |

Le lien morceau ↔ destination n'est pas un choix de disque, c'est une
conséquence de la **décompression en place** (§14) : le flux compressé est
lu dans la queue de son emplacement final et déplié sur place — l'unité de
compression est donc forcément une plage RAM contiguë. Éparpiller le contenu
d'un seul bloc compressé exigerait un tampon de transit et une passe de
copie, précisément ce que le §14 a montré ne pas exister et ne pas devoir
exister.

**La correction** : surcharger la destination d'un élément le détache **du
morceau** — pas du flux disque. Les morceaux d'un même fichier sont émis à
la suite, collés à l'octet près, lus dans le même balayage de tête : la
continuité disque est une propriété de l'ordre d'émission, indépendante des
destinations RAM, qui peuvent être aussi non linéaires qu'on veut. Le coût
réel d'une surcharge : une entrée de répertoire (8-24 o) et une ligne de
table de scène. Pas un seek, pas un tour de disque. Le §18 reste juste sur
tout le reste ; le manuel est reformulé pour ne plus suggérer une
discontinuité disque.

### Plusieurs index générés dans un fichier : le cas est déjà réel

Le main de stage v1/v2 exporte CINQ tables — `Obj_Index_Page/Address`,
`Img_Page_Index`, `Ani_Page_Index`, `Ani_Asd_Index` — cinq index générés
sur cinq cibles différentes, dans un seul fichier résident. Ce n'est pas un
cas limite du modèle, c'est son cas central. Deux conséquences de
conception :

1. **L'index est un élément généré AVEC UNE CIBLE, déclarable où il vit.**
   La forme du §17 (`<index arena="…">` enfant de sa collection, téléporté
   ailleurs) n'est qu'un raccourci. La forme générale : un index se déclare
   comme élément du fichier QUI L'HÉBERGE, en nommant sa cible —
   `<index of="stage1.tiles"/>` dans le fichier d'interface du stage. Cinq
   index dans un fichier = cinq éléments. Ça résout au passage la gêne de
   durée de vie du §18 (limite 2) : un index déclaré chez son hôte a la
   durée de vie de l'hôte, ce qui est exactement le contrat des cinq tables.
2. **L'invariant qui rend tout ordonnançable** : les enregistrements générés
   sont à **largeur fixe**, donc la TAILLE d'un index ne dépend que de la
   structure de sa cible (des comptes, des variantes déclarées) — jamais des
   placements. D'où l'ordre de build en deux temps, valable quel que soit le
   nombre d'index et leur imbrication : (a) tout se MESURE (les éléments par
   assemblage, les index par comptage) et tout se PLACE en une passe ;
   (b) tout se REMPLIT, dans n'importe quel ordre — un remplissage ne
   consomme que des placements, figés en (a), jamais le contenu d'une autre
   table. L'index d'index (`Img_Page_Index` pointe les descripteurs,
   eux-mêmes générés) passe sans étage supplémentaire : la place d'un
   descripteur est un placement comme un autre.

   La règle de conception qui porte l'invariant : **champs à largeur fixe
   dans toute table générée**. Une table à largeur variable (un index
   compressé, des enregistrements optionnels dépendant d'une valeur placée)
   casserait « taille avant placement » — à interdire, ou à reléguer
   explicitement dans une génération à deux passes qui dirait son nom.

En creux, la leçon de la question : le morceau se définit par la destination
et la compression — le disque n'y est pour rien, il ne connaît que l'ordre.

## 20. La réutilisation (2026-08-09)

Question d'auteur : si la position est associée au fichier, comment
réutiliser des fichiers ? et des éléments (les ennemis des stages 1, 4, 7) ?

**Le malentendu à lever : la place est par fichier, pas par usage.** Un
fichier se déclare une fois et se charge depuis autant de scènes qu'on veut ;
sa place attitrée est UNE place pour tout le jeu, résolue pour que toutes
les compositions qui le chargent tiennent (§12, raffinement 3 — résolution
globale, pas première-scène). L'épinglage n'empêche pas la réutilisation :
il la rend gratuite — tout consommateur cuit contre cette place unique, et
chaque scène retrouve le fichier au même endroit. La bibliothèque existe
déjà dans le dépôt (`src/enemies/`, un ennemi = un dossier) : la
réutilisation se fait au `<load>`, pas à la déclaration.

**Les deux formes, et l'aiguillage entre elles :**

1. **Partager** : un fichier, n scènes qui le chargent. Une copie disque,
   une place RAM. L'optimiseur peut donner la même place à deux fichiers
   qu'aucune scène ne co-charge (patapata des stages 1/4/7 et cancer du
   stage 2) — le partage ne gèle pas l'espace des autres.
2. **Recopier** : les mêmes SOURCES déclarées dans un fichier (ou une
   collection) par stage. Chaque stage place sa copie librement, son index —
   régénéré pour lui — pointe la sienne. Coût disquette, liberté RAM.

L'aiguillage est un refus de build informatif : quand aucune place ne
satisfait toutes les compositions d'un fichier partagé, le message doit
proposer la recopie (et réciproquement, le rapport média peut signaler une
recopie dont toutes les copies auraient tenu à une place commune).

**Pourquoi ça marche sans mécanisme nouveau : l'index absorbe.** L'identité
d'un ennemi dans le jeu est son numéro d'objet ; l'index du stage courant
dit où il vit. Partagé (même place partout) ou recopié (une place par
stage), l'index régénéré du stage donne la bonne réponse — le code ne voit
jamais la différence. C'est la même propriété qui couvrait déjà les
alternatives (§4.6 du manuel) et le placement libre : la table est le joint
de dilatation du modèle.

**Deux notes de réalité** : sur un jeu multi-disquette, partager un fichier
entre stages de disquettes différentes provoque l'invite d'échange — la
recopie par disquette est la forme normale là-bas (la v1 fait ainsi). Et la
dédup média (deux fichiers au contenu identique stockés une fois) est une
optimisation possible du builder, à ne considérer que si la disquette
manque — jamais un concept utilisateur.

Manuel : cas 4.11 ajouté (les mêmes ennemis aux stages 1, 4 et 7 — partager
d'abord, recopier sur suggestion du build).

Ordre suggéré, le jour de l'implémentation :

1. **Les retraits sans risque** (code mort Java : souches de `LayoutResolver`,
   tuyauterie `pages="auto"`, `member()`, `range=`) + les corrections de doc.
   Preuve : 12 configs identiques à l'octet.
2. **Membres = résultat du rangement** (§4, option B) + l'adresse de membre
   lue de la zone. Les images changent (répertoire plus court, ids décalés,
   tables de scènes raccourcies) : méthode standard complète, banc d'échange
   stage1↔stage2 rejoué — c'est lui qui exerce les alternatives à comptes
   différents.
3. **La marche %10/%11 du loader** : optionnelle, à coupler avec la prochaine
   campagne loader pour amortir la revalidation.
