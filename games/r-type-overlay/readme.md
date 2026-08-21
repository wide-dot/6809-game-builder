# r-type-overlay — le fork du chantier overlay

**Ce répertoire est un CLONE de `games/r-type`** (19/08/2026, branche
`overlay-render`) : le banc du chantier « rendu overlay » — remplacer la
sauvegarde de fond (`bdraw`) par le dessin seul (`draw`), et a terme un
effacement plein champ en tete de trame. `games/r-type` reste la reference
et ne doit pas etre touche par ce chantier ; toute correction du jeu
s'applique DEUX fois tant que les deux vivent.

Etat de cette base (etape 1 du chantier) :
- config : `<define symbol="OverlayMode"/>`, tous les encodeurs en `draw`
  (200 explicites + la cascade `images.encoder`) ;
  **CORRECTIF 21/08/2026** : la cascade n'etait declaree que sur le
  `<directory id="0">`, et deux entrees du repertoire 1 y echappaient encore —
  `stage1.dobkeratopsjaw` et `stage1.dobkeratopssaw` sortaient en `bdraw`.
  Ce n'est pas qu'un gaspillage (3 568 octets de sauvegarde/effacement morts,
  jaw 3 925 -> 2 200, saw 4 637 -> 2 794) : un sprite `bdraw` ouvre par
  `STS glb_register_s / LEAS ,Y` pour empiler le fond sauve, et le
  `BuildSprites` overlay appelle `jsr [_draw_routine]` sans poser le moindre
  tampon dans Y. La cascade est posee sur les neuf repertoires ; la machoire
  et les scies du boss du stage 1 sont donc a revoir a l'ecran ;
- engine : pack `sprite-overlay-pack` v1 importe (BuildSprites remplace
  CheckSpritesRefresh/EraseSprites/DrawSprites/UnsetDisplayPriority) ;
- **pas encore d'effacement de fond** : les sprites LAISSENT DES TRAINEES,
  c'est attendu ;
- les effaceurs a la main sont RETIRES (19/08, valide visuellement) : la
  rotonde de shells (eraser/shelleraser.unit/mask supprimes, table et hooks
  purges, l'ObjID 26 garde son numero et pointe le placeholder) et la
  machinerie bg-erase de la queue du Dobkeratops — TailDrawAll dessine
  seul, les quatre segments sont recompiles depuis leurs PNG par la chaine
  gfxcomp (les 703 lignes de blits colles au generateur perdu sont
  supprimees). Restent, a traiter AVEC le chantier effacement :
  starfield.erase (sans effacement de fond les etoiles traineraient), les
  bandes Wipe de la mort du boss (animation scriptee, pas de la
  comptabilite d'effacement), les talons EraseSprites_ClearAll et les
  ecritures glb_force_sprite_refresh (inertes) ;
- l'EFFACEMENT DE FOND est en place (19/08) : `playfield.clearBlast`
  (src/common/fx/clearblast.asm), stack-blast maison PSHS 9 octets/14 cy
  entierement deroule, pleine largeur, lignes 9-178 — 21 215 cycles exacts
  (la version generee par gfxcomp : 25 596, gardee dans la page pour
  comparaison). La rangee de tuiles du BAS n'est pas effacee : in.png la
  garde toujours peinte, et tools/sky_transparent.py (blocs 3x6, la maille
  arcade) l'exclut du remap. DrawTiles repeint chaque trame ; le starfield
  est passe a UNE passe (ecriture directe entre effacement et tuiles, la
  passe ERASE et ses tables par buffer sont supprimees). Deux pieges 6809
  payes et documentes dans clearblast.asm : pas de bsr/rts quand S est le
  pointeur d'ecriture, et CC inpoussable sous IRQ ouvertes (le RTI restaure
  E=1) ;
- mesure : defilement 9,2 img/s contre 8,8 en reference — la zone de jeu
  principale est PLUS RAPIDE que le mode background-erase, a rendu complet
  et sans trainees. Ouverture 15,2 (23,2 ref), boss 7,7 (9,3), sequence de
  fin 12,7 (40,5 — elle efface pour rien, optimisation connue) ;
- PIEGE APPRIS (19/08) : la convention des offsets camera CHANGE avec le
  pack. En background-erase ils portent le cadre ecran (48/28) ; le
  BuildSprites overlay les traite en MARGE hors-ecran et veut ZERO ici —
  les poser a 48/28 decale chaque sprite playfield avec wrap au bord.
  Le cadre 48-207 reste la convention de DRS_XYToAddress : les effaceurs
  a la main y transposent par les constantes screen_left/screen_top.

Le reste de ce readme est celui du jeu de reference.

---

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

La queue du dernier tileset de chaque stage ne se perd pas : sa **wave** la
comble, dans un `<block>` du pageset. La wave est déjà lue par page montée,
donc le code n'a rien à adapter — seule sa page, connue après rangement, est
écrite en équate par le builder (`gen/stages/NN/pages.asm`).

Seule valeur du banc qui n'est pas celle du jeu : la vitesse de scroll,
$0200 au lieu de $0030 — traverser le niveau 1 à la vitesse de r-type
prendrait 7680 trames.

## Le socle des ennemis

Ce que le moteur résident porte désormais, et qu'aucun ennemi ne peut éviter :
la chaîne **sprites** (`DisplaySprite`, `CheckSpritesRefresh`, `EraseSprites`,
`DrawSprites`, `BgBufferAlloc`, `DeleteObject`), l'**animation**
(`AnimateSprite`, `AnimateSpriteSync`, `moveByScript`), les **collisions AABB**
et le RNG. La boucle de stage les appelle dans l'ordre de la v1 : effacer, puis
les tuiles, puis les sprites.

Les **cinq** tables de la frontière sont câblées — l'index d'objets, les deux
index d'animation et l'index d'images — chaque stage exportant les siennes.

### Les collisions, et ce qui en meurt

La chaîne AABB est entière. Chaque objet inscrit sa boîte à sa création et la
retire à sa mort — le vaisseau dans `AABB_list_player`, pata-pata dans
`AABB_list_ennemy`, le tir et le beam dans `AABB_list_friend` — et la **passe de
détection** vit dans le moteur résident, à côté des listes qu'elle lit :

```asm
Collision_Run
        _Collision_Do AABB_list_friend,AABB_list_ennemy
        _Collision_Do AABB_list_player,AABB_list_bonus
        _Collision_Do AABB_list_player,AABB_list_ennemy_unkillable
        _Collision_Do AABB_list_player,AABB_list_ennemy
        rts
```

La v1 la déportait dans un objet monté (`obj_mainext`) faute de place dans sa
page résidente ; le stage v2 vit DANS cette page, donc la raison a disparu et
l'interface gagne un nom au lieu de trois — `_Collision_Do` est un macro qui
écrit dans deux opérandes auto-modifiées du moteur, qui restent ainsi privées.
Cas de migration : [main-private-object.md](../../docs/lang/en/migration/main-private-object.md).

Manquent, faute des objets qui les peuplent : `AABB_list_foefire` et
`AABB_list_forcepod` (tir ennemi et force pod non portés) et
`WeaponContactTick`. Les lignes v1 correspondantes sont conservées en
commentaire dans `engine.asm`, dans l'ordre.

Le vaisseau meurt au contact d'un pata-pata — explosion, gel de l'écran,
décompte d'une vie, rechargement du checkpoint — et un pata-pata meurt sous le
tir : il rend son score et fait naître une explosion.

### L'explosion

Un seul objet pour tout ce qui meurt, `subtype` choisissant l'animation. Ses
treize sprites pèsent 17 881 octets, plus qu'une page : le **code** est rangé
par le builder sur les deux pages d'un `<pageset>` (24 parts sur `$15`, 2 sur
`$16`) tandis que l'objet et son **index** restent dans une page à eux — c'est
celle que `Img_Page_Index` monte pour lire les descripteurs, elle ne peut pas
être répartie. Chaque descripteur porte donc la page de SON image, exactement
comme la v1, et l'index entier est cuit au build : zéro donnée de lien.

C'est une capacité neuve du builder (`<gfxcomp imageset>` + élément
`<imageset>`), sur la route que le tilemap emprunte déjà. Cas de migration :
[imageset-pages.md](../../docs/lang/en/migration/imageset-pages.md).

Une image sur deux seulement est compilée : c'est ce que déclare la cible
disquette de la v1 (`obj.d7.properties`), le code rattachant les manquantes à
la suivante sous `IFNDEF t2`.

### La séquence d'ouverture

Le vaisseau entre en autopilote par la gauche, flammes de réacteur allumées,
ralentit, dérive en arrière et rend la main. C'est l'objet v1 `initlevel1`, en
quatre phases : `subtype = -1` (invisible) pendant 50 trames, `subtype = -2`
avec les flammes et `x_vel = 280` jusqu'à `x_pos > 140`, ralentissement à 150,
puis marche arrière à −180 jusqu'à 60 px de la caméra, et enfin `clr subtype` +
auto-suppression.

**Rien n'était cassé — rien n'était branché.** Le joueur porté implémentait déjà
les deux portes de l'autopilote (`lbmi SkipPlayer1Controls` sur un `subtype`
négatif, et « si -1, ne pas dessiner »), simplement personne ne posait le
subtype : `ObjectDp_Clear` met l'OST à zéro à l'ouverture, donc le vaisseau
apparaissait pilotable et posé. Manquaient les deux identifiants d'objets — que
`gen_objid.py` ne pouvait deviner, la v1 les ensemençant à la main dans son main
plutôt que par la wave —, les deux unités, et les trois lignes d'ensemencement.

Elle est ensemencée **après `IrqOn`**, comme la v1 (`main.asm:171`) : l'objet
compte des trames, et le poser avant la trame d'amorce lui ferait consommer d'un
coup le frame-drop du chargement de scène. Chaque stage fournit sa
`stage.openingSequence` — le niveau 2 répond en ne faisant rien, on y entre par
un échange et pas par un début de partie.

Les flammes ont leur propre unité alors qu'elles sont une pièce du vaisseau :
les deux fichiers v1 nomment leurs routines internes `Init`, `Live` et
`Routines`, et les réunir dans une unité les fait entrer en collision. C'est la
même raison qui donne à chacune des quatre armes sa région.

### Le tir ennemi

La chaîne complète, portée telle quelle : un ennemi charge son **preset de
tir** (`_loadFirePreset`, sous-routine paginée), `tryFoeFire` décompte à chaque
trame et, l'échéance venue, appelle `createFoeFire` — qui alloue un objet, vise
le joueur par `setDirectionTo` (seize directions) et lui pose la vitesse du
preset. Le projectile (`foefire`) avance en 8.8, meurt sur le décor ou hors du
viewport, et tue le vaisseau au contact sans être détruit par lui.

La répartition est celle de la v1, qui n'est pas évidente : `tryFoeFire`,
`setDirectionTo` et les deux `moveXPos8.8`/`moveYPos8.8` sont **résidents**
(son main les inclut, `main.asm:565-568`), tandis que `createFoeFire` et
`loadFirePreset` sont des unités **montées** — de simples sous-routines
qu'un ennemi atteint par `RunPgSubRoutine`. Le lien remet les deux bouts en
face : `createFoeFire`, monté, appelle `setDirectionTo`, résident.

Conséquence à connaître : le résident cite désormais `ObjID_createFoeFire`,
donc il dépend d'une numérotation d'objets alors qu'elle est *par stage*. C'est
tenable parce que `gen_objid.py` sème les identifiants du commun **avant** de
lire la wave — les treize premiers portent le même numéro dans tous les stages.

Les variables inter-main (`globals.difficulty`, `globals.backgroundSolid`,
`globals.score`) ont quitté leurs étiquettes de page pour la **zone réservée**
`globals`, en équates absolues comme en v1 : deux étiquettes dans deux pages ne
sont pas la même variable, et le tir ennemi lit `backgroundSolid` depuis la
sienne. Cas de migration :
[shared-globals.md](../../docs/lang/en/migration/shared-globals.md).

### Le HUD

Le bandeau du bas — jauge de beam en cinq segments, vies, score sur cinq
chiffres significatifs — et le décompte de fin de stage. Il peint **directement
en mémoire vidéo**, à des adresses absolues de la fenêtre `$A000-$DFFF` : c'est
la page derrière la fenêtre qui alterne au double tampon, pas l'adresse.

Comme le champ d'étoiles, ce n'est pas un objet : ni OST, ni état par entité, et
rien dans la vague ne le nomme. Ses deux routines sont donc des symboles visés
par `paged.call` — et il le fallait, car **`paged.call` écrase `B`**, où la v1
passait sa commande (`hud.NORMAL` / `hud.READOUT`). Deux entrées exportées
remplacent l'ObjID et le registre de commande.

**Ses douze sprites sont repassés par la chaîne.** La v1 les portait en dur —
du code généré une fois puis collé, ce que son `.properties` dit en toutes
lettres (« used to generate code, should be commented because replaced by the
code above »), faute d'un encodeur au bon contrat d'appel : le `draw` consomme
`U`, or le HUD enchaîne `jsr` puis `leau 1,u` pour poser la rangée suivante.
La v2 a l'option (`<encoder planes="offset">`), donc les PNG redeviennent la
source et 306 lignes quittent `hud.asm`.

Mesuré avant de supprimer quoi que ce soit : sur les douze sprites, **huit sont
identiques à l'octet** au code collé et **quatre ne diffèrent que par l'ordre de
groupes d'écriture disjoints** (la recherche d'ordre de l'encodeur). À l'écran,
les deux builds sont **strictement identiques, pixel pour pixel**, et l'unité
pèse 5 184 octets des deux côtés. Ce qui était périmé, ce n'étaient pas les PNG
mais les `.asm` générés posés à côté — supprimés. Cas de migration :
[pasted-generated-code.md](../../docs/lang/en/migration/pasted-generated-code.md).

Deux écarts tracés : le dispatch sur `B`, et un bouchon pour l'état du décompte
(`main.endstage.scoreArmed/scoreDone`, qui appartiennent à l'objet `endstage`
non porté, et `soundFX.newSound`, la boîte aux lettres du son). `hud.readout`
est donc exporté mais jamais appelé.

**Les vies ont changé de maison au passage** : elles vivaient dans `game.lives`,
une variable du moteur inventée par le banc, alors que c'est `globals.lives` que
le HUD dessine — et deux compteurs dans deux endroits n'en font pas un. Elles
rejoignent le bloc réservé, à deux vies comme la v1.

La page `$14` a été redécoupée pour l'accueillir : ses 5 184 octets ne tenaient
pas dans la fin de la page des overlays, mais `$14` n'était remplie qu'à 22 %.
Redécouper coûtait moins qu'une page neuve — les pages sont ce qui manquera aux
tuiles.

### La manette, et le clavier en bouton B

Les manettes Thomson n'ont qu'un bouton ; le rappel du force pod en demande un
second. `joypad.readKbd` injecte KTEST (`$E7C8` bit 0, au moins une touche
enfoncée) dans le bit BRUT du bouton B de la manette 0, **avant** la détection
de front : `joypad.pressed.fire` se comporte alors comme un vrai bouton B, front
propre et pas de rafale tant que la touche reste enfoncée. Porté de
`ReadJoypadsKbd.asm`, et comme en v1 dans son **propre fichier** : un jeu qui
n'en veut pas inclut `joypad.asm` seul et ne le paie pas.

### Pata-pata

Il tire désormais : les deux `V2-DEVIATION` qui neutralisaient `tryFoeFire` et
`_loadFirePreset` sont levées, et le fichier ne diverge plus de la v1 que par
ses en-têtes (portés par l'unité hôte) et par les entrées d'imageset, qui
passent de `Img_<nom>` à `set_<nom>` — le nom que gfxcomp génère.

À savoir : `pata-pata/animation.asm` et `bug/animation.asm` sont du **code
mort** hérité de la v1 — ils référencent des symboles (`x1B139`) définis nulle
part, et les vrais scripts sont l'objet commun.

Reste absent du résident, et **volontairement** : la musique (YMM, soundFX),
les maths du boss (`CalcSine`, `Mul9x16`), `LoadGameMode` (remplacé par
`scene.load`) et `PalUpdateNowLean`.

## La carte de la zone résidente (page $01)

```
$6100  région common   moteur résident, 7 851 o sur $2700 déclarés (78 %)
$8800  région stage    stage courant, 1 721 o (st.1) sur $08B0 (77 %)
$90B0  réservé         pool d'objets, 16 slots x 117 o
$9875  LIBRE           1 547 o d'un seul tenant — la réserve du pool
$9E80  réservé         un seul bloc de $80 : variables inter-main (13 o),
       (~99 o)         témoins du banc (16 o), puis la PILE SYSTÈME qui
                       croît vers le bas depuis $9F00
$9F00  réservé         PAGE DIRECTE — et c'est là que vit l'OST DU JOUEUR
         $9F00  espace utilisateur (149 o) : player1 equ dp, un OST de 117 o
         $9F97  dp_extreg  registres étendus (28 o)
         $9FB3  dp_engine  scratch moteur (30 o)
         $9FD1  glb_Page, timers, caméra… jusqu'à glb_ram_end $9FF4
```

**Le moteur résident est à 78 % de son budget** depuis le rééquilibrage du
04/08 : la frontière `common`/`stage` avait été posée avant qu'on connaisse les
tailles — 93 % contre 46 % — et elle est recalée, le trou de 176 octets repris
au passage. `loader.DEFAULT_SCENE_EXEC_ADDR` lit désormais l'équate
`stage.address` générée plutôt qu'un littéral : dupliquer cette adresse, c'était
démarrer dans le vide le jour où la frontière bouge.

Ce qu'il reste de marge, et le chemin pour retrouver les **50 slots d'objets de
la v1** (nous en avons 16), sont chiffrés dans
[`analyse-residente-2026-08.md`](../../docs/lang/fr/analyse-residente-2026-08.md).
En un mot : le contenu v2 tient dans 244 octets de plus que celui de la v1, donc
le pool n'est pas petit parce que le code a grossi.

Premier axe traité, le 04/08 : **le fondu de palette est redevenu un objet
monté**, comme en v1 (`object.fade=…`). Il a un OST et un index de routine —
rien ne le distinguait de l'explosion, que `Obj_Run` va chercher dans sa page
sans que personne y pense. 279 octets rendus à la page 1, pour 86 octets de
données de lien. Il vit page `$14`, avec l'explosion et la chaîne de tir.

Le joueur ayant ses données en page directe, `ObjectDp_Clear` (remise à zéro
de `dp` à `dp_extreg`) fait partie du résident, et `_Obj_RunU ObjID_Player1,#player1`
est la forme d'appel qui l'anime. Les valeurs de la page directe sont la chaîne
d'équates de `engine/constants.asm`, évaluée depuis `glb_ram_end = $A000-12`.

Hors résident, en pages physiques : `$4000-$5FFF` le pool d'objets (page
`$00`, demi-page épinglée par PRC bit 0 — 60 slots dynamiques + fondu +
3 slots d'armement depuis le 20/08/2026 ; c'était le tampon de fond du
background-erase, sans usager depuis l'overlay),
vidéo montée en `$A000` alternant `$02` et `$03`, loader `$04`, ennemis `$05`,
tuiles `$06-$0D`, cartes `$0E`, scripts d'animation `$0F`, overlays `$10`,
joueur `$11`, collision terrain du stage `$12`, armement `$13` (quatre régions
à adresses fixes), `$14` l'explosion, la chaîne de tir ennemi, son projectile,
le fondu, les flammes de réacteur et le HUD (six régions), et les sprites d'explosion sur `$15-$16`.

L'occupation réelle de tout cela se lit dans `dist/ram-map-fd.txt`, produit à
chaque build — une carte par scène.

## Les zones réservées

Le builder vérifiait les chevauchements **entre chargements** d'une même
scène, mais il ne connaît pas ce que le jeu occupe *sans* rien charger : le
pool d'objets, les variables inter-main, la pile, la page directe. Ce sont des
équates du code, invisibles à la configuration. On les déclare :

```xml
<reserved name="objects.pool" page="$01" address="$90B0" size="$0750"/>
<reserved name="globals"      page="$01" address="$9E80" size="$0080"/>
<reserved name="stack"        page="$01" address="$9F00" size="$0100"/>
```

Une zone réservée se **mutualise** plutôt que de se multiplier. Les témoins du
banc ont eu la leur — `$9C00`, 644 octets déclarés pour seize écrits — avant de
rejoindre le bloc `globals` en équates, à côté des variables inter-main
(`bench.const.asm` les pose sur `GLOBAL_VARIABLES+13`). Même mécanisme, même
zone, et quand le banc partira ses seize équates partiront avec lui **sans
laisser de trou dans le layout** : c'est ce qu'une équate a de plus qu'une
région. L'ancre est passée de `$9E84` — une valeur dérivée de la v1, le premier
octet libre après *son* main — à `$9E80`, qui donne un bloc de `$80` pile.

Aucune région ne peut plus y atterrir, et **le contrôle porte sur les
déclarations**, pas sur la taille de ce qui est chargé : une région déclarée
par-dessus le pool est une faute latente même tant que son contenu reste
petit. Les régions sont aussi vérifiées entre elles.

Ça a immédiatement attrapé un vrai défaut de ce banc : la région `stage`
déclarée `$8300-$98FF` empiétait sur le pool d'objets `$90B0-$97FF`. Son
contenu ne l'atteignait pas encore.

`gensymbols` émet `<nom>.address` et `<nom>.size` pour chaque zone, donc le
code peut s'y référer au lieu de redéclarer les mêmes adresses.

## Traçabilité v1

`v1-map.csv` : chaque fichier repris, chemin v1 → chemin v2, contenu
identique à la migration (02/08/2026), le contenu ne l'est plus : la campagne
palette de 08/2026 a réécrit une centaine de PNG et la promesse d'identité
octet pour octet est abandonnée (décision auteur, 17/08). Le CSV garde son rôle
de traçabilité. Non repris, consultables en v1 :
les `.properties` (~600, remplacés par le config.xml), les variantes
`.t2.asm` (le média cartouche n'existe pas encore en v2), les mains 02..08,
les bancs `test-fire`/`fadetest`/`objects/test`, `generated-code/` et les
intermédiaires leanscroll (`out.png`, `fullLean.png`, `*-color/`).

## La chaîne map

`src/stages/NN/map/in.png` est la source ; le BUILD fait le reste (7c) :
l'élément `<leanscroll>` du config dérive les deux plans, fenêtre et
renumérote sous `gen/stages/NN/map/`, et la géométrie sort en équates. Les
stages câblés (01, 02) n'ont plus de sorties committées ; les stages 03-08
gardent leurs plans committés (`0/0.png`, `1/1.png`, `*.0.bin`) en attendant
leur câblage. Voir `docs/lang/en/tilemaps.md`, et `tools/leanscroll-06.txt`
pour la recette de reconstitution d'un `in.png` depuis l'arcade.

## Porter un ennemi

Le geste est court depuis 7b : les images sont DÉJÀ en place et numérotées
(le renommage du stock complet suit l'ordre des properties d7 v1) — écrire
l'unité hôte en copiant celle d'un ennemi voisin (`scant.unit.asm` : entrée
exportée, INCLUDE api, en-têtes communs, table de liaison `Img_* equ set_*`),
et déclarer le `<file>` avec une ou deux lignes `<images>`. `check_variants.py`
rapproche le résultat des properties v1 par contenu.

Ce paragraphe vaut pour un ennemi qui a une source v1 (stage 1). Pour tout
le reste — les casts des stages 2-8, sans source v1 — la référence est le
code arcade et le mode opératoire est le skill **`enemy-port`**
(`.claude/skills/enemy-port/` : extraction de la spec depuis la base Ghidra,
table de correspondance arcade→v2, choix de l'exemplaire, intégration,
validation).

## Référence

`reference/` : matériel arcade et SMS (sprites, niveaux, musiques) servant de
source d'authoring. `doc/` : notes de référence arcade (combat, scoring).

`src/enemies/<ennemi>/images/original/` : les sprites arcade d'origine de CET
ennemi, rangés par pose comme l'extracteur les sort (`<pose>/<n>_<adresse
rom>.png` — l'adresse est le lien vers la ROM). Ce sont des images de
**référence** pour le portage graphique, jamais une entrée de build : le
`config.xml` ne lit que les PNG convertis à côté.

Source : `re.arcade.r-type`, `out/sprites/` (l'extracteur les pose sur un
plan 256×256 palettisé). Le 15/08/2026, le cast des stages 2-8 encore sans
graphismes et les deux boss exportés ont été importés tels quels — 590 images,
19 ennemis. Manquent, faute d'export amont : **gomander** (boss du stage 2 ;
au catalogue de l'extracteur, mais son moteur `tile_grid indirect` ne sort
pas), et **bellmite** (5), **bronco** (7), **bydo** (8), qui n'ont qu'une
routine identifiée et aucune entrée de catalogue.
