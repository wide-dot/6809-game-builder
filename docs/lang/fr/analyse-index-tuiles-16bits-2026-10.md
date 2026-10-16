# Index de tuiles et de chunks au-delà de 1 024 / 256 — analyse d'impact (16/10/2026)

Demande de l'auteur : une version du système de tuiles et de défilement de
Sonic 2 (`TilemapBuffer` + `<chunkmap>` + collision) qui adresse les tuiles
et les blocs sur 16 bits, pour rendre à Hidden Palace 1 ce que la coupe lui a
retiré (colonnes torsadées, et avec elles 22 des 30 orbes lumineux). Avant
tout code : ce qui change, où, à quel coût, et sous quelle forme (fichier
dupliqué ou `IFDEF`).

## 1. Ce qui bloque vraiment

- **Les tuiles.** Une entrée de chunk est un mot `PSST TOII IIII IIII` :
  priorité, solidités, bit opaque (demi-ligne), et **10 bits d'index** de
  tuile 8×16 (1 024). L'acte 1 du remaster en demandait **1 026**.
- **Les chunks.** Le layout d'un acte est **un octet par cellule** et les
  chunks sont dans deux banques de 128 (bit 7 = banque) : **256 chunks**.
  L'acte 1 en demandait **341**.
- **Les blocs n'existent pas à l'exécution.** `blocks.bin` (les mappings 8
  octets de s2) n'est lu que par le builder, pour le bit de priorité. Une
  entrée de chunk pointe directement une tuile TO8, fusion de (image,
  collision primaire, collision secondaire, retournement). Les « blocs sur
  16 bits » ne concernent donc que le **format source** : le mot de mapping
  de s2 (bloc sur 10 bits) que `ChunkMap.java` lit et que
  `tools/hpz_adapt.py` écrit (il refuse au-delà de 1 024 blocs, l. 167).
- La coupe de l'auteur (`HPZ/map-edits.json`) : 269 blocs cachés et
  80 chunks remplacés. Acte 1 aujourd'hui : 654 tuiles, **256 chunks pile**
  (`gen/ehz/cmap/HPZ1/slices.txt`).

Marge des autres zones (tuiles / chunks) : ARZ 651 / 217, CNZ 534 / 211,
CPZ 696 / 200, HPZ2 645 / 165, HTZ 454 / 153, MCZ 653 / 214, EHZ 480. Seul
HPZ 1 bute.

## 2. Ce qui ne bouge pas

La boucle par trame ne lit jamais l'index. `DrawBufferedTile`, la file des
tuiles de haute priorité, `DrawHighPriorityBufferedTile`, les routines de
fond qui lisent le bit opaque (`_common/background/view-rows.asm`), le plan B
de Hill Top, `TileAnimScript` et les stubs `TlsAni_*` lisent tous la cellule
du tampon : 4 octets `[drapeaux][page][adresse]`, drapeaux bit 7 priorité,
bit 2 opaque. **Tant que la cellule garde cette forme, rien de tout cela ne
change**, et c'est là que sont les cycles (~29 ms par trame pour
`DrawBufferedTile`).

L'index n'est lu qu'à deux endroits :

1. `DrawTile` (`TilemapBuffer.asm` 399-440), une fois par cellule qui
   entre dans la vue ;
2. `Find_Tile` et ses appelants (`sonic-2/objects/level/stage/_common/
   collision/collision.asm`), à chaque sonde de collision.

## 3. La conception proposée

### 3a. Index 16 bits : l'entrée de chunk devient un numéro de « cellule type »

Garder l'entrée de chunk sur **16 bits**, mais lui faire porter **un seul
champ : un index de 0 à 65 535** (0 = cellule vide). Les drapeaux qu'elle
porte aujourd'hui (priorité, solidités, opaque) passent dans une table par
index. Le builder fusionne les cellules sur la clé
(image, collisions, retournement, priorité, solidités, opaque) au lieu de
(image, collisions, retournement) : deux index qui ne diffèrent que par les
drapeaux **pointent la même routine compilée**. Le nombre de routines
(la vraie mémoire) ne change pas, seul le nombre d'entrées de table grandit.

Tables par zone :

| Table | Taille par index | Page | Lue par |
|---|---|---|---|
| index des tuiles `[drapeaux][page][adresse]` | 4 octets (3 aujourd'hui) | `glb_map_tiles_pge` | `DrawTile` |
| solidité (l'octet haut d'aujourd'hui) | 1 | `glb_map_pge` | `FindFloor`… |
| collision primaire, secondaire, retournement | 3 (inchangé) | `glb_map_pge` | `FindFloor`… |

Conséquences :

- **Les chunks gardent 128 octets** (64 mots), les banques 16 Ko, `LoadChunk`
  et `writeBanks` ne bougent pas pour cette partie.
- **`DrawTile` devient plus simple** : `ldd ,u++ / beq vide / ×4 / ldd ,x /
  std ,y / ldd 2,x / std 2,y` — plus de masques, plus de ×3. Moins de cycles
  qu'aujourd'hui.
- **La collision** : `Find_Tile` rend l'index entier ; les cinq `anda #3`
  disparaissent ; le test de solidité (`lda <glb_d4 / bita <glb_d5_b`, l. 147,
  285, 401, 529, 667) lit l'octet de la table de solidité au lieu de l'octet
  haut de l'entrée : ~10 cycles de plus par sonde (une dizaine de sondes par
  trame : ~100 à 200 cycles par trame).
- **Limite pratique** : le site de la collision tient 4 octets par index dans
  la page de la zone (avec le reste de l'objet zone), l'index des tuiles 4
  octets dans sa page. Une page de 16 Ko tient ~4 000 index en tables seules,
  bien au-delà des besoins (HPZ 1 entier : ~1 026 images, avec les variantes
  de drapeaux de l'ordre de 1 300 à 1 600 index, à mesurer).
- Les tuiles animées gardent leur mécanisme : des index au-delà du tileset
  dont l'entrée pointe un stub `TlsAni_*` (seul le numérotage du builder
  change).

L'autre forme envisagée — des entrées de chunk plus larges (3 ou 4 octets) —
est écartée : chunks de 192 ou 256 octets, banques qui ne sont plus des
puissances de deux ou deux fois plus de banques (HPZ 1 : 32 Ko de chunks
deviendraient 64 Ko), toute la géométrie de `LoadChunk`/`Find_Tile` à
reprendre, pour rien gagner sur les cycles.

### 3b. Plus de 256 chunks : le layout sur 16 bits

Indépendant de 3a, nécessaire seulement si on dépasse 256 chunks dans un
acte (le cas de HPZ 1 entier : 341).

- Layout **un mot par cellule** (rangées de 256 octets au lieu de 128 : le
  layout d'un acte passe de 2 à 4 Ko).
- La banque d'un chunk = `id >> 7` dans une table de banques
  `(page, adresse)` au lieu du bit 7 et de deux descripteurs
  (`map-16bits.equ` `layer_chunk0/1`, les macros des sept objets zone).
- À reprendre : `ComputeTileBuffer`/`FeedTileBuffer` (195-216, 328-331),
  `LoadChunk` (362-378), `Find_Tile` (70-95), `CNZ_LayoutPeek`/`Poke`
  (lecture et écriture d'octets de layout), `level-size-load.asm`,
  `gen_v2.parts()` ; côté builder `MAX_CHUNKS`, l'écriture des layouts
  (`(byte)` l. 305 et 373), les tranches.
- Coût : quelques cycles par cellule nouvelle et par sonde ; +2 Ko de RAM
  par acte.

### 3c. Blocs source au-delà de 1 024

Builder et Python seulement : un format de mapping source plus large
(`ChunkMap.java` 238-241, 590-594, le parse des animés ; `hpz_adapt.py`
164-168 qui écrit les mots ; `zone_adapt.py`, `zone_animated.py`). Un
attribut de `<chunkmap>` qui dit la largeur du mapping source suffit ; les
zones de s2 gardent le format de s2.

## 4. IFDEF ou duplication

**Recommandation : `IFDEF`**, deux defines indépendants,
`TilemapBuffer.INDEX16` (3a) et `TilemapBuffer.LAYOUT16` (3b).

- Les différences sont **localisées** : ~40 lignes dans `TilemapBuffer.asm`
  (`DrawTile`, `LoadChunk`, l'adressage du layout) sur 776, et dans le jeu
  `Find_Tile` plus cinq paires masque/test dans `collision.asm`. La boucle
  chaude n'est pas touchée.
- `TilemapBuffer.asm` est **un import v1 1:1** suivi au manifest
  (`engine/v1-manifest.csv` l. 90) avec ses écarts déjà sous `IFDEF`
  (`OPAQUE`, `PLANES_CURSOR`, `SKIP_ROWS`). Un fork de 776 lignes pour
  40 lignes de différence casserait le diff contre la v1 et dériverait
  (corrections faites dans l'un, oubliées dans l'autre). Le précédent du fork,
  `mscroll1`, se justifiait par un algorithme différent (1 bpp, autre carte),
  pas par un format d'entrée.
- C'est le style de la grille : opt-in, un projet qui ne s'en sert pas ne
  paie rien (corpus identique), le coût chiffré dans `tilemaps.md`.

**Portée** : un define vaut pour tout le mode de jeu (le code est partagé par
toutes les zones). Allumer `INDEX16` dans le mode de jeu des niveaux de
Sonic 2 impose le nouveau format à **toutes** ses zones — sans coût : le
builder les produit toutes (`<chunkmap>`), sauf **EHZ** dont la carte est
encore celle de la v1, écrite par les outils Python (`ehz_zone.py`,
`ehz_opaque.py`, `ehz_priority.py`). EHZ passe donc par `<chunkmap>`
(l'équivalence a déjà été prouvée case par case en 10/2026,
`tools/chunkmap_check.py`, deux écarts tous deux de la v1), ou ses outils
écrivent le nouveau format. Un interrupteur par zone à l'exécution coûterait
un test par cellule et par sonde : écarté.

## 5. La mémoire, la vraie limite pour HPZ 1

Lever les index ne rend pas la place. Estimation pour HPZ 1 **entier**
(1 026 tuiles, 341 chunks) contre aujourd'hui (654, 256) :

| | Aujourd'hui | Entier | Écart |
|---|---|---|---|
| tuiles compilées (~88 octets la tuile 8×16 demi-ligne) | ~57 Ko | ~90 Ko | **+33 Ko** |
| banques de chunks (128 octets le chunk) | 32 Ko | 43 Ko | **+11 Ko** |
| tables (index + collision) | 2,6 Ko | ~6 à 8 Ko | +4 Ko |
| layout | 2 Ko | 4 Ko | +2 Ko |
| **total** | | | **~+50 Ko** |

L'état HPZ_1 a **~27 Ko libres**. L'acte entier ne revient donc pas ; ce
qui revient doit se choisir (les colonnes et leurs orbes d'abord), et se
mesure : la page des tuiles (`tools/hpz_tiles_page.py`) sait ce que chaque
groupe de blocs cachés coûte en tuiles et en chunks.

## 6. Plan proposé

1. **Builder** : `<chunkmap>` sort le nouveau format sur attribut
   (index 16 bits, table de solidité, clé de fusion élargie) ; `<tilemap>`
   des entrées de 4 octets ; tests JUnit ; défaut inchangé.
2. **Moteur** : `TilemapBuffer.INDEX16` dans `DrawTile` ; manuel
   `tilemaps.md` ; corpus identique.
3. **Sonic 2** : `collision.asm` sous le même define ; EHZ par `<chunkmap>` ;
   toutes les zones régénérées ; bancs (EHZ, actes, collision) sous toje.
4. **Mesurer** ce que coûte le retour des colonnes de HPZ 1 (tuiles,
   chunks, Ko), puis décider ce qui revient.
5. **Seulement si** le retour dépasse 256 chunks : `TilemapBuffer.LAYOUT16`
   (3b).

## 7. Décisions et réalisé (16/10/2026)

- **Pas de mesure préalable** (auteur) : le nombre de chunks est la limite,
  certainement. `TilemapBuffer` n'est utilisé que par Sonic 2 en v2 : la
  compatibilité peut se casser, pas de define.
- **Dynamique par acte**, plutôt qu'un format pour tout le mode de jeu : seul
  HPZ 1 dépasse, les autres actes gardent leur layout d'un octet par cellule
  (2 Ko de moins chacun).
- **Place en résident** d'abord : `Sonic_Pos_Record_Buf` sorti de `ehz.main`
  vers `$9C00` (256 octets, sonic-2 ec72272).
- **Layout 16 bits dynamique, fait** :
  - builder : `<chunkmap banks="n">` (2 à 4) — n banques de 128, layouts en
    mots big endian au-delà de deux, tests `ChunkMapTest` ;
  - moteur : `TilemapBuffer.SetCells` au chargement de l'acte (A banques,
    B largeur, X premier enregistrement de banque) — table des banques
    `glb_map_bank_tbl`, pas de rangée `glb_map_stride`, deux instructions de
    2 octets réécrites (la lecture de cellule de `LoadChunk`, le dernier
    décalage de la colonne) ; le descripteur : `layer_map_banks` (l'ancien
    `layer_map_height`, jamais lu) ;
  - Sonic 2 : `Find_Tile_SetCells` réécrit la première instruction de
    `Find_Tile` en `jmp FT_word` ; HPZ 1 à 3 banques.
- **Mesuré** : `ehz.main` 11 947 octets (+171 sur 11 776) ; en mode octet,
  aucun cycle de plus (les instructions d'origine restent) ; HPZ 1 en mots
  devant la cascade de x 3144, 10,05 boucles par seconde (10,04 en octets) ;
  une course scriptée dans HPZ 1 suit le même parcours dans les deux modes
  (sols, tubes, sauts), l'arène du boss charge, cinq actes démarrent.
- **Reste** : rendre à HPZ 1 les chunks que la coupe a remplacés (au-delà de
  256, ce que les 3 banques permettent désormais) ; l'index de tuile au-delà
  de 1 024 (§3a) si le retour des colonnes le demande.
