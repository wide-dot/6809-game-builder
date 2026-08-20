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
