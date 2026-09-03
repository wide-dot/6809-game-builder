# La saisie du high score à la mort — relevé arcade

Étude du code arcade (base Ghidra `maincpu`, seg code `0x40`, seg données
`0x1000`) préalable au portage v2. Tout ce qui suit est relevé, pas déduit ;
les adresses sont données pour rejouer la lecture au connecteur `asm-ark`.

Sous-système : `level / stage_cleared_flow`. La saisie n'a pas de fiche
propre — elle est *collée* au flux de fin de stage, dont elle partage
l'objet contrôleur et le champ d'état `BP[+0x00]`.

## 1. Le fil complet, état par état

Un seul ObjectRecord porte toute la séquence : son `tick_handler`
(`BP[+0x00]`) est réécrit à chaque étape. Aucune de ces routines n'est
appelée par une autre — elles se succèdent par réécriture du vecteur.

| Adresse | Nom | Rôle |
|---|---|---|
| `0x124F` | `wait_then_rank_score` | délai après la dernière vie, puis saute au classement |
| `0x1446` | `rank_score_for_high_score_table` | comparaison BCD, insertion, décalage |
| `0x14F9` | `init_high_score_name_entry` | gèle le tick, efface les deux tilemaps, attend 8 trames |
| `0x1515` | `run_high_score_name_entry_setup` | palettes, fond cyclique, engendre les lignes |
| `0x160F` | `..._post_setup_wait` | engendre les deux curseurs, **arme le chrono**, attend `0x24` |
| `0x1655` | `..._post_cursor_wait` | temporisation `0x24` avant d'ouvrir l'entrée |
| `0x1660` | `run_high_score_name_entry_input` | **la boucle de saisie** |
| `0x1724` | `name_entry_step_back` | RUB : efface et recule d'un cran |
| `0x176B` | `name_entry_commit_letter` | valide une lettre, ou traite RUB / END |
| `0x17D7` | `run_name_entry_post_commit_wait` | maintien `0x38` trames, écourté par START |
| `0x17FB` | `init_high_score_table_display` | bascule sur l'affichage du tableau |
| `0x1878` | `run_high_score_table_exit_wait` | sortie |

Si le score ne classe pas, `0x1446` écrit `0` dans `BP[+0x08]` et saute
directement à `continue_prompt_gate` (`0x12A7`) — l'écran continue, que nous
portons déjà dans `hud.asm`.

## 2. Le classement (`0x1446`)

- Gèle le jeu (`game_tick_disable_flag := 1`).
- Le score courant est **BCD packé sur 4 octets, octet de poids faible en
  tête** (P1 `0x2F37`, P2 `0x2F3F`). Le plate Ghidra annonçait « MSB-first » :
  c'est faux, et cela se prouve sans désassembler — lue dans ce sens, la table
  livrée n'est pas triée (451700 suivi de 861600). Relue octet de poids faible
  en tête, elle décroît exactement. Corrigé dans la base.
- Parcourt les 10 entrées de `high_score_table` (`0x2F54`), **pas de 11
  octets**, via `bcd_compare_4_bytes`. Le premier `CF=1` donne le rang.
- Rang retenu dans `BP[+0x08]`, valeur **1..10**.
- Insertion : décalage des entrées inférieures d'un cran par `MOVSB` en sens
  décroissant (`0x2FBE` → `0x2FB3`), sur `(10 − rang)` entrées.
- La nouvelle entrée reçoit les 4 octets de score, puis **7 octets remplis
  d'espaces `0x20`** — le nom est un vide à remplir, pas un défaut.

### Format d'une entrée : 11 octets

```
+0 .. +3   score, BCD packé, octet de poids faible en tête
+4 .. +10  nom, 7 caracteres ASCII
```

Confirmé par la table par défaut en ROM (`high_score_table_default`,
`0x1000:07AC`, 110 octets) : `ABIKO..` 174500, `SUMITA ` 168600,
`AKIO.O ` 159700, `SHINJI.` 117900, `MISAKO!` 100500, `MASATO ` 98900,
`HAMA...` 92000, `KENT.K ` 80000, `JIJEE..` 76000, `IREM . ` 75000.

## 3. La boucle de saisie (`0x1660`)

Trois variables d'état, toutes sur le contrôleur :

| Champ | Rôle | Domaine |
|---|---|---|
| `BP[+0x0C]` | position du curseur dans le nom | 0..7, sortie à 7 |
| `BP[+0x0E]` | index dans l'alphabet | 0..0x21 |
| `BP[+0x0A]` | **chrono global de saisie** | armé à `0x800` |
| `BP[+0x10]` | compteur de maintien (auto-répétition) | seuil `0x0C` |

**Sept caractères**, malgré la borne à 7 : le curseur va de 0 à 6, et sort
dès qu'il atteint 7 — ce qui recoupe exactement les 7 octets de nom de
l'entrée.

Par trame :

1. Dessine le caractère courant à la cellule du curseur, dans le segment
   tile RAM `0xD000`. La **palette alterne `0x0C`/`0x0D` toutes les 8
   trames** (`global_counter` `0x2EB6`, bit 3) — c'est le clignotement du
   caractère en cours de choix.
2. `controller_pressed` (`0x2F23`) :
   - bits `0xC0` (Fire ou Force) → validation, saut en `0x176B` ;
   - bits `0x03` (gauche/droite) → pas dans l'alphabet, SFX `0x40` ;
   - sinon `controller_held` (`0x2F21`) avec le compteur `BP[+0x10]` :
     **auto-répétition au bout de `0x0C` trames** de maintien.
3. L'alphabet **boucle** dans les deux sens (0 → `0x21` → 0).
4. Sans entrée, la cellule du curseur revient au tiret `'-'` (`0x2D`)
   en palette `8` — l'autre moitié du clignotement.

### Le chrono : une correction aux annotations Ghidra

`BP[+0x0A]` est étiqueté « cursor X seed » en `0x163B` et « blink countdown »
dans le plate de `0x1660`. **Les deux sont faux**, et c'est important pour le
portage : le champ est décrémenté à chaque trame en tête de boucle, et son
passage à zéro tombe dans le chemin de fin (`0x16E0`). C'est la **limite de
temps de saisie**, armée à `0x800` = **2048 trames**, soit environ **37 s**
à 55 Hz.

La preuve tient dans END : `name_entry_commit_letter` termine la saisie en
posant `BP[+0x0A] := 1` — au tick suivant le décrément l'amène à zéro. Un
compteur de clignotement ne se manipulerait pas ainsi.

## 4. L'alphabet (`0x1000:0B5C`, 34 entrées)

Les codes sont de l'**ASCII direct**, ce qui simplifie beaucoup le portage :

```
index 0x00..0x19  'A'..'Z'
index 0x1A..0x1F  '!' '?' '>' '.' ',' '-'
index 0x20        '<'   -> RUB  (efface et recule)
index 0x21        ':'   -> END  (termine la saisie)
```

Les deux dernières entrées ne sont pas des caractères mais des **commandes**,
dessinées par des tuiles dédiées dans le tileset arcade.

Détail à ne pas manquer : à la validation, un `'-'` (`0x2D`) est stocké comme
**espace** (`0x20`) dans la table. Le tiret est donc à la fois le curseur
vide et un moyen d'écrire un blanc.

## 5. Les positions à l'écran (`0x1000:0B7E`, 8 mots)

```
0x2B78  0x2B80  0x2B88  0x2B90  0x2B98  0x2BA0  0x2BA8  0x2BB0
```

Huit cibles en tile RAM (`0xD000`), régulièrement espacées de 8 octets.
Chaque cellule occupe 4 octets : identifiant de tuile, puis attribut de
palette à `+2`.

## 6. Habillage et son

- `0x1515` programme les palettes `0x05`←`0x10`, `0x0C`←`0x0C`, `0x0D`←`0x0D`,
  et engendre une **palette cyclique** (`create_cycling_palette(0x17)`) plus
  un fond animé (`0x40:FAD7`).
- Les lignes du tableau sont engendrées une par une, une par stage atteint,
  avec un flux de tuiles distinct pour le nom et pour le score
  (`0x188E`, `0x1951`, `0x1A51`).
- SFX : `0x28` à l'ouverture, `0x40` à chaque pas dans l'alphabet, `0x41` à
  la validation d'une lettre, `0x2A` à la fin du nom, `0x29` au passage au
  tableau.

## 7. Ce que le portage v2 peut réutiliser

L'écran vit naturellement dans `src/common/hud/hud.asm`, à côté de l'écran
continue et du relevé de fin de stage : même police (celle du title,
dupliquée), même `hud.drawStr`, même convention de placement
`$C000 + ligne*40 + colonne`, cellule d'un octet pour 4 px, glyphe haut de
8 lignes.

**Ce que la police a déjà** : `A`–`Z`, `0`–`9`, l'espace, `!`, `.`, et `[`
utilisé pour le ©.

**Ce qui manquait pour l'alphabet arcade** : `?`, `>`, `,`, `-`, `<`, `:`.
Décision de l'auteur : les dessiner — voir la section 8.

**Points de structure conservés** : les 7 caractères, le classement sur
10 rangs, l'auto-répétition à 12 trames de maintien, le bouclage de
l'alphabet, et le chrono — converti : 2048 trames arcade ≈ 37 s, soit
**1850 trames** à nos 50 Hz.

**Écart déjà acté ailleurs** : notre écran continue ne remet pas le score à
zéro, faute de table de classement. Ce portage-ci lui en donne une : la
question de la remise à zéro du score au continue se rouvre, et se tranche
avec l'auteur.

## 8. Ce qui a été construit et abandonné (29/08/2026) — le mauvais écran

Une première implémentation a posé le **tableau des 10 meilleurs scores**
(le RANKING) comme fond de la saisie, avec les glyphes de ponctuation
manquants dessinés, une table partagée title/résident en RAM stable, et la
persistance disque. **Ce n'était pas le bon écran** — releve auteur, comparé
à une vraie capture d'écran arcade (image jointe à la conversation,
29/08/2026) :

> deux colonnes du STAGE 1 au STAGE 16, avec la mention TOTAL SC, sous
> laquelle vient ENTER YOUR INITIALS. NO.n, la ligne de saisie — le tout
> décoré de Pata-Pata volant en arrière-plan.

Ce n'est **pas** le tableau des 10 rangs : c'est le récapitulatif **par
stage joué**, que la section 3 de ce document mentionnait déjà en passant
(`0x1515`, étape 6 : « Loop... until BP[+0x1a] reaches current_stage ») sans
que la première implémentation n'en tienne compte. Le tableau des 10 rangs
existe bel et bien dans l'arcade (`0x181D`, `high_score_table_row_setup`,
titre RANKING) mais c'est un **second écran**, montré APRÈS la saisie —
voir §1, états `0x17FB`→`0x1878`.

**Décision de l'auteur (29/08/2026) : tout le code de cette tentative est
retiré** (branche remise à l'état de `master` avant ce travail). Ce qui
suit capitalise ce qui reste utile pour refaire l'écran correctement.

## 9. Le vrai écran : STAGE SCORE (relevé complémentaire, 29/08/2026)

### 9.1 Composition visuelle (confirmée par capture d'écran arcade)

```
        STAGE SCORE

  1 STAGE     42300
  2 STAGE     62400
  3 STAGE      8500
  TOTAL SC   113100

  ENTER YOUR INITIALS.
        NO.5  A_______
```

Décor : plusieurs Pata-Pata volant à des positions et hauteurs aléatoires,
entrant par la droite de l'écran.

### 9.2 La machine à états (`0x1515`, corrigée)

`run_high_score_name_entry_setup` construit CET écran, pas un fond pour le
RANKING — le plate Ghidra d'origine ("cycling-palette background helper")
était fautif et a été corrigé dans la base (voir §9.4). Séquence :

1. SFX `0x28`, réactive le tick de jeu.
2. Engendre l'émetteur de Pata-Pata décoratif (`0xFAD7`, priorité `0x200`).
3. Programme les palettes `0x05`/`0x0C`/`0x0D`, palette cyclique `0x17`.
4. Engendre le curseur de ligne (tick `0x1951`, `pos_y_int = 0xCCE`).
5. Choisit, selon le joueur actif :
   - `starting_stage_pN` (`0x2FCE`/`0x2FCF`) → nombre de stages joués ;
   - `stage_score_table_pN + 3` (`0x2FDB`/`0x301B`) → pointeur MSB de la
     première entrée de score par stage (voir §9.3 pour le +3).
6. Boucle : un objet-ligne par stage joué (tick `0x188E`, priorité
   `0x1000`), jusqu'à épuiser le nombre de stages.
7. Une dernière ligne, même tick, forcée sur le label `TOTAL SC ` (`0x0DB4`,
   8 octets ASCII **vérifiés en ROM**) et le score total (`score_running_pN`
   MSB, `0x2F37`/`0x2F3F`).

### 9.3 Le score par stage — ce qui manque dans notre moteur

**Notre moteur ne trace AUCUN score par stage aujourd'hui** — seul
`globals.score` (le total) existe. L'arcade, elle, additionne CHAQUE
récompense à DEUX endroits en même temps (`update_current_stage_score`,
`0x40:E8BD`, sous-système `hud/score_panels`) :

```
stage_score_table_p1  equ $2FD8   ; P1 : 8 entrees de 4 octets BCD, une par stage
stage_score_table_p2  equ $3018   ; P2 : idem
```

Indexé par `(stage-1)*4`. Chaque gain de score (`update_current_stage_score`,
appelé partout où un ennemi meurt/un bonus est pris) fait DEUX additions BCD
4 octets (V30 `ADD4S`) : une dans `score_running_pN` (le total), une dans
`stage_score_table_pN[stage-1]` (le score DE ce stage). Les deux sont
plafonnées à `09999999` (7 chiffres).

Pour notre v2 : il faut un tableau `globals.stageScore[8]` (3 octets
binaires par stage, comme `globals.score`), rempli au même endroit que
`AwardScore` incrémente `globals.score` aujourd'hui — la même remise à
zéro que le score total à une nouvelle partie.

**Le `+3` dans `run_high_score_name_entry_setup` (`0x1515`)** : le pointeur
vaut `stage_score_table_pN + 3`, pas la base — c'est l'octet de poids FORT
(MSB) du premier champ 4 octets, cohérent avec la convention "pointeur MSB,
décrémenté" que le traceur de ligne (`0x188E`) utilise pour dérouler les
chiffres (même convention que `score_running_pN + 3` pour le total, voir
§2). Pas un bug, une convention systématique.

**Ce qui reste flou** : le flux de "codes d'étiquette" à `0x0DBC` (les
libellés "1 STAGE ", "2 STAGE "...) ne se résout pas directement en texte
ASCII à l'adresse ROM lue cette fois-ci (probablement une indirection
relative à un segment/ES non élucidé dans cette passe) — seul `TOTAL SC `
à `0x0DB4` est confirmé en clair. **À réexaminer avant de recoder ce point**
plutôt que de deviner le texte des 8 libellés "N STAGE ".

Le rendu d'une ligne (`0x188E`, `run_high_score_row_render`) : 8 octets de
libellé + espace, puis 7 chiffres décodés depuis le BCD (mêmes helpers que
le classement : `emit_bcd_digit_low_nibble` + 3×`emit_bcd_digit_pair`), puis
`blank_leading_zero_digits` — donc le même masquage des zéros de tête que
pour le tableau des 10 rangs.

### 9.4 Pata-Pata : le décor, corrigé dans la base Ghidra

`0x40:FAD7` était étiqueté « générique » ("random drop dispatcher", pouvant
spawner ~30 variétés d'ennemis/bonus selon un index aléatoire 0-15). **Faux,
corrigé dans la base le 29/08/2026** : le code charge `CH=0x6C` en DUR avant
de calculer l'index de la table de 51 mots à `0xB92D` — l'index qui en
résulte (`0x36/2 = 27`) tombe TOUJOURS sur `create_pata_pata` (`0x596D`).
L'octet aléatoire lu juste avant est calculé puis... jamais utilisé (mort,
ou vestige d'un sélecteur plus générique dont ce site d'appel ne se sert
plus). Net : ce spawner ne peut produire QUE des Pata-Pata, au rythme
« toutes les 8 trames, ~1 chance sur 8 ».

Renommé dans la base : `spawn_score_screen_patapata_emitter` /
`run_score_screen_patapata_emitter`.

**Ce que ça implique côté v2** : le Pata-Pata est aujourd'hui un ennemi de
**cast de stage** (`src/enemies/pata-pata`, chargé avec les assets d'un
stage particulier — stages 1/3/4/7). Le faire voler sur un écran **résident**
(chargé après la mort, page indépendante des stages) demande soit une copie
légère résidente de son sprite/logique, soit un chargement explicite de ses
assets à cet instant — à concevoir, pas un simple appel.

### 9.5 Découverte annexe, hors périmètre : `second_loop`

La table `stage_score_table_pN` est indexée `1..8` (`BL = current_stage`,
`(1..8)` per le plate de `update_current_stage_score`) — cohérent avec notre
port à 8 stages. **Mais** un symbole `second_loop` existe en ROM (`0x2F2D`),
confirmant que l'arcade fait **rejouer les 8 stages une seconde fois** (plus
difficile), d'où les captures montrant jusqu'à 16 lignes en deux colonnes
(8+8). Notre v2 n'a qu'une seule boucle. **Hors périmètre de ce chantier**,
sauf décision explicite de l'auteur d'ajouter un New Game+.

## 10. Ce qui est réutilisable pour la prochaine tentative

Rien de ce qui suit n'est câblé dans le jeu aujourd'hui — conservé comme
référence, à réintégrer dans la bonne composition d'écran.

### 10.1 Les glyphes de ponctuation — conservés tels quels

`tools/gen_font_glyphs.py` (gardé dans le dépôt, non branché) génère les 6
glyphes manquants de la police du title (`?`, `>`, `,`, `-`, `<`, `:`) dans
le format relevé sur les glyphes existants : BM16 deux plans, 4 px de large
× 8 lignes, ancrage au milieu, charte de dégradé (3/6 en haut, 5 au corps,
4 en bas). Le codec a été vérifié par aller-retour (décoder le fichier
généré redonne les grilles). Directement réutilisable : rejouer
`python3 tools/gen_font_glyphs.py > gen/hud/font-extra.asm` et inclure ce
fichier où la police doit porter `<`/`:`/etc.

### 10.2 La boucle de saisie — la mécanique, à réimplanter

Alphabet qui défile sous le curseur, boucle aux deux bouts, auto-répétition
après 12 trames de maintien, clignotement par alternance glyphe/tiret (faute
d'attribut de palette par cellule) :

```asm
; lire une direction, avec auto-repetition (A = -1/+1/0)
hs.readDir
        lda   joypad.pressed.dpad
        bita  #joypad.0.RIGHT
        bne   @droite
        bita  #joypad.0.LEFT
        bne   @gauche
        lda   joypad.held.dpad
        bita  #joypad.0.RIGHT+joypad.0.LEFT
        bne   @tenue
        clr   hs.hold
        clra
        rts
@tenue  inc   hs.hold
        lda   hs.hold
        cmpa  #hs.REPEAT               ; seuil : 12 trames
        blo   @rien
        clr   hs.hold
        lda   joypad.held.dpad
        bita  #joypad.0.RIGHT
        bne   @droite
        bra   @gauche
@rien   clra
        rts
@droite clr   hs.hold
        lda   #1
        rts
@gauche clr   hs.hold
        lda   #-1
        rts

; un pas dans l'alphabet, qui boucle aux deux bouts
hs.stepAlpha
        adda  hs.alpha
        bpl   >
        lda   #hs.ALPHALEN-1
!       cmpa  #hs.ALPHALEN
        blo   >
        clra
!       sta   hs.alpha
        rts
```

Boucle principale (chrono de saisie, validation, RUB/END) :

```asm
hs.nameEntry
        clr   hs.cursor
        clr   hs.alpha
        clr   hs.hold
        ldd   #hs.TIMEOUT
        std   hs.timer
hs.entry.frame
        _waitFrames #1
        ; LA LIMITE DE TEMPS (0x800 sur la borne, ~37 s)
        ldd   hs.timer
        subd  #1
        std   hs.timer
        lbeq  hs.entry.done
        jsr   hs.paintCursor
        jsr   joypad.readKbd
        jsr   hs.readDir               ; A = -1 gauche, +1 droite, 0 rien
        tsta
        beq   @fire
        jsr   hs.stepAlpha
@fire   jsr   hud.cont.checkFire
        lbeq  hs.entry.frame
        ; --- validation (0x176b) -----------------------------------------
        lda   hs.alpha
        cmpa  #hs.END
        lbeq  hs.entry.done
        cmpa  #hs.RUB
        lbeq  hs.entry.rub
        ldy   #hs.alphabet             ; la lettre choisie
        lda   a,y
        cmpa  #'-'                     ; la borne range le tiret en espace
        bne   >
        lda   #' '
!       jsr   hs.putChar
        clr   hs.alpha                 ; l'alphabet repart de A
        inc   hs.cursor
        lda   hs.cursor
        cmpa  #hs.NAMELEN
        lblo  hs.entry.frame
hs.entry.done
        rts

hs.entry.rub                           ; RUB : effacer et reculer (0x1724)
        clr   hs.alpha
        lda   hs.cursor
        lbeq  hs.entry.frame           ; deja au debut : rien a defaire
        deca
        sta   hs.cursor
        lda   #' '
        jsr   hs.putChar
        lbra  hs.entry.frame

; ---------------------------------------------------------------------------
; hs.putChar — poser A dans l'entree, a la position du curseur, et l'afficher
; ---------------------------------------------------------------------------
```

### 10.3 Le mécanisme disque — probablement toujours valide

Écriture/lecture d'un secteur (`map.DKCO`, pas `map.DKCONT` qui ne lit que),
la FACE dans le bit 0 de `map.DK.DRV` et non dans la piste, gestion de la
disquette protégée (`map.DK.STA = 1`) avec message et attente nue du joueur
avant de retenter — cette mécanique ne dépend pas de la composition d'écran
et reste valable quand la persistance sera reprise.

### 10.4 Deux leçons de portée générale, déjà en mémoire de session

- **Un compteur de boucle ne survit pas dans `B`** dès qu'une soustraction
  24 bits passe par `ldd` (qui écrase B). Mémoire : `offset-indexe-b-signe.md`
  (piège voisin : un offset indexé `b,y` après `mul` est SIGNÉ sur 8 bits).
- **`paged.call` masque la page de l'appelant** : toute donnée lue par deux
  pages différentes (ex. title + résident) doit vivre en RAM non paginée.
  Mémoire : `ram-partagee-demi-page-0.md`.

### 10.5 Trouvaille annexe : la taille d'un OST sous `OverlayMode` (à vérifier sur `master`)

Sans rapport avec le high score, mais découverte pendant ce chantier et
perdue par le retour en arrière du code — consignée ici pour ne pas la
reperdre :

**Le layout de `to8.config.xml` comptait 117 octets par OST** dans ses
`<reserved name="objects.pool">` / `<reserved name="objects.static">`
(page 0, demi-page vue en `$4000`) — c'est la taille d'AVANT le passage à
l'overlay. **Sous `OverlayMode`, un OST fait 63 octets** (`object_rsvd_size`
vaut 5, pas 59 — voir `engine/constants.asm`), donc :

```
pool (60 slots)      : $4000-$4EC3   (3780 o, et non $1B6C = 7020 o)
4 OST statiques       : $4EC4-$4FBF   (252 o, et non $01D4 = 468 o)
```

**Mesuré, pas déduit** : sous toje, sur l'attract complet, le stage 1
(8000 trames), un game over et le stage 4, la plus haute adresse jamais
écrite dans cette demi-page est `$4FBF` — le dernier octet du 4ᵉ OST
statique avec la taille corrigée. Au-delà, `$4FC0`-`$5FFF` (4160 octets)
est libre, pas les « 704 octets » que disait la note d'origine du layout
(calculée sur 117 au lieu de 63).

Cette correction a été appliquée dans `to8.config.xml` (`overlay-render`,
commits aujourd'hui retirés) puis perdue avec le retour en arrière — et de
toute façon recouverte par la réorganisation mémoire d'une autre session sur
`master` (nouveau modèle `slice`/fenêtre, budget de l'arène `objects`
retaillé indépendamment). **À vérifier sur `master`** : la taille par OST
qui y est utilisée aujourd'hui compte-t-elle bien 63 octets sous
`OverlayMode`, ou hérite-t-elle encore de la valeur 117 d'avant l'overlay ?
Si c'est la seconde, il y a là de la marge récupérable pour le budget serré
de l'arène `objects` (voir `docs/lang/fr/reorganisation-memoire-2026-09.md`,
qui documente ce budget comme tendu).

## 11. Statut (29/08/2026)

Implémentation retirée. Ce document reste la référence pour repartir :
§1-7 et §9 décrivent l'arcade telle qu'elle est ; §10 capitalise ce qui
peut être réinjecté sans refaire le travail d'analyse. Prochaine étape
suggérée : trancher le tracé des 8 libellés "N STAGE " (§9.3, point flou),
concevoir le score par stage côté moteur, puis la composition d'écran
complète avant de coder quoi que ce soit.
