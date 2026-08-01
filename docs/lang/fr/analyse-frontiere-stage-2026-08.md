# La frontière stage / commun, mesurée sur le niveau 1

Conception du point 7 (pipeline builder), premier livrable : l'inventaire
mécanique de ce qui traverse la frontière entre le main du niveau 1 de R-Type
et le moteur qu'il inclut. Objectif énoncé par l'auteur : garder en place les
ressources communes à tous les stages, ne charger par stage que le main
spécifique, la map, la wave et les ennemis.

Contrainte assumée : **on conçoit à l'aveugle** — les game modes 02..08 de la
v1 sont des copies figées du stage 1 à un instant t, sans spécialisation
réelle. Les seuls points de données par-stage authentiques sont les
`LevelInit` et les unités de collision des niveaux 01..04 (map, largeur,
paramètres de scroll). Le reste se déduit du niveau 1 seul, et la parade est
double : une frontière **réversible** (déplacer une routine d'un côté à
l'autre = déplacer un include, relinker), et un **banc à deux stages
synthétiques** comme critère d'acceptation avant tout vrai stage 2.

## Le principe qui rend la frontière trouvable

Ne pas découper le main : **changer la nature de ses includes**. Le main v1
est un monolithe textuel mais pas structurel — une liste d'INCLUDE moteur,
du code de stage autour. Tout le main est spécifique ; les includes moteur
deviennent des liens dynamiques vers l'unité commune. Corollaire : la boucle
principale reste au stage (le moteur = mécanismes purs, la politique = le
stage). Un commun fait de mécanismes se délimite sans stage 2 ; une boucle à
crochets exigerait de deviner les bons crochets, ce que l'aveugle interdit.

## La frontière a quatre voies (inventaire scripté, niveau 1)

Scan : 45 fichiers moteur inclus, 17 fichiers stage/projet.

### 1. Voie compile-time — en-têtes partagés, pas de liaison

15 macros moteur utilisées par le stage (`_Obj_Run*`, `_gfxlock.*`,
`_terrainCollision.init`, `_ymm.*`, `_asld`…), ~23 équates moteur, les
structs. Les deux unités incluent les mêmes en-têtes ; cette surface doit
rester **stable et versionnée** (un changement d'équate moteur invalide les
stages déjà assemblés).

### 2. Voie stage → moteur — l'API, 41 labels

`RunObjects`, `LoadObject_x`, `Scroll`, `DrawTiles`, `ObjectWave`,
`CheckSpritesRefresh`, `Draw/EraseSprites`, `UnsetDisplayPriority`,
`Irq*`, `PalUpdateNow`/`Pal_current`/`PalRefresh`, `gfxlock.*`,
`joypad.buffer.addDirection`, `moveByScript.register`, `RunPgSubRoutine`,
`InitGlobals`/`InitStack`/`InitScroll`/`InitDrawSprites`/`InitRNG`/
`InitJoypads`, `scroll_vel`/`scroll_tile_pos`,
`terrainCollision.bgByteOff/bgBitShift`, `rx`/`ry` (RNG)…
C'est la liste d'exports de l'unité commune — le rôle 1 du linker, rien à
inventer.

### 3. Voie moteur → stage — cinq tables, c'est tout

Le moteur ne lit du stage que **l'interface générée** :

    Obj_Index_Page      Obj_Index_Address
    Img_Page_Index      Ani_Page_Index      Ani_Asd_Index

(plus les listes AABB, passées par macro en opérandes auto-modifiées — pas de
liaison). Le mécanisme d'isolation existe déjà : le moteur les importe en
`EXTERNAL`, chaque stage exporte les siennes, **le re-link global de
`scene.load` repointe le moteur à chaque échange** — comportement validé par
loader-ut depuis l'origine. Pas de vtable, pas d'adresses de convention.

Ces cinq tables sont exactement ce que les quatre bancs v2 écrivent à la
main : le pipeline du point 7 a pour première mission de les générer, en
sections `.static` dans l'unité du stage (tout est placé → zéro link data
pour leur contenu ; seules les cinq têtes de table restent des symboles
dynamiques repointés à l'échange).

### 4. Voie figée à l'assemblage — 13 équates, à gérer une fois

Le moteur assemblé une fois fige : `nb_dynamic_objects` (dimensionne la pile
de slots DANS RunObjects), `nb_graphical_objects`, `ext_variables_size`,
`Dynamic_Object_RAM`/`_End`, `moveByScript.POS/NEGX/YSTEP`,
`map_width`/`viewport_width`, `DEBUG`, `SOUND_CARD_PROTOTYPE`.

Décisions : géométrie du pool d'objets **fixée pour le jeu entier** (R-Type
utilise déjà les mêmes valeurs partout) ; les pas de moveByScript idem.
`map_width` sort de cette voie par un mécanisme déjà présent : c'est le
défaut d'init de `scroll_max`, qui est une **variable** que le stage écrit
(le boss l'écrase déjà via `bossStopX`) — largeur par stage = écriture de
`scroll_max` au LevelInit, et l'unité terrain (par-stage) porte son propre
`map_width`.

## Le verrou builder que ça révèle : l'interface de stage

Chaque stage exporte les **mêmes noms** (les cinq tables, la wave, son
entrée). Or l'unicité des exports est vérifiée globalement au target. C'est
le concept d'« interface de groups » de la conception d'origine, jamais
implémenté (« deux blocks de même id doivent avoir la même liste d'exports,
triée, pour partager les index »). Version minimale nécessaire au point 7 :

1. l'unicité d'un export se vérifie **par ensemble co-chargeable** — deux
   direntries qu'aucune scène ne charge ensemble peuvent partager leurs noms
   (prouvable avec ce que SceneChecks sait déjà) ;
2. un contrôle « même liste d'exports » entre les unités interchangeables
   d'une même région, qui est la définition opératoire d'une interface.

## L'état persistant

Score, vies, armement, difficulté survivent aux échanges : une plage RAM
déclarée **hors de toute destination de load**, vérifiable au build (les
compositions sont connues). À matérialiser comme attribut de région ou plage
réservée du layout.

## Le critère d'acceptation : deux stages synthétiques

Philosophie des mires appliquée au point 7. Deux mini-stages générés (deux
maps, deux waves, deux lots d'ennemis factices, exports d'interface
identiques) au-dessus d'une couche commune, et le banc prouve :

- l'échange stage1 → stage2 → stage1 par `scene.load` seul, régions communes
  intactes (unload implicite validé T8) ;
- le re-link du moteur vers les nouvelles tables (les cinq symboles) ;
- l'état persistant intact à travers l'échange ;
- le **checkpoint intra-stage sans disque** : reset d'état +
  `ObjectWave_Init` (repositionnement du pointeur de wave sur l'horloge,
  déjà exercé par objects T17) + retour caméra.

Si ce banc tient, la couture est prouvée avant qu'un vrai stage 2 existe.

## Hors périmètre de cette analyse

Les ~149 objets montés consomment les mêmes surfaces (les cinq tables, l'API
moteur, les globales DP) — sous `undefextern` en v1, en `EXTERNAL` explicites
en v2 comme l'unité terrain de tilescroll l'a montré (8 déclarations). Leur
inventaire par objet relève du portage R-Type, pas de la conception du
pipeline ; la mécanique est la même.
