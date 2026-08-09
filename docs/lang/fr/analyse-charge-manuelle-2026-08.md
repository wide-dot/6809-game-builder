---
date: 2026-08-09
sujet: Inventaire de ce que r-type construit encore à la main autour du builder
  v2 — scripts de glue, tables écrites au clavier, répétitions de config — et
  ce que le modèle cible en absorbe.
statut: analyse, rien d'implémenté
s'appuie sur: analyse-placement-2026-08.md (le modèle cible, §12-§23)
---

# La charge manuelle de r-type : ce que le builder ne fait pas encore

Méthode : relevé exhaustif dans `games/r-type/` — les scripts de `tools/`,
les fichiers marqués « généré par … ne pas éditer », les tables écrites à la
main, les répétitions du config. Chaque poste est chiffré, puis mis en face
de ce que le modèle cible couvre déjà ou pas.

## 1. L'inventaire, par nature

### A. Générés par des scripts Python HORS builder (sorties committées)

| quoi | script | volume | déclencheur de régénération |
|---|---|---|---|
| `objid.const.asm` + `objid.index.asm` par stage (équates `ObjID_*` + tables parallèles Obj/Ani/Img) | `gen_objid.py` | 249 lignes (stage 1), ×2 stages | **chaque** modification de wave ou du cast — à la main, à ne pas oublier |
| unité hôte d'un ennemi + bloc XML à coller | `gen_enemy_unit.py` | ~40 lignes asm + ~30 lignes XML par ennemi | chaque portage d'ennemi |
| `map.const.asm` par section (géométrie) | `crop_stage.py` | ~10 lignes ×4 | changement de découpe de niveau |
| tilesets + cartes leanscroll | invocations dans `tools/leanscroll-NN.txt`, sorties committées | 2 stages | changement d'art de niveau — la chaîne n'est pas orchestrée par le builder |
| resynchronisation des waves sur l'extraction arcade | `sync_waves.py` | — | avancée de l'extraction (charge de CONTENU, pas de builder — reste) |

Le motif commun : **le builder possède déjà toutes les informations que ces
scripts recalculent** (les placements, les exports, les pages), mais elles ne
sortent que par `gensymbols` — les scripts relisent les équates et
reconstruisent le reste. Chaque script est un morceau du pipeline v1
(`.properties` → `.glb`) recréé à la main, exactement ce que le point 7 de la
roadmap appelle « le pipeline builder jeu ».

### B. Écrits à la main, de nature générable

| quoi | volume | remarque |
|---|---|---|
| `api.asm` — l'interface moteur↔stage, EXPORT ou EXTERNAL selon `ENGINE_RESIDENT` | 320 lignes | la liste des 41+ labels est maintenue au clavier ; le builder connaît pourtant chaque export du moteur |
| `stage-tables.asm` — les EXTERNAL des 5 tables côté moteur | 28 lignes | le pendant consommateur du même contrat |
| le préambule rituel de chaque unité paginée (INCLUDE api, `Obj_Index_* EXTERNAL`, SECTION, includes de constantes) | ~30 lignes × 12 ennemis | identique à 90 %, écrit 12 fois — c'est ce que `gen_enemy_unit.py` émet, preuve qu'il est mécanique |
| les blocs `<image index="N">` + `<encoder>` du config | 52 `<gfxcomp>`, jusqu'à 24 lignes de `<image>` par ennemi | la liste des frames et leurs variantes existait déjà dans le `.properties` v1 ; elle est retraduite bloc par bloc |
| `to8.config.xml` dans son ensemble | **2 568 lignes, 76 file/direntry** | le gros du volume est la répétition des blocs ennemis, collés depuis la sortie du script |

### C. Généré par le builder — pour mémoire, le contraste

`entries.asm` (équates de numéros), `gensymbols` de layout, tables de scènes,
index d'imageset, tables de tilemap : là où le builder émet, personne ne
régénère à la main et rien ne s'oublie. La charge est exactement là où il
n'émet PAS.

## 2. La mise en face du modèle cible

| poste | couvert par | reste à concevoir |
|---|---|---|
| `objid.index.asm` (tables Obj/Ani/Img) | **oui** — l'index hébergé + contributions (`index="Obj_Index"`, §23), les instances par stage | rien : c'est LE cas nominal du modèle |
| `objid.const.asm` (équates `ObjID_*`) | **oui** — les numéros d'un index sortent en équates, comme `entries.asm` aujourd'hui | nommage des équates ; stabilité si un état persistant les retient (faille 7) |
| bloc XML par ennemi | **partiellement** — la collection contributrice réduit le bloc à `<file … index="Obj_Index">` + son contenu | une déclaration d'images compacte : la liste des `<image index>`/`<encoder>` un par frame doit pouvoir se dire « ce répertoire, dans cet ordre, cet encodeur » — un manifeste par ennemi plutôt que 24 lignes de config |
| unité hôte + préambule rituel | **non** — c'est de l'asm | un include-pack généré (l'en-tête d'unité paginée), ou assumer le gabarit par script mais VERSÉ dans le builder ; à arbitrer contre la doctrine 1:1 |
| `api.asm` / `stage-tables.asm` | **partiellement** — le bake par défaut ne supprime pas les déclarations EXTERNAL que lwasm exige | le builder connaît tous les exports : il peut émettre les `.external.asm` d'un contrat nommé, comme il émet `entries.asm`. La dérive entre les deux côtés devient impossible — c'est déjà l'argument qui a créé api.asm, un cran plus loin |
| chaîne leanscroll / crop | **par principe** — « un contenu est produit par des modules » (déf. du file, §12) : leanscroll EST un module v2, il n'est juste pas branché | un élément producteur qui invoque leanscroll dans le `<file>`, comme `<vgm2ymm>` ; `crop` absorbé pareil |
| `sync_waves.py` | hors sujet — outil de contenu (l'extraction arcade progresse), pas de la glue builder | rien |

## 3. Lecture et priorités

La charge n'est pas également répartie. Par friction décroissante pour le
développeur :

1. **Les index et leurs équates** (`gen_objid.py`) — la friction est
   QUOTIDIENNE : toute modification de wave ou de cast exige de relancer le
   script, et l'oubli est silencieux jusqu'au runtime. C'est aussi le poste
   le mieux couvert : l'émetteur d'index du modèle cible (§10, §23) le
   remplace terme à terme. Première pièce à construire, et banc de
   validation tout trouvé — produire byte-identique à la sortie du script.
2. **La déclaration d'images par frame** — le plus gros du volume config
   (52 blocs). La collection contributrice en absorbe la moitié ; l'autre
   moitié demande la déclaration compacte (répertoire ordonné + encodeur +
   exceptions). À concevoir avec la migration des ennemis restants, qui la
   testera 60 fois.
3. **Les contrats d'interface générés** (`api.asm`, `stage-tables.asm`,
   préambules) — friction à chaque évolution du moteur ; la génération des
   `.external.asm` depuis le registre d'exports est la suite naturelle
   d'`entries.asm`.
4. **L'orchestration leanscroll/crop** — friction rare (l'art des niveaux
   bouge peu), mais c'est la dernière chaîne où un build complet dépend d'un
   geste humain non tracé par le builder.

Le critère de fin, mesurable : **`games/r-type/tools/` ne contient plus que
des outils de contenu** (extraction arcade, prévisualisation) — plus aucun
script dont la sortie est requise par le build.
