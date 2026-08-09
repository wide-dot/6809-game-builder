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

## Phase 0 — Les retraits sans risque (courte)

Le code mort du §5 de l'analyse : souches de `LayoutResolver` (`taken`/
`occupy`, `autoPages`/`sparepages`, `autoPage`), la tuyauterie
`pages="auto"` (Regions.pagesUsed/measuredPages + voyage dans Target),
`PageSetPlugin.member()`, `range=` de gfxcomp. Corrections doc associées
(`scenes.md` documente encore `pages="auto"`).

*Preuve : 12 configs identiques à l'octet. Aucun risque, aucun préalable.*

## Phase 1 — L'émetteur d'index et les contributions (la valeur immédiate)

La pièce qui rembourse tout de suite : le service en trois étages (§16 —
résolution `StaticLink` existante, conventions, deux gabarits standards) et
la déclaration inversée (§23) : `<index name="…">` hébergé nu dans un
fichier, attribut `index="…"` de contribution sur les fichiers, instances
par composition pour les alternatives, équates de numéros émises comme
`entries.asm`.

Introduit **en plus** de l'existant : les configs actuelles ne bougent pas,
r-type bascule seul. `gen_objid.py` est remplacé, puis supprimé.

*Preuve : la sortie de l'émetteur est comparée **byte à byte** aux
`objid.const.asm`/`objid.index.asm` committés (le banc est tout trouvé),
puis le banc r-type 5/5 sous toje. 12 configs inchangées.*

*Étend, dans la foulée : les tables d'animation (même gabarit parallèle),
et l'imageset délégué au même service de résolution — sans toucher son
format runtime (§16, option C).*

## Phase 2 — Membres de pageset dérivés du rangement (l'héritage v1 tombe)

Le sujet d'origine : `DirectoryPlugin` mesure et range au moment de la
réservation (§4, option B), le nombre de membres devient le résultat du
rangement, les membres vides disparaissent, l'adresse de membre est lue de
la **zone** (plus du scalaire `region.address`). L'assertion
réservés == émis reste le garde-fou.

*Preuve : les images CHANGENT (répertoire plus court, ids décalés, tables de
scènes raccourcies) — méthode standard complète, banc r-type 5/5 (c'est lui
qui exerce les alternatives à comptes différents : stage1 = 5 membres,
stage2 = 4).*

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
