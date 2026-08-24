# Table de correspondance arcade → v2

Chaque idiome du code arcade (V30/x86, base Ghidra `maincpu`) et son
équivalent dans le runtime v2 (6809, engine de ce repo). Les faits marqués
« vérifié » sont lus dans le code des deux côtés — les reprendre tels quels.
Une décision nouvelle prise pendant un portage s'AJOUTE ici.

## Machines et repères

| | Arcade (Irem M72) | TO8 v2 |
|---|---|---|
| CPU | NEC V30 (x86 16 bits) | 6809 |
| Trame | ~55 Hz | 50 Hz (VBL), frame drop compensé |
| Écran | 384×256 | BM16 160 px larges × 200 (144 visibles + bord de 8) |
| Objet | ObjectRecord chaîné, tick par `+0x00` | OST de `object_size` octets, `RunObjects` |

## Coordonnées et échelle (vérifié : `src/common/lib/scale.asm`)

- **1 px arcade = 0.375 px large TO8 en X** (`scale.XP1PX equ $0060` en 8.8)
  et **0.75 px TO8 en Y** (`scale.YP1PX equ $00C0`). Contrôle : 384×0.375 =
  144 = largeur visible ; 256×0.75 = 192.
- Une vitesse arcade en px/trame se convertit par cette échelle et se pose en
  8.8 (`x_sub`/`y_sub`, helpers `moveXPos8.8`/`moveYPos8.8`).
- **Espaces différents, et la question se pose POUR CHAQUE ennemi.** Le
  mouvement de caméra est **explicite** en arcade : `auto_scroll` (0x40:0467)
  publie un delta par trame en `0x2ED0..0x2ED6`, et chaque tick d'objet décide
  de se l'appliquer ou non. En v2 il est **implicite** : un `x_pos,u` en repère
  PLAYFIELD (`render_playfieldcoord_mask`) recule tout seul quand la caméra
  avance. Les deux cas sont donc inverses l'un de l'autre, et **le test est
  mécanique — le tick arcade lit-il `0x2ED0` ?** (`bridge_xrefs_to` sur cette
  adresse donne la liste complète des objets qui s'y accrochent) :
  - **il le lit** = ancré au décor. En v2 : ne rien faire, supprimer les
    additions de `scroll_amount`, garder le mouvement propre.
  - **il ne le lit pas** = ancré à l'ÉCRAN. Deux transpositions possibles,
    et le choix dépend de ce que l'objet TOUCHE :
    1. *Il interagit avec le monde* (terrain, ancrage ponctuel — tabrok en
       `fall_left`, le joueur, `commonmissile`) : rester en playfield et
       **rendre le scroll explicite** en tirant l'objet avec la caméra —
       `x_pos += glb_camera_x_pos - glb_camera_x_pos_old`. Frame-drop-aware
       par construction, et `Scroll` fige `camera_old` avant d'avancer puis
       tourne avant `RunObjects` : tous les objets d'une trame lisent le
       même delta.
    2. *Il est entièrement piloté par script, sans contact avec le monde*
       (l'outslay) : **vivre en référence écran NATIVE** (décision auteur,
       21/08/2026). Compenser la caméra à chaque trame pour un objet qui n'en
       veut pas, c'est payer pour annuler. `x_pos`/`y_pos` directement dans
       le cadre 48-207 / 28-227 de `DRS_XYToAddress`, `render_flags` sans le
       masque playfield (le chemin `@screencoordinates` du moteur lit
       `xy_pixel` = les octets bas de position) ; `moveByScript` s'en moque,
       il n'ajoute que des deltas. Tout devient moins cher : le cull en
       octets (référentiel décalé), la boîte de collision en deux
       soustractions 8 bits, et un renderer groupé publie ses slots **sans
       aucune conversion**. Seules les FRONTIÈRES convertissent : ce qui en
       sort vers le playfield (`foefire`, explosions : `x - 48 + caméra`,
       `y - 28`, une fois par spawn) et ce qui en entre (le joueur dans un
       test de portée). L'émetteur d'une chaîne vit dans le même repère que
       ses segments — c'est lui qui fixe le point de ponte.
- **La conversion qui fait foi est `re.arcade.r-type` `Conv.java`** :
  `x_v2 = round((x_arcade − 320) × 0.375) + 8` et
  `y_v2 = round((y_arcade − 144) × −0.75) + 190` — l'**axe Y arcade pointe
  VERS LE HAUT** (origine en bas, ratio négatif) : un y arcade plus grand
  est plus haut à l'écran, et le +8/+190 porte les offsets de viewport v2
  (8/11). Appris sur l'intro du stage 1 (y=0x110 décodé 12 px trop bas).
- Points d'ancrage vérifiés : spawn au bord droit arcade `x=0x2C8/0x2D0` ↔
  v2 `glb_camera_x_pos + 144+8+3` (pata-pata, cite `fc7e`). Seuils arcade
  fréquents : `< 0x270` = entré à l'écran, `< 0x130` = sorti à gauche — les
  transposer relativement à la caméra via l'échelle X, et valider à l'œil.
- Tables Y arcade : importées déjà recalées (ex.
  `src/common/lib/presets/18db0_preset-y.asm`, valeurs ≤ $B7 < 200).

## Caméras et registres de scroll (vérifié : `auto_scroll` 0x40:0467)

- **Un registre de SCROLL n'est pas une coordonnée d'objet — `Conv.yratio` ne
  s'y applique PAS avec son signe.** Les caméras arcade
  (`x_foreground_camera` 0x2EC0, `x_background_camera` 0x2EC8,
  `y_background_camera` 0x2ECC) indexent la tilemap, et la tilemap s'indexe
  vers le BAS : c'est exactement la convention de `mscroll.camera.y` en v2.
  Conversion d'une vitesse de caméra : **magnitude du ratio, sans bascule
  d'axe** — X : `v*6`, **Y : `v*+12`** (pour un `v` en 1/16 de px arcade).
  Une coordonnée d'OBJET, elle, garde `Conv.yratio` avec son signe négatif.
- **Comment les distinguer dans le code, deux indices indépendants :**
  1. *Le fetch de tuile.* Le lookup de tuile de fond (0x40:1EE0..1F03)
     calcule sa ligne `row ≈ (cam_y + 0x17F − pos_y) / 8` : un `cam_y` plus
     GRAND va chercher une tuile plus BAS dans la carte pour le même point
     d'écran — le contenu monte à l'écran, comme en v2.
  2. *Le `NEG` manquant.* `auto_scroll` dérive un delta par trame pour chaque
     caméra et le donne aux objets (pour traîner les sprites fixes du monde).
     Les deltas X sont négués (0x0490, 0x04C4), **les deltas Y ne le sont
     pas** (0x04FA, 0x051B). Cette asymétrie EST l'axe Y-vers-le-haut de
     l'arcade qui annule déjà l'inversion de caméra : appliquer `yratio`
     par-dessus la compte DEUX FOIS.
- Le wrap est sur l'ENTIER de la caméra : `AND ...,0x1FF` = 512 px arcade sur
  les deux axes (le X est un anneau alimenté par streaming de colonnes, le Y
  boucle vraiment). En v2 : 512 × 0,75 = 384 px = hauteur de la carte.
- Appris sur la chorégraphie du warship (stage 3, 20/08/2026) : toute la
  trajectoire verticale était MIROIR. L'arcade tient le cuirassé HAUT dans la
  bande 27 s durant (33,8 s → 60,9 s du combat) ; sur TO8 il restait en BAS
  aussi longtemps. Tout le reste concordait — excursion, durées, forme de la
  danse — ce qui rend l'erreur chère à voir : une trajectoire miroir reste
  une trajectoire plausible. Corrigé dans `re.arcade.r-type`
  `extractor/Warship.java` (la source de vérité) et dans l'export commité
  `src/stages/03/warship/camera-script.asm`.
- **Méthode qui a débloqué** (à reprendre) : deux campagnes de banc avaient
  prouvé « la variable suit la référence » puis « l'écran suit la variable » —
  vrai, et inutile, parce que **la référence portait l'erreur**. Un banc qui
  confronte le runtime à un modèle converti ne peut que prouver le runtime
  fidèle à la conversion. C'est un JOURNAL RUNTIME par trame
  (`tools/warship_log.py` + l'instrumentation `WARSHIP_LOG_PAGE` de
  `warship/pilot.asm` : un enregistrement de 16 octets par trame vidéo dans un
  anneau en page libre, drainé par la sonde) qui a tranché : **0 divergence
  sur 7044 trames** ⇒ plus rien à chercher côté v2, l'erreur est côté arcade.
  Quand modèle et runtime concordent parfaitement et que le résultat reste
  faux, arrêter de déboguer le runtime et re-dériver la conversion depuis la
  MACHINE, pas depuis les annotations Ghidra (le commentaire de l'exporteur
  portait déjà `; speedy sign follows Conv.yratio — validate at integration`,
  un drapeau levé jamais abaissé ; et les commentaires de `tick_warship_master`
  et de `warship_inner_script_step` se contredisaient sur X/Y).

## Rythme et horloges

- **Les comptes de trames arcade se gardent tels quels** (périodes, durées de
  phase, cadences de tir) : la politique v1, conservée, est « mêmes nombres,
  horloge de jeu 50 Hz ». Ne jamais re-chronométrer en temps mur.
- **EXCEPTION `frame_time` (0x2F4B)** : c'est une horloge **demi-trame**
  (octet décimal 0x2F4A, +0,5 par trame vidéo) — tout seuil exprimé dessus
  (waves, scripts type pilote d'intro 0x1F1B/0x10C2, checkpoints) vaut
  **x2 en trames** ; c'est le `rate = 2.0` de l'exporteur de waves
  (re.arcade.r-type `ObjectWave.java`), et `lvlTimeStart[]` y donne
  l'époque de chaque stage (stage 1 : 0x600). Les deltas de mouvement de
  ces mêmes scripts s'appliquent eux **par trame vidéo** — ne pas les
  doubler. Appris sur l'intro du stage 1 (vol deux fois trop court et
  trop tôt au premier décodage).
- L'horloge de jeu est `gfxlock.frame.gameCount` (compense le frame drop).
  Cadence dérivée de l'horloge globale : `gfxlock.frame.count` (ex. tabrok
  FIX #5, tir quand `count & $7F` franchit 0 ↔ arcade `== 0` tous les $80).
- Au spawn, `ObjectWave` dépose les trames manquées dans `wave_frame_drop,u`
  (= `anim_frame_duration,u`) : l'Init les consomme (cf. pata-pata,
  `moveByScript.runByB`) pour rester calé sur l'horodatage arcade.
- En vie : `moveByScript.runByFrameDrop` déroule les pas de script au rythme
  compensé.
- **Un script de mouvement est un INDICE, pas une adresse — et il vit dans
  l'objet d'animation commun.** `moveByScript.initialize` attend dans X un
  décalage d'octets dans la LUT de `Ani_Asd_common` (`ldx anim.addr,x`, base
  posée par `moveByScript.register`), et il monte la page de cet objet avant
  de lire ; `runByFrameDrop` la remonte à chaque tour pour relire les
  segments. Un script posé dans la page de l'ennemi est donc illisible, quelle
  que soit la façon de le référencer. Marche à suivre pour un ennemi porté :
  vérifier que ses scripts sont déjà dans `src/common/fx/animation/script.asm`
  (l'export arcade couvre toute la zone de scripts, ils y sont en général),
  leur ajouter une ligne dans `index.asm` **et** `index.equ`, et référencer
  l'équate `anim_<addr>` — comme pata-pata (`ldx #anim_19ACE`) et outslay
  (`fdb anim_1A4E6`). Ne pas oublier
  `INCLUDE "src/common/fx/animation/index.equ"` dans l'unité.
  Symptôme quand on s'est trompé (cytron, 24/08/2026) : l'ennemi frémit sur
  place — quelques pixels en cent trames — parce que `sub_anim,u` pointe hors
  de l'objet d'animation et que l'interprète lit de la RAM moteur comme des
  commandes de déplacement ; `anim_frame,u` prend des valeurs hors 0-15
  (127 relevé) que le masque `andb #$0F` cache à l'affichage.

## L'ObjectRecord arcade ↔ l'OST v2

> **DEUX OCTETS DE L'OST SONT PARTAGÉS — l'Init doit lire avant d'écrire.**
> `subtype_w+1` (le descripteur de spawn) **est** `render_flags` (offset 2), et
> `wave_frame_drop` **est** `anim_frame_duration` (offset 13). Un Init qui pose
> `render_flags` ou la vitesse d'anim puis relit le descripteur ou le retard de
> wave relit ce qu'il vient d'écrire, sans que rien ne le signale. Règle :
> **tout ce qui dépend du descripteur de spawn et du retard de wave se fait en
> tête d'Init**, avant la première écriture sur ces deux octets.
> Les deux pièges se sont refermés le même jour sur le cytron (24/08/2026) :
> `render_playfieldcoord_mask` vaut `$08`, donc le `anda #$F0` de la sélection
> de script rendait 0 et les 38 cytrons du stage tiraient tous la variante 0 —
> la seule des seize qui aille tout droit ; et le rattrapage rejouait l'octet
> de variante au lieu du retard. Voir `bug/mgr.asm` et `outslay/obj.asm`, qui
> commentent déjà l'alias de `wave_frame_drop`.

| Arcade | v2 |
|---|---|
| `+0x00` tick handler, réécrit entre phases | `routine,u` = index dans la table `Routines` (fdb) du dispatch. « installe le handler 0x7048 » → un index nommé de plus ; `inc routine,u` ou `lda #n / sta routine,u` |
| `+0x04` pos_x, `+0x08` pos_y | `x_pos,u`/`y_pos,u` (+ `x_sub`/`y_sub` en 8.8), repère playfield |
| priorité d'alloc (`CX=0x8010`…) | `priority,u` 1 (devant) à 8 (fond) — choisir par comparaison visuelle, pas par la valeur arcade |
| `+0x06` slot palette corps, `+0x3E` palette hit, `get_palette_id`/`unload_palette` | **ABANDONNÉ** — palette TO8 globale (12 communes + 4 du stage). Les appels restent en commentaire (style tabrok). Feedback de hit : rien, ou bascule d'imageset dédiée si l'auteur le demande |
| `+0x1F` damage_taken monte vers `+0x2F` damage_max | modèle INVERSÉ : `AABB.p` part de `<nom>_hitdamage` (= PV) et DESCEND, mort à 0 (`lda AABB_0+AABB.p,u / beq @destroy`). Négatif = invincible, 127 = fragile. Voir `doc/arcade-combat-reference.md` pour les PV arcade |
| hitbox via `DI = &aabb_table[...]` | `AABB_0 equ ext_variables` (9 octets), `_Collision_AddAABB AABB_0,AABB_list_ennemy` à l'Init, `_Collision_RemoveAABB` à la mort ; chaque trame recopier `cx`/`cy` depuis `x_pos - glb_camera_x_pos` et `y_pos+1` |
| `do_collision_with_player_and_weapons_vN` appelé par le tick | rien à appeler : la passe `Collision_Run` est globale, l'objet ne fait que tenir son AABB à jour |
| `+0x22` compteur d'anim, recettes de sprites | table `ImageIndex` de `fdb set_<nom>_<i>` + compteur en `ext_variables`, ou `AnimateSpriteSync`/`moveByScript` ; `std image_set,u` puis `jmp DisplaySprite`. `catalog.yaml` donne nb_frames et frame_duration |
| `MOV DX,0x86xx` + `update_current_stage_score` | `scoreIdx = (0x86xx − 0x86E8) / 4` — équate dans `enemies_properties.asm`, `ldb #idx / jsr AwardScore` (plafond 99 999). Table complète : `doc/arcade-scoring-reference.md` |
| SFX queue (`0x52` explosion, `0x57` hit…) | `_soundFX.play soundFX.<Nom>,<prio>`. Six sons existent : Fire, Explosion, Bonus, PodAttach, FireBlast, PlayerHit (`soundFX.const.asm`). Mort → ExplosionSound ; hit → rien. Un son NOUVEAU est une décision d'auteur |
| tables de difficulté `ES:[BX+…]` indexées par `difficulty` | **ABANDONNÉ** — difficulté fixe (politique v1). Prendre la valeur d'indice 0 (normal), garder la table arcade en commentaire |
| `load_managed_object(prio, tick)` → CY=plein | `jsr LoadObject_x` → `BEQ` = pool plein (abandonner sans erreur) ; puis `_ldd ObjID_<enfant>,<subtype> / std id,x` et copier `x_pos`/`y_pos`. La page de l'enfant vient des tables `Obj_Index_Page/Address` du stage — l'enfant DOIT avoir sa ligne dans `objid.const.asm` + `objid.index.asm` |
| chaînage parent→enfant (`+0x3C` dernier-né, back-refs) | pointeurs OST en `ext_variables` (voir p-staff/dobkeratops pour la marche des listes de segments) |
| `unload_managed_object` (silent unload) | `DeleteObject` si l'objet a affiché (efface le sprite), `UnloadObject_u` sinon ; toujours `_Collision_RemoveAABB` avant. Silent = sans son ni score |
| `game_tick_disable_flag` (gel à la mort du joueur) | géré par le moteur : `RunFrozenObjects` redessine sans dérouler la logique — rien à coder dans l'ennemi |
| `set_direction_to(player_one)` | `setDirectionTo` / `FoeFireTarget` (api.asm) |
| tir ennemi (bydo shot, presets de tir) | chaîne résidente : `tryFoeFire` (+ `_loadFirePreset` à l'Init, presets par adresse arcade dans `src/common/lib/presets/`) ; le projectile est `_shared/foefire` ou `_shared/commonmissile` |
| sonde de tuile terrain (sentinelle `0xFA0` « sur la surface ») | API `terrainCollision.*` (init.do / do / xAxis.doRight-doLeft / update, capteurs `sensor.x/y`, résultat `impact.x`) — la carte de bits est montée par le stage |
| événements différés (`enqueue_event`) | appel direct (`jsr AwardScore`…) — pas de file d'événements en v2 |

## Chaînes de segments (acté sur l'outslay, 21/08/2026)

Un ennemi « serpent » arcade n'est pas un objet à sous-objets : c'est un
**émetteur invisible** qui alloue N ObjectRecords indépendants, tous
initialisés à la MÊME position et avec le MÊME script de mouvement rejoué
depuis son début. Le décalage temporel des spawns (une table `(handler,
délai)`) est ce qui fabrique la forme du serpent — aucun segment ne suit
géométriquement son aîné. Transposition v2 :

- **Deux ObjID** : l'émetteur (celui que la wave cite) et le segment. Le
  RÔLE du segment voyage dans `subtype` au spawn (`lda #ObjID / std id,x`
  écrit id+subtype d'un coup), puis devient l'index de routine à l'Init.
  Ordonner les rôles pour que les tests d'appartenance de l'arcade
  (« l'aîné est-il body / body_explode / neck ? ») deviennent un encadrement.
- **Le chaînage frère-à-frère** (`[+0x3c]` arcade) : l'émetteur garde le
  dernier-né dans ses `ext_variables` et l'écrit dans l'enfant suivant AVANT
  que celui-ci ne tourne — l'émetteur écrit donc directement dans l'OST du
  petit, comme l'arcade. Limite héritée : rien n'invalide le pointeur quand
  l'aîné rend son slot.
- **LE TIMING, et c'est là que tout se joue.** L'exemplaire est
  `bug/obj_main.asm` (`LiveCreator` + `Init`), pas pata-pata. L'échéance du
  prochain enfant se compte en **trames vidéo**, pas en tours de routine :
  `lda timer,u / suba gfxlock.frameDrop.count`. Ce dont le compteur **dépasse**
  zéro — le reste négatif — n'est ni jeté ni réabsorbé dans la période
  (`addb timer,u` pour recharger, jamais `ldb #période`) : il part avec
  l'enfant dans `anim_frame_duration`, et l'Init de l'enfant le rattrape par
  `moveByScript.runByB` avant que le champ ne devienne la vitesse d'anim.
  L'Init entre ensuite dans son rôle **sans refaire un pas de script**, sinon
  la trame de naissance compte double.
  Sans ça, sous un frame drop de 5 (ce que donne le rendu overlay), les écarts
  d'une chaîne à périodes 10/11 dérivent de 16 à 30 pas au lieu de 20/22 — et
  surtout l'Init, qui consomme le `wave_frame_drop` de la wave, pose d'un coup
  autant d'enfants **tous à la position zéro** : 33 trames de retard donnent
  quatre segments exactement superposés. Vécu sur l'outslay le 21/08/2026.
  Nuance à garder : `runByB` traite `B = 0` comme `B = 1` (sa garde
  anti-256-tours), donc tester `tstb / beq` avant l'appel si le retard nul doit
  vraiment valoir zéro pas.
- Un émetteur invisible se déclare `priority = 0` et n'appelle jamais
  `DisplaySprite` ; il sort par `UnloadObject_u`, pas `DeleteObject`.

## Portée de tir : convertir la distance, pas les coordonnées

Un test de distance arcade est en **pixels arcade**, et les deux axes v2
n'ont pas la même échelle (X 0.375, Y 0.75 — Y vaut le double de X). Une
distance de Manhattan `|dx| + |dy| < R` arcade devient donc, en pixels
larges, `|dx| + |dy|/2 < R * 0.375`. Vérifié sur l'outslay : `< 0x90` (144)
donne `|dx| + |dy|/2 < 54`.

## Le cast d'un stage est UNE unité : préfixer toutes les étiquettes

Depuis le group `stageN.cast`, tous les `obj.asm` du cast sont assemblés
dans la même unité. `Object`, `Init`, `Routines`, `Live`, `endCheck`,
`ImageIndex` — les noms canoniques du patron pata-pata — ne peuvent servir
qu'une fois. Chaque implémentation préfixe ses étiquettes de son nom
(`outslay.Init`, `outslay.Routines`…), y compris les équates
d'`ext_variables` (`outslay.AABB` et non `AABB_0`). Les branches courtes
deviennent vite trop courtes : un `beq` vers la routine de mort d'un objet
de 600 lignes veut un `lbeq`.

## Deux pièges de configuration relevés sur ce portage

- **`images.encoder` est une cascade PAR RÉPERTOIRE.** Seul le
  `<directory id="0">` la portait (`value="draw"`, le mode overlay). Une
  rangée `<images>` ajoutée dans un autre répertoire retombe silencieusement
  en `bdraw` : le cast du stage 2 pesait **34 675 octets au lieu de 18 806**.
  Le piège avait **déjà mordu avant ce portage** — `stage1.dobkeratopsjaw` et
  `stage1.dobkeratopssaw` (répertoire 1) sortaient encore en `bdraw`, ce qui
  en mode overlay est pire qu'un gaspillage : un sprite `bdraw` ouvre par
  `STS glb_register_s / LEAS ,Y` pour empiler le fond sauvé, or `BuildSprites`
  ne pose aucun tampon de fond dans Y. La cascade est désormais déclarée sur
  les NEUF répertoires ; c'est là qu'il faut la chercher avant d'ajouter des
  `<images>`.
- **16 Ko par direntry, pas par arène.** Un cast de 37 sprites 12x24 en
  dessin seul pèse ~17,6 Ko : il faut le couper en deux entrées, sur le
  modèle de `stage1.tabrok.imgWalk` / `dobkeratops.imgFace`. Les symboles
  qui franchissent la coupure ne coûtent RIEN au chargement tant que les
  deux entrées vivent dans la même arène — le builder les place, donc il les
  cuit (`0` octet de données de lien dans le rapport).

## Arrêter le scroll pour un boss

Un boss arcade fige la caméra lui-même — `create_gomander` (0x40:a22e) écrit
zéro dans les deux vitesses d'autoscroll (`0x2eec`, `0x2ef4`) et son
`_silent_unload` les relance. En v2, **ne pas transposer ça en baissant
`scroll_max`** comme le fait le stage 1 : la séquence de fin COMMUNE aux
stages 2-8 (`obj_endlevel`) déclenche sa victoire sur `camera >= scroll_max`,
donc baisser le plafond termine le niveau en plein combat. Le stage 1 peut se
le permettre parce qu'il a sa propre séquence. Poser `scroll_vel` à zéro et le
restaurer à la sortie est à la fois le geste arcade et le geste sans effet de
bord.

Deux propriétés à connaître avant de figer quoi que ce soit :
- `Scroll` applique `scroll_vel` **`gfxlock.frameDrop.count` fois** : la caméra
  suit le temps réel, pas le nombre de tours de boucle.
- `DrawTiles` ne repeint que si `glb_camera_move` est levé, et `Scroll` ne le
  lève que quand la caméra a bougé. En mode overlay le champ est effacé chaque
  trame, donc un scroll figé effacerait le décor sans le redessiner — la
  boucle overlay force déjà ce drapeau à 1 avant `DrawTiles`. C'est ce qui rend
  un boss à l'arrêt possible ; ne pas défaire ce forçage.

Et pour armer la fin : un vrai boss lève `globals.bossDefeated` lui-même, ce
que `obj_endlevel` honore désormais avant son combat de substitution.

## Le spawn par la wave (vérifié : `ObjectWave-subtype.asm`)

- Format d'une entrée : `AAAA` horodatage (comparé à `frame.gameCount`),
  `BB` ObjID, `CCCC` subtype ; fin `$FFFF`. Les horodatages sont ceux de
  l'arcade.
- `subtype_w` (2 octets) CHEVAUCHE `render_flags` : **lire le subtype avant
  d'écrire `render_flags`** dans l'Init (piège documenté dans la routine).
- Idiome subtype : l'octet bas encode le variant/preset (pata-pata :
  `& $0F` → index Y, et `_loadFirePreset` sur l'octet complet). Les plates
  Ghidra disent ce que l'arcade encode dans `CX` au spawn — le transposer
  dans le subtype.
- Plafond : les ObjID d'un ensemble co-chargeable ≤ 127 (`RunObjects`
  indexe par `id*2` sur 8 bits).

## L'attribut de SpriteRecipe, et la profondeur (décodé le 21/08/2026)

`write_1_sprite_b` (0x0040_1BE9) construit un sprite matériel depuis un objet
et une recette de 6 octets :

```
[SI+0] Y    = obj.pos_y + (int8) recipe[1]
[SI+2] tile =              recipe[2..3]
[SI+4] attr =              recipe[4..5], octet bas remplacé par obj.palette_idx
[SI+6] X    = obj.pos_x + (int8) recipe[0]
```

Tout ce qui est authoré **par sprite** et non par objet vit donc dans l'octet
haut de `recipe[4..5]` :

| bits | champ | conversion v2 |
|---|---|---|
| 15-14 | code de **largeur** — largeur = `1 << code` tuiles de 16×16 | dimension de l'imageset |
| 13-12 | code de **hauteur** — hauteur = `1 << code` | idem |
| 11 | **miroir horizontal** | `render_xmirror_mask` / variante `XD0` |
| 10 | **miroir vertical** | `render_ymirror_mask` / variante `YD0` |
| 9-8 | jamais posés par aucune recette de la ROM | — |
| 7-0 | palette, authorée à 0 et écrasée au blit | palette de l'objet |

Preuves, pas suppositions :

- **bit 11** — `cancer_sprite_recipes_facing_left` (0x1000_3C32) et
  `..._facing_right` (0x1000_3C44) portent les **mêmes trois identifiants de
  tuile** et ne diffèrent que par ce bit (`0x5000` / `0x5800`). Le même
  appariement gauche/droite se retrouve sur pow-armor, dop et gouger.
- **codes de taille** — cytron lit `0x5?00` (codes 1 et 1 → 2×2 tuiles =
  32×32 px) et son cadre arcade extrait fait exactement 32×32 ; wick lit
  `0x0?00` (1×1 = 16×16) pour un sprite d'une tuile. Lequel est la largeur se
  tranche sur deux cas asymétriques : `bottom-reactor-flame-straight-down` =
  `0x2000` → 1 large × 4 haut (une flamme vers le bas), et `horizontal-laser`
  = `0x4400` → 2 large × 1 haut. Donc **15-14 = largeur, 13-12 = hauteur**.
- **bits 9-8** — recensement des 1 134 recettes référencées par le catalogue :
  22 valeurs distinctes seulement, ces deux bits nuls partout.
  (`re.arcade.r-type --extract-spriteattr`)

### Il n'y a AUCUN bit de priorité

C'est la question qui avait ouvert ce décodage, et la réponse est négative des
deux côtés :

- côté sprite, tous les bits sont expliqués par la taille et les miroirs ;
- côté tuile, l'octet d'attribut vaut `0x80 | banque_de_palette` sur **toutes
  les cellules des huit niveaux** (bit 7 toujours armé, donc pas une catégorie
  par cellule), et les bits 4-5 du mot d'identifiant sont toujours nuls.

**La profondeur n'est donc pas authorée par objet.** Elle découle de la couche
dans laquelle une entité se dessine :

| couche | entités | profondeur v2 |
|---|---|---|
| **sprite** (`meta_sprite`) | les 33 entités du catalogue : bink, boldo, brood, bug, cancer, compiler, cytron, dobkeratops, dop, geld, gouger, mid, mikun, newt, outslay, p-staff, pata-pata, pow-armor, pursuer, scant, shell, slither, tabrok, wick, win, zoid, foefire, bonus, starfield… | `BuildSprites` |
| **tilemap** (`tile_script`, `tile_grid`, `tile_recipe`) | l'engloutissement du gomander, l'épave du warship, le panneau de ville — plus les écrivains à l'exécution : le mur de la rotonde du shell, les cellules Bydo de cytron, l'effaceur de tilemap du Dobkeratops, le nettoyage de chambre du Bydo core | profondeur du décor |

Règle de portage : **si l'arcade dessine l'entité dans la tilemap, elle va à la
profondeur du décor ; si elle passe par `write_1_sprite_*`, elle va dans la
passe sprites.** Un objet qui doit apparaître *derrière* le décor sans être de
la tilemap est un choix du portage, pas une donnée arcade — le noter comme
écart.

Non tranché : l'ordre global entre la couche sprite et le plan de premier plan.
Il n'est pas dans les données du jeu ; il faudra le lire dans le pilote vidéo
M72 ou l'observer sous MAME.

## Un tick dédié ne veut pas dire un art dédié (21/08/2026)

Quand un ennemi tire, la question « projectile commun ou projectile propre ? »
ne se tranche PAS sur l'existence d'une routine dédiée. Trois cas relevés en
inspectant les six tireurs du jeu, et les trois se ressemblent dans l'index de
connaissance (`projectile/`, `actor/enemy_*`) :

| ennemi | tick | table de recipes | verdict |
|---|---|---|---|
| blaster, pata-pata, cancer, bug | `create_foe_fire` 0x40:f657 | `0x1000_84ae` | commun, rien à faire |
| shell 0x40:6e27, newt 0x40:7435 | **dédié** | `0x2eee` / `0x327e` | **art commun quand même** |
| outslay 0x40:95f1 | dédié | `0x1000_417e` | art dédié, à extraire |

Les tables du shell et du newt sont **identiques à l'octet près** à celle du
bullet commun (mêmes tuiles 0x00dc/0x00dd, même AABB rayon 2), au seul ancrage
près : `f0 f0` (-16,-16) contre `f8 f8` (-8,-8). Leur tick n'est dédié que pour
le *comportement* — le shell tue son tir passé 192 px derrière son anneau, le
newt a un TTL avant d'armer la sonde terrain.

**Le test qui tranche : lire les octets de la table, pas le nom de la
routine.** `bridge_data_peek` sur la base du `ADD BX,<base>` juste avant
`write_1_sprite_a`, et comparer avec `0x1000_84ae`. Deux tuiles miroitées
(attr 0x00/0x04/0x08 sur deux ids) = c'est le bullet commun. Quatre ids
distincts = art propre.

Le bydo shot de l'outslay est le seul vrai cas : quatre tuiles (0x09fe, 0x09ff,
0x0af0, 0x0af1), une boule qui enfle de 6x6 à 12x12, et une AABB à SOI
(`0x1000_4196`, rayon 4 = le double du commun).

### Deux détails de cadence à ne pas rater

`run_foe_fire` calcule sa frame avec `(BP >> 3 + global_counter) & 0x18` : le
`BP >> 3` **désynchronise volontairement les instances** (deux bullets alloués
à des offsets d'ObjectRecord différents ne tournent pas en phase). Le bydo shot
fait `(global_counter & 6) * 3` — **sans** `BP >> 3` : les huit tirs d'une salve
battent en phase. Porter la désynchro sur un projectile qui n'en a pas est une
erreur visible à l'écran.

Et le pas : `& 0x18` sur un stride 6 tient une image 8 trames ; `& 6` la tient
2 trames. Côté v2 la table étant en `fdb` (stride 2), `andb #6` donne
directement le décalage — voir `outslay/shot.asm`.

### Convertir l'art sur la BONNE palette

`arcade_to_sprites.py` convertit tout `images/original/` d'un coup, ce qui
réécrirait les jeux déjà commités — et la campagne palette les a retouchés
depuis, donc aucune invocation ne les reproduit. Pour n'ajouter qu'un jeu :
monter un répertoire temporaire ne contenant que `images/original/<jeu>/`, et
passer `--palette <un PNG déjà commité de l'objet>` — un chemin de PNG ouvre
les cases 13-16 et lit la palette réellement employée. Le projectile tombe
alors exactement sur la palette de l'ennemi qui le tire (ce que l'arcade fait
aussi : le bydo shot et le corps de l'outslay partagent la palette 0x3f).

## Les xrefs Ghidra ne sont pas exhaustives — balayer les octets (21/08/2026)

En relevant les écritures de `end_level_sequence_flag` (0x2FC1), `bridge_xrefs_to`
a rendu **4** sites. Le vrai compte est **11**, et l'un des manquants
(`0x40:B970`, la fin du stage 7) portait justement une information qu'aucun
autre site ne donnait. Ghidra n'enregistre une xref de donnée que si son
analyse a typé l'opérande ; sur du 8086 fraîchement désassemblé, beaucoup de
`MOV byte ptr [imm16], imm8` y échappent.

**Quand une question est de la forme « tous les endroits qui… », balayer le
binaire.** `out/rom/maincpu.bin` est dans le dépôt d'extraction ; l'adresse
linéaire d'un `0x0040:offset` y vaut `0x400 + offset`. Chercher le motif
d'instruction complet, valeur immédiate comprise, révèle du même coup les
**variantes de valeur** — c'est ainsi qu'est apparu le `0x0F` du stage 8 là où
les huit autres bosses posent `0xFF`.

```python
d = open("out/rom/maincpu.bin", "rb").read()
pat = bytes.fromhex("c606c12f")     # MOV byte ptr [0x2fc1], imm8
i = 0
while (i := d.find(pat, i)) >= 0:
    print("0x%04X <- 0x%02X" % (i - 0x400, d[i+4])); i += 1
```

Ne pas conclure « aucun autre stage ne fait ça » sur la seule foi des xrefs :
la conclusion négative demande le balayage.

## Un ratio par axe, y compris pour les seuils (21/08/2026)

`Conv` donne deux rapports, `144/384 = 0,375` en X et `-180/240 = -0,75` en Y.
Ils s'appliquent aussi aux **grandeurs scalaires** — rayons, seuils, zones
mortes — et pas seulement aux coordonnées. La zone morte de l'autopilote
arcade vaut 4 px arcade sur les deux axes, ce qui donne **2 en X et 3 en Y**,
pas une valeur unique. Elle avait été portée à 3 partout : le chiffre du Y
appliqué aux deux, soit une bande horizontale deux fois trop large.

Le signe qui aurait dû alerter : la vitesse du même autopilote était, elle,
déjà convertie par axe (`scale.XN1PX` = 0,375 px/trame contre `scale.YN1PX` =
0,75). Quand une vitesse est convertie par axe, le seuil qui la gouverne l'est
aussi.

Formules complètes, vérifiées sur deux valeurs déjà portées :

```
X_v2 = (X_arcade - 320) * 144/384 + 8
Y_v2 = (Y_arcade - 128 - 16) * -180/240 + 190     ; axe arcade vers le haut
```

Le `- 16` du Y est la hauteur du bandeau arcade (`Conv.HeightHUDArcade`) ; on
l'oublie facilement, et il décale de 12 px v2.

## Un écart n'est pas un bug tant qu'on n'a pas vu la suite (21/08/2026)

Quand un stage fait autrement que les autres, la tentation est de conclure au
défaut — surtout si une annotation d'analyste va déjà dans ce sens. Le stage 8
pose `end_level_sequence_flag = 0x0F` là où les huit autres bosses posent
`0xFF`, ce qui déplace le point de ralliement du vaisseau ; une note
« should be xff ? » traînait sur la ligne, et j'ai conclu à l'accident.

C'était faux, et la réponse était à deux instructions de là : le `unload` de
fin (0x40:C280) est annoté « Stage 8 ending sequence takes over ». **Les
stages 1 à 7 s'achèvent ; le stage 8 termine le jeu.** Pas de stage cleared,
pas de relevé de score — donc aucune raison de rallier le vaisseau au centre.
Il est placé pour la scène finale, plus à gauche et plus haut, ce qui dégage
le centre et le bas du champ.

**La règle : avant de qualifier un écart d'accident, remonter à ce que la
séquence rend comme main.** Un chemin qui diverge sert souvent un événement
différent, pas le même événement mal fait. Et se demander si la valeur a
d'autres lecteurs : ici le drapeau n'en a que deux dans toute la ROM, tous
deux de simples tests de non-nullité — `0x0F` n'est pas un code, c'est
« n'importe quoi sauf 0 et 0xFF ».
