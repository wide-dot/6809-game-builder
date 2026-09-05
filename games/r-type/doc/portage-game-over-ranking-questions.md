# Game over, saisie du nom, tableau des scores — les choix à faire

Questions posées le 04/09/2026 avant toute implémentation, à partir du
relevé arcade (`arcade-game-over-ranking-reference.md`) et de la maquette
(`portage-game-over-ranking-maquette.md`). Chaque question donne les faits
du portage qui pèsent, les options avec leur coût, et une recommandation.
Rien n'est tranché ici.

## Ce que le portage a déjà (faits)

- **Score** : `globals.score`, 24 bits en unités de 100 points, plafond
  99 999 (soit 9 999 900 affiché). Le relevé de fin de stage montre
  7 chiffres (5 significatifs + « 00 »).
- **Fin de stage** (`hud.asm`, unité `common.hud`, page 7, 5 713 o) :
  « S T A G E n C L E A R E D » ligne 52 puis « STAGE SCORE nnnnnnn »
  ligne 92, chiffres qui tournent, avec la police 4 × 8 copiée du title.
- **Game over** : message GAME OVER (images bm4 existantes, `messages`),
  tenu le temps du morceau (`hud.gameOverWait`), puis `stage.gameOver` :
  `game.stage := 0` et **rechargement de la scène title depuis la
  disquette** (`game.stage.switch`).
- **Continue** : écran CONTINUE déjà porté dans `hud.asm` (free play,
  « PUSH FIRE BUTTON », quota `game.continue.MAX` = 1, musique
  `sounds.continue.ymm` de 12 s). Il vient **avant** le GAME OVER, et il
  ne remet pas le score à zéro (écart arcade assumé).
- **Title** : phase d'attract 8 = tableau « R A N K I N G » dessiné par
  l'objet `text` avec la même police, données statiques `allscores`
  (mot = score/100 + 7 caractères, les dix noms de l'arcade), numéros de
  rang en sprites 18 × 9 (`scores` unit, `Img_number_01..10`), palette
  `Pal_scores`, pas 14 lignes.
- **RAM résidente** : le bloc `globals` ($9DCB–$9E5E, 148 o) est occupé à
  147 o. La carte mémoire est pleine (note mémoire du 03/09) : mesurer par
  zone avant d'ajouter quoi que ce soit au résident ou à l'arène `objects`.
- **Police** : A–Z, 0–9, espace, `!`, `.` ; les six glyphes de l'alphabet
  arcade (`? > < , - :`) ont leurs grilles dans `tools/gen_font_glyphs.py`,
  pas encore assemblées. Les glyphes ont des couleurs fixes (indices 3, 4,
  5, 6 en dégradé).
- **Entrées** : manette (A = tir, B, croix) et clavier via `joypad.kb`.

---

## Q1. Quand montrer STAGE SCORE et la saisie ?

Arcade : après le GAME OVER, **seulement si le score entre dans le top 10** ;
un joueur non classé ne voit ni STAGE SCORE ni RANKING.

| Option | Pour | Contre |
|---|---|---|
| A. Comme l'arcade : test du rang d'abord, écrans seulement si classé | fidèle ; rien de plus à afficher dans le cas courant | la plupart des parties d'un débutant ne montrent jamais le tableau par stage |
| B. STAGE SCORE + TOTAL toujours après le GAME OVER, saisie seulement si classé | le joueur voit toujours son bilan | écart arcade ; une attente de plus avant le title |
| C. Comme A, et le RANKING aussi quand on n'est pas classé | le joueur voit où il en est | écart ; deux écrans de plus à chaque partie |

Recommandation : **A**. C'est la règle arcade, et la table par défaut (dernier
rang 75 000) fait que le classement arrive vite dès qu'on joue un peu.

## Q2. Avant ou après le CONTINUE ?

Arcade : GAME OVER → rang → (saisie → tableau) → CONTINUE. Le continue
arcade remet le score et la table par stage à zéro. Portage actuel :
CONTINUE → refus → GAME OVER → title, score conservé.

| Option | Pour | Contre |
|---|---|---|
| A. Garder notre ordre : le classement se fait au GAME OVER final, une seule fois par partie | simple ; pas de double classement ; le score cumulé des continues est classé | écart d'ordre avec l'arcade, invisible pour le joueur |
| B. Ordre arcade : classer avant de proposer le continue | fidèle | un joueur qui continue est classé puis rejoue avec un score à zéro : il faut remettre le score à zéro au continue, ce qu'on a choisi de ne pas faire |

Recommandation : **A**.

> **Révisé le 04/09/2026** : l'auteur a rejoué la borne — classement AVANT le
> continue, et le continue remet le score et la table par stage à zéro (un
> nouveau crédit, dont le récapitulatif ne montre que ses stages). C'est
> l'ordre B qui est retenu, avec le score à zéro. Rendu possible sans
> chargement supplémentaire par la musique de saisie résidente (voir le plan).

## Q3. Où vit le code de ces écrans ?

Deux hôtes possibles, avec des conséquences très différentes.

| Option | Pour | Contre |
|---|---|---|
| A. Dans `common.hud` (page 7), à côté du relevé et du CONTINUE, appelé par `paged.call` depuis le corps de stage avant `stage.gameOver` | enchaînement immédiat après le GAME OVER, sans disque ; police et `hud.drawStr` déjà là | il faut la place dans l'arène `objects`, qui est pleine ; les sprites de rang du title et `Pal_scores` ne sont pas dans la scène de stage ; les Pata-Pata non plus |
| B. Dans la **scène title**, exécutés à l'entrée du title quand un drapeau résident dit « partie finie, rang n » | zéro octet dans les scènes de stage ; la police, les numéros de rang, `Pal_scores` et le tableau existant sont déjà chargés par le title ; le tableau du title devient naturellement le tableau vivant | un chargement disque entre GAME OVER et STAGE SCORE (le même qui existe déjà avant le title, l'arcade a de toute façon 2 s de noir) ; l'unité title grossit |

Recommandation : **B**. C'est le seul choix qui ne coûte rien aux stages,
et il unifie le RANKING du title et celui de fin de partie (Q5).

## Q4. La table des scores : vivante, résidente, format ?

Elle doit survivre aux échanges de scènes (stage ↔ title) : elle ne peut
vivre que dans la RAM résidente. Pas de sauvegarde disque possible (le
loader ne sait pas écrire) : comme l'arcade, la table repart des valeurs
par défaut à l'allumage.

| Sous-question | Options | Recommandation |
|---|---|---|
| Taille d'un score | 2 octets /100 (format `allscores` du title, plafond 6 553 500) ; **3 octets /100** (format `globals.score`, plafond 9 999 900) | 3 octets |
| Taille de la table | 10 × (3 + 7) = **100 o** | 100 o résidents à trouver hors du bloc `globals` (147/148 o) : un nouveau `<reserved>`, à mesurer |
| Valeurs par défaut | les dix entrées arcade (déjà dans le title) | garder |
| Ex æquo | arcade : strict, un score égal n'entre pas au-dessus | garder |

## Q5. Le RANKING du title et celui de fin de partie : un seul ?

Le title dessine déjà un tableau depuis `allscores` (statique). Si la table
devient vivante (Q4), le title doit lire la RAM et non sa constante.

| Option | Pour | Contre |
|---|---|---|
| A. Un seul rendu (celui du title, `text` mode 2 + sprites de rang), utilisé aussi après la saisie, nouvelle entrée mise en valeur | un seul code, une seule mise en page, les numéros de rang 18 × 9 existent | la mise en page du title (pas 14 lignes, score à la colonne 17) n'est pas celle de la maquette ; à harmoniser |
| B. Deux rendus : le title garde le sien, la fin de partie a le sien (maquette) | liberté de mise en page | deux codes pour la même chose |

Recommandation : **A**, en prenant la mise en page du title comme base et en
y ajoutant la mise en valeur de la nouvelle entrée (Q9).

## Q6. Table par stage : combien d'emplacements, et où ?

Arcade : 16 emplacements de 4 octets (deux tours de 8 stages), deux colonnes.
Le portage a 8 stages ; le second tour n'existe pas aujourd'hui.

| Option | Pour | Contre |
|---|---|---|
| A. 16 × 3 o = **48 o résidents**, deux colonnes comme l'arcade | prêt pour un second tour ; maquette telle quelle | 48 o résidents de plus |
| B. 8 × 3 o = 24 o, une seule colonne (gauche) | moitié moins ; l'écran reste lisible | l'écran ne ressemble plus à l'arcade sur une partie complète |
| C. Pas de table : afficher seulement le stage courant et le TOTAL | 0 o | on perd l'essentiel de l'écran |

Recommandation : **A** si les 48 o se trouvent, **B** sinon. Dans les deux
cas, l'écriture se fait à la fin de chaque stage (le relevé actuel calcule
déjà `score − stageScoreBase`).

## Q7. Mise en page (maquette)

| Point | Options | Recommandation |
|---|---|---|
| Pas vertical des lignes de stage | 16 px (arcade, tout remonte de deux rangées, « NO.n » colle au bas) ; **12 px** (les huit lignes tiennent en 96 px, 32 px d'air pour le bas) | 12 px |
| Titres « STAGE SCORE », « RANKING » | lettres jointes (44 px) ; **espacées** comme fait le title (« S T A G E ») | espacées, pour rester dans la langue visuelle du title |
| Lignes de score | jointes, 16 cellules de 4 px (obligé : 64 px la ligne) | jointes |
| Cases de saisie | 7 cases au pas de 8 px, tiret dans les cases vides (arcade) | garder |
| Rangs du RANKING | ` 1.`…`10.` en police ; **sprites 18 × 9 du title** | sprites du title (si Q3 = B) |
| GAME OVER | images bm4 existantes, position actuelle | garder |

## Q8. Saisie : commandes et limites

Arcade : gauche/droite font défiler 34 entrées (A–Z, `! ? > . , -`, RUB,
END), tir ou Force valide, RUB efface la case précédente, END termine,
7e lettre termine, limite 0x800 trames, auto-répétition après 12 trames.

| Option | Pour | Contre |
|---|---|---|
| A. Arcade à l'identique (croix gauche/droite, A valide, RUB/END dans l'alphabet) | fidèle, code minimal | RUB et END sont des glyphes à dessiner (arcade : tuiles 0x3C et 0x3A, aspect non vérifié) |
| B. A + raccourcis manette : haut/bas = défilement aussi, **B = RUB** | plus confortable | deux chemins pour la même action |
| C. A + **clavier** : une lettre tapée s'écrit directement, Entrée = END, Effacement = RUB | le TO8 a un clavier, c'est l'usage naturel | table touche → lettre à écrire ; à tester sous toje |

Recommandation : **A d'abord**, C en second temps si le clavier se prête
bien (`joypad.kb` lit déjà le clavier pour la manette).

Limite de temps : 0x800 trames arcade = 37 s ; à 50 Hz, 2 048 trames = 41 s
(règle du portage : comptes de trames arcade gardés tels quels). Garder.

## Q9. Clignotement de la lettre en cours et mise en valeur de la nouvelle entrée

La police a des couleurs fixes ; l'arcade alterne deux palettes (0xC/0xD)
toutes les 8 trames et colore la nouvelle ligne du tableau en palette 7.

| Option | Pour | Contre |
|---|---|---|
| A. **Clignotement on/off** : redessiner la lettre puis une case noire toutes les 8 trames ; nouvelle entrée du tableau signalée par un **marqueur** (`>` avant la ligne) ou par son clignotement | aucun coût palette ni glyphe | moins riche que deux couleurs |
| B. Animer les entrées de palette 3–6 | vraie alternance de couleur | change TOUT le texte de l'écran en même temps |
| C. Second jeu de glyphes dans d'autres indices | fidèle | 104 glyphes de plus, exclu par la mémoire |

Recommandation : **A**.

## Q10. Sons et musique

Arcade : SFX 0x28 (ouverture de l'écran), 0x40 (pas de curseur), 0x41
(validation), 0x2A (fin de saisie), 0x29 (passage au tableau). Musique
non tracée.

| Option | Pour | Contre |
|---|---|---|
| A. Réutiliser des bruitages existants (BonusSound pour valider, FireSound pour le pas, ExtraLife pour la fin) | zéro donnée | approximatif |
| B. Convertir les cinq SFX arcade par la chaîne son existante (`arcade-sound-reference.md`) | fidèle | cinq entrées de plus dans le pilote de bruitages, données à loger |
| Musique | silence ; ou un morceau (le continue en a un) | à ton choix |

Recommandation : **A** pour commencer, la conversion est un chantier à part.

## Q11. Les Pata-Pata décoratifs

L'objet et son art sont dans le cast des stages ; la scène title ne les a
pas. Les charger dans le title coûte de la place et du disque.

| Option | Pour | Contre |
|---|---|---|
| A. Sans Pata-Pata | rien à charger | l'écran est plus nu que l'arcade |
| B. Charger l'objet et son art dans la scène title | fidèle | page à trouver dans le title, chargement plus long |
| C. Une décoration du title (starfield, logo) à la place | pas de chargement | ce n'est pas l'arcade |

Recommandation : **A** pour la première version, B si la place se trouve.

## Q12. Le GAME OVER lui-même

L'arcade laisse GAME OVER figé 5,2 s. Le portage le tient le temps de son
morceau. Rien à changer, sauf si tu veux le noir de 2 s de l'arcade entre
GAME OVER et STAGE SCORE (avec Q3 = B, le chargement disque le fournit).

---

## Résumé des recommandations

| # | Sujet | Recommandation |
|---|---|---|
| 1 | Quand | Arcade : seulement si classé |
| 2 | Continue | Notre ordre, classement au GAME OVER final |
| 3 | Hôte | Scène title, à l'entrée, sur drapeau résident |
| 4 | Table | 10 × (3 + 7) = 100 o résidents, défauts arcade, ex æquo strict |
| 5 | Rendu du tableau | Un seul, celui du title, avec mise en valeur |
| 6 | Table par stage | 16 × 3 o si la place existe, sinon 8 |
| 7 | Mise en page | pas 12 px, titres espacés, sprites de rang du title |
| 8 | Saisie | Arcade, clavier plus tard |
| 9 | Clignotement | On/off, marqueur pour la nouvelle entrée |
| 10 | Sons | Bruitages existants |
| 11 | Pata-Pata | Sans, pour commencer |
| 12 | GAME OVER | Inchangé |

Deux mesures à faire avant de trancher 3, 4 et 6 : la place dans l'unité
title (arène `title`) et la place résidente pour 100 + 48 o.

---

## Décisions de l'auteur (04/09/2026) et faits vérifiés dans la foulée

| # | Décision |
|---|---|
| 1 | Seulement si classé. |
| 2 | Notre ordre (continue avant), classement au GAME OVER final. |
| 3 | **Unité HUD** (page 7, chemin `paged.call` depuis le corps de stage, avant `stage.gameOver`) : la police y est déjà, et les Pata-Pata sont dans la scène de stage. |
| 4 | **La demi-page de l'OST** ($4000–$5FFF, page 0 tranche 1, RAM stable sous OverlayMode) héberge tout l'état du système : scores par stage, table des dix, état de saisie. |
| 5 | Rendu unique du RANKING ; les sprites de rang y vont aussi si la place existe. |
| 6 | Saisie **manette seule**, pas de clavier. |
| 7 | Pata-Pata dès maintenant. GAME OVER inchangé. Musique : voir ci-dessous. |

### La demi-page de l'OST : la réserve est bien surestimée

`engine/constants.asm` : sous `OverlayMode` (posé par `to8.config.xml`),
`object_rsvd_size` vaut 5 et non 59, donc **`object_size` = 38 + 20 + 5 =
63** — le listing assemblé le confirme (`object_size` = $3F,
`Dynamic_Object_RAM_End` = $4EC4). Le layout, lui, réserve encore pour 117 :

| Bloc | Réservé (config) | Occupé réellement |
|---|---|---|
| `objects.pool` (60 slots) | $4000–$5B6B (7 020 o) | $4000–$4EC3 (3 780 o) |
| `objects.static` (4 OST) | $5B6C–$5D3F (468 o) | $4EC4–$4FBF (252 o) |
| `objects.bullets` | $5D40–$5F3F (512 o) | idem |
| queue libre | $5F40–$5FFF (192 o) | |

Soit **3 456 o inutilisés entre $4FC0 et $5D3F**, plus 192 o en queue. En
remontant `objects.bullets` juste après les OST statiques, le bloc libre
devient **contigu : $51C0–$5FFF = 3 648 o**. Ce qu'on veut y mettre :

| Contenu | Taille |
|---|---|
| table des dix : 10 × (3 o score/100 + 7 caractères) | 100 o |
| scores par stage : 16 × 3 o (deux tours) | 48 o |
| état de saisie (rang, curseur, index alphabet, minuterie, répétition) | ~8 o |
| sprites de rang du title (`title.scores`, 10 images 18 × 9 compilées) | 2 224 o |
| **total** | **~2 380 o** |

Ça tient, avec 1 200 o de marge. Points à valider au moment de le faire :
le `<reserved>` à redécouper (`objects.pool` à $0EC4, `objects.static` à
$00FC, `objects.bullets` remonté), les equates `ram.const.asm` qui bougent
avec (le commentaire y dit encore « object_size vaut 117 »), et le
chargement d'un direntry en page 0 tranche 1 (le loader écrit par la
fenêtre vidéo, le builder pose le bit de tranche — modèle mémoire de
septembre, jamais exercé sur cette demi-page : à vérifier sous toje). Les
sprites compilés s'exécutent alors à leur adresse absolue dans la
demi-page, quelle que soit la page montée en fenêtre cartouche.

### Le pas vertical : pourquoi 12 ou 16, et ce que donne l'arcade

Il n'y a **aucune contrainte technique** : l'ancre d'un glyphe est une
ligne quelconque (40 octets par ligne). Les deux valeurs de la maquette
venaient de la grille de dessin (rangées de 8 px), pas du matériel.

L'arcade met ses lignes au pas de 16 px sur 240 px de jeu, avec des glyphes
de 8 px : deux hauteurs de glyphe par ligne. Notre écran fait 200 px
(échelle 0,833) mais notre glyphe garde 8 lignes (non réduit) :

| Choix | Pas | Ce qu'il respecte |
|---|---|---|
| échelle de l'écran | **13 px** (16 × 200/240 = 13,3) | les proportions arcade à l'écran, tout l'écran occupé comme l'arcade |
| échelle de la police | 16 px | deux hauteurs de glyphe par ligne comme l'arcade, mais tout remonte de 2 rangées et la dernière ligne colle au bas |
| compact | 12 px | rien de particulier, c'était une grille de dessin |

Positions arcade mises à l'échelle (y = ancre haute du glyphe) :

| Élément | Arcade y | TO8 y (× 0,833) |
|---|---|---|
| STAGE SCORE / R A N K I N G | 32 | 27 |
| lignes de stage 1..8 | 56 … 168 pas 16 | 47 … 138 pas 13 |
| TOTAL au 17e emplacement | 184 | 153 |
| ENTER YOUR INITIALS. | 200 | 167 |
| NO.n et cases | 216 | 180 |
| rangs 1..10 du RANKING | 64 … 208 pas 16 | 53 … 173 pas 13 |
| GAME OVER (haut) | 104 | 87 |

Recommandation : **13 px, ancres ci-dessus** — c'est l'arcade à l'échelle,
et il reste 12 lignes sous « NO.n ».

### Musique : ce qui existe, et ce que fait l'arcade

Pistes prêtes dans le portage : title, `sounds.gameover.ymm`,
`sounds.continue.ymm` (12 s), `sounds.clearstage.ymm` (jingle),
`sounds.boss.ymm`. **Aucune piste dédiée** à l'écran des scores ou à la
saisie ; les sources ADNZ (`src/common/music/adnz`) n'en contiennent pas non
plus.

Arcade : la musique est coupée au kickoff (commande 0) et **rien n'en
relance** sur STAGE SCORE, la saisie ni RANKING — toutes les commandes de
ces états sont ≥ 0x22, des bruitages : 0x28 carillon d'ouverture, 0x40 pas
de curseur, 0x41 lettre validée, 0x2A fin de saisie, 0x29 passage au
tableau (`arcade-sound-reference.md`). L'arcade joue donc **en silence avec
des carillons**.

Options : silence + bruitages existants (BonusSound pour valider,
FireSound pour le pas) comme l'arcade ; ou une piste existante en boucle
(`continue.ymm` est la seule d'une durée utile) ; ou une piste à demander.

### Pas vertical : 12 px (décision auteur, 04/09/2026)

C'est l'échelle Y de la conversion arcade → TO8 du portage (0,75 : 16 px
arcade = 12 px, `scale.asm`), pas une grille de dessin. Ancres = y arcade
× 0,75, décalées de 10 px pour centrer les 180 px de terrain dans les
200 px sans HUD (table dans la maquette, section « pas de 12 px »).

### Musique : la piste de saisie (ajoutée par l'auteur le 04/09/2026)

`src/common/music/adnz/vgm/rtype-name-entry.vgm` (+ .dmf) : convertie par
`vgm2ymm`, **3 588 o**, 38,7 s, boucle sur toute la longueur. Où la loger
en page $1A :

| Créneau | Adresses | Taille | Occupé |
|---|---|---|---|
| lecteur | $1C9B–$20BB | 1 057 | plein |
| commun (boss, clearstage, continue, gameover) | $20BC–$2C08 | 2 893 | **plein à l'octet** (1220+502+897+274) |
| piste de stage / title | $2C09–$3BFF | 4 087 | la plus grosse : stage 1, 4 032 |
| zone `objects` | $3C00–$3FFF | 1 024 | arène commune |

Elle ne tient pas dans le créneau commun, mais **tient dans le créneau de
stage** (3 588 < 4 087). Au moment de la saisie la musique du stage est
finie et son créneau est libre : proposition = un direntry
`common.nameentry.ymm` à `$2C09`, chargé **depuis la disquette** par le
chemin HUD quand le classement est acquis (une scène d'un seul fichier,
comme les musiques de stage), là où l'arcade a de toute façon 2 s de noir.
À valider : appeler le loader depuis le corps de stage à ce point (page
DATA du loader montée, IRQ coupée, comme `game.stage.switch`), et le
`ymm.restart` ensuite. Sans disque, l'alternative est de déplacer la
frontière commun/stage de page $1A, ce qui rogne l'arène `objects` ($3C00)
déjà pleine.
