# R-Type — TO8 (v2)

Portage du projet R-Type de la v1 (`thomson-to8-game-engine/game-projects/r-type`)
sur la toolchain v2. **En cours** : l'arborescence est en place, le build v2
(config.xml, scènes, direntries) arrive avec le banc d'échange de stages.

## L'arborescence reflète la frontière de chargement

La structure suit le modèle mémoire du point 7 (voir
`docs/lang/fr/analyse-frontiere-stage-2026-08.md`) : ce qui est résident se
lit d'un coup d'œil, ce qui s'échange par stage aussi.

```
src/
├── common/        le RÉSIDENT — chargé une fois pour tout le jeu
│   ├── engine/    l'unité moteur commun (créée avec le build v2)
│   ├── state/     état persistant : score, vies, armement, checkpoint
│   ├── player/    le vaisseau et ses flammes
│   ├── weapons/   tout l'armement : weapon, beam, missile, forcepods, bitdevice
│   ├── pickups/   les bonus (pow)
│   ├── hud/       hud, messages, mask
│   ├── fx/        explosion, soundfx, animation
│   ├── flow/      loading, clearstage, endstage, bossmusic, mainext
│   ├── music/     jingles partagés
│   └── lib/       macros et aides partagées (ex global/ v1)
├── enemies/       BIBLIOTHÈQUE — chaque stage y puise via la config
│   ├── _shared/   tirs génériques (foefire, commonmissile, emitter-flash)
│   └── <nom>/     un ennemi = un dossier autonome, SES tirs avec lui
│                  (scant/fire.asm, tabrok/canon.asm — c'était foefire/ en v1)
├── stages/NN/     l'ÉCHANGEABLE — un chargement par stage
│   │              main, stage.asm (LevelInit), wave, map/, terrain/, musique
│   └── 02..08     données réelles seulement ; les mains v1 étaient des
│                  copies figées du 01, non reprises
└── title/         écran-titre (ex game-mode/00 + levels/00)
```

## Le banc d'échange de stages

Premier morceau construit sur cette arborescence, et critère d'acceptation du
pipeline : deux stages réels échangés par `scene.load`, moteur résident intact.

    to8.config.xml            régions common / stage / tiles.even / tiles.odd
    src/common/engine/        l'unité résidente
      api.asm                 L'INTERFACE — une seule liste, EXPORT côté moteur
                              et EXTERNAL côté stage selon ENGINE_RESIDENT, donc
                              les deux côtés ne peuvent pas dériver
      stage-tables.asm        l'autre sens : les tables que le moteur relit
    src/stages/stage-main.asm la boucle, partagée (les mains v1 02..08 l'étaient)
    src/stages/NN/main.asm    ce qui distingue le stage : cartes, wave, index

Données réelles : les cartes viennent de `in.png` des niveaux 1 et 2 via
leanscroll, les waves sont celles de l'arcade avec leurs horodatages, les
index d'objets sont générés depuis les identifiants que ces waves citent
(16 pour le niveau 1, 2 pour le niveau 2). Les ennemis n'étant pas portés,
toutes les entrées d'index pointent un objet bouchon — le chemin exercé, lui,
est le vrai : wave → slot → identifiant → index du stage chargé → code.

**Résultat (02/08/2026)** : 5/5 sous toje, scénario complet joué —
`$9C07..$9C0B` = `01 01 01 01 01`. Le stage 2 est atteint par son propre
index d'objets, ce qui ne peut arriver que si le re-link a repointé le
moteur ; l'état persistant traverse l'échange ; le retour au stage 1
fonctionne ; le checkpoint sans disque retrouve exactement la position de
wave que la lecture normale avait atteinte.

**Le niveau 1 est entier** (02/08/2026) : 132 colonnes, 244 tuiles paires et
303 impaires, rangées par `<pageset>` sur 3 et 5 pages, et 11 880 octets de
tables de carte dans une page à elles — la RAM résidente n'en a pas la place,
mais le scroll porte déjà une page par plan de carte. La caméra traverse les
1440 px et l'art du milieu de niveau (tourelles, parois nervurées) s'affiche
juste, ce qui n'arrive que si chaque tuile est lue sur la bonne des huit
pages. **Le stage 2 est entier aussi** : 96 colonnes, 190 tuiles paires sur 3 pages
et 229 impaires sur 4, 8 640 octets de tables. Les deux niveaux sont donc
construits en entier, sur leurs vraies données.

Seule valeur du banc qui n'est pas celle du jeu : la vitesse de scroll,
$0200 au lieu de $0030 — traverser le niveau 1 à la vitesse de r-type
prendrait 7680 trames.

## Traçabilité v1

`v1-map.csv` : chaque fichier repris, chemin v1 → chemin v2, contenu
byte-identique à la migration (02/08/2026). Non repris, consultables en v1 :
les `.properties` (~600, remplacés par le config.xml), les variantes
`.t2.asm` (le média cartouche n'existe pas encore en v2), les mains 02..08,
les bancs `test-fire`/`fadetest`/`objects/test`, `generated-code/` et les
intermédiaires leanscroll (`out.png`, `fullLean.png`, `*-color/`).

## La chaîne map

`src/stages/NN/map/` porte les sorties leanscroll committées (tileset normal
`0/0.png`, pré-décalé `1/1.png`, indexes `*.0.bin`, viewport `init.png`) et
`in.png` la source. L'invocation est committée dans `tools/leanscroll-NN.txt`
— régénération manuelle quand `in.png` change. Le build v2 compile les strips
par `<gfxcomp grid>` et génère les tables par `<tilemap>` (voir
`docs/lang/en/tilemaps.md`).

## Référence

`reference/` : matériel arcade et SMS (sprites, niveaux, musiques) servant de
source d'authoring. `doc/` : notes de référence arcade (combat, scoring).
