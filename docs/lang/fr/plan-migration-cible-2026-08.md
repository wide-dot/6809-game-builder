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

## Phase 3 — Bake par défaut, link dérivé

Le renversement du §12/§23, en trois pas :

3a. **Le link dérivé de la multiplicité** : un nom à fournisseur unique se
    cuit, un nom multi-fournisseurs à places différentes se résout au
    chargement — l'aiguillage remplace le refus d'élection. Le rapport
    « résolu au chargement, avec cause » naît ici ; `interface="true"` et
    l'heuristique « même destination = alternatives » deviennent des
    conséquences, plus des déclarations.
3b. **`bake="auto"` partout** dans le corpus (mécanique : l'attribut est
    déjà posé sur r-type) — les configs d'exemples migrent une à une, chaque
    migration validée par exécution (les images changent : la donnée de
    liaison fond).
3c. **Le défaut passe de NONE à AUTO** ; l'attribut devient l'exception
    (`link` explicite pour forcer, cas rares de bancs).

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
4b. **Migration du corpus** : les 12 configs d'exemples puis r-type, région
    par région — une région devient soit une place explicite partagée par
    des alternatives, soit rien (la place attitrée suffit). Réécriture
    mécanique, un projet par commit.
4c. **Retrait de `<region>`** quand plus rien ne l'utilise.

*Preuve : 4a est additif (configs inchangées = images inchangées) ; chaque
migration 4b vise l'IDENTITÉ D'EXÉCUTION (bancs toje verts, RAM vérifiée)
plutôt que l'identité binaire — les places bougent, le comportement non.
4c par identité binaire.*

## Phase 5 — Les collections fluides (la coupe par les creux)

Le placement en deux temps (§15) : rigide posé, fluide coulé, morceaux
taillés par les creux, seuil de creux avec ses deux plateaux au rapport. Le
`<pageset>` se dissout dans la contribution (§23) : un fichier `index=` à
contenu divisible EST la collection ; `<block>` devient un fichier ordinaire
que l'écoulement contourne.

*Preuve : r-type re-rangé — attendu mesurable : moins de morceaux que de
membres actuels (2 au lieu de 5 sur l'exemple des tuiles), pages rendues
visibles au rapport, banc 5/5, niveau 1 entier traversé sous toje.*

## Phase 6 — Le média dérivé des scènes

L'ordre disquette par première utilisation (le builder trie `cwrite` par
scène au lieu de l'ordre de déclaration), le rapport de seeks par scène
(le journal de `FdUtil` existe), et le mot `codec` qui devient silence
(défaut compressé, repli brut déjà en place).

*Preuve : les images changent (ordre des secteurs) — chargements vérifiés
sous toje, le rapport doit montrer ZÉRO retour de tête pour une scène dont
les fichiers ne sont pas partagés.*

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

## Phase 9 — La passe documentaire finale

Le manuel cible et le workflow perdent leur bandeau « modèle en
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
