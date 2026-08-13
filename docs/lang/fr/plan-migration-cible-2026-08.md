---
date: 2026-08-09
sujet: Plan de migration complet du builder/loader/configs vers le modèle cible
  « file maître » (analyse-placement-2026-08.md §12-§23).
statut: plan, rien d'implémenté. Remplace l'« ordre suggéré » en queue de
  l'analyse.
s'appuie sur: analyse-placement-2026-08.md, analyse-charge-manuelle-2026-08.md,
  manuel-cible-2026-08.md, manuel-cible-workflow-2026-08.md
---

# Migration vers le modèle cible — le plan

## Les principes du plan

1. **Le build reste vert à chaque commit.** Chaque phase se termine par la
   méthode standard (12 configs comparées à la référence, loader-ut sous
   toje, JUnit, banc r-type 5/5) ; chaque étape annonce d'avance si les
   images doivent être **identiques à l'octet** ou **changer** — un
   changement non annoncé est un bug, dans un sens comme dans l'autre.
2. **La valeur d'abord, le risque ensuite.** Les premières phases servent le
   portage r-type en cours (les ennemis) sans toucher aux configs
   existantes ; les phases qui cassent la syntaxe sont groupées et tardives ;
   le loader est touché une seule fois, en dernier, pour amortir sa
   revalidation.
3. **Additif avant soustractif.** Chaque nouveau mécanisme cohabite avec
   l'ancien le temps de migrer le corpus ; l'ancien n'est retiré que quand
   plus rien ne l'utilise — et son retrait est une phase à part, prouvée par
   identité binaire.
4. **Chaque phase met à jour les docs dans le commit** (règle du recueil de
   cas) : `scenes.md`/`sprites.md`/`symbols.md` côté normatif anglais, le
   manuel cible passant du statut « modèle en discussion » à « ce que le
   builder fait » section par section.

## Phase 0 — Les retraits sans risque (courte) — FAITE (2026-08-09)

Le code mort du §5 de l'analyse : souches de `LayoutResolver` (`taken`/
`occupy`, `autoPages`/`sparepages`, `autoPage`), la tuyauterie
`pages="auto"` (Regions.pagesUsed/measuredPages + voyage dans Target),
`PageSetPlugin.member()`, `range=` de gfxcomp. Corrections doc associées
(`scenes.md` documente encore `pages="auto"`).

*Preuve : **faite** — les 15 configs du corpus (59 images fd/sap/sd)
identiques à l'octet avant/après, JUnit 61/61. Trois préalables
d'environnement corrigés au passage : lwtools 4.25 compilé pour Linux
(l'amont 4.18 ne comprenait pas les labels @), l'include fantôme
gen/enemies/cast-pages.asm retiré des mains r-type (un clone frais ne
construisait pas), les includes de log ajoutés au main de
stacked-overflow (régression du système de log).*

## Phase 1 — L'émetteur d'index et les contributions (la valeur immédiate) — FAITE (2026-08-09)

La pièce qui rembourse tout de suite : le service en trois étages (§16 —
résolution `StaticLink` existante, conventions, deux gabarits standards) et
la déclaration inversée (§23) : `<index name="…">` hébergé nu dans un
fichier, attribut `index="…"` de contribution sur les fichiers, instances
par composition pour les alternatives, équates de numéros émises comme
`entries.asm`.

Introduit **en plus** de l'existant : les configs actuelles ne bougent pas,
r-type bascule seul. `gen_objid.py` est remplacé, puis supprimé.

**Arbitrage rendu (auteur, 2026-08-09) : l'émetteur reste le modèle cible
pur, la transition reste déclarée.** La table actuelle est dérivée de la
WAVE par le script, avec repli bouchon pour les ennemis non portés — une
logique de transition. L'option écartée (le builder apprend le repli
bouchon) aurait construit un mécanisme jetable ; l'option retenue : les
entrées bouchon sont des **déclarations explicites** du stage (id fixé,
cible = l'objet bouchon), qui tombent une à une au fil du portage. État des
lieux favorable : le cast du stage 1 est entièrement porté (chaque ligne
pointe un vrai `.Object`) — les bouchons ne concernent plus que les stages
2..8.

Contraintes de conception relevées sur la table réelle : une entrée est un
couple (nom `ObjID_*` → fichier de page + symbole `*.Object`) — plusieurs
ObjID peuvent viser le même fichier (`firechain` en porte deux) ; les ids
doivent reproduire l'ordre de citation de la wave (les équates `ObjID_*`
sont assemblées dans la wave), donc **id explicite au niveau de l'entrée**
pendant la transition ; le fichier généré porte aussi les tables Ani (même
gabarit parallèle, mêmes contributeurs).

*Preuve REFORMULÉE : on bascule r-type du script vers l'émetteur + les
déclarations, et **l'image .fd reste identique à l'octet** (le contenu
assemblé de la table est le même, peu importe le format du fichier
intermédiaire — exiger l'identité du .asm généré aurait mimé jusqu'aux
commentaires du Python, fragile et sans valeur). Puis banc r-type 5/5 sous
toje ; les 14 autres configs inchangées ; `gen_objid.py` supprimé.*

*Étend, dans la foulée : les tables d'animation (même gabarit parallèle),
et l'imageset délégué au même service de résolution — sans toucher son
format runtime (§16, option C).*

*Réalisé : élément `<objectindex>` (plugin `objectindex/ObjectIndexPlugin`,
specs déclarées) — les entrées sont des déclarations explicites
`<entry name file object [asd]>` dans l'ordre des ids (option b : le
bouchon est une déclaration du stage, pas un mécanisme du builder). Il
émet le fichier d'équates (`ObjID_*`, `objid.count`, alias
`objid.animation`, garde IFNDEF) et le fichier des 5 tables parallèles
(Obj_Index_Page/Address, Ani_Page_Index, Ani_Asd_Index, Img_Page_Index)
— les tables d'animation sont donc DANS l'émetteur, pas une extension.
r-type basculé : 77 entrées transplantées dans `to8.config.xml` (45 + 32),
`objid.const.asm` des stages réduits à un relais d'include,
`gen_objid.py` et les `objid.index.asm` manuscrits supprimés.
**Preuve tenue : les 59 images des 15 configs identiques à l'octet**
(dont le .fd r-type), JUnit 61/61. Banc r-type 5/5 sous toje : à rejouer
par l'auteur (pas d'émulateur ici) — sans enjeu attendu, l'image étant
byte-identique. Reste de l'extension : l'imageset délégué au même service
de résolution — différé en phase 3, car supprimer sa link data change
les images, ce qui contredirait la preuve d'identité de cette phase.*

## Phase 2 — Membres de pageset dérivés du rangement (l'héritage v1 tombe) — FAITE (2026-08-09)

Le sujet d'origine : `DirectoryPlugin` mesure et range au moment de la
réservation (§4, option B), le nombre de membres devient le résultat du
rangement, les membres vides disparaissent, l'adresse de membre est lue de
la **zone** (plus du scalaire `region.address`). L'assertion
réservés == émis reste le garde-fou.

*Preuve : les images CHANGENT (répertoire plus court, ids décalés, tables de
scènes raccourcies) — méthode standard complète, banc r-type 5/5 (c'est lui
qui exerce les alternatives à comptes différents : stage1 = 5 membres,
stage2 = 4).*

*Réalisé : `PageSetPlugin` scindé en `pack()` (mesure + premier-ajustement,
appelé par la boucle de réservation du répertoire) et `run()` (émission,
qui réutilise le rangement mémorisé — mesurer deux fois laisserait les
passes diverger, ce que l'assertion réservés==émis refuserait). Le pageset
est traité comme la scène : cas particulier du répertoire, plus de handler
média générique — hors répertoire il n'a pas de sens, ses membres sont des
entrées. Subtilité payée en route : le rangement assemble du contenu, il
doit donc voir les `<default>`/`<define>` propres au répertoire exactement
comme l'émission les verrait — la boucle de réservation les rejoue dans un
contexte de brouillon (sans quoi `lwasm.format=obj` manquait et la mesure
refusait les EXPORT). `stage2.tiles.odd.4` a disparu (répertoire −3 blocs,
table de `scenes.stage2` −5 octets, ids suivants décalés) ; la scène peut
désormais précéder son pageset, `ctx.pageSets` étant peuplé dès la
réservation. **Preuve tenue : seules les 4 images r-type changent, les 55
images des 14 autres configs sont identiques à l'octet, JUnit 61/61.**
Banc r-type 5/5 sous toje : à rejouer par l'auteur (pas d'émulateur ici) —
cette fois l'image change, la revalidation a un enjeu réel. Docs du même
commit : note datée dans analyse-multipage (membre vide/octet de
remplissage : variante rejetée), phrase de CLAUDE.md.*

## Phase 3 — Bake par défaut, link dérivé — FAITE (2026-08-10, hors arbitrage interface)

Le renversement du §12/§23, en trois pas :

3a. **Le link dérivé de la multiplicité** : un nom à fournisseur unique se
    cuit, un nom multi-fournisseurs à places différentes se résout au
    chargement — l'aiguillage remplace le refus d'élection. Le rapport
    « résolu au chargement, avec cause » naît ici ; `interface="true"` et
    l'heuristique « même destination = alternatives » deviennent des
    conséquences, plus des déclarations.

    *Réalisé (10/08) — la voix de l'aiguillage.* L'aiguillage lui-même
    existait déjà (`bake="auto"` retombait sur le lien), mais il **avalait
    sa cause** (`catch { continue; }`). Désormais chaque décision est
    enregistrée (`StaticLink.recordLinked`, aussi pour les `bake="none"`
    déclarés) et rapportée : les classifications au log, la liste complète
    dans `linked-refs-<target>.csv` (file, symbol, sites, mode, cause).
    Sur r-type le rapport montre exactement la frontière attendue — les 5
    tables moteur→stage, `mainloop.state`, les palettes de stage — chaque
    ligne avec les alternatives qui la causent. Doc : `symbols.md`,
    section « The caused list ». JUnit 61→64, **59 images identiques à
    l'octet** (preuve d'identité tenue). L'arbitrage
    interface/« même destination » reste ouvert, dans l'ordre voulu par
    l'état des lieux du 10/08 : le rapport d'abord, l'observation ensuite —
    les retirer avant d'avoir lu la liste causée sur le corpus migré serait
    aveugle. Restes de 3a : cet arbitrage, et ~~l'imageset délégué au service
    de résolution (les images r-type changent — à faire banc vert)~~
    **CLOS PAR MESURE (10/08)** : la fonte avait déjà eu lieu à `4576b95`
    (05/08 — `bake="auto"` posé sur les fichiers porteurs d'index, images
    changées et validées alors) ; les notes « différé » recopiaient un état
    caduc. Mesure : externPg = 0 sur tout le corpus hors mplus (14 réfs
    style getPageID, hors imageset) ; aucune ligne `$PAGE` ni symbole
    d'imageset dans les listes causées ; contre-preuve par cassage
    (`bake="none"` sur common.overlay → 282 octets de lien dont 1 externPg,
    restauré, image byte-identique) ; bancs verts en tête de branche
    (loader-ut 17/17 `$0D`, r-type 5/5). Le critère du §16.C est tenu : un
    seul service de résolution — `<imageset>` appelle `StaticLink.pageOf`
    par image, la forme in-unit `genindex` émet `<file>$PAGE` symbolique
    que `StaticLink.resolvePage` cuit à la passe bake. Le repli externPg
    de la forme in-unit meurt naturellement à 3c (défaut AUTO), aucun code
    à écrire.

    *Observation faite (10/08, corpus migré — le préalable acté de
    l'arbitrage)* : les listes causées du corpus dissous sont VIDES
    partout sauf trois. r-type, 27 lignes : exactement la frontière
    moteur→stage (5 tables ×leurs sites, palettes de stage,
    `mainloop.state`, `checkpoint.positions`), chaque cause étant
    « exported by [stage1, stage2], run-time alternatives ». loader-ut
    (37) et sound (15) : non migrés — l'un garde ses chemins link à
    dessein, l'autre est suspendu. Matière pour la dérivation : après la
    dissolution 4b, la relation « alternatives » est LISIBLE dans
    `FilePlaces` (deux fichiers à place attitrée égale — les mains de
    stage partagent la région `stage`, demain une place littérale
    partagée) ; l'élection de `LinkSymbols` peut la lire là au lieu de
    balayer les loads, et `interface="true"` devient un contrôle dérivé
    (fichiers co-placés ⇒ même liste d'exports post-élagage). Les quatre
    régions `interface` de r-type (stage, maps, tiles.even/odd,
    collision) sont conservées comme matière de l'arbitrage — leur
    dissolution suit sa décision, pas l'inverse.*
3b. **`bake="auto"` partout** dans le corpus (mécanique : l'attribut est
    déjà posé sur r-type) — les configs d'exemples migrent une à une, chaque
    migration validée par exécution (les images changent : la donnée de
    liaison fond).
3c. **Le défaut passe de NONE à AUTO** ; l'attribut devient l'exception
    (`link` explicite pour forcer, cas rares de bancs).

    *Arbitrage interface/alternatives TRANCHÉ ET EXÉCUTÉ (10/08, décision
    auteur)* : **aucune logique ni contrôle lié à l'interchangeabilité ou à
    la co-location.** La mesure préalable a montré que l'élection ne servait
    pas l'interchangeabilité mais compensait une collision de noms générés
    (421 noms de tuiles partagés entre stages, 2 089 sites — la règle nue
    seule aurait rendu ~12 Ko de lien et des refus bake=all). Option B :
    les labels générés s'uniquifient AU GÉNÉRATEUR (une tuile devient
    `adr_<hôte>_<id>_<variante>`, l'hôte = fichier ou pageset, unique par
    construction ; `<tilemap tiles=…>` nomme l'hôte), et l'entrée principale
    d'une table garde son nom commun POUR LE LIEN. Puis la taille : élection
    par consommateur → **comptage nu des fournisseurs** (plusieurs ⇒ lié,
    sauf constantes absolues de même valeur), refus d'unicité des exports
    supprimé (le doublon est un fait, premier-chargé gagne, visibilité par
    la liste causée), `interface="true"` retiré (la garantie vit dans
    api.asm + les bancs), régions `stage` et `maps` dissoutes en places
    littérales partagées (`collision`/`stageinit` restent : chaîne d'ancrage
    mesurée). Le moteur saute sur `stage.main` par le lien (nom commun
    exporté par les deux mains, repointé à chaque échange) au lieu du
    littéral de région. Coût mesuré du retrait : 512 → 634 octets de lien
    (+122 : map.even/odd, stage.wave, stage.main — exactement les entrées
    principales voulues au lien), liste causée 27 → 33 lignes. PREUVE :
    seules les images r-type changent, banc 5/5, loader-ut 17/17, JUnit
    70/70. Doc : symbols.md (comptage nu, § Shared export names).

    *FAIT (10/08)* : `BakeMode.parse` bascule, loader-ut s'exempte par un
    `<default file.bake=none>` par répertoire (l'arbitrage rendu), les 93
    `bake="auto"` redondants du corpus tombent — restent les 5
    `bake="all"` volontaires de r-type. Preuve par identité parfaite aux
    deux pas (bascule seule, puis retrait des attributs : 59 images
    inchangées chaque fois), JUnit 70/70. La phase 3 est close, à
    l'arbitrage interface près (qui vit en 4b/4c).

    *Arbitrage loader-ut rendu (10/08, test par test sur le config réel)* :
    **le décor est vide.** Les 32 `linkdata=` sont tous objets de test —
    les marqueurs et le gm portent les re-links que T1-T18 mesurent, les
    pads et ifaces SONT la croissance d'index de T12/T14, et les loads à
    destination explicite sont la forme par-load dont loader-ut est le
    gardien désigné jusqu'à 4c (alternatives bb/cc sur marker.b comprises).
    Il ne migre donc RIEN en 3b/4b ; sa protection à 3c tient en une
    ligne — `<default name="file.bake" value="none"/>` dans son
    répertoire — et son sort par-load se décide à 4c (forme témoin
    conservée ou conversion, à trancher alors).

    *Dépendance de 3c* : ~~la bascule attend le vert de sound~~ **LEVÉE
    (10/08)** — la régression sound est résolue (passerelle `irq.off`,
    voir TODO « À corriger » et `irq-bridge.md`) et son témoin toje est
    vert. 3c reste la dernière ligne, après la migration 3b de sound.

*Preuve à chaque pas : bancs sous toje (loader-ut garde des tests DÉDIÉS aux
chemins link — le loader doit rester complet), link-report et pool-map en
décrue mesurée, banc r-type 5/5. Les images changent à 3b/3c.*

## Phase 4 — La place attitrée, la région absorbée

Le grand basculement de syntaxe, groupé pour ne casser qu'une fois :

4a. **Résolution globale des places** : un fichier chargé par n scènes
    reçoit UNE place qui satisfait toutes ses compositions (l'optimiseur
    voit toutes les scènes) ; deux fichiers jamais co-chargés peuvent
    partager une place. Les fichiers gagnent `arena=`/`page=`+`address=` ;
    `<load>` se réduit à un nom.

    *Réalisé (10/08) — la syntaxe et sa résolution, additives.* `<file>`
    gagne `arena=`/`region=`/`page=`+`address=` (une forme au plus,
    `FilePlaces` dans le contexte) ; un `<load>` nu résout contre la place
    attitrée de son fichier dans les trois points de lecture (`ScenePlugin`,
    `PlacementScan`, `ArenaPacker`) ; le `<pageset>` n'a rien à gagner — son
    `region=` déclaré EST sa place, un load le nomme nu. Un load qui répète
    la même destination est toléré (forme transitionnelle), un load qui la
    contredit est une erreur nommant les deux déclarations, une seconde
    place pour le même nom aussi. L'unicité devient structurelle. Vérifié
    sur le corpus réel : les 85 loads de r-type n'ont AUCUNE incohérence de
    destination par fichier — la revendication du modèle, mesurée. Doc :
    `scenes.md` § The attributed place. Preuve : 59 images identiques à
    l'octet (rien ne l'utilise encore), JUnit 64/64 ; la migration r-type
    (commit suivant) prouve l'équivalence par identité sur les 4 images.
    Reste de 4a : la vérification globale des places fixes hors arène
    (déclarée mais non recoupée toutes-compositions), différée avec 4b.
4b. **Migration du corpus** : les 12 configs d'exemples puis r-type, région
    par région — une région devient soit une place explicite partagée par
    des alternatives, soit rien (la place attitrée suffit). Réécriture
    mécanique, un projet par commit.

    *Entamée par le pilote (10/08) : r-type migré en premier* — l'ordre du
    plan (exemples d'abord) supposait la preuve par exécution ; le
    déplacement d'attribut à places égales se prouve par IDENTITÉ, et
    r-type est le seul config à arènes, donc le vrai banc du mécanisme.
    75 fichiers annotés (64 arena, 11 region), 4 pagesets nommés nus, les
    84 loads réduits au nom (reste `engine.sound.ym.const`, export-only
    par absence de place — l'historique). **Les 59 images du corpus
    restent identiques à l'octet, dont les 4 de r-type.** La dissolution
    des régions elle-même (une région → place attitrée partagée ou rien)
    reste à faire, exemples compris.

    *Étendue aux exemples dans la foulée (10/08)* : 13 configs migrés du
    même mouvement (71 fichiers annotés, 71 loads réduits), MO6 compris —
    le déplacement à places égales se prouve par identité, ce qui couvre
    exactement les images qu'aucun émulateur ne valide ici. **loader-ut
    est exclu à dessein** : il garde la forme par-load vivante dans le
    corpus tant que 4c ne l'a pas retirée, comme il garde ses chemins
    link pour 3b. Preuve : 59 images identiques à l'octet.
4c. **Retrait de `<region>`** quand plus rien ne l'utilise.

*Preuve : 4a est additif (configs inchangées = images inchangées) ; chaque
migration 4b vise l'IDENTITÉ D'EXÉCUTION (bancs toje verts, RAM vérifiée)
plutôt que l'identité binaire — les places bougent, le comportement non.
4c par identité binaire.*

## Phase 5 — Les collections fluides (la coupe par les creux)

Le placement en deux temps (§15) : rigide posé, fluide coulé, morceaux
taillés par les creux, seuil de creux avec ses deux plateaux au rapport.
~~Le `<pageset>` se dissout dans la contribution (§23) : un fichier `index=`
à contenu divisible EST la collection~~ — **périmé, voir le modèle arrêté
ci-dessous** : la contribution par `index=` est morte avec la sortie des
objets du XML (11/08), et la divisibilité ne se déclare pas.

### Le modèle, arrêté avec l'auteur le 11/08 (§28)

Quatre phrases, et rien d'autre :

1. **Un plugin déclare combien d'éléments il produit.** `lwasm` en rend UN
   (une assemblée, d'un tenant) ; `gfxcomp` en expose N. La frontière du
   découpage est le PLUGIN, jamais le fichier — donc aucun mot à écrire, et
   les quatre options du §27 tombent avec la question qu'elles posaient.
2. **Les éléments coulent dans les creux** que les indivisibles ont laissés
   (la coupe par les creux, déjà faite).
3. **Tout ce qui référence un élément passe par une table.** C'est ce marché
   qui autorise le builder à poser l'élément où il veut : un élément est
   coupable PARCE QU'il est indexé.
4. **Toute table demande la page d'un élément en écrivant `élément$PAGE`** —
   générée ou manuscrite, même question, même résolution. L'adresse est déjà
   le symbole ; le numéro est authoré ou porté par la donnée.

Plus `<unit>`, qui **groupe des plugins dont la sortie doit rester
continue** (objet composite ; absent de r-type, prévisible). Qui ÉCRIT une
table dépend d'une seule chose — qui connaît les entrées : le builder quand
lui seul les connaît (`<tilemap>`, `<imageset>`), le développeur quand elles
sont authorées (la table d'objets, prouvée le 11/08).

### Les trois étapes restantes, et la règle de travail

> **Règle actée le 11/08 : chaque étape est spécifiée EN DÉTAIL et validée
> par l'auteur AVANT son implémentation.** Le plan porte la spec ; le commit
> porte la preuve.

- **5b — l'attribut de page d'un élément. FAIT (11/08).** `StaticLink.pageOfName`
  consulte les deux tables (fichiers placés, symboles exportés) et REFUSE un
  nom qui répond aux deux, en les nommant ; le chemin de cuisson l'utilise, la
  forme liée reste sur un id de fichier. Les trois générateurs demandent la
  page PAR SON NOM : `<tilemap>` et les deux formes de l'imageset écrivent
  `<expression machine><symbole>$PAGE` au lieu d'un littéral, déclarent le
  `$PAGE EXTERNAL` de chaque élément et émettent l'include de la machine
  (gardé). `ImageSets.PageOf` et son câblage disparaissent, la branche à deux
  formes de `pageSymbol` se réduit à une ligne, et les deux derniers `0x60`
  du builder partent — il ne reste de constante machine que dans
  `ObjectIndexPlugin`, qui meurt en 5e. PRÉALABLE FAIT : la définition machine
  (`engine/config/machine.xml`, lue comme `storage.xml`) porte l'expression et
  son include. PREUVE : 59 images identiques à l'octet (le littéral cuit vaut
  ce que le symbole résout), JUnit 142/142, banc r-type 5/5, et les deux
  garde-fous LUS pour de vrai — « 'overlay$PAGE' is ambiguous : … » et
  « 'nowhere$PAGE' resolves to nothing : … ».
- **5c — le flux par élément, sur tout fichier. FAIT (12/08), option (i)
  tranchée par l'auteur (« un seul tri »).** Les quatre `<pageset>` sont des
  `<file>` ordinaires ; le packer trie TOUT plus-gros-d'abord, pose entier ce
  qui rentre (le fichier garde son nom), et coule en membres `<fichier>.N` ce
  qui ne rentre pas. PREUVE : seules les 4 images r-type changent — les 48
  fichiers ennemis ont leur `gfxcomp` IMBRIQUÉ dans `lwasm`, donc un seul
  élément, donc un tri inchangé ; le dilemme (i)/(ii) ne portait en réalité
  que sur les 4 tilesets. 55 images identiques à l'octet, JUnit vert, banc
  r-type 5/5 sous toje (caméra à 1440, échange réversible), reproductibilité
  reconfirmée sur les 59. Gain mesuré du tri unique : les deux tilesets d'un
  stage partagent désormais les queues de pages (even coule dans ce que odd
  laisse), là où deux pagesets ne savaient remplir que des pages disjointes.
  Le retrait de la machinerie `<pageset>` (commit B) est FAIT aussi :
  élément, plugin (685 lignes), specs, `arenaGaps`, `memberNames` — le
  `<unit>` relogé dans son propre plugin, les 6 scénarios de flux
  retargetés sur `ArenaPacker.cut`, docs alignées. Preuve : 59 images
  identiques à l'octet.
- **5d — `<unit>` sur son vrai rôle. FAIT (12/08), volets (a)+(b)+(c) —
  décision auteur : « b tout de suite, on fait un builder générique ».**
  `unit` est au registre PARTS : un fichier d'arène mêlant `<gfxcomp>` et
  `<unit>` est une collection dont le unit est un élément insécable —
  mesuré et assemblé SEUL (les noms internes des units se répètent), le
  membre qui le porte concatène des BINAIRES (une assemblée par série
  divisible, une par unit, dans l'ordre de déclaration), et un genindex
  imbriqué reçoit le nom du membre réel. Les 2 units du corpus (vagues)
  basculent sur ce chemin. PREUVE : 59 images identiques à l'octet (les
  vagues émises par la voie collection, mêmes octets), JUnit vert, et le
  nouveau banc `examples/collection` — 40 tuiles + un unit coupés en 4
  membres (12+12+12+4+unit), **4/4 sous toje** : contenu du unit relu à
  travers son membre, coupe prouvée par pages distinctes, pointeur
  inter-membres DANS le unit égal au pointeur du game mode (rebasage des
  link data du membre concaténé). L'erreur « does not fit » lue en vrai
  (690 octets restants sur 3 zones). Doc : scenes.md § unit.

- **5e — retrait de `<objectindex>`. FAIT (12/08).** L'élément, son plugin
  (les 5 derniers `map.RAM_OVER_CART` codés en dur du builder) et les specs
  `<objectindex>`/`<entry>` retirés ; XSD −219 lignes. Avec lui disparaît
  la dernière constante machine hors `machine.xml`. PREUVE : 59 images
  identiques à l'octet, JUnit vert.

### 5d — spécification détaillée (VALIDÉE le 12/08 — « b tout de suite », réalisée le jour même)

*Le rôle, dans le modèle du §28.* Un `<unit>` est le mot qui groupe des
plugins dont la sortie doit rester **continue** : un élément aux yeux du
placement, jamais coupé en son intérieur. Trois faits mesurés sur l'état
d'aujourd'hui :

1. **Le corpus compte 4 `<unit>`** (les vagues des stages 1-2, deux armes),
   tous **enfant unique d'un `<file>`** — la continuité y est triviale
   puisque rien d'autre ne partage le fichier. L'élément fonctionne :
   enveloppe générée (EXPORT + section + label d'entrée), assemblée seule,
   patch du `file=` d'un gfxcomp à genindex imbriqué.
2. **Le refus historique « pas de unit dans la forme arène » est déjà
   tombé** — il vivait dans PageSetPlugin, mort au commit B. Un
   `<file arena=…><unit>…</unit></file>` est le pattern courant des vagues.
3. **Ce qui n'est PAS exprimable : le fichier mixte.** Un `<file arena=…>`
   mêlant des éléments coupables (`<gfxcomp>`) et un `<unit>` n'est pas vu
   comme collection — la détection exige que TOUS les enfants sachent nommer
   leurs parties, et `unit` n'est pas au registre PARTS. Le fichier entier
   devient donc rigide : c'est le cas composite du §28 (« certains objets
   composites qui ne sont pas dans rtype »).

*Ce que la 5d ferait, en trois volets :*

- **(a) La fiche.** La spec de l'élément dit déjà « one indivisible object »
  (réécrite au commit B). Reste le manuel : un paragraphe `<unit>` dans
  scenes.md — grouper pour la continuité, les deux espèces (sources
  auto-enveloppées vs données nues via `section=`), et le composite.
- **(b) unit = fournisseur d'éléments.** Enregistrer `unit` au registre
  PARTS avec UNE partie : sa source générée + son `symbol`. Effet : le
  fichier mixte devient une collection dont le unit est un élément
  insécable — le packer peut couper ENTRE le unit et les tuiles, jamais
  DANS le unit. Coût réel, pas une ligne : la MESURE d'une collection
  assemble aujourd'hui tous les éléments en un seul lot, or deux units ne
  peuvent pas partager une assemblée (les sources v1 réutilisent leurs noms
  internes `Object`/`Routines` — c'est pour ça que l'ancien pageset
  mesurait chaque unit À PART). Il faut donc réintroduire la mesure
  séparée des units dans CollectionPlugin, et l'émission par morceau doit
  concaténer des BINAIRES (divisible + units), pas des sources.
- **(c) Le cas composite documenté**, avec un exemple synthétique.

*LE POINT À TRANCHER : (b) maintenant ou au premier consommateur ?* Aucun
objet de r-type n'a besoin du fichier mixte (les 48 ennemis imbriquent leur
gfxcomp DANS le lwasm — un seul élément, continuité par construction ; les
4 units du corpus sont seuls dans leur fichier). Implémenter (b) aujourd'hui
c'est réintroduire ~80 lignes de mesure/émission spéciales units sans
personne pour les exercer en vrai — un banc JUnit synthétique serait la
seule preuve, et la machinerie dormirait. Ne faire que (a)+(c) c'est
documenter le modèle et laisser le registre PARTS comme point d'ancrage
nommé — la ligne `PARTS.put("unit", …)` est exactement où brancher le jour
où un objet composite existe.

**Recommandation : (a)+(c) maintenant, (b) différé au premier objet
composite réel.** C'est le précédent du repo (le retrait du ServiceLoader :
on ne garde pas de machinerie sans consommateur, on garde le point
d'ancrage). Preuve de (a)+(c) : identité 59/59 — c'est de la doc.

**Tranché par l'auteur le 12/08 : (b) tout de suite — « on fait un builder
générique, pas juste rtype », avec test par exemples.** Réalisé le jour
même ; le consommateur qui manquait a été construit : `examples/collection`
(art généré en mire, l'index de chaque tuile encodé dans son dessin),
validé 4/4 sous toje. Voir le bilan en tête de phase.

### Prérequis mesuré : les éléments portent-ils déjà un nom ?

Question d'auteur, préalable à `X$PAGE` — vérifié sur le corpus :

- **Éléments générés : oui, tous.** Un membre de pageset ouvre par
  `adr_stage1.tiles.even_0_ND0 EXPORT` (un par tuile) ; un index d'imageset
  réparti déclare `adr_dobkeratops_eye102_NB0 EXTERNAL` (un par image, plus
  sa variante d'effacement). Le nommage a été normalisé le 10/08
  (`adr_<hôte>_<id>_<variante>`).
- **Éléments `<unit>` : oui, par construction** — l'attribut `symbol` est
  REQUIS par la spec de l'élément.
- **Éléments `<lwasm>` : oui en pratique, par convention.** Ils exportent
  leur point d'entrée parce que c'est ainsi qu'on les atteint
  (`patapata.Object EXPORT`). Rien ne l'impose : un lwasm qui n'exporte
  rien n'aurait pas de poignée.
- **Binaires bruts `<bin>` : non, et c'est structurel** — pas de symbole
  possible. Un seul cas dans tout le corpus (`prefix-256.bin`, loader-ut).

*Conséquence pour 5b, et elle est déjà dans la spec* : `X$PAGE` doit
accepter **un symbole OU un nom de fichier**, la forme fichier restant la
réponse pour ce qui n'a pas de nom. C'est exactement la double consultation
spécifiée ci-dessous. (Note d'instrument : ne pas mesurer ça avec
`link-report-*.csv` — il compte les exports APRÈS élagage, donc un fichier
dont personne n'importe l'entrée y paraît sans export alors qu'il en
déclare un. La table de `StaticLink`, elle, porte tous les exports
déclarés, ce qui est bien ce que `pageOf` interroge.)

### 5c — spécification détaillée (VALIDÉE le 11/08, réalisée le 12/08 en option (i))

*Le modèle.* Le packer d'arène ne range plus des FICHIERS mais des
**éléments**. Un élément est ce qu'un plugin produit : `lwasm` en rend un
(une assemblée, d'un tenant), `gfxcomp` en expose N (il sait nommer ses
parties), `bin` un, `<unit>` un — il groupe justement des plugins dont la
sortie doit rester continue. C'est déjà la frontière que le code connaît
(`PartsPluginInterface`, un seul inscrit).

*La règle de découpe : **entier s'il rentre, coupé sinon**.* Un fichier qui
tient dans un creux reste UNE entrée et **garde son nom**, sans suffixe —
c'est ce qui préserve les 84 loads, les équates de place et les scènes. Un
fichier qui ne rentre pas coule dans les creux et donne une entrée par creux
utilisé, nommée `<fichier>.0`, `.1`… : la règle des membres d'aujourd'hui,
généralisée. La coupe devient donc un **repli**, pas une politique — là où
le build s'arrêtait sur « l'arène ne peut pas tenir X », il range.

*Ce qui disparaît.* `<pageset>` et ses quatre déclarations, qui deviennent
des `<file>` (attributs réellement employés, mesurés : `name`, `arena`,
`linkdata`, `gendir` — `gensymbols`, `gapmin`, `codec`, `section` et `bake`
n'ont aucun usage). La forme `region=` meurt avec lui : **zéro utilisateur**
depuis le re-rangement du 11/08. Et le refus de `<unit>` dans la forme arène
tombe — les fichiers mixtes deviennent exprimables.

*Pourquoi couper est sûr.* Un fichier mixte porte déjà ses moitiés en
assemblées séparées : le code d'un ennemi référence ses images par symbole,
qu'elles soient dans la même entrée ou non. Couper entre deux éléments ne
change donc rien à la résolution — cuite ou liée — et une référence
*interne* à un élément ne peut pas être coupée, puisque l'élément est
l'unité. Le contrat est tenu par l'assembleur, pas par la confiance.

*Un effet à traiter explicitement : la place publiée.* Un fichier d'arène
reçoit aujourd'hui son équate `<fichier>.page`. Un fichier COUPÉ n'a plus
une page unique : publier l'équate serait un mensonge. Elle n'est donc pas
émise pour lui, et le code qui a besoin d'une page demande `symbole$PAGE`
(5b) — c'est exactement ce que l'attribut résout.

*LE POINT À TRANCHER, et il décide de la preuve.* Un fichier divisible qui
tient entier participe-t-il à la phase « plus gros d'abord » avec les
indivisibles ?

- **(i) oui — un seul tri.** Meilleur remplissage possible, modèle plus pur.
  MAIS l'ordre de pose change pour les 48 fichiers `lwasm`+`gfxcomp` : les
  adresses bougent, **les images changent**, et la preuve devient le banc.
- **(ii) non — les divisibles coulent après les indivisibles**, comme les
  pagesets aujourd'hui. L'ordre de pose est inchangé, **les 59 images
  restent identiques à l'octet**, et la coupe n'apparaît que là où elle est
  nécessaire.

**Recommandation : (ii).** Le gain de (i) est un remplissage meilleur — non
mesuré, non demandé — et son coût est de perdre la preuve par identité sur
un changement structurel de vocabulaire : mauvais échange. (ii) généralise
ce qui marche déjà, et laisse (i) mesurable plus tard, isolément, quand une
arène serrera vraiment.

**Tranché par l'auteur le 12/08 : (i), « un seul tri, maintenant ».** Et la
mesure a dissous le dilemme : ma prémisse « les 48 fichiers changent
d'adresses » était fausse. Leur `gfxcomp` est imbriqué DANS le `<lwasm>` —
un seul élément au sens du modèle, donc un fichier indivisible, donc un tri
identique à avant. Seuls les 4 tilesets (gfxcomp au premier niveau) sont
divisibles ; l'écart entre (i) et (ii) se réduisait à eux, qui changeaient
de toute façon.

*Preuve rendue (option i, 12/08)* : 4 images r-type changées, 55 identiques
à l'octet ; JUnit vert ; banc r-type 5/5 sous toje ; reproductibilité
reconfirmée (deux corpus consécutifs identiques). Un piège Java attrapé au
premier build : le ternaire `d != null ? d.total : fileSize(f)` mélange
`int` et `Integer`, la promotion numérique déboxe le null AVANT le test —
NPE dans la passe de découverte, corrigé en `if/else` commenté.

### 5b — spécification détaillée (à valider)

*Ce que ça ajoute.* `X$PAGE` accepte un **symbole** là où il n'accepte
aujourd'hui qu'un nom de fichier. La valeur rendue est le **numéro de page
nu** — jamais les bits du registre cartouche.

*Résolution.* À la cuisson uniquement : `pageOf(symbole)` élit le
fournisseur puis lit son placement (le service existe, deux appelants Java
aujourd'hui). Les DEUX tables sont consultées, symboles et fichiers ; si les
deux répondent, **erreur nommant les deux** — jamais de repli silencieux
(c'est la règle du comptage nu, et ça corrige le §25(a)).

*Ce qui ne change pas.* La forme LIÉE reste sur un id de fichier
(`externPg`) : un symbole dont le fournisseur n'est pas placé au build est
donc une erreur, pas une relocation. L'étage load-time par symbole est
possible et bon marché (§25) mais relève de la phase 8. Une référence
`$PAGE` sur 16 bits reste l'erreur nommée qu'elle est déjà.

*Ce que les générateurs deviennent.* `<tilemap>` et la forme répartie de
`<imageset>` émettent `map.RAM_OVER_CART+<symbole>$PAGE` au lieu d'un
littéral ; `StaticLink.pageOf` n'est plus appelé depuis Java, l'interface
`ImageSets.PageOf` et son câblage disparaissent, la branche à deux formes de
`ImageSet.pageSymbol` se réduit à une ligne.

*Point tranché avec l'auteur le 11/08 : l'expression se configure, elle ne
se code pas.* Mes deux premières sorties étaient toutes deux mauvaises, et
la mesure le montre — **le builder connaît DÉJÀ la machine, à huit endroits
et dans deux orthographes** : `ObjectIndexPlugin` écrit le NOM
`map.RAM_OVER_CART+` (5 sites), `TilemapPlugin` aussi (1 site), et
`ImageSet` écrit la VALEUR `0x60` (2 sites). « Ne rien changer » ne coûtait
donc pas zéro : ça gardait une fuite existante.

État des définitions externes : il y en a **une seule**,
`engine/config/storage.xml`, tirée par un `<default name="floppydisk.storage">`
que chaque config pose. **Il n'existe aucun équivalent machine** — la
machine n'est jamais nommée dans le config, elle n'existe qu'implicitement,
par les chemins `engine/system/to8|mo6/` que les includes visent.
`<target name="fd">` nomme la cible média, pas la machine.

Forme retenue : une **définition machine** sur le modèle de `storage.xml`,
portant deux entrées qui se répondent —
- l'**expression** du préfixe de page (`map.RAM_OVER_CART+`),
- l'**include** qui la définit (`engine/system/to8/map.const.asm`).

Le générateur émet la ligne d'include PUIS l'expression, sans rien savoir.
Ça ferme les deux défauts d'un coup : plus de valeur dupliquée entre le XML
et l'asm (c'est un nom, pas un nombre), et plus d'include à poser à la main
config par config (le générateur l'écrit depuis la déclaration). Les huit
sites en dur tombent.

*Reste à trancher* : la portée de la définition machine — un fichier XML
dédié (l'analogue exact de `storage.xml`, une entrée aujourd'hui, la règle
du dépôt « capitaliser à la première occurrence » y pousse) ou un simple
`<default>` dans le config. Candidats à y rejoindre plus tard : le nombre
de pages RAM par défaut (aujourd'hui un défaut Java de 32, déjà
surchargeable par `<layout pages=>`).

*Preuve.* Identité binaire sur les 59 images — le littéral cuit aujourd'hui
vaut exactement ce que le symbole résoudra — plus JUnit, plus le contrôle de
collision cassé exprès pour le lire (règle du dépôt : un garde-fou qui n'a
jamais échoué est un garde-fou que personne n'a lu).

*Preuve : r-type re-rangé — attendu mesurable : moins de morceaux que de
membres actuels (2 au lieu de 5 sur l'exemple des tuiles), pages rendues
visibles au rapport, banc 5/5, niveau 1 entier traversé sous toje.*

*La coupe par les creux est FAITE (10/08).* Deux temps au placement :
l'ArenaPacker enregistre les creux que le rangement rigide laisse par zone,
et `<pageset arena="…">` y coule ses éléments — un morceau par creux
utilisé, aussi gros que son creux le permet, seuil `gapmin` (256 par
défaut, les deux plateaux au rapport), erreurs nommées (élément trop gros,
ensemble qui ne tient pas, avec le manque mesuré). Les creux consommés
partiellement et les creux trop petits pour l'élément en cours restent
disponibles pour la collection suivante. `<unit>` refusé dans la forme
arène (un rigide ordinaire y suffit — et `<unit>` marche désormais aussi
dans un `<file>`, la promesse de la spec est tenue). La forme `region=`
est intacte. r-type re-rangé : les 8 pages de tuiles deviennent deux
arènes alternatives (l'échange passe par scene.unload, les destinations
divergent sans danger), cartes et vagues sont des rigides posés par le
packer, et **les adresses mesurées à la main disparaissent** ($1C9B « fin
mesurée », $09C7) — la fenêtre des musiques permanentes de $1A est
déclarée en deux zones libres, et la collision musiques/tuiles a été
attrapée par le contrôle de scène AVANT toute exécution. Mesure honnête :
l'espace étant quasi plein (reste 4 001 octets utilisables côté stage 1),
la coupe donne 10 morceaux là où la forme région en avait 8 — les
fenêtres fragmentent ; le gain ici est la disparition du câblage manuel
et la visibilité du reste, pas le nombre d'entrées (le « 2 au lieu de
5 » du manuel suppose des zones spacieuses, prouvé par le test unitaire
qui rejoue son exemple). PREUVE : mécanisme par identité 59/59 + JUnit
125/125 (6 tests sur la fonction pure de flux) ; re-rangement par
exécution — banc r-type 5/5, niveau 1 traversé (caméra à 1440), zéro
retour de tête conservé, 4 images r-type changent (annoncé), reste du
corpus identique.*

*Re-validation entamée (10/08) — le cas objet est mesuré au §24 de
l'analyse : la réutilisation multi-stages est massive et sans axe (20
objets sur 54, sous-ensembles arbitraires), la v1 n'avait aucun contrat de
numérotation entre stages, le contrat v2 vient du résident et porte sur
25 ObjID exactement, plus deux contraintes de second ordre (clusters
ennemi+satellites sur binaire partagé ; présence forcée par source
partagée — le bouchon shellEraser). Conclusion de l'étude : l'objet de
l'arbitrage est le MODÈLE DE NUMÉROTATION (trois étages : résident figé,
clusters cohérents, local libre), orthogonal à la syntaxe de déclaration —
l'inversion « le contributeur nomme son index » échoue sur la matrice,
l'instance par co-chargement et le centralisé dédoublonné exigent tous
deux le même ordonnanceur. Arbitrage auteur en attente ; la coupe par les
creux reste indépendante et peut précéder.*

## Phase 6 — Le média dérivé des scènes

L'ordre disquette par première utilisation (le builder trie `cwrite` par
scène au lieu de l'ordre de déclaration), le rapport de seeks par scène
(le journal de `FdUtil` existe), et le mot `codec` qui devient silence
(défaut compressé, repli brut déjà en place).

*Le rapport de seeks est FAIT (10/08)* — consommateur en lecture seule du
journal média + de la RAM map (`report/SeekReport`,
`seek-report-<target>.txt`) : pistes visitées par scène dans l'ordre de la
table, retours de tête marqués avec leur provenance, distance totale.
Première lecture sur r-type : `scenes.boot` paie 4 retours (dont
`stage1.init` à t25 qui force un retour à t7) — l'instrument montre
exactement ce que l'ordre par première utilisation fera disparaître, et le
critère « zéro retour pour une scène non partagée » est imprimé en tête du
rapport. Aucune image ne change (59/59 identiques). Reste de la phase :
l'ordre d'écriture lui-même, et le silence du `codec`.

*Le silence du `codec` est FAIT (10/08)* — le défaut devient `zx0`
(`DirEntryPlugin.effectiveCodec`, appliqué aux trois lecteurs : entrée,
réservation du répertoire, pageset), `codec="none"` est l'opt-out explicite
(brut, aucun bloc de compression). La table de scène reste épinglée brute
dans le générateur — le loader la parcourt sans passe de décompression, un
tableau compressé serait lu tel quel. Le pageset écrit sa décision effective
sur chaque membre, `none` compris (un attribut omis serait re-défauté). La
réservation du répertoire lisait les attributs hors du contexte des
`<default>` rejoués — bug latent tant qu'aucun défaut ne touchait au nombre
de blocs, attrapé par l'assertion réservé==émis (103 vs 77). loader-ut
opte out par `<default name="file.codec" value="none"/>` (ses chemins bruts
sont des objets de test) ; les `codec="zx0"` devenus redondants sont
supprimés des 12 autres configs. PREUVE : 46/59 images changent (annoncé),
loader-ut et tlsf-ut identiques à l'octet ; retrait des attributs prouvé
par identité 59/59 ; JUnit 116/116 ; banc complet sous toje — r-type 5/5,
loader-ut $0D + T18, objects $0D, sprites, tilescroll, stacked, sound
(échange à chaud + flux YMM/VGC), mplus test+pcm (séquences d'écrans
identiques aux références), hscroll aligné à k=−16 (la compression fait
gagner 16 trames de chargement, écrans identiques aux deux jalons). MO6 sur
foi du jumeau TO8, annoncé. Mesure : mplus-test −4248 octets média (−24 %),
sound −405 ; r-type +17 (ses entrées déclaraient déjà zx0 — le delta est
le bloc de compression des petites entrées stockées brutes).

*Preuve : les images changent (ordre des secteurs) — chargements vérifiés
sous toje, le rapport doit montrer ZÉRO retour de tête pour une scène dont
les fichiers ne sont pas partagés.*

*L'ordre d'écriture est FAIT (10/08) — la phase 6 est close.* Les cwrite
d'une entrée sont différés (`DirEntry.Pending` : section, octets, offset du
descripteur à patcher) et le répertoire les flush dans l'ordre de première
utilisation — la table de la première scène, puis ses fichiers dans l'ordre
de la table, puis la scène suivante ; les fichiers hors scène gardent
l'ordre de déclaration, après. Le descripteur de 6 octets est patché dans
les blocs au flush, seule partie d'une entrée qui dépend d'où tombent les
octets. Garde-fou : une entrée bâtie hors `<directory>` (aucun point de
flush) est une erreur au niveau du floppydisk. PREUVE : critère atteint —
r-type `scenes.boot` passe de 4 retours/75 pistes à **0 retour/25 pistes**,
stage1 35→25, ZÉRO retour sur tout le corpus ; 24/59 images changent
(annoncé — hscroll, loader-ut, mplus-test TO8+MO6, tilescroll, r-type ;
les autres étaient déjà dans l'ordre), reconstruction reproductible ;
JUnit 119/119 ; bancs des images changées verts (loader-ut $0D+T18,
r-type 5/5, tilescroll, hscroll aligné k=−13, mplus-test séquence
identique). MO6 sur foi du jumeau TO8, annoncé.

## Phase 7 — Les contrats générés (la fin de la glue)

La charge manuelle restante (analyse-charge-manuelle) : les `.external.asm`
émis depuis le registre d'exports (api.asm et stage-tables.asm générés — la
dérive moteur↔stage devient impossible), la déclaration d'images compacte
(un répertoire ordonné + un encodeur + exceptions, à concevoir avec le
portage des ~60 ennemis qui la testera), l'orchestration leanscroll/crop en
modules producteurs dans le `<file>`.

*Preuve et critère de fin : `games/r-type/tools/` ne contient plus que des
outils de contenu — plus aucun script dont la sortie est requise par le
build. Le bloc config d'un ennemi tient en ~6 lignes.*

### Phase 7 — recadrage mesuré (12/08, après la clôture de la phase 5)

L'analyse-charge-manuelle date du 09/08 ; trois de ses postes ont bougé
depuis :

- **Le poste n°1 (`gen_objid.py`, index et équates) est DISSOUS** — pas par
  un générateur, par la décision 5-objets : les tables d'objets sont de
  l'asm de dev, l'invariant du préfixe est un include. Le script est
  supprimé depuis la phase 1 ; `<objectindex>`, son remplaçant transitoire,
  est retiré (5e). Plus rien à construire.
- **`crop_stage.py` ne coupe plus rien** : sa fenêtre est aujourd'hui le
  niveau ENTIER (132 colonnes = les 1584 px du niveau 1 ; `intro/even.png`
  mesure 245 tuiles). Son rôle réel restant : adapter le format des sorties
  leanscroll (strip + bin renumérotés) et émettre `map.const.asm` (la
  géométrie). C'est un adaptateur, plus un choix de contenu.
- **`api.asm` rend déjà la dérive impossible** : une seule liste, lue en
  EXPORT par le moteur (`ENGINE_RESIDENT`) et en EXTERNAL par les stages,
  via la macro `_api`. La propriété que le générateur devait apporter est
  acquise sans machinerie.

### 7a — les contrats d'interface : rien à générer — FAIT (13/08)

Clos comme proposé : l'idiome du contrat à liste unique est au manuel
(symbols.md § The single-list contract, avec le générateur `.external.asm`
REJETÉ et son pourquoi — la circularité), zéro mécanisme.
`gen_enemy_unit.py` est retiré dans la foulée (son moule XML a fondu avec
7b ; le geste de portage restant est documenté dans games/r-type/readme.md
§ Porter un ennemi). **Le critère de fin de la phase 7 est atteint :
`games/r-type/tools/` ne contient plus que des outils de contenu**
(arcade_to_in, sync_waves, check_variants, remap_font_colors, fade_preview,
la recette leanscroll-06) — plus aucun script dont la sortie est requise
par le build.

*Analyse d'origine :*

Le générateur imaginé (`.external.asm` émis du registre d'exports) porte une
circularité : la liste des exports du moteur EST le contrat authoré —
« la liste reste délibérément courte » est une décision de design (chaque nom
coûte 4 octets de pool et une recherche linéaire par référence). Générer la
liste depuis « ce que le moteur exporte » inverserait la causalité : c'est
api.asm qui DÉCIDE ce que le moteur exporte. Et le côté consommateur est déjà
généré… par la même macro. `stage-tables.asm` (28 lignes, 5 tables, stable
depuis la frontière mesurée) a la même propriété en sens inverse.

**Proposition : 7a se clôt par un enregistrement de décision** (l'alternative
rejetée est nommée : le générateur `.external.asm`) **et un paragraphe de
manuel** sur l'idiome du contrat à liste unique. Zéro mécanisme.

### 7b — la déclaration d'images compacte (le gros du volume — spec à valider)

Mesure : **340 blocs `<image>`** dans le config r-type, ~9 motifs d'encodeur
seulement — `bdraw/none/0` en couvre 209, les miroirs continuent la
numérotation des mêmes fichiers (scant : 3 png, images 0-2 en `none`, 3-5 les
MÊMES png en `mirror=x`). La forme compacte proposée, UN élément :

```xml
<images dir="src/enemies/scant/images" match="scant_v2_*.png"
        encoder="bdraw"/>
<images dir="src/enemies/scant/images" match="scant_v2_*.png"
        encoder="bdraw" mirror="x"/>
```

- `dir` + `match` : la liste ordonnée (tri numérique sur le nom de fichier —
  l'ordre EST la numérotation, comme les properties v1) ;
- les index continuent d'un `<images>` au suivant dans le même gfxcomp ;
- un `<image>` unitaire reste valide au milieu (l'exception : shift
  particulier, png hors série) — les deux formes se mélangent, les index
  se suivent ;
- POINT À TRANCHER — le nom des symboles : aujourd'hui authoré
  (`name="scant_0"`), non dérivable du fichier (`scant_v2_0.png`). Deux
  options : (i) dériver du nom de fichier (les symboles CHANGENT, les
  équates de liaison `Img_* equ set_*` des unités suivent — un renommage
  mécanique, prouvé par le banc) ; (ii) un attribut `names="scant_%d"`
  (gabarit, les symboles ne bougent pas, preuve par identité).
  Recommandation : **(ii) d'abord** — l'identité reste la preuve — et (i)
  en phase de renommage finale, où il a sa place.

**7b FAIT (12/08), en deux commits.** (A) L'élément `<images>` : expansion
en nœuds `<image>` (tri par préfixe NN, index continus à travers lignes et
exceptions littérales, compteurs de noms par base, un encodeur par décalage
de `shifts=` — cascade `<default name="images.shifts">` = la décision d7/t2
en une ligne par target), `match` par défaut `[0-9]*.png` (les restes d'un
répertoire n'entrent jamais dans une série), erreurs nommées sur préfixe
manquant ou dupliqué, `index="none"` pour les séries adressées par nom dans
un set indexé (la mâchoire du boss — un index inventé grossirait chaque
descripteur de son octet idx, ATTRAPÉ par l'identité avant commit : +38/+4/+3
octets sur trois entrées dobkeratops). 9 tests d'expansion.
(B) **355 fichiers renommés** (autorité : le config v2 pour le porté —
c'est son ordre que l'identité protège — puis les properties d7 pour le
reste ; familles par préfixe de basename, sous-répertoire par famille
plurielle, singletons à plat avec label `NN-<nom>.png`), v1-map.csv suivi,
**17 gfxcomp compactés** (vérifiés par expansion python == déclaration
littérale, au tuple près) et 31 gardés littéraux avec chemins renommés
(numérotations irrégulières, singletons, commentaires authorés) — le config
perd 375 lignes net. `check_variants.py` refait au **hash de contenu**
(les renommages n'ont pas changé un octet) et il VOIT enfin : **14
divergences v1↔v2 préexistantes** détectées (pow sans ses XB0/NB1,
scantfire avec des décalées que la d7 v1 n'a pas…) — l'ancien rapprochement
par chemin les manquait ; consignées, à arbitrer au portage, pas touchées
ici. PREUVE : **63 images identiques à l'octet** (jusqu'au hash exact),
JUnit vert, banc r-type 5/5 sous toje.

**Complément demandé par l'auteur (12/08) : le match exige de renommer les
ressources et de traiter proprement d7/t2.** L'étude de la référence v1
(properties de game-mode et d7/t2) et la proposition d'organisation —
un répertoire = une série homogène, noms `NN[-label].png` (l'ordre est le
nom, assigné depuis l'ordre des properties d7 : l'inversion rship est
absorbée par le renommage), une ligne `<images>` par série (`mirror=`
re-liste le répertoire, les index continuent), et le profil d'encodage en
défaut de target (`images.profile` : `B0` en fd, `B0,B1` en t2 — les
déclarations d'objets deviennent identiques entre targets, vocabulaire de
variantes v1 conservé) — vivent dans
[`analyse-images-7b-2026-08.md`](analyse-images-7b-2026-08.md), avec la
table de renommage committée, la mise à jour de v1-map.csv et de
check_variants, et trois points ouverts (étendue du renommage, défaut de
`names=`, profil des tuiles). EN ATTENTE DE VALIDATION.

*Preuve 7b : réécrire les 52 gfxcomp du config en forme compacte, 59+4
images identiques à l'octet (option ii). Le banc : le config perd ~500
lignes, le bloc d'un ennemi tient en ~8 lignes.*

### 7c — leanscroll + crop orchestrés — FAIT (13/08)

Réalisé comme spécifié : élément `<leanscroll>` (module en JVM, cache sur
l'image + les paramètres, `crop_stage.py` absorbé — fenêtre, renumérotation,
strips even/odd, cartes 16 bits colonne-major, géométrie en équates
`map.COLS`/`map.ROWS`), rejoué par la passe de placement (les tuiles qu'une
collection mesure sont tranchées dans ses sorties). Les stages 01 et 02 sont
câblés dessus ; `crop_stage.py`, `leanscroll-01.txt`, les `intro/` et les
plans committés `0/`,`1/` des deux stages câblés sont supprimés (les stages
03-08 gardent leurs plans committés en attendant leur câblage — candidats de
la passe 9). La palette du stage 2 (`png2pal`) lit le strip généré.

PREUVE en trois étages : (1) reproduction — les strips régénérés sont
identiques AU PIXEL aux committés sur les deux stages, les cartes du stage 2
identiques À L'OCTET ; (2) l'écart résiduel est mesuré, RENDU À L'AUTEUR en
image, et adjugé — les cartes du stage 1 différaient de **6 octets**
(3 cellules × 2 plans, col 48 lignes 6-8) : le rendu de la zone a montré que
l'image source n'y porte RIEN de distinctif (fond, bords et cellules
divergentes sont le même index de palette), ce qui excluait un marqueur
d'art et désignait une retouche directe de la carte générée — confirmé par
l'auteur : **une modification nécessaire au checkpoint** (la bande centrale
n'est pas reconstruite par le scroll depuis ses blocs de début de stage ;
le checkpoint repeint depuis la carte, ces cellules doivent rester
dessinées). La retouche devient une donnée DÉCLARÉE : attribut
`refresh="48:6-8"` sur `<leanscroll>` (cellules liées à la première tuile
du set). Cas au recueil :
[`checkpoint-refresh-cells.md`](../en/migration/checkpoint-refresh-cells.md)
— avec sa règle générale : un résidu inexpliqué entre un généré committé et
sa régénération peut être une décision d'auteur non déclarée, à faire
remonter avant d'adopter l'un ou l'autre ; (3) **identité TOTALE : les 63
images du corpus sont identiques à l'octet à la référence d'avant 7c** —
la chaîne entière reproduit les octets livrés, retouche comprise — JUnit
vert, reproductibilité avec le chemin du CACHE exercé, rebuild propre sans
les intermédiaires supprimés au même hash exact (l'image r-type est
byte-identique à celle déjà validée 5/5 au banc).

Deux pièges attrapés en route : `drawImage` vers une image indexée REMAPPE
les couleurs par proximité (les deux magentas fusionnaient, chaque index
glissait — débordements d'octets dans les tuiles compilées ; remplacé par
une copie de raster brute) ; et un cache qui survit à un correctif du code
ressert les sorties corrompues — la version de cache se bumpe avec le code.

*Spec d'origine :*

État : la chaîne carte est la DERNIÈRE où le build dépend d'un geste hors
builder — `tools/leanscroll-NN.txt` (invocations manuelles, chemins Windows
pointant le repo v1) puis `crop_stage.py` (adaptation de format + géométrie),
sorties committées. Les entrées (`in.png`, `init.png`) sont déjà dans v2.
leanscroll est déjà un module Maven v2.

Proposition : un élément `<leanscroll>` producteur, déclaré là où ses
sorties sont consommées (le `<file>` des tuiles), invoquant le module en
JVM comme les convertisseurs, avec cache (mêmes entrées → pas de re-calcul,
comme gfxcomp) :

```xml
<leanscroll image="src/stages/01/map/in.png" lean="src/stages/01/map/init.png"
            tile="12x12" gendir="gen/stages/01/map"/>
```

émettant `even.png/even.bin/odd.png/odd.bin` sous `gendir`, consommés par
le `<image grid>` et le `<tilemap>` du même config ; la géométrie
(`map_width`…) émise en équates par le builder (gensymbols de l'élément —
`map.const.asm` disparaît). `crop_stage.py` et les `.txt` sont supprimés ;
les sorties committées quittent `src/` (décision du 02/08 à REVOIR avec
l'auteur : elle datait d'avant l'orchestration).

*Preuve 7c : les .bin/.png régénérés identiques aux committés (leanscroll
est déterministe), puis 63 images identiques, banc r-type 5/5 et
tilescroll sous toje.*

### Ce qui reste dans tools/ après 7 (le critère de fin, réactualisé)

`arcade_to_in.py`, `sync_waves.py` (extraction arcade — contenu),
`check_variants.py` (garde-fou de migration v1, vit tant que le portage des
ennemis n'est pas fini), `fade_preview.html`, `remap_font_colors.py`
(prévisualisation/contenu), `gen_enemy_unit.py` — à trancher : son moule XML
fond avec 7b, son moule asm est l'affaire du dev (doctrine 5-objets) ;
proposition : le retirer quand 7b sera là, le préambule restant documenté
dans le manuel.

**Ordre proposé : 7b (volume, preuve par identité) → 7c (chaîne, preuve par
régénération + bancs) → 7a (décision + manuel).** Chaque pas validé par
l'auteur avant implémentation.

## Phase 8 — La campagne loader (une seule, à la fin)

Tout ce qui touche le binaire du loader, groupé pour une seule revalidation
complète : retrait de la marche de destination %10/%11 (morte depuis les
arènes — la dérivation d'ids par flags RESTE), dépoussiérage des
commentaires $ff00/éviction, et ce que les phases précédentes auront mis en
attente côté runtime. Les 12+ images changent une dernière fois.

*Preuve : loader-ut complet sous toje (chemins link compris), échanges de
disquettes, banc r-type, mplus/tlsf/sound — la totale.*

### Phase 8 — spécification détaillée (13/08, à valider)

**Mesure préalable (faite le 13/08, sur les tables générées du corpus).**
Les 24 tables de scènes émises par les 15 configs contiennent exactement
4 blocs séquentiels, TOUS export-only à la pseudo-destination (0,0) :

| Scène | Type | Fichiers |
|---|---|---|
| r-type `scenes.boot` | %10 | 1 (`engine.sound.ym.const` — un singleton ne chaîne pas) |
| sound `title` (TO8) | %11 | 2 (`ym.const` + suivant) |
| loader-ut `stress-iface` | %11 | 6 |
| loader-ut `stress-pad` | %11 | 16 |

Deux conséquences. D'abord la confirmation de l'analyse placement §
« mort en pratique » : toute l'arithmétique de la marche (lecture de
taille, test $ff00, accumulation, franchissement de page) tourne pour
produire (0,0) constant — plus aucune table manuscrite n'existe, plus
aucun empilage de données ne subsiste (les arènes les ont résorbés).
Ensuite, et c'est la bonne surprise : **les DEUX chemins sont déjà
exercés par les bancs verts** — le banc r-type 5/5 passe par le %10 du
boot à chaque exécution, loader-ut T12/T14 par les %11 (la croissance
d'index de stress-pad EST un bloc %11 de 16). Aucun test à inventer
pour couvrir le retrait.

**Pas A — préparation, prouvée par identité (le binaire ne bouge pas).**

1. *Verrou builder.* `SceneGenerator` refuse un bloc séquentiel
   contenant un fichier NON vide (erreur nommant le fichier et la
   scène). C'est le contrat sur lequel le pas B s'appuie — après lui,
   « séquentiel = export-only » n'est plus une convention du générateur
   mais une propriété vérifiée à chaque build. Le corpus le satisfait
   déjà (mesure ci-dessus) : preuve par le build lui-même, plus un test
   JUnit qui provoque l'erreur et la lit.
2. *Trois `sizeof{}` d'une autre struct corrigés* — la dette « même
   taille aujourd'hui, fragile » consignée depuis juillet :
   `extern16.link` avance de `sizeof{linkData.content.extern8}`
   (loader.asm:1464), `symbol.search` avance deux fois de
   `sizeof{linkData.content.intern}` (:1582, :1601). Mêmes valeurs
   numériques, binaire identique — c'est ce qui rend le correctif
   prouvable par identité, et c'est maintenant qu'il faut le passer,
   avant qu'une struct ne bouge un jour.
3. *Dépoussiérage des commentaires.* L'éviction par destination a été
   retirée (9c176a3, remplacée par le rapport d'occupation — « the
   scene that ENDS declares what it drops ») mais des commentaires la
   racontent encore au présent : `examples/loader-ut/to8.config.xml:11`
   (« is what makes the loader's implicit unload evict… »), le récit
   T8 de `main.asm`, et les justifications $ff00 du loader qui motivent
   l'exemption d'un mécanisme disparu. Inventaire exhaustif à
   l'implémentation ; règle de tri : ce qui décrit le comportement
   ACTUEL reste, ce qui est de l'histoire va au README de loader-ut
   (qui la raconte déjà) ou tombe. Les commentaires ne changent pas un
   octet assemblé.

*Preuve pas A : 63 images identiques à l'octet, JUnit (dont le nouveau
test du verrou, cassé et lu).*

*RÉALISÉ (13/08, décisions auteur : pas de piège loader, rien d'autre à
embarquer).* Deux trouvailles à l'implémentation :
1. **Le verrou existait déjà** — `SceneChecks` (cas `EXPORT_ONLY`) refuse
   depuis la phase B des scènes déclaratives un load sans destination qui
   porte des données, tailles connues, et son test JUnit
   (`exportOnlyCoherence`) le casse et le lit. Le pas A s'est réduit à
   reformuler le message (il conseillait « make it export-only » à un load
   qui l'était déjà) et à documenter en commentaire que ce contrôle est ce
   qui autorise les handlers séquentiels à ne rien placer.
2. **Le dépoussiérage débordait des commentaires du loader** : deux docs
   NORMATIVES racontaient l'éviction au présent (`scenes.md` § The model
   in one rule, `groups.md` — règle cœur, table du cycle de vie, deux
   puces), plus la ligne T8 du README loader-ut (« implicit unload » alors
   que le test est devenu l'unload explicite) et le commentaire de layout
   de son config. Tous réécrits sur le modèle actuel (piège LOAD_OVERLAP,
   « la scène qui finit déclare ce qu'elle lâche », recouvrement partiel
   détecté même-disque, exemption des fichiers vides devenue « n'occupent
   aucun octet ») ; les récits au passé (T5, liste des bugs) restent.
Les trois `sizeof{}` corrigés (extern16:1464, symbol.search:1582/1601).
Preuve rendue : **63 images identiques à l'octet**, JUnit 84/84.

**Pas B — la marche tombe (le binaire du loader change ; la totale).**

Le FORMAT de scène ne change pas — triplets %01, liste %10, bloc %11 de
7 octets, repli silencieux %11→%10 du générateur : les tables restent
identiques à l'octet. Seuls les handlers changent :

- `loader.scene.apply.type10` : la destination devient constante (le
  page/adresse du bloc, passé tel quel à chaque appel). Tombent : le
  `dir.getFile` par fichier (il ne servait qu'à lire la taille), la
  lecture de taille 14 bits, le test $ff00, l'accumulation
  `leau size,u`, le franchissement de page (`CART_END`/`CART_START`,
  `incb`, garde 15/31, `bra *` plein) et le commentaire V2-FIX MO6 qui
  n'annotait que cette marche. Le handler devient un %01 à destination
  partagée.
- `loader.scene.apply.type11` : mêmes retraits ; RESTENT le
  `dir.getFile` par fichier et la dérivation d'id par les flags
  (`+1 +compressed +linked`, l'`abx`) — le cœur du %11.
- Ce qui ne bouge pas ailleurs : la convention $ff00 partout où elle
  est vivante (`fileSize`, `loadByPtr`, l'indexation des link data), le
  choix %01/%10/%11 côté générateur.
- `map.ram.CART_START`/`CART_END` et `boot.CHECK_MEMORY_EXT` perdent
  leurs seuls consommateurs DANS loader.asm (vérifié : lignes
  409-479 uniquement) ; les équates restent — elles appartiennent à la
  carte machine (`map.const.asm`), seules les références de la marche
  tombent.

Bilan attendu : ~50 lignes en moins, et la dernière décision de
placement prise à l'exécution disparaît — l'auteur déclare, le builder
mesure et place, le runtime ne place rien. Le gain est la simplicité,
pas les octets (le loader a de la marge depuis l'INDEX au secteur 4).

*Preuve pas B — la totale, payée une fois :*
- toutes les images portant le loader changent (annoncé ; seule
  `to8-disk1.fd` de loader-ut, sans loader, reste identique — à
  vérifier au build) ; reproductibilité : deux corpus consécutifs
  identiques ; hashes de référence réenregistrés ;
- JUnit complet ;
- la lane toje entière : loader-ut 17/17 + `$0D` + T18 `$8301`
  échanges de disquettes compris (exerce les %11), banc r-type 5/5
  (exerce le %10 du boot), collection 4/4, objects 18/18, sprites,
  tilescroll, hscroll, sound TO8 (mainLoop + data.page=$66 + bascule
  title→level1), mplus-test + mplus-pcm (séquences), tlsf-ut ;
- MO6 : au build, sur la foi du jumeau TO8 (même binaire de loader,
  même générateur de tables).

*RÉALISÉ (13/08).* Conforme à la spec : destination constante dans les
deux handlers, `dir.getFile` conservé dans le seul %11 (dérivation d'ids
par flags), format de scène inchangé — **les 24 tables générées sont
identiques à l'octet** (aucun diff sur les `.table.asm`), les références
`CART_START`/`CART_END`/`CHECK_MEMORY_EXT` sont tombées à zéro dans
loader.asm (les équates restent à la carte machine). Preuve rendue :
**62 images changent, `to8-disk1.fd` (sans loader) identique à l'octet**
— exactement l'annonce ; reproductibilité (2 corpus consécutifs
identiques) ; et la lane toje entière : loader-ut 17/17 `$0D` +
T18 `$8301` avec échanges de disquettes, r-type 5/5, collection 4/4,
objects 18/18 `$0D`, sprites 7/7 tête de liste stable, tilescroll
caméra + terrain 3/3, hscroll aligné k=−13 sur le témoin de référence,
tlsf-ut 10 000 trames de stress aléatoire sans piège, stacked-overflow
10 marqueurs justes à cheval sur deux pages, sound TO8 (title joué,
bascule à chaud vers level1 prouvée dans les deux flux, player intact),
mplus-test séquence d'écrans **identique pré/post aux mêmes créneaux**,
mplus-pcm boucle principale vivante. Les hashes de référence sont
réenregistrés.

Deux leçons de banc, payées pendant la revalidation : une image
d'exemple ne s'appelle pas toujours `to8.fd` (le banc stacked a d'abord
« échoué » sur un émulateur démarré SANS disquette — écran « No Disk »,
tout à zéro ; le hash de l'écran No Disk, `030f4c…`, est désormais
reconnaissable) ; et un build de contre-épreuve doit être vérifié
`exit=0` avant de croire sa sonde (deux faux échecs successifs :
`-Dbasedir` manquant, puis `<hfe/>` sans hxcfe Linux — le script corpus
retire ces sorties, un build manuel doit faire pareil).

**La phase 8 est close.** Reste la phase 9 (code mort prouvé, puis
passe documentaire).

**Décisions jointes (rien à coder — consignées pour ne pas y revenir).**

- *L'étage load-time de `symbole$PAGE`* (analyse placement §25) : NON
  RETENU. Aucun consommateur mesuré — le fluide est toujours placé,
  donc toujours cuisible ; la forme liée reste `externPg` sur id de
  fichier. Rouvrir sur besoin réel uniquement.
- *Les différés loader du TODO* (suivi des tailles / recouvrement
  partiel, paginated groups, `unloadAll`) : restent différés, besoin
  réel.
- *`loader.CHECK_UNRESOLVED_SYMBOLS`* : reste opt-in — incompatible
  avec les références en avant (consigné depuis M2), inchangé.

**Questions ouvertes à l'auteur.**

1. Le verrou du pas A (builder) suffit-il, ou veux-tu AUSSI un piège
   loader (fichier non vide rencontré dans un bloc séquentiel →
   `bra *`) ? Recommandation : builder seul. Dans le %10 le piège
   réintroduirait exactement ce qu'on retire (le `dir.getFile` + test
   de taille par fichier) ; dans le %11 il serait presque gratuit
   (`dir.getFile` déjà là) mais asymétrique. Le générateur étant le
   seul émetteur de tables depuis la phase C de 2026-07, le verrou
   builder couvre tout ce qui peut atteindre le loader.
2. Autre chose à embarquer dans ce dernier changement du binaire
   loader ? La revalidation complète est payée une fois ; mon
   inventaire (défauts annexes de juillet, différés, files d'attente
   des phases 3-7) ne trouve rien d'autre de mûr — les trois
   `sizeof{}` passent au pas A précisément parce qu'ils n'ont pas
   besoin d'attendre le pas B.

## Phase 9 — La passe finale : code mort, puis documentation

**Le contrôle du code mort d'abord** (demande d'auteur, 11/08). La campagne
a été additive par principe (principe 3) : chaque mécanisme a cohabité avec
celui qu'il remplaçait. En fin de course, on passe une fois sur tout ce que
plus personne n'utilise, en le PROUVANT plutôt qu'en le supposant — pour
chaque candidat, l'absence de consommateur est mesurée avant le retrait, et
le retrait est prouvé par identité binaire. Candidats déjà identifiés :

- `<objectindex>` et son plugin, si 5e ne l'a pas déjà retiré ;
- la publication `.address` et `.size` du layout — **zéro consommateur
  mesuré** (§27), seul `.page` sert ;
- `ImageSets.PageOf` et son câblage, la branche à deux formes de
  `ImageSet.pageSymbol` — morts avec 5b ;
- `<pageset>` et ce qui n'en sert plus — mort avec 5c ;
- les restes des mécanismes retirés en cours de route (comptage nu,
  `interface=`, forme par-load) : vérifier qu'aucune souche ne traîne.

*Preuve : identité binaire à chaque retrait, JUnit, et la méthode standard
en clôture. Un candidat dont l'absence de consommateur n'est pas mesurable
n'est pas retiré — il est consigné.*

**Puis la documentation.** Le manuel cible et le workflow perdent leur
bandeau « modèle en
discussion » et sont rehomés en normatif ; la version anglaise
(`docs/lang/en/`) est refaite en une passe (règle du dépôt) ; les documents
d'étude de la campagne (`analyse-placement`, esquisses) sont fermés avec
leurs variantes rejetées — c'est leur rôle ; `CLAUDE.md` et `TODO.md` sont
réalignés.

### Phase 9 — spécification détaillée (13/08, à valider)

**Périmètre et ordre.** Deux passes, dans cet ordre : le code mort d'abord
(le code doit être dans son état final avant que la doc le décrive), la
documentation ensuite. Restent HORS phase 9 : le renommage de l'engine ASM
(`docs/engine-naming.csv` — phase finale post-jeux, inchangé) et la version
FRANÇAISE du recueil de cas (liée à la fin de la migration v1, pas à la
campagne).

#### Passe 1 — le code mort, candidat par candidat

Méthode par candidat : mesurer les consommateurs (grep + build), retirer,
prouver par **identité 63/63 + JUnit**. Un retrait qui bouge une image se
requalifie en changement de comportement et SORT de la passe. Un candidat
dont l'absence de consommateur n'est pas mesurable n'est pas retiré — il
est consigné.

État des candidats, re-mesuré le 13/08 (la liste d'origine avait vieilli) :

1. **Déjà tombés en route — rien à faire, consigné** (vérifié par grep) :
   `<objectindex>` et son plugin (5e), `ImageSets.PageOf` et la branche à
   deux formes de `pageSymbol` (5b), `interface=` et le comptage nu
   (arbitrage), `PageSetPlugin` (5c), `stacked=` (modèle zones).
2. **Publication des équates de layout — le seul vrai retrait Java.** La
   mesure d'origine (§27 : « `.address`/`.size` zéro consommateur ») est
   PÉRIMÉE pour `.address` : `stage1.address` sert de
   `loader.DEFAULT_SCENE_EXEC_ADDR` dans r-type, `samples.address` est lu
   par mplus — `.address` RESTE. `.size` : zéro consommateur au grep frais
   → retirer l'émission. `.pages`/`.page.last` : à mesurer à
   l'implémentation, même règle. Le §27 est corrigé au passage (une mesure
   citée doit porter sa date).
3. **Le registre `PageSets` n'est PAS mort** — il porte les membres coupés
   du packer vers scène/répertoire/collection ; seul son NOM est un
   vestige du `<pageset>` disparu. À l'implémentation : mesurer son
   recouvrement avec le registre `Cuts` (né en 5c) — s'ils se recouvrent,
   fusion ; sinon renommage au vocabulaire de la collection (les deux
   prouvables par identité, c'est du Java interne).
4. **Les orphelins du dépôt** (les « Dettes » de CLAUDE.md rejoignent la
   passe — c'est la même passe) : `data.asm` et `mub.o` à la racine,
   `engine/system/mo6/graphics/gfx.memset..asm` (double point, orphelin),
   `examples/timing/` + `docs/lang/fr/timing.md` (API `wait.*`
   inexistante — supprimer, le besoin réel vit déjà dans l'état des lieux
   de CLAUDE.md). `engine/pack/mub.asm` (chemins d'INCLUDE invalides) :
   NON retiré — c'est du MUCOM88 « écrit non branché », pas du mort ;
   consigné tel quel.
5. **Souches des mécanismes retirés** : grep de clôture sur les mots des
   mécanismes disparus (éviction/`findByDest`, `stacked`, budget=membres,
   `pages="auto"`, `range=` gfxcomp, `member()`) — le grep doit rendre
   ZÉRO occurrence hors historique daté.
6. **La forme par-load** (destination portée par le `<load>`) n'est pas
   une souche : conservée À DESSEIN, loader-ut en est le gardien désigné
   (elle exerce le chemin %01 du loader avec destinations explicites).
   À STATUER (question 1 ci-dessous) : l'acter comme forme de test
   permanente, ou exécuter 4c (retrait + migration de loader-ut).

*Preuve passe 1 : identité 63/63 à chaque retrait, JUnit ; grep de clôture
du point 5 archivé dans le commit.*

#### Passe 2 — la documentation

1. **Le modèle cible devient LE modèle.** `manuel-cible-2026-08.md` et
   `manuel-cible-workflow-2026-08.md` perdent leur bandeau « brouillon
   d'étude … DISCUSSION » ; leur contenu normatif passe dans le manuel
   anglais (la règle du dépôt : `docs/lang/en/*.md` décrit le modèle v2
   pour qui n'a jamais vu ni la v1 ni la campagne), et les deux fichiers
   français sont fermés en études (statut + renvoi vers le manuel).
2. **La passe anglaise** couvre les fichiers du MODÈLE : `scenes.md`
   (zones/arènes/places attitrées/collections — déjà partiellement à
   jour), `symbols.md`, `tilemaps.md`, `sprites.md`, `objects.md`,
   `groups.md`, `config.md`, `project-setup.md`/`project-build.md`,
   `readme.md`/`toc.md`. Les pages outillage (`toolbox.md`,
   `file-format-stm.md`, `unpack-tools.md`…) ne sont reprises que si
   elles sont FAUSSES. Critère de fin : un grep de `pageset|interface=|
   stacked|évict` sur `docs/lang/en/` ne rend que de l'historique daté.
3. **Les études de la campagne sont fermées, variantes rejetées
   CONSERVÉES** (c'est le rôle du tiers) : `analyse-placement` (statut
   « rien d'implémenté » → clos + renvoi), `analyse-reste-cible`,
   `analyse-multipage` (la note datée du § « membre non rempli », dérive
   déjà consignée), `analyse-frontiere-stage`, `modele-zones`,
   `scenes-declaratives`. Chaque en-tête `statut:` redevient VRAI.
4. **CLAUDE.md réaligné** : les sections périmées mesurées aujourd'hui —
   « Plugins de conversion … ServiceLoader » (contredit par le retrait du
   mécanisme, raconté 200 lignes plus bas), « État de validation au
   30/07 » (8 configs → 15, corpus 63 images, lane toje headless),
   la ligne sprites « un set trop gros se déclare en `<pageset>` », la
   section loader « cycle de vie incomplet » (l'éviction implicite y est
   racontée comme actuelle ; le pas B n'y est pas), les Dettes purgées
   par la passe 1, `rom t2` (décision : porter ou retirer de la doc —
   question 3). TODO.md : la campagne fermée, les reliquats reversés aux
   bonnes sections.
5. **Liens** : les 4 liens vides du `readme.md` racine, le renvoi
   `docs/lang/fr/readme.md` inexistant.

*Preuve passe 2 : les docs ne touchent pas les images — la preuve est la
COHÉRENCE : greps de clôture (point 2), liens résolus (un script one-shot
suffit), statuts d'en-tête tous vrais, et l'identité 63/63 en clôture de
phase (rien d'autre que des docs n'a bougé).*

#### Questions ouvertes à l'auteur

1. **La forme par-load** — recommandation INVERSÉE après re-mesure
   (13/08, question de l'auteur : « le test mérite-t-il de vivre ? »).
   Le relevé exhaustif des 19 destinations par-load de loader-ut montre
   que **chaque fichier n'a qu'UNE destination à travers toutes les
   scènes** — y compris T18 : la provocation charge `bb` à sa propre
   place habituelle (`marker.b`, où `cc` se trouve alors) ; bb/cc et
   dd/ee sont des ALTERNATIVES à une place partagée, forme que le modèle
   cible autorise déjà. La première justification du gardien (« même
   fichier, deux destinations, inexprimable en place attitrée ») était
   un artefact de mesure — consigné ici pour la méthode. Conséquences :
   T18 se garde TEL QUEL (c'est le « casse le garde-fou » du piège
   LOAD_OVERLAP, la seule protection contre une erreur que le builder ne
   peut pas voir — il ne connaît pas l'ordre des scènes) et **4c devient
   bon marché** : migrer loader-ut vers les places attitrées (les
   destinations ne bougent pas → tables générées identiques à l'octet,
   preuve par identité), puis retirer les branches par-load de
   ScenePlugin, la spec et le XSD. Recommandation : exécuter 4c dans la
   passe 1, le test vit.
2. **`PageSets`/`Cuts`** : d'accord pour fusionner ou renommer ces
   registres Java internes si la mesure montre le recouvrement (prouvé
   par identité) ?
3. **`rom t2`** : aucun média cartouche n'existe dans le registre v2 —
   retirer la mention de la doc (recommandé, le portage ROM restant au
   backlog), ou le laisser annoncé ?
4. **`examples/timing` + `timing.md`** : supprimer (l'API `wait.*`
   n'existe pas — recommandé, la trace du besoin reste dans l'état des
   lieux), ou garder comme spécification d'une API à venir ?

## Ce que le plan ne couvre pas, à dessein

Le portage des ennemis et des game modes continue EN PARALLÈLE des phases
0-3 (elles sont additives) ; il marque une pause pendant 4-5 (bascule de
syntaxe) — à caler avec l'auteur. Les non-features actées restent actées :
pas de place-par-usage (§21), pas de flux inter-pages (§9), pas de DSL
(§16). Les numéros d'index face à l'état persistant (faille 7) restent une
règle d'écriture, pas un mécanisme.

## La carte des dépendances

```
0 (mort) ──────────────────────────────┐
1 (index) ── 2 (membres dérivés) ── 4 (place attitrée) ── 5 (fluide) ── 6 (média)
        └── 3 (bake défaut) ─────────┘                                └─ 8 (loader)
7 (contrats générés) : après 1, affiné jusqu'à la fin          9 (docs) : dernière
```

Les phases 1 et 3 sont le cœur du retour sur investissement (la glue
quotidienne et le pool de liens) ; 4 et 5 sont le cœur du modèle ; 6 et 8
sont de la consolidation. Si la campagne devait s'interrompre, chaque
frontière de phase est un état stable et documenté.
