# R-Type arcade — séquence game over, saisie du nom, tableau des scores

Relevé fait le 04/09/2026 **exclusivement** dans la base Ghidra `maincpu`
(MCP asm-ark) : listings, plate comments et tables ROM lues à la main.
Aucune adaptation à notre version, aucune lecture de l'ancienne analyse
(`high-score-entry-arcade.md`) : ce document est la cible, pas un plan.

Conventions : les adresses code sont `0x0040:xxxx`, la RAM de travail est le
segment `0x4000`, la ROM de données le segment `0x1000`, la tilemap
d'avant-plan le segment `0xD000`. Les durées sont en trames (55 Hz environ
sur M72 ; 1 s ≈ 55 trames).

## 1. Géométrie de l'écran (pour placer les caractères)

- **Tilemap d'avant-plan** : 64 × 64 cases de 8 × 8 px, 4 octets par case
  (mot tuile, mot attribut = palette). Ligne = 0x100 octets, case =
  `ligne × 0x100 + colonne × 4`.
- **Bande visible** (déduite de `probe_foreground_tile` 0x1E6C, base
  `0x1020`, et des chargements de terrain à 0x1020 sur 30 lignes) :
  colonnes **8 à 55** (48 cases = 384 px), lignes **16 à 45** (30 cases =
  240 px). Conversion : `x = 8·(col − 8)`, `y = 8·(ligne − 16)`.
- **HUD** : lignes 0 et 1 de la tilemap (`clear_foreground_tiles_preserving_hud`
  préserve 0x0000..0x01FF), affichées par **split raster** (IRQ à la ligne
  0x16F − 0x100 ≈ 239, scroll Y forcé à 0x90) sur les **16 dernières lignes**
  de l'écran (240..255). Total écran : 48 × 32 cases, 384 × 256 px.
- Sur les écrans étudiés le split n'importe pas : `init_foreground_tilemap`
  efface toute la tilemap, HUD compris.
- Coordonnées objet (sprites) : `x_écran = pos_x − 0x140`,
  `y_écran = 0x17F − pos_y` (axe Y arcade vers le haut).
- Police : les identifiants de tuile des textes sont les **codes ASCII**
  (`'A'` = tuile 0x41…), 8 × 8 px. Tuile 0x11 = blanc du HUD, 0x20 = espace.

Contrôles de cohérence de la conversion : « CONTINUE » (col 25, 16 cases)
est centré à x ≈ 200, « R A N K I N G » (col 25, 14 cases) à x ≈ 192,
« INSERT COIN » (col 22, 22 cases) à x ≈ 200, et la bande de tuiles nettoyée
sous la bannière GAME OVER (cols 22..41, lignes 29..30) tombe exactement
sous les huit sprites (x 112..271, y 104..119).

## 2. Enchaînement complet

```
mort (dernière vie)
 ├─ run_player_explosion_step 0x22CD : au 1er cadre du dernier pas de l'explosion,
 │    si vies == 1 → SFX 0x22 (jingle game over) + spawn_game_over_banner 0x2365
 │    au cadre suivant : pause_flag := $FF  →  le jeu est GELÉ (objets et
 │    balayage des sprites sautés dans la boucle principale 0x0247/0x0277) :
 │    la bannière reste affichée figée.
 ├─ contrôleur de stage 0x1125→0x11A0 : compte à rebours 0x5F + 0xC0 = 0x11F
 │    trames (~5,2 s) de GAME OVER gelé
 ├─ 0x11BB : 0x3F trames ; 0x11CC : pause levée (la bannière, comptée à 2,
 │    disparaît en 2 trames), fondu palette au noir à 0x30 trames de la fin
 ├─ 0x11E2 stage_rebuild_kickoff : wave stoppée, palette sprites rechargée,
 │    STOP MUSIC (cmd 0), caméras à 0, tuiles effacées (HUD préservé),
 │    vies −1 → 0 → 0x1244 : attente 0x3F trames
 ├─ 0x1446 rank_score_for_high_score_table
 │    ├─ pas classé → continue_prompt_gate 0x12A7
 │    └─ classé (rang 1..10) → init_high_score_name_entry 0x14F9
 │          ├─ écran STAGE SCORE + saisie des initiales   (§3, §4)
 │          ├─ tableau RANKING                            (§5)
 │          └─ continue_prompt_gate 0x12A7
 └─ continue_prompt_gate
      ├─ continue refusé (DSW2:5) ou octet 0x2F42 ≥ 2 → 0x1258
      │     → un joueur : 0x1299 : high_score_dirty_flag := 0, joueur := P1,
      │       état := 0x76C = retour au TITRE
      └─ sinon écran CONTINUE (9→0, 0x3E trames par chiffre) puis, faute de
            START, le même retour au titre via 0x1258
```

Points à retenir :

- **La saisie du nom n'apparaît que si le score entre dans le top 10.**
  Le test est un `bcd_compare_4_bytes` strict : à score égal, l'entrée
  existante garde sa place (le nouveau score n'entre pas au rang égal, il
  descend d'un cran ou sort).
- **Le tableau RANKING n'est montré qu'après une saisie** : un joueur non
  classé ne voit ni STAGE SCORE, ni RANKING, il va droit au continue.
- **Le continue est proposé APRÈS le tableau** pour un joueur classé (sortie
  de 0x1878 vers 0x12A7), et directement pour un joueur non classé.
- Un second chemin existe (`run_game_over_sequence` 0xEFAD, depuis la
  pré-initialisation de stage) : attente 0x120 trames, vies := 1,
  bannière 3 trames, drapeau 0x2FC2. Il n'a pas été tracé plus loin.
- L'attract (title_demo, 0x0A8B) a **sa propre** bannière GAME OVER :
  clignotante, 0x24 trames allumée toutes les 0x40 trames, trois fois, puis
  retour au titre. Ce n'est pas le chemin du vrai game over.

## 3. Écran STAGE SCORE (0x1515)

Construction, dans l'ordre, une fois le compte à rebours de 8 trames écoulé
(après effacement complet des deux tilemaps) :

| Étape | Détail |
|---|---|
| Son | SFX **0x28** |
| Pata-Pata | émetteur `spawn_score_screen_patapata_emitter` (priorité 0x200) |
| Palettes | emplacements 5, 0xC, 0xD reprogrammés (`request_palette_blackout_bg`), palette cyclique **0x17** |
| Titre | objet streamer descripteur ROM 0x0CCE : « STAGE SCORE » |
| Lignes | un objet `run_high_score_row_render` (0x188E) par stage joué + 1 ligne TOTAL |
| Attente | `0x40 + 8 × (nb lignes)` trames, puis « ENTER YOUR INITIALS. » et la ligne « NO.n » |
| Saisie | 0x24 trames de latence, puis boucle d'entrée 0x1660 |

### 3.1 Placement (tilemap → pixels)

| Élément | Ligne | Colonnes | y | x | Palette |
|---|---|---|---|---|---|
| `STAGE SCORE ` (12 cases) | 20 | 13..24 | 32 | 40..135 | 5 |
| stages 1..8 (colonne gauche), 16 cases | 23, 25, … 37 | 12..27 | 56, 72, … 168 | 32..159 | 6 |
| stages 9..16 (colonne droite), 16 cases | 23, 25, … 37 | 34..49 | 56, 72, … 168 | 208..335 | 6 |
| emplacement 17 (TOTAL d'une partie complète) | 39 | 34..49 | 184 | 208..335 | 6 |
| `ENTER YOUR INITIALS.` (20 cases) | 41 | 18..37 | 200 | 80..239 | 5 |
| ligne `NO.n` + 7 tirets (30 cases, col 13) | 43 | 13..42 | 216 | 40..279 | 5 |
| dont `NO.` | 43 | 24..26 | 216 | 128..151 | 5 |
| dont le rang (`1 `…`10`) | 43 | 27..28 | 216 | 152..167 | 5 |
| dont les 7 cases de saisie | 43 | 30, 32, … 42 | 216 | 176, 192, … 272 | 5 |

Flux des destinations (ROM 0x0DBC, 17 mots) : 0x1730, 0x1930, … 0x2530
(lignes 23..37, col 12), puis 0x1788 … 0x2588 (lignes 23..37, col 34), puis
0x2788 (ligne 39, col 34). **La ligne TOTAL prend l'emplacement qui suit la
dernière ligne de stage**, pas une position fixe : une partie finie au
stage 3 a TOTAL SC en ligne 29 colonne 12.

### 3.2 Contenu d'une ligne (16 cases)

- 8 caractères de libellé lus en ROM 0x0D34 + 8·(stage−1) : `" 1 STAGE"`,
  `" 2 STAGE"`, … `" 9 STAGE"`, `"10 STAGE"` … `"16 STAGE"` ; la dernière
  ligne utilise 0x0DB4 = `"TOTAL SC"`.
- 1 espace.
- **7 chiffres** décodés depuis 4 octets BCD (quartet bas de l'octet fort,
  puis 3 paires) ; les zéros de tête deviennent la tuile 0x11 (blanc), le
  dernier chiffre reste toujours affiché. Score max 9 999 999.
- Source : `stage_score_table_pN` (0x2FD8 / 0x3018, 16 × 4 octets, indexée
  `(stage−1)·4`, remplie par `update_current_stage_score` 0xE8BD) ; TOTAL =
  score courant 0x2F34 / 0x2F3C.
- Les lignes vont du **stage de départ** (0x2FCE/0x2FCF, remis au stage
  courant à chaque continue, table de stages effacée) au stage courant ; le
  flux de destinations repart toujours de l'emplacement 0, les lignes sont
  donc tassées en haut de la colonne gauche.
- Apparition : ligne i affichée après `0x20 + 8·i` trames, puis **1 case par
  trame** (16 trames), palette 6. Le titre et les deux textes du bas sont
  révélés à **3 cases par trame**.

### 3.3 Les Pata-Pata décoratifs

`run_score_screen_patapata_emitter` (0xFAE1) : toutes les 8 trames, un bit
aléatoire (`TEST AL,0x20` après décalage, soit 1 chance sur 2 — le plate
comment dit 1 sur 8, l'instruction dit 1 sur 2) appelle `create_pata_pata`
avec un paramètre aléatoire 0..15 : X = 0x2C8 (x écran 392, juste hors
bord droit), Y pris dans `pata_pata_preset_y` (16 valeurs 0x170..0x98, soit
y écran 15 à 231), script de vol standard, même objet qu'en jeu (tir compris,
non tracé ici). Ils vivent tant que `game_tick_disable_flag` est à 0 : ils
disparaissent au passage au tableau RANKING, qui n'a **pas** de Pata-Pata.

## 4. Saisie des initiales (0x160F → 0x17D7)

| Paramètre | Valeur |
|---|---|
| Longueur du nom | **7** caractères (table à 11 octets par entrée : 4 BCD + 7) |
| Alphabet (ROM 0x0B5C, 34 entrées) | `A`…`Z` (0..25), `!` `?` `>` `.` `,` `-` (26..31), **0x20 = RUB** (tuile 0x3C), **0x21 = END** (tuile 0x3A) |
| Position des 7 cases (ROM 0x0B7E) | 0x2B78, +8 par case (ligne 43, cols 30..42 pas 2) |
| Limite de temps | 0x800 trames (~37 s), décrémentée à chaque trame |
| Auto-répétition gauche/droite | seuil 0xC trames maintenues |
| Clignotement de la lettre en cours | palette 0xC / 0xD alternée toutes les 8 trames (bit 3 du compteur global) |
| Lettre validée | palette 5 |
| Case effacée (RUB) ou abandon | tuile `-` (0x2D), palette 5 (RUB) ou 8 (abandon) |

Commandes :

- **Gauche / droite** : SFX **0x40**, index alphabet ±1, bouclage 0 ↔ 0x21.
- **Tir ou Force (bits 0xC0)** : SFX **0x41** puis
  - lettre : tuile écrite, octet stocké **immédiatement** dans la table
    (`0x2F55 + 11·(rang−1) + curseur`), `-` stocké comme espace, curseur +1,
    index alphabet remis à `A` ;
  - RUB : case courante remise à `-`, curseur −1 (borné à 0), l'octet
    devient un espace, index remis à `A` ;
  - END : force la fin (limite de temps := 1).
- **Fin** : 7e lettre validée, END, ou temps écoulé (dans ce dernier cas la
  case clignotante est remise à `-` palette 8). SFX **0x2A**, puis attente
  0x40 trames ; START écourte après les 8 premières trames. Ensuite
  `game_tick_disable_flag := 1` (les Pata-Pata s'en vont), SFX **0x29**,
  état 0x17FB.
- Un nom non saisi reste 7 espaces (initialisé à l'insertion).
- Il n'y a pas de curseur sprite : la lettre proposée s'affiche directement
  dans la case, c'est son clignotement qui sert de curseur.

## 5. Tableau RANKING (0x17FB → 0x1878)

Construction : `game_tick_disable_flag := 0`, effacement des deux tilemaps,
16 trames, puis palettes cycliques **0x17** et **0x1A**, emplacement palette
8 amorcé (0x46), titre « R A N K I N G » (streamer 0x0CBA), et 10 objets
`create_high_score_row_body` (0x1AA1), rang 1 à 10.

| Élément | Ligne(s) | Colonnes | y | x | Palette |
|---|---|---|---|---|---|
| `R A N K I N G ` (14 cases) | 20 | 25..38 | 32 | 136..247 | 6 |
| graphisme de rang r (6 cases × 2 lignes) | 23+2(r−1), 24+2(r−1) | 19..24 | 56+16(r−1) | 88..135 | 8 |
| score, 7 chiffres | 24+2(r−1) | 27..33 | 64+16(r−1) | 152..207 | 6 (7 pour l'entrée nouvelle) |
| 3 espaces | idem | 34..36 | | 208..231 | |
| nom, 7 caractères | idem | 37..43 | | 232..287 | 6 / 7 |

- Destination par rang : ROM 0x0BA2 = 0x186C, 0x1A6C … 0x2A6C (lignes
  24..42 pas 2, col 27). Dernier rang en y = 208.
- Graphisme de rang : ROM 0x0BB6 pointe 10 flux de 12 mots (0x0BCA + 24·(r−1)) :
  4 tuiles communes 0x3B2/0x3B4/0x3B6/0x3B8 (haut) et 0x3B3/0x3B5/0x3B7/0x3B9
  (bas) suivies de 2 tuiles propres au rang (0x38A/0x38C haut, 0x38B/0x38D
  bas pour le rang 1, puis +4 par rang) : un motif de 32 px + un numéro de
  16 px de large sur **16 px de haut**, peint sur les lignes r−1 et r
  (`DI − 0x120` puis `DI − 0x20`), palette 8.
- Révélation : rang r attend **10·r trames** (ROM 0x0B8E : 0x0A..0x64),
  peint son graphisme de rang d'un coup, puis diffuse ses 17 cases à
  **3 par trame**. Le tableau complet est affiché vers la trame 106.
- L'entrée fraîchement insérée est reconnue par comparaison de rang
  (`+0x06` = rang courant BP[+8]) : palette **7** au lieu de 6.
- Zéros de tête : tuile 0x11.
- Sortie : **256 trames** ou un front START (`joypad_edge & 3`), puis
  `game_tick_disable_flag := 1` et saut à `continue_prompt_gate`.

## 6. La bannière GAME OVER en jeu

- `spawn_game_over_banner` (0x2365) : nettoie d'abord les attributs (palette
  seule conservée) de 20 cases × 2 lignes sous la bannière (cols 22..41,
  lignes 29..30, soit x 112..271, y 104..119), puis crée un objet
  (priorité 0xFF20, palette 0x61) en (0x200, 0x110).
- `run_game_over_banner` (0x23C8) émet **8 sprites 16 × 16** (recettes ROM
  0x1180, 0x1192, 0x11A4) : « GAME » aux décalages x −80, −64, −48, −32
  (tuiles 0xAFC..0xAFF) et « OVER » à +16, +32, +48, +64 (tuiles 0x0D0,
  0x0D1, 0xAFF, 0x0D2), décalage y −8. Sur l'écran : GAME en x 112..175,
  OVER en x 208..271, trou de 32 px au centre (192), y ≈ 104..119.
- Compteur de vie de l'objet = 2 trames, mais la pause (`pause_flag`) gèle
  les objets **et** le balayage de la RAM sprites : la bannière reste donc à
  l'écran, figée, pendant les 0x11F trames du compte à rebours, puis
  disparaît quand 0x11CC lève la pause et le fondu au noir commence
  15 trames plus tard.

## 7. Données

### 7.1 Table des scores en RAM

- Base `0x2F51` (`high_score_table_slot0_minus1`), **10 entrées de 11 octets** :
  4 octets BCD **poids faible en premier** (0x2F51..0x2F54 pour le rang 1, le
  quartet haut de l'octet fort masqué à l'insertion), puis 7 caractères
  ASCII. Le rang r commence en `0x2F51 + 11·(r−1)`.
- Insertion (0x147D) : décalage vers le bas des rangs r..9 par `MOVSB`
  descendant (source 0x2FB3, destination 0x2FBE), écriture du score et de
  7 espaces. Le 10e est perdu.
- `score_top` (0x2F50) et le miroir HUD `score_top_hud` (0x2F4D) sont mis à
  jour **en jeu** par `update_current_stage_score`, indépendamment de la table.
- Pas de sauvegarde : `load_default_high_score_table` (segment 0x3000, appelée
  au POST) recopie les 110 octets de ROM 0x1000:07AC à chaque allumage. La
  table survit aux parties tant que la machine reste sous tension.

### 7.2 Table par défaut (ROM 0x1000:07AC)

| Rang | Score | Nom (7) |
|---|---|---|
| 1 | 174500 | `ABIKO..` |
| 2 | 168600 | `SUMITA ` |
| 3 | 159700 | `AKIO.O ` |
| 4 | 117900 | `SHINJI.` |
| 5 | 100500 | `MISAKO!` |
| 6 | 98900 | `MASATO ` |
| 7 | 92000 | `HAMA...` |
| 8 | 80000 | `KENT.K ` |
| 9 | 76000 | `JIJEE..` |
| 10 | 75000 | `IREM . ` |

Il faut donc **plus de 75 000 points** pour voir la saisie sur une machine
fraîchement allumée.

### 7.3 Descripteurs de texte (ROM, format de `create_high_score_row_score_stream` 0x1951)

`mot destination tilemap, mot palette, mot nombre de cases, cases…`

| Adresse | Dest | Pal | N | Texte |
|---|---|---|---|---|
| 0x0CBA | 0x1464 | 6 | 14 | `R A N K I N G ` |
| 0x0CCE | 0x1434 | 5 | 12 | `STAGE SCORE ` |
| 0x0CE0 | 0x2948 | 5 | 20 | `ENTER YOUR INITIALS.` |
| 0x0CFA | 0x2B34 | 5 | 30 | 11 espaces, `NO.`, 2 cases de rang (ROM 0x0D1E : `1 `…`10`), espace, `- - - - - - -` |

### 7.4 Sons (commandes audio, `enqueue_audio_cmd`)

| Id | Moment |
|---|---|
| 0x22 | jingle game over, à la dernière explosion |
| 0x00 | stop musique (kickoff 0x11E2) |
| 0x28 | ouverture de l'écran STAGE SCORE |
| 0x40 | pas de curseur gauche/droite |
| 0x41 | validation (lettre, RUB ou END) |
| 0x2A | fin de saisie |
| 0x29 | passage au tableau RANKING |

## 8. Chronologie type (un joueur, classé)

| Étape | Trames | ≈ s |
|---|---|---|
| GAME OVER figé | 0x11F = 287 | 5,2 |
| dégel + fondu au noir | 63 | 1,1 |
| écran noir après kickoff | 63 | 1,1 |
| effacement avant STAGE SCORE | 8 | 0,15 |
| construction des lignes (n lignes) | 0x40 + 8n | 1,2 + 0,15n |
| latence avant saisie | 0x24 = 36 | 0,65 |
| saisie | ≤ 0x800 = 2048 | ≤ 37 |
| tenue après saisie | 0x40 = 64 (START après 8) | 1,2 |
| effacement avant RANKING | 16 | 0,3 |
| révélation des 10 rangs | ~106 | 1,9 |
| tenue du tableau | 256 (ou START) | 4,7 |

## 9. Ce qui n'est pas établi

- Apparence réelle des tuiles 0x3C (RUB) et 0x3A (END) dans la police : les
  identifiants sont ceux de `<` et `:` en ASCII, le graphisme peut être
  différent. À vérifier sur la ROM de tuiles ou en vidéo.
- Numérotation du stage courant au second tour : les tables (16 entrées de
  score, libellés `9 STAGE`…`16 STAGE`, 16 emplacements + TOTAL) imposent
  9..16, mais le calcul n'a pas été tracé.
- Le graphisme des rangs (tuiles 0x38A..0x3B1) : un motif 4 cases + numéro
  2 cases sur 16 px de haut, contenu exact à lire dans la ROM de tuiles.
- Ancrage vertical exact des sprites de la bannière (déduit à ±8 px de la
  bande de nettoyage).
- Comportement à deux joueurs (alternance 0x1258) : hors périmètre.
- Les Pata-Pata de l'écran de score tirent-ils ? L'objet est celui du jeu,
  avec sa logique de tir ; non vérifié.
