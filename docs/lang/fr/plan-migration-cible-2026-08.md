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
- **5c — le flux par élément, sur tout fichier.** Retire `<pageset>` du
  vocabulaire. Spec détaillée ci-dessous, EN ATTENTE DE VALIDATION.
- **5d — `<unit>` sur son vrai rôle.** Fiche réécrite (grouper pour la
  continuité), refus dans la forme arène levé, cas composite documenté.
  À spécifier après 5c.

- **5e — retrait de `<objectindex>`.** Son unique consommateur est parti le
  11/08 (les tables d'objets sont manuscrites) : l'élément, son plugin et
  ses specs n'ont plus personne. Retrait mécanique, prouvé par identité.

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

### 5c — spécification détaillée (à valider)

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

*Preuve attendue (option ii)* : 59 images identiques à l'octet — les quatre
pagesets deviennent des fichiers de même contenu, même ordre, même découpe —
JUnit, et le banc r-type 5/5 par sécurité, le vocabulaire changeant même si
le placement ne change pas.

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

## Phase 8 — La campagne loader (une seule, à la fin)

Tout ce qui touche le binaire du loader, groupé pour une seule revalidation
complète : retrait de la marche de destination %10/%11 (morte depuis les
arènes — la dérivation d'ids par flags RESTE), dépoussiérage des
commentaires $ff00/éviction, et ce que les phases précédentes auront mis en
attente côté runtime. Les 12+ images changent une dernière fois.

*Preuve : loader-ut complet sous toje (chemins link compris), échanges de
disquettes, banc r-type, mplus/tlsf/sound — la totale.*

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
