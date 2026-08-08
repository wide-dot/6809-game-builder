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
