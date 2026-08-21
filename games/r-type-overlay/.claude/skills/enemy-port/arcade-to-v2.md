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
- **Espaces différents** : l'arcade tient ses positions en repère ÉCRAN — un
  objet posé au sol « dérive de `scroll_amount` » à chaque trame. La v2 tient
  `x_pos,u`/`y_pos,u` en repère PLAYFIELD avec
  `render_playfieldcoord_mask` : l'objet ancré au décor **ne bouge pas**, la
  caméra passe. Traduction : supprimer les additions de `scroll_amount`,
  garder seulement le mouvement propre.
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

## L'ObjectRecord arcade ↔ l'OST v2

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
- **La compensation de frame drop** de l'émetteur se fait en déroulant son
  pas de script `gfxlock.frameDrop.count` fois (et `wave_frame_drop` fois à
  l'Init) — pas en compensant dans les délais.
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
