---
date: 2026-08-10
sujet: Ce qui manque, mesuré dans le code, pour atteindre le modèle cible
  « file maître » — confrontation du plan (phases 0-9) avec l'état réel du
  builder au lendemain du banc r-type 5/5.
statut: état des lieux ; ne remplace pas le plan, il le chiffre.
s'appuie sur: plan-migration-cible-2026-08.md, analyse-placement-2026-08.md,
  manuel-cible-2026-08.md, analyse-charge-manuelle-2026-08.md
---

# Le reste du chemin vers la syntaxe cible — état des lieux

## 1. Pourquoi maintenant

Le plan a trois phases derrière lui (0, 1, 2) et le préalable qui manquait à
toutes les autres vient de tomber : **le banc r-type est vert (5/5 sous
toje)**, et le corpus d'identité binaire (`ci/build-corpus.sh`, 15 configs,
59 images) a servi deux fois en conditions réelles cette semaine. Les phases
3b, 4b, 5 et 6 exigent toutes des preuves « les images changent, l'exécution
non » — elles étaient inabordables tant que le banc mentait.

La confrontation ci-dessous est faite contre le code, pas contre le souvenir
du plan. Deux surprises en ressortent, dans le bon sens : **une partie de la
phase 3a et une partie de la phase 4a existent déjà**, posées par les
campagnes précédentes sans avoir été pointées au plan.

## 2. Ce qui est déjà acquis (et que le plan ne crédite pas)

| Pièce du modèle cible | Où elle vit | Ce qui est fait |
|---|---|---|
| Aiguillage cuit/lié (3a) | `spi/globals/BakeMode.java`, `StaticLink.java` | `bake=none/auto/all` existe ; en `auto`, chaque référence est classée, et un refus d'élection (multi-fournisseurs atteignables) **retombe silencieusement sur le lien au chargement** (`StaticLink.java:201-208`) — l'aiguillage du plan, déjà en place |
| Élection consciente des alternatives | `StaticLink.electProvider` (`:303`) | Fournisseur inatteignable (alternative du consommateur, ou co-chargé avec une) exclu ; constantes absolues identiques fusionnées |
| Arènes = places décidées par le builder (4a) | `config/ArenaPacker.java`, `PlacementScan.java`, `<arena>` dans `Handlers` | **Un rangement par arène, toutes scènes ensemble**, plus-gros-d'abord, place publiée par fichier (`<file>.page/.address`) ; deux arènes peuvent déclarer les mêmes zones pour les alternances — r-type l'utilise (2 arènes, ~20 loads) |
| Journal d'écriture disquette (6) | `plugin/floppydisk/storage/FdUtil.java:38-50` | Le `journal` des `Piece` existe — la matière première du rapport de seeks est là, personne ne la lit encore |
| Membres de pageset dérivés (2) | `PageSetPlugin` scindé pack/run | Fait (phase 2) ; la scène peut précéder son pageset |
| Émetteur d'index (1) | `<objectindex>` | Fait, forme transitionnelle : entrées **centralisées et explicites** dans le config (77 chez r-type) |

## 3. Le manque, phase par phase

### Phase 3 — bake par défaut, link dérivé — LA MOINS CHÈRE, entamée de fait

Ce qui manque réellement à 3a n'est plus le mécanisme, c'est **la voix** :

- ~~Le repli vers le lien au chargement **avale sa cause**~~ **FAIT
  (10/08, dans la foulée de cet état des lieux)** : chaque décision est
  enregistrée avec sa cause (`StaticLink.recordLinked`) et rapportée —
  classifications au log, liste complète dans `linked-refs-<target>.csv`.
  Voir `symbols.md` § « The caused list » et l'annotation 3a du plan.
- `interface="true"` reste une **déclaration** (5 usages, tous chez r-type)
  et l'heuristique « même destination = alternatives » reste un mécanisme
  d'élagage d'exports séparé (`LinkSymbols`) : le plan veut qu'ils deviennent
  des conséquences de la multiplicité. Tant que le rapport de cause n'existe
  pas, les retirer serait aveugle — l'ordre est donc rapport d'abord. (M)
- Le reliquat déclaré de la phase 1 : **l'imageset délégué au service de
  résolution** (sa link data fond) — différé exprès jusqu'ici parce qu'il
  change les images. (S)

3b est le gros du volume : la migration du corpus. Le recensement au
2026-08-10 :

| Config | `bake=` | `linkdata=` | `<region>` | `codec=` |
|---|---|---|---|---|
| games/r-type | 80 | 77 | 11 | 78 |
| examples/loader-ut | 0 | 32 | 8 | 6 |
| examples/stacked-overflow (×2) | 0 | 22 | 2 | 0 |
| examples/sound (×2) | 0 | 18 | 10 | 10 |
| examples/mplus (×3) | 0 | 22 | 4 | — |
| examples/tilescroll | 1 | 3 | 3 | 1 |
| examples/sprites | 1 | 2 | 2 | 1 |
| examples/objects | 0 | 2 | 2 | 1 |
| examples/hscroll | 0 | 1 | 3 | 1 |
| examples/tlsf-ut (×2) | 0 | 0 | 2 | 2 |

Soit **~100 `linkdata=` hors r-type à faire fondre un config à la fois**,
chaque migration validée par exécution. Deux contraintes mesurées :

- **loader-ut est un cas à part** : ses 32 `linkdata=` sont l'objet même du
  banc (T1-T18 exercent le linker). Le plan le dit déjà — il GARDE des tests
  dédiés aux chemins link. Concrètement : loader-ut ne migre pas en bloc, il
  se scinde en « ce qui teste le linker » (reste `bake=none`) et « le
  décor » (migre). À arbitrer test par test. (M)
- **Les images MO6 ne se valident qu'au build** (pas d'émulateur MO6 dans la
  lane) : sound/mo6, tlsf/mo6, stacked-overflow/mo6, mplus/mo6 migreront
  sur la foi de leur jumeau TO8 — à annoncer comme tel dans les commits.

3c (défaut `NONE` → `AUTO`, `BakeMode.parse` `:26`) est une ligne — mais
c'est la dernière ligne, après 3b. (S)

### Phase 4 — place attitrée, région absorbée — le mécanisme est là, la syntaxe non

L'écart entre l'existant et 4a est précis :

- `arena=` vit sur le **`<load>`** (`Handlers.java:156-161`), pas sur le
  `<file>`. Le modèle cible veut la place déclarée SUR le fichier
  (`arena=`, ou `page=`+`address=` pour une place fixe), et `<load>` réduit
  à un nom. C'est un déplacement d'attribut plus une résolution : quand
  plusieurs scènes chargent le même fichier, l'attribut sur le fichier rend
  l'unicité de place structurelle au lieu de vérifiée. (M)
- Le contenu **hors arène** (régions fixes : stage, tiles, maps, ymm…) n'a
  pas d'optimiseur : les adresses de régions restent choisies à la main.
  4a ne promet pas l'optimiseur général (écarté au §21), mais la place fixe
  déclarée sur le fichier doit au minimum être **vérifiée globalement**
  (toutes compositions) comme l'arène l'est déjà. (M)
- 4b : **36 `<region>` hors r-type + 11 chez r-type** à convertir, un projet
  par commit, preuve par identité d'exécution. C'est le plus gros volume
  mécanique du plan avec 3b — et les deux se recouvrent : migrer un config
  vers `bake=auto` ET vers la place attitrée en deux passes séparées
  coûterait deux revalidations toje. **Recommandation : fusionner 3b et 4b
  par config** (un config = un commit = une validation), le plan les
  ordonne mais ne l'interdit pas. (L, fusionné)
- 4c : retrait de `<region>` — identité binaire, mécanique. (S)
- Résidu de phase 2 constaté au build : `pageset stage2.tiles.odd fills 4
  of the 5 zones region tiles.odd declares` — la zone à rendre est le
  premier client de la syntaxe 4 (le budget déclaré redevient exact). (S)

### Phase 5 — collections fluides — rien de commencé, et un arbitrage à rendre

Aucun code. Le `<pageset>` (pack/run), le `<block>` de comblement et
`<objectindex>` centralisé sont les trois formes que la phase dissout dans
la **contribution** (`index=` sur le fichier, §23) — et cette inversion de
déclaration, que le plan datait de la phase 1, a été **différée par
l'arbitrage de la phase 1** (émetteur pur, entrées explicites). Elle
réapparaît donc ici, entière. Avant de coder : re-valider avec l'auteur que
l'inversion tient toujours maintenant que la forme centralisée a servi —
77 entrées dans le config sont lisibles ; 77 attributs éparpillés sur les
fichiers le seront-ils autant ? C'est le seul point du plan où l'expérience
acquise depuis peut renverser un choix. (XL, arbitrage d'abord)

La coupe par les creux (rigide posé, fluide coulé, seuil à deux plateaux)
est indépendante de l'inversion et peut se faire d'abord — c'est elle qui
rend les pages (« 2 morceaux au lieu de 5 » sur les tuiles). (L)

### Phase 6 — média dérivé des scènes — la matière première attend

- Le journal de `FdUtil` existe et n'est pas lu : le **rapport de seeks par
  scène** est un consommateur à écrire, sans toucher au média. (S)
- L'**ordre d'écriture par première utilisation** touche `Target`/le
  répertoire (l'ordre des `cwrite`) : les images changent, validation
  chargements sous toje, critère « zéro retour de tête pour une scène non
  partagée ». (M)
- Le **silence du `codec`** (défaut compressé) : ~100 `codec=` dans le
  corpus deviennent des exceptions. Mécanique une fois le défaut posé. (S)

### Phase 7 — contrats générés — l'état n'a pas bougé depuis l'analyse

- `api.asm` : **320 lignes au clavier** (l'interface moteur↔stage,
  EXPORT/EXTERNAL selon `ENGINE_RESIDENT`) ; `stage-tables.asm` 28 lignes.
  L'émission depuis un registre d'exports est à concevoir — le préalable
  (l'émetteur d'index et ses conventions) est en place depuis la phase 1. (M)
- `games/r-type/tools/` contient encore **des scripts dont la sortie nourrit
  le build** : `gen_enemy_unit.py`, `crop_stage.py`, `sync_waves.py`, plus
  l'orchestration leanscroll (les invocations `leanscroll-01.txt`/`-06.txt`
  sont des traces committées, pas des modules). `arcade_to_in.py`,
  `check_variants.py`, `fade_preview.html` sont des outils de contenu — eux
  restent. (L)
- La **déclaration d'images compacte** attend son banc naturel : le portage
  des ~60 ennemis. À concevoir AVEC lui, comme le plan le dit — pas avant. (M)

### Phase 8 — campagne loader — inchangée, toujours en dernier

La marche de destination `%10`/`%11` est toujours dans
`engine/system/thomson/bootloader/loader.asm` (`:335-448`). Rien à faire
avant que 3-6 aient vidé leur file d'attente côté runtime ; la revalidation
(loader-ut complet + échanges de disquettes + banc r-type + mplus/tlsf/
sound) coûte cher et ne doit être payée qu'une fois. (M, gelée)

### Phase 9 — passe documentaire — mesurable au bandeau

`manuel-cible-2026-08.md` et `manuel-cible-workflow-2026-08.md` portent
encore `statut: brouillon d'étude … DISCUSSION` ; la version anglaise
normative n'existe pas ; `analyse-placement` reste ouverte. Rien d'anormal
— c'est la définition de la phase 9 — mais le manuel cible peut commencer à
gagner ses sections « ce que le builder fait » **au fil des phases** (le
plan le demande, principe 4) : arènes et `bake=` sont déjà racontables. (M)

## 4. La photographie en une ligne par phase

| Phase | État | Reste | Taille |
|---|---|---|---|
| 0-2 | faites, prouvées | — | — |
| 3a | mécanisme fait | rapport de cause, interface/élagage en conséquences, imageset délégué | S+M |
| 3b | 2 configs sur 12 | ~100 `linkdata=` à fondre, loader-ut à scinder, MO6 sur parole | L |
| 3c | non | une ligne, après 3b | S |
| 4a | arènes faites | place sur le `<file>`, vérif globale des places fixes | M |
| 4b | non | 47 `<region>` à convertir — **fusionner avec 3b par config** | L |
| 4c | non | retrait mécanique | S |
| 5 | non | arbitrage inversion À RE-VALIDER, puis coupe par les creux | XL |
| 6 | journal prêt | rapport de seeks (S), ordre par scène (M), codec silencieux (S) | M |
| 7 | non | api/stage-tables générés, 3 scripts + leanscroll à absorber, images compactes avec les ennemis | L |
| 8 | gelée exprès | %10/%11 + dépoussiérage, une revalidation totale | M |
| 9 | non | bandeaux, version EN, clôture des études | M |

## 5. L'ordre de reprise recommandé

1. **3a-voix** : le rapport « lié au chargement, avec cause » (petite pièce,
   débloque le pilotage de tout 3b/4b) ; l'imageset délégué dans la foulée
   (les images r-type changent — le banc est vert, c'est le moment).
2. **3b+4b fusionnées, un config par commit**, du plus simple au plus
   chargé : tlsf → hscroll → objects → sprites → tilescroll → sound →
   stacked-overflow → mplus → loader-ut (scission) → r-type. Chaque commit :
   bake=auto + place attitrée + codec par défaut si 6 est prête, corpus
   diffé, banc toje du config concerné.
3. **6-rapport de seeks** en parallèle (lecture seule, aucune image ne
   change) ; l'ordre par scène quand 4b est finie.
4. **4c puis 3c** : les retraits, par identité binaire.
5. **5** après l'arbitrage re-validé avec l'auteur — c'est la seule phase
   où un choix du plan mérite d'être rejoué à la lumière de la forme
   centralisée qui a vécu.
6. **7** au rythme du portage des ennemis (sa matière), **8** et **9** en
   clôture, comme au plan.

Le plan reste juste ; ce qui a changé depuis le 09/08, c'est que ses deux
préalables implicites — un banc qui dit la vérité et des mécanismes 3a/4a
déjà debout — sont acquis. Le chemin critique n'est plus du code neuf :
c'est la **migration validée du corpus**, config par config, avec le
rapport de cause comme instrument de bord.
