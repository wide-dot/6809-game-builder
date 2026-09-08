# La mort du Gomander : la cascade d'explosions arcade, face au Dobkeratops

Analyse du 08/09/2026, base Ghidra `maincpu` (MCP asm-ark). Question posée :
comment la borne fait exploser le boss du stage 2, en quoi cela diffère du
stage 1, et ce que le code déjà en place (stage 1, compiler, gomander)
permet de réutiliser.

## 1. Ce que fait la borne au stage 2

Trois routines, toutes dans le sous-système `gomander` de la base :

**`_arm_death_sequence` (40:A4CD)** — PV épuisés, atteint depuis l'état
orbe ouvert :

- `stage_unload_request` levé, score 0x8718 mis en file ;
- **spawn d'un acteur enfant** `tick_gomander_death_explosion_cascade`
  (40:A6A5, priorité 0xEF00) à la position du boss + (0, +4), curseur de
  script = 1000:5602, durée de vie 0x160 = 352 trames ;
- une boucle qui masque les attributs de 0x480 mots de la VRAM tilemap
  (D000:1C02, pas 4, `AND 0xF`) — la même « préparation de fondu » que le
  jalon 0x1760 de `_combat_join` ;
- compte à rebours de mort 0x180 = 384 trames, état → `_tick_death_sequence`.

**`_tick_death_sequence` (40:A523)** — la chronologie, DÉJÀ portée dans
`gomander/obj.asm` (DEATH, DEATH_2NDBLAST, DEATH_LATCH) :

| compteur | événement arcade |
|---|---|
| = 0x100 (t+128) | SFX 0x1B + `palette_blackout_15_bg(7)` : la palette du fond fond vers le noir, une entrée toutes les 8 trames |
| = 0x80 (t+256) | SFX 0x1A + 0x1C, `end_level_sequence_flag` : le niveau enchaîne |
| < 0x80 | secousse : le scroll Y du fond alterne 0x00C0 / 0xFF00 toutes les deux trames |
| = 0 (t+384) | `_silent_unload` : autoscroll relancé, slot rendu |

Les segments d'outslay et les pellets d'orbe testent `tick == A523` et se
nettoient d'eux-mêmes pendant cette phase.

**`tick_gomander_death_explosion_cascade` (40:A6A5)** — l'acteur enfant,
chaque trame :

- suit le scroll Y du fond (sans objet chez nous, le scroll est figé) ;
- **trame impaire du compteur global : rien** (décrémente la vie et sort) ;
- **toutes les 4 trames** : tirage `random & 6` ; 0 (une chance sur quatre)
  = silence, sinon SFX 0x51/0x52/0x53 ;
- **une explosion par trame paire** : `explosion_small_x3` (40:E7B6) par
  défaut, **une chance sur quatre** de la remplacer par
  `big_explosion_with_grey_brown_flash_disk` (40:E817) ;
- position = boss + (dx, dy) lus **par indirection** : l'entrée courante du
  script est un pointeur proche vers un couple de mots ; curseur += 2 ;
  terminateur 0x0000 → retour en tête (le script boucle) ;
- vie à 0 → décharge. Pause → décharge anticipée.

### La table de positions (1000:5602)

Décodée cette session (script `decode_gomander.py`, à refaire depuis
`maincpu.bin` dans le générateur) :

- **288 pointeurs** (576 octets + terminateur) vers **68 couples distincts**
  (dx, dy) situés en 1000:54F2..55FE — c'est la zone que la base étiquette
  `gomander_orb_sprite_offsets` : le plan des cellules de sprite du corps,
  relatif au centre (0x200, 0x104). La cascade explose donc *sur les
  cellules du corps*, chaque cellule revenant environ quatre fois dans un
  ordre brassé à la main ;
- étendue arcade : dx −120..+128, dy −112..+16 (axe Y arcade vers le haut :
  le nuage pend SOUS l'orbe) ;
- 352 trames à une explosion par trame paire = **176 explosions** : le
  script n'atteint jamais son terminateur (288 entrées). Seules les 176
  premières comptent.

Le corps du Gomander n'est **jamais effacé** : il est dans la tilemap de
fond, et c'est le blackout de palette de t+128 qui le fait disparaître avec
le décor.

## 2. Ce que fait la borne au stage 1 (Dobkeratops)

**`init_dobkeratops_explosion` (40:9D10)** — score 0x8714, `parent+0x32 = 1`
(le signal « enfants, explosez » lu par mâchoire, queue et nerfs), puis le
**slot du monstre lui-même** passe sur `dobkeratops_explosion` avec le
curseur 1000:454E.

**`dobkeratops_explosion` (40:9D30)** — chaque trame (le délai se réarme à 1
à chaque tour, relique) :

- SFX `0x50 + (random & 3)`, un quart de silence ;
- lit un **triplet de 6 octets** (dx:word, dy:word, constructeur:word),
  spawne l'explosion avec CE constructeur à monstre + (dx, dy), et lui
  glisse la table d'effacement 1000:452E en +0x3E ;
- curseur += 6 ; sentinelle 0x8000 → palettes rendues, slot rendu.

Table : **62 triplets** (sentinelle vérifiée en 1000:46C2), donc 62
explosions en 62 trames. Quatre constructeurs y figurent : `small_x3`
(E7B6), `small_x2` (E7BE), `big grey/brown` (E817) et
**`boss_explosion_and_tile_erase` (E700)** — visuel de small_x3, mais 16
trames après sa naissance elle écrit 16 tuiles vides (0xFA0) dans la tilemap
de fond en marchant le motif 1452E (un bloc 4×4 en colonne, sondé à
(pos −12, +12)). C'est ce mécanisme que la mémoire retient comme « la map
collision » : ce n'est pas la carte de collision, c'est **l'effacement du
corps tuile par tuile**, l'explosion servant de gomme.

## 3. La comparaison

| | Dobkeratops (stage 1) | Gomander (stage 2) |
|---|---|---|
| qui déroule | le slot du monstre, après sa mort | un acteur enfant dédié |
| cadence | une explosion par trame | une par trame paire |
| durée | 62 trames (fin de table) | 352 trames (durée de vie), table bouclante |
| positions | 62 triplets fixes, forme dessinée entrée par entrée | 288 pointeurs vers 68 cellules du corps, 176 consommées |
| type | par entrée (4 constructeurs) | small_x3 fixe, 25 % de grosse au hasard |
| son | par explosion, $50..$53, 1/4 de silence | toutes les 4 trames, $51..$53, 1/4 de silence |
| effacement du corps | 16 explosions « gomme » effacent des blocs 4×4 | aucun ; blackout de la palette du fond à t+128 |
| suite | signal enfants + séquence du parent (9AC8) | compte à rebours 384 : 2e déflagration, latch, secousse, décharge |

Le mécanisme du Gomander est **le patron canonique des autres boss** : la
base le dit pour bellmite (`tick_bellmite_death_explosion_cascade`, 40:B4C9,
21 entrées, 64 trames) et compiler (`compiler_part_destroy_with_explosion_
cascade`, 40:B062, 64 trames) ; bydo (40:C284) est la variante à offsets
aléatoires. Même forme partout : parité globale, 25 % de grosse, SFX toutes
les 4 trames, liste d'offsets avec retour en tête, durée de vie. Le
Dobkeratops est l'exception : liste finie, un constructeur par entrée,
et la gomme de tilemap.

## 4. Ce qui existe déjà en v2

**`dobkeratopsExplosion` — `src/enemies/dobkeratops/explosion.asm`** (v1
1:1, objet commun n° 29, direntry `stage1.dobkeratopsexplosion` dans l'arène
`stage1.foes`). Un marcheur de triplets de **3 octets** (dx, dy, subtype)
sur la table `1454E_preset_dobkeratops-explosions.asm` (62 entrées, déjà à
l'échelle v2 : x×0,375, y×0,75 signe inversé — vérifié sur la première :
arcade (36, 40) → ($0E, $E2)). Le 3e octet est le subtype d'explosion :
$00 smallx3 (12), $02 smallx2 (6), $0C big.brown (13), **$0E smallx3.erase
(31)**. Il consomme `frameDrop.count` entrées par trame rendue (compensation
correcte), s'arrête au $80, et le monstre le fait naître à sa position dans
`Delete` (`monster.asm`). Le son est porté par l'objet explosion
(`explosion.sfx.cascade`, tirage par explosion, un quart de silence — le
même tirage que 9D30). Le subtype `.erase` est aujourd'hui l'animation
smallx3 nue : en overlay, cesser de dessiner EST l'effacement
(`overlay-erase-by-omission.md`), la gomme n'a plus d'objet.

**`PartBoom` — `src/enemies/compiler/obj.asm:989`** : le patron canonique
(B062) porté DANS l'objet de la pièce : 64 trames, une entrée par trame
paire, listes de couples signés de 2 octets générées par
`tools/gen_compiler_death.py` depuis la ROM. Écart non consigné : pas de
25 % de grosse (smallx3 seul, son `cascade2`). Il vit dans l'OST de la
pièce, pas en enfant.

**`gomander.Boom` / `gomander.Flash` — `src/enemies/gomander/obj.asm`** :
la chronologie de mort est portée (384, jalon 0x100, latch 0x80) mais la
cascade est « réduite à une explosion par jalon » (une grosse à ArmDeath,
une à la 2e déflagration) ; le blackout de palette est remplacé par un strobe
du décor (`tilemapanim` blink toutes les 8 trames sur les 128 dernières).
Le budget `ext_variables` du gomander est **plein** (20/20, le curseur
d'orbe occupe le 19).

**`tilemapanim` + `tilemap.patch`** : l'animation de décor comme objet — le
seul moyen v2 de toucher le corps du boss (qui est dans la tilemap), si l'on
voulait un équivalent du blackout.

## 5. Ce qui se réutilise, et comment

Le bon candidat est le **marcheur du Dobkeratops**, pas `PartBoom` : il est
déjà un objet enfant positionné par son parent (la forme arcade du
Gomander), il compense le frame drop, et son format à 3 octets (dx, dy,
subtype) absorbe le tirage « 25 % de grosse » en le **pré-tirant à la
génération** — de la variété déterministe, comme le compiler. Il lui manque
deux choses :

1. **une cadence** : une entrée par trame paire, et non par trame. Un octet
   « diviseur » (ou un reste de trames dans l'OST) ; le tour de boucle
   consomme `frameDrop.count / 2` entrées en gardant le reste ;
2. **rien d'autre** : la table peut être **tronquée aux 176 entrées
   consommées** (la borne n'en lit jamais plus), donc pas de boucle ni de
   durée de vie — la fin de table tient lieu des 352 trames.

Deux voies pour l'obtenir :

- **A. Un objet commun `bosscascade`** (`src/common/fx/…` ou
  `src/enemies/_shared/`), copie du marcheur v1 plus la cadence, exporté sous
  un nom propre. Le fichier v1 du Dobkeratops reste intact (règle 1:1) ; le
  stage 1 garde le sien. Prix : ~90 octets de code dupliqués une fois.
- **B. Étendre le fichier v1** avec la cadence sous `V2-DEVIATION` et le
  charger aussi au stage 2. Plus économe, mais c'est un fichier suivi par le
  drift-check et le stage 1 n'en a pas besoin.

Recommandation : **A**, et faire de l'objet commun n° 29 « la cascade de
mort du boss » : le stage 1 y met `dobkeratopsExplosion`, le stage 2 (puis
5 et 8) y met `bosscascade` — deux unités alternatives sous le même
identifiant, ce que l'index par stage permet déjà (le slot 29 du stage 2
est un `stage.placeholder`). Un alias d'équate suffit, sans renommer le
symbole v1.

**La table** : un générateur `tools/gen_gomander_death.py` sur le modèle de
`gen_compiler_death.py` — lire les 176 premiers pointeurs de 1000:5602,
déréférencer dans 1000:54EA, convertir (x×0,375 ; y×−0,75), pré-tirer la
grosse (`random & 6 == 0` → subtype big.brown, graine fixe), écrire des
triplets `fcb dx,dy,subtype` terminés par `$80` : **529 octets**. Variante
plus courte si la place manque : 68 couples (136 o) + 176 index d'un octet
avec le bit 7 pour la grosse (176 o) = 312 o, au prix d'une indirection dans
le marcheur — à ne faire que si nécessaire.

**Ancrage** : l'enfant naît à la position du gomander (camera+80, 103) plus
(0, −3) pour le +4 arcade — le geste de `gomander.Boom` aujourd'hui.

**Place** : le cast du stage 2 (page $11) n'a **38 octets** libres ; la
cascade sera son **propre direntry** dans l'arène `stage2.foes` (comme
`stage2.cast.zoid`), page résolue par le symbole `.page` dans
`objid.index.asm`. Trous mesurés sur le dernier build : page $13 1 486 o,
$15 1 035 o, $14 556 o, $12 461 o — code + table à 3 octets (~620 o)
tiennent dans $13 ou $15.

**Son** : le tirage par explosion de l'objet explosion vaut le tirage
« toutes les 4 trames » de la borne à un facteur 2 près ; les priorités
plafonnent. C'est déjà l'écart accepté au stage 1.

**Charge** : 176 explosions en 352 trames, smallx3 vivant 30 trames et la
grosse 54 : 15 à 20 objets en vol sur les 60 du pool, pendant 7 secondes.
Le stage 1 en fait naître 62 en 62 trames (pic plus haut, plus court). À
mesurer sous toje : le frame drop pendant la cascade, et que les serpents
en vie (outslay) se retirent bien pendant la mort — la borne les fait
partir sur l'état A523.

**Ce qui ne se porte pas** : le blackout de la palette du fond (une seule
palette chez nous) — le strobe existant reste ; la secousse verticale (pas
de scroll Y fin) — idem. Si l'on veut que le corps DISPARAISSE à t+128,
c'est un descripteur `tilemapanim` de tuiles noires sur le rectangle du
corps, à générer comme les tubes — c'est l'équivalent v2 de ce que la gomme
1452E fait au stage 1, mais la borne ne le fait pas au stage 2.

## 6. Sources

- Ghidra `maincpu` : 40:A4CD, 40:A523, 40:A6A5, 40:A473 (gomander) ;
  40:9D10, 40:9D30, 40:E700, 40:E71C, 40:E75C (dobkeratops) ; 40:B062,
  40:B4C9, 40:C284 (les autres boss) ; données 1000:5602, 1000:54EA,
  1000:454E, 1000:452E.
- v2 : `src/enemies/dobkeratops/explosion.asm`, `monster.asm` (Delete),
  `src/common/lib/presets/1454E_preset_dobkeratops-explosions.asm`,
  `src/enemies/compiler/obj.asm` (PartBoom), `tools/gen_compiler_death.py`,
  `src/enemies/gomander/obj.asm` (Boom, Flash, ArmDeath, Death),
  `src/common/fx/explosion/`, `src/common/fx/tilemapanim/obj.asm`,
  `src/stages/02/objid.index.asm`, `dist/occupancy-fd.html`.

## 7. Réalisation (08/09/2026, cadrage auteur)

Trois précisions de l'auteur sur l'attendu : ne pas stocker les 176 entrées
(« on ne pourra pas les afficher »), **échantillonner sur la base de 8
images par seconde** ; le retrait des outslay **comme l'arcade** ; et **aucun
autre effet secondaire** que les explosions.

- **`src/common/fx/bosscascade/obj.asm`** — le marcheur commun : une entrée
  {dx, dy, subtype} toutes les `bosscascade.PERIOD` trames vidéo, frame drop
  compensé (reste porté dans l'OST), fin de table `$80`, `UnloadObject_u`.
  Il ne dessine rien ; le son est celui de l'explosion (bits 4-6).
- **`tools/gen_gomander_death.py` → `src/enemies/gomander/explosions.asm`**
  (commis, comme celui du compiler) : les 176 spawns arcade lus dans
  1000:5602, **un sur quatre** (une entrée toutes les 8 trames, 44 entrées,
  352 trames tenues), conversion x×0,375 / y×−0,75, la grosse explosion
  pré-tirée à graine fixe (11 sur 44, le quart de la borne). 133 octets de
  table.
- **`src/enemies/gomander/cascade.unit.asm`** — l'unité, son propre direntry
  `stage2.cascade` (arène `stage2.foes`, placé page $12, 245 octets), chargé
  par `scenes.stage2`. Le slot commun 29 devient `ObjID_bosscascade` (alias
  de `ObjID_dobkeratops_explosion`) ; l'index du stage 2 y pointe
  `bosscascade.Object` avec la page de l'unité.
- **Gomander** : `ArmDeath` lève `gomander.dying` (un octet de la page du
  cast, tenant lieu de l'adresse de tick a523) et fait naître l'enfant à
  (0, −3) ; `Boom`, la seconde déflagration et `d2nd` sont retirés, et le
  strobe du décor des 128 dernières trames aussi (retiré dans un second
  temps : il clignotait sous la cascade — aucun effet hors les explosions).
- **Outslay** : la marche des records passe par le retrait du drain (boîte,
  slot, état 3) dès que `gomander.dying` est levé ; le maître se rend dans la
  même boucle ; tête, finalizer et tirs bydo se déchargent en silence
  (954b/9569 : ni son, ni score, ni explosion).
- Slots de lien inchangés (24) ; le cast grossit de 12 octets (14 380).

**Vérifié sous toje (08/09/2026)** : rtype_bench 7/7 (chaîne 1→2→3, qui
passe par le timeout du gomander) ; et la sonde `tools/gomander_death_probe.py`
(coup fatal posé dans la boîte) : cascade née à +2 trames, objets outslay
3 → 0 à +20, 3 à 6 explosions en vol jusqu'à +340, cascade rendue à +360,
`bossDefeated` à +256, stage 3 atteint. Le nuage se pose sur le corps du
boss (captures `cascade-60/160/280.png`).

## 8. Le tremblement et la disparition du boss (analyse du 08/09/2026, rien de modifié)

### Ce que fait la borne, mesuré dans `_tick_death_sequence` (40:A523)

**Le plan qui bouge est le plan AVANT**, celui du boss. Les deux écritures
de 40:A54A/A55D vont dans la case 0x2EF0 de la table des vitesses ;
`auto_scroll` (40:04DC..04FA) l'accumule dans `scroll_y_bg1` (0x2EC4/0x2EC5)
et `program_scroll_registers` sort cette valeur sur le port $80, le scroll Y
du plan avant (MAME : `m_scrolly[0]`, le fg). Le delta par trame est écrit
en 0x2ED2 — c'est celui que l'acteur de cascade ajoute à son Y : les
explosions naissent sur le plan qui bouge, elles le suivent.

**Le mouvement**, pendant les 255 dernières trames (compteur de 0xFF à 1 —
le plate comment de Ghidra dit « < 0x80 », le code non : après le `== 0x100`
et le `JNC` sur `>= 0x100`, le `== 0x80` ne garde que le son et le latch,
et le bloc a54a tourne pour tout le reste — corrigé le 08/09 après la
première vidéo) :

| parité de (compteur & 2) | vitesse Y (8.8) | par trame |
|---|---|---|
| bit levé (2 trames) | 0x00C0 | +0,75 px |
| bit baissé (2 trames) | 0xFF00 | −1,00 px |

Par cycle de 4 trames : +1,5 − 2 = **−0,5 px net**, donc **−32 px sur les
255 trames** ; un scroll Y qui baisse fait descendre le contenu : **le plan
avant coule de 32 px** (24 lignes TO8), de la seconde déflagration (t+128)
à la décharge, avec une **secousse d'environ 2 px à 15 Hz**.
`_silent_unload` remet la vitesse à zéro : le plan reste descendu, le flux
de fin de stage recharge le suivant.

**La disparition** n'est pas le mouvement, c'est la palette. À t+128
(`_death_second_blast`), `palette_blackout_15_bg(7)` arme 15 entrées de
`cycling_palette_table_2` — **la palette des tuiles**, commune aux deux
plans (les sprites ont l'autre) — vers le noir, un pas toutes les 8 trames,
0x1F pas : **noir complet à t+376**, juste avant la décharge à t+384. Le
tremblement (t+256..384) se joue donc sur un décor déjà à moitié éteint,
qui finit noir pendant qu'il coule : c'est le « disparaît vers le bas ».
Descente et fondu commencent ensemble, à t+128.
Les sprites (la cascade) gardent leurs couleurs.

### Ce que la v2 sait faire

**La hauteur de rendu de la tilemap se règle, gratuitement.**
`DrawTilesCols` calcule le haut de ses colonnes par
`scroll_vp_y_pos × 40 + glb_screen_location_1` (scroll-columns.asm, le
prologue) : un octet en lignes écran, lu à chaque trame. Le décaler d'une
unité descend toute la carte d'une ligne, sans une instruction de plus —
la carte est de toute façon repeinte entière à chaque trame en overlay.
La secousse et la descente se font donc en écrivant `scroll_vp_y_pos`
depuis la routine de mort : 11 → 23 en 128 trames, ±1 ligne de tremblement.

Trois contraintes, toutes au bord bas :

1. **Rien ne clippe.** La carte du stage 2 occupe les lignes 11-190 (15
   rangées de 12) ; le champ effacé par `playfield.clearBlast` s'arrête à
   190, le HUD tient les lignes 191-199 (beam en 193). Une descente de 12
   lignes pose la dernière rangée sur 191-202 : elle recouvre le bandeau et
   dépasse l'écran de 3 lignes (120 octets).
2. **Le dépassement est inoffensif** : derrière les 8 000 octets d'une
   demi-page vidéo il reste 192 octets libres ($BF40-$BFFF, $DF40-$DFFF ;
   pages 2 et 3 pareilles), rien n'y est réservé — jusqu'à 4 lignes de
   débordement n'écrasent rien.
3. **Le bandeau HUD garderait les résidus** : `hud.normal` repeint chaque
   trame le beam, les vies et le score, mais pas les libellés « 1P- » et
   « BEAM », posés une fois. Des tuiles qui y coulent y laissent leurs
   pixels. Deux parades : `playfield.clearBlastFull` (les 200 lignes, +89
   poussées soit +11 % du blast, le temps de la mort) en repeignant les
   libellés ; ou un clip par rangée dans une variante de `DrawTilesCols`
   (les cellules d'une colonne sont dans l'ordre des rangées : `cmpd`
   contre la borne puis saut de colonne, ~9 cycles par cellule, ~400 par
   trame, assemblée à part pour ne rien coûter hors de la mort) — mais un
   clip par cellule entière fait disparaître la dernière rangée dès qu'elle
   mord la borne, pas ligne par ligne.

**Les explosions suivent** comme sur la borne : l'ancre de la cascade est
un objet, il suffit qu'il ajoute le même delta à son `y_pos` (une globale
« descente courante », lue à chaque spawn) ; les explosions déjà nées ne
bougent pas — sur la borne non plus (`run_explosion` n'ancre qu'en X).

**La disparition ne se reproduit pas par la palette** : une seule palette
pour les tuiles et les sprites, un fondu éteindrait la cascade avec le
décor. Ce qui reste possible :
- éteindre seulement les quatre entrées propres au stage (5, 7, 15, 16 —
  les teintes du boss) : partiel, les couleurs communes restent ;
- **la dissolution par cellules** : puisque les tuiles sont peintes AVANT
  les sprites pendant la mort (`globals.tilesBehind`), une variante de
  `DrawTilesCols` peut sauter les cellules dont une clé pseudo-aléatoire
  (par exemple `(colonne × 7 + rangée × 13) & 31`) est sous un seuil qui
  monte de 0 à 31 sur 248 trames : le décor s'efface cellule par cellule
  jusqu'au noir, les explosions par-dessus intactes. ~15 cycles par
  cellule, ~700 par trame, dans la variante seulement ;
- le fondu pixel du moteur (`FadeOut`) n'est pas utilisable ici : le décor
  étant repeint entier à chaque trame, il faudrait le rejouer en entier à
  chaque trame (jusqu'à 80 cellules de 400 px), hors de prix.

**Ce que ça coûterait, au total**, si l'auteur retient descente + secousse
+ dissolution par cellules : une globale de descente, quelques lignes dans
`gomander.Death` (le compteur existe, les jalons aussi), un ajout dans
`bosscascade` (le delta à la naissance), une variante `DrawTilesColsDeath`
(clip + dissolution, ~1 100 cycles par trame pendant 2,5 s), et le blast
plein ou le repeint des libellés pendant la mort. Rien dans la boucle
normale.

### Réalisation (08/09/2026, cadrage auteur : « tout sauf la disparition »)

- `globals.tilesDrop` (+162, signé, lignes) : la descente courante du décor ;
  bloc `globals` à $A3, pile en $9E6E.
- `gomander.Death`, sous le jalon 0x80 : la hauteur est **calculée depuis le
  compteur** (sûre au frame drop) — e = 128 − compteur, tendance 3·(e/4)/8
  lignes (0 → 11), une ligne plus haut sur les deux trames « montantes » du
  cycle de quatre ; écrite dans `scroll_vp_y_pos` (11 + descente) et dans
  `globals.tilesDrop`. `Init` rend les deux. `Finish` laisse le décor
  descendu, comme `_silent_unload`.
- `bosscascade` ajoute `globals.tilesDrop` au Y de chaque explosion à sa
  naissance : l'ancre suit le plan, comme l'acteur arcade (a6a8).
- **Aucun traitement de bandeau** : le masque du champ (opaque aux lignes
  191 et 199, partiel sur 192-198) et le HUD (sept cases de vies, sept
  cellules de score, cinq segments de beam, noirs compris) repeignent toute
  la bande à chaque trame ; les trois lignes de dépassement tombent dans les
  192 octets libres derrière chaque demi-page vidéo.
- Ni variante de `DrawTilesCols`, ni dissolution : rien dans la boucle
  normale, une lecture d'octet de plus par explosion.
- Vérifié sous toje : rtype_bench 7/7 ; sonde `gomander_death_probe.py` :
  `drop` 0 → −1 → +2 → +4 → +6 → +8 → +10 → +11 sur les 128 dernières
  trames, `scroll_vp_y_pos` 11 → 22, cascade et fin de stage inchangées,
  stage 3 atteint ; captures `sink/cascade-320/360/380.png`.

### Correction du 08/09/2026, après la première vidéo (retour auteur)

- **Descente** : elle partait à t+256 et faisait 12 lignes — le plate
  comment de Ghidra ; le code fait 255 trames depuis t+128, 24 lignes.
  `gomander.DEATH_SINK` (0x100) déclenche, `e = 256 − compteur`, tendance
  3·(e/4)/8 de 0 à 23. La dernière rangée descend jusqu'à la ligne 214 :
  les 15 lignes de trop vont dans les 192 octets libres derrière le plan,
  puis dans les lignes 0-10 de l'autre plan (repeintes chaque trame par le
  masque) ou dans la ROM moniteur (écriture ignorée). Budget mesuré, pas de
  clip.
- **Répartition des explosions** : la liste arcade répète ses groupes de
  quatre pointeurs tous les 32, toujours à l'index 1 mod 4 ; le pas fixe de
  4 tombait chaque fois sur la même cellule des groupes — 37 des 44
  explosions à droite du centre (la borne : 88/88). Le générateur choisit
  maintenant, par fenêtre de quatre spawns arcade, le candidat dont le
  quadrant du corps est le plus en retard sur sa part arcade (bas 61 %,
  haut 39 %), puis la cellule la moins servie ; ordre arcade conservé.
  Résultat : 36 cellules distinctes au lieu de 26, quadrants à la
  proportion arcade.

## 9. Le fondu au noir de la mort, par la palette (étude du 08/09/2026, rien de modifié)

Question de l'auteur : reproduire le fondu de palette de la borne — en
global chez nous, une seule palette —, au même moment et au même rythme,
puis un fondu d'entrée pour l'écran « stage cleared » ; ce qui en fait une
alternative au fondu pixel de la fin de stage.

### Ce que fait la borne, de la mort au stage suivant (trames à 60 Hz, t0 = le coup fatal)

| instant | événement | source |
|---|---|---|
| t0 | cascade d'explosions (352 trames), compteur de mort 384 | a4cd |
| t0+128 | **fondu au noir de la palette des tuiles** : `palette_blackout_15_bg(7)`, 15 banques sur 16, **un pas toutes les 8 trames, 31 pas** (composantes 5 bits, ±1 par pas) → **noir à t0+376** ; descente du décor jusqu'à la décharge | a56c, 5579, 5360 |
| t0+256 | SFX 0x1A + 0x1C (la fanfare et le jingle), `end_level_sequence_flag` : autopilote du vaisseau | a53b..a545 |
| t0+384 | décharge : `stage_unload_request`, autoscroll relancé | a473 |
| +0..15 | le dispatcher de stage attend `global_counter & 15 == 0`, pose les libellés, coupe le tick, arme 0x5F | 1125 |
| +95 | attente ; puis 0x3F | 11bb |
| +15 | `palette_blackout_15_bg(0)` : re-noircit ce qui resterait, un pas par trame | 11cc |
| +48 | reconstruction : palette sprites rechargée, musique coupée, tuiles avant effacées HUD préservé, plan arrière réinitialisé | 11e2 |
| ensuite | le relevé de score du stage (« STAGE n CLEARED », chiffres) sur fond noir, puis `handle_stage_init_event` du stage suivant : **palette rechargée en fondu, un pas toutes les 4 trames, 31 pas = 124 trames** | 1258, f01b, 5541 |

Trois détails qui comptent pour la transposition :
- le fondu ne touche que **la palette des tuiles** (15 banques sur 16) : le
  vaisseau, la cascade, le HUD et les textes (16e banque, épargnée) restent
  à pleine couleur sur un décor qui s'éteint ;
- le vaisseau reste donc **visible** pendant son autopilote, sur noir ;
- l'écran « stage cleared » arrive **~173 trames après la décharge**, soit
  t0+557 environ, texte à pleine couleur sur noir, sans fondu d'entrée : le
  seul fondu d'entrée de la borne est celui du stage suivant (124 trames).

### Ce que la v2 a déjà

- **L'objet de fondu de palette** (`engine/objects/palette/fade/fade.asm`,
  OST statique `palettefade`, tourné à chaque trame par la boucle) : 16
  cycles, chaque cycle rapproche chaque composante 4 bits de sa cible d'une
  unité toutes les `o_fade_wait` trames. `stage.paletteFadeCommon` (stage-
  main.asm) l'arme avec une cible et une attente : sortie vers `Pal_black`
  en attente 1, entrée vers `Pal_stage` en attente 4.
- **La séquence de fin** (`obj_endlevel`) : `bossDefeated` arme un compte à
  rebours de $C0 ; jingle + autopilote à T−16, glissée, pré-fondu de deux
  rendus, **fondu pixel** (160 pas, un par trame, les deux pages), pause 50,
  relevé (224 trames de chiffres + 150 de maintien), sortie. La boucle
  cesse de peindre tuiles et sprites dès `PHASE_FADE` (`stage.frame.faded`).
- Le relevé se dessine avec `Pal_stage` (hud.asm : « le texte doit se voir »).

### La transposition proposée

**Le rythme.** 15 pas de 4 bits contre 31 pas de 5 bits : `o_fade_wait` = 15
donne 16 × 15 = **240 trames** (borne 248, l'écart est d'un pas). Pour le
fondu d'entrée du relevé, l'attente 8 donne 128 trames (le 124 de la borne
pour son stage suivant).

**Le déclenchement.** Au jalon `DEATH_SINK` (compteur 0x100, t0+128), là où
la descente part, le boss lance le fondu vers `Pal_black`, attente 15. Le
gomander est dans la page du cast, la routine dans le main du stage :
`stage.paletteFadeOut` prend l'attente en A, il suffit de l'exporter (ou
d'un octet `globals` « fondu de mort demandé » lu par la boucle, un tst).
Le jeu continue de tout peindre — tuiles derrière, cascade, vaisseau — sous
une palette qui s'éteint : c'est la borne.

**Après le noir** (t0+368). Une nouvelle voie dans `endlevel`, choisie par
le stage (comme `rallyX`) : « fondu de palette » au lieu de « fondu
pixel ». Quand la palette est noire (l'objet est `Idle`), la boucle passe
en `faded` (plus de tuiles ni de sprites) et les deux tampons sont effacés
(deux `clearBlastFull`, ou `checkpoint.clearData`) ; puis le maintien sur
noir, ~170 trames comme la borne ; puis le relevé avec le texte déjà posé
et la palette qui remonte vers `Pal_stage` en attente 8. Les phases 3-4
(pré-fondu, fondu pixel) sont sautées sur cette voie, le reste (relevé,
sortie, silence des puces) est inchangé.

**Le jingle** — trouvé en chemin : sur la borne il part à t0+256, avec
l'autopilote. Chez nous `bossDefeated` à t0+256 arme $C0 et le jingle ne
part qu'à T−16 = **t0+432, 176 trames trop tard**. Ce $C0 est le compte du
Dobkeratops (stage 1) ; pour le Gomander le drapeau est levé directement.
Sur cette voie, armer le compte à $10 au lieu de $C0 (le stage publie sa
durée, comme son point de ralliement) remet jingle et autopilote à
l'heure. Cette correction vaut indépendamment du fondu.

**Le coût.** Rien par trame : l'objet de fondu tourne déjà, la boucle
teste déjà la phase. Deux effacements plein écran (889 poussées chacun)
une fois. Le fondu pixel reste disponible pour les stages qui le gardent.

### Les écarts qu'on accepte en passant en global

- **Le vaisseau s'éteint avec le décor** : l'autopilote (t0+256 → t0+448)
  se joue dans le noir à partir de t0+368. Sur la borne il reste visible.
- **La fin de la cascade s'éteint** : ses 100 dernières trames tombent sous
  une palette déjà aux deux tiers noire.
- **Le HUD s'éteint** aussi, puis revient avec le fondu d'entrée du relevé.
- **Le fondu d'entrée du relevé n'existe pas sur la borne** (texte à pleine
  couleur d'emblée) : c'est le prix de la palette unique, et c'est ce que
  l'auteur propose.

Une variante qui sauve le vaisseau et le HUD : ne fondre que les entrées
propres au décor. Les quatre entrées de stage (5, 7, 15, 16) sont les
teintes du corps du boss ; les douze communes servent aussi aux sprites.
Fondre ces quatre-là seulement éteint le boss mais pas les parois, qui
utilisent les communes — un demi-effet, pas la borne non plus.

### Réalisation de la voie complète (08/09/2026, « voie complète avec écarts »)

- **`stage.deathFadeOut`** (stage-main.asm, exporté) : la palette vers le
  noir, attente 15, lancée par le Gomander au jalon 0x100 (`gomander.FadeOut`,
  une fois ; le timeout la lance à `Finish`).
- **Le mode compensé de l'objet de fondu** — découvert en route : la v1
  décompte l'attente **par trame rendue** ; à 8 images par seconde une
  attente de 15 en fait 90 de vidéo et le fondu prenait 1 400 trames. Un
  octet d'OST `o_fade_drop` (V2-DEVIATION dans `engine/objects/palette/fade/
  fade.asm`) : levé, chaque appel consomme `gfxlock.frameDrop.count` trames
  et fait autant de pas que l'attente en contient. Les fondus d'entrée et
  de reprise le laissent à zéro (strictement la v1).
- **Le stage publie deux réglages de plus** à `endlevel` :
  `main.endstage.duration` ($10 pour le Gomander, qui lève lui-même le
  drapeau de fin — jingle et autopilote à t0+256 comme la borne, ils
  partaient 176 trames trop tard ; $C0 ailleurs) et `main.endstage.fadeMode`
  (palette au stage 2, pixel ailleurs).
- **`endlevel`, voie palette** : à la glissée finie, attendre l'Idle du
  fondu ; phase 4 = le noir — les deux tampons effacés par
  `playfield.clearBlastFull` (un par trame, `paged.call` réentrant) ; la
  palette remonte **aussitôt** le second effacé (`ReadoutFadeIn`, attente 8,
  128 trames, vers `Pal_stage`) — le vaisseau réapparaît, sur la borne il
  n'a jamais disparu ; le relevé, lui, attend `READOUT_WAIT` = 170 trames
  après le noir. Sur la borne, à la décharge (t0+384) l'autoscroll repart à
  0,5 px/trame sur un plan noir, la carte a ~64 px à défiler jusqu'à son
  bout (~130 trames), puis la passation lance le relevé : ~t0+540, le noir
  tombant à t0+368. Le fondu pixel reste aux stages qui le déclarent.
- Mesuré à la sonde (dumps de `Pal_current`) : fondu lancé à +128, palette
  noire et objet Idle à +368, deux trames d'effacement, remontée aussitôt, relevé à +540,
  « STAGE 2 CLEARED » puis stage 3. rtype_bench 7/7 (le timeout du stage 2
  prend la même voie ; le stage 3 garde le pixel).
- **Les objets du pool gèlent dès que le champ est parti** (phase ≥ 4, la
  boucle appelle `RunFrozenObjects` au lieu de `RunObjects`) : c'est la
  passation de la borne, où `game_tick_disable_flag` fait décharger chaque
  tick. Retour auteur : les gougers de la salle du boss jouaient leurs sons
  sous le relevé. Vaut pour toutes les voies ; le joueur, l'armement, le
  fondu et la séquence sont hors pool et continuent.
