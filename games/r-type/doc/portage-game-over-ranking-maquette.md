# Maquette ASCII du portage — game over, STAGE SCORE, RANKING

Proposition du 04/09/2026, a discuter avant toute implementation. Hypotheses :

- ecran TO8 160 x 200 en BM16, **plein ecran, sans HUD** ;
- police = celle du stage cleared actuel (`hud.asm`, copie de la police du
  title) : glyphe **4 px de large x 8 lignes**, une cellule = un octet par
  plan, avance d'une cellule par caractere (`leau 1,u`), ancre au milieu du
  glyphe (`U-120..U+160`) ; le point d'ancrage peut etre n'importe quelle
  ligne, la grille de 8 lignes ci-dessous n'est qu'une commodite de dessin ;
- jeu de glyphes : A-Z, 0-9, espace, `!`, `.` (existants) + `? > < , - :`
  (grilles pretes dans `tools/gen_font_glyphs.py`, a assembler) ;
- GAME OVER : les deux images bm4 existantes (`messages/`, 59 et 58 x 10 px).

Grille : 40 cellules de 4 px en largeur, 25 rangees de 8 px en hauteur.
Une ligne de score arcade (16 cases de 8 px = 128 px) devient 16 cellules
de 4 px = 64 px : les deux colonnes de stages tiennent de front (x 12..75 et
88..151), comme sur l'arcade.

## Correspondance arcade -> portage

| Element | Arcade (case, x, y) | Portage (cellule, x, y) | Regle |
|---|---|---|---|
| `STAGE SCORE` | col 13, y 32 | cellule 4, y 16 | x * 160/384 ; y ramene sur la grille |
| stages 1-8 | col 12, y 56..168 pas 16 | cellule 3, y 32..144 pas 16 | pas 16 px garde (8 lignes + 8 de blanc) |
| stages 9-16 | col 34, y 56..168 | cellule 22, y 32..144 | idem |
| `TOTAL SC` | emplacement suivant | emplacement suivant (17e = cellule 22, y 160) | meme regle qu'en arcade |
| `ENTER YOUR INITIALS.` | col 18, y 200 | cellule 8, y 176 | 80 px de large, decale a gauche comme l'arcade |
| `NO.n` | col 24, y 216 | cellule 15, y 192 | |
| 7 cases de saisie | cols 30..42 pas 2, y 216 | cellules 21..33 pas 2, y 192 | pas 8 px (une cellule vide entre deux lettres) |
| `R A N K I N G` | col 25, y 32 | cellule 14, y 16 | centre a x 84 |
| rang r | cols 19..24, y 56+16(r-1) (graphisme 48x16) | cellules 9..11 `nn.`, y 32+16(r-1) | pas de graphisme de rang : le numero en police |
| score du rang r | col 27, y 64+16(r-1) | cellule 15, y 32+16(r-1) | 7 chiffres, zeros de tete blancs |
| nom | col 37 | cellule 25 | 7 caracteres |
| GAME OVER | x 112..271, y 104..119 | images existantes centrees, y ~ 88..98 | |

Ce qui change par rapport a l'arcade, et pourquoi :

- **25 rangees au lieu de 30** : tout remonte de deux rangees, le pas de
  16 px entre lignes est conserve (8 lignes de glyphe + 8 de blanc) ; la
  derniere ligne (`NO.`) occupe y 192..199, sans marge basse. Si on veut de
  l'air, passer le pas des stages a 12 px (l'ancre est libre) : les huit
  lignes tiennent alors en 96 px et tout descend de 16 px.
- **le graphisme de rang** (tuiles 0x38A.., 48 x 16 px, contenu inconnu)
  est remplace par ` 1.` .. `10.` dans la police.
- **les lettres se touchent** (4 px pleins) la ou l'arcade a 8 px par
  caractere : `STAGE SCORE` fait 44 px. Le title ecarte les lettres d'une
  cellule (`S T A G E`) ; on peut faire pareil pour les deux titres, pas pour
  les lignes de score (16 cellules pleines).
- **pas de HUD** : la bande basse arcade n'existe pas ici, l'ecran est a nous.
- Pata-Pata : `<o` marque des positions possibles, l'objet existe deja dans
  le portage (stage 1), il entre par la droite a une hauteur aleatoire.

### GAME OVER — images existantes (messages/), centrees, y ~ 88..98

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  8 |                                        |
y 16 |                                        |
y 24 |                                        |
y 32 |                                        |
y 40 |                                        |
y 48 |                                        |
y 56 |                                        |
y 64 |                                        |
y 72 |                                        |
y 80 |~~~~ terrain fige, vaisseau explose ~~~~|
y 88 |    [ G A M E ]     [ O V E R ]         |
y 96 |      59 px          58 px              |
y104 |                                        |
y112 |                                        |
y120 |                                        |
y128 |                                        |
y136 |                                        |
y144 |                                        |
y152 |                                        |
y160 |                                        |
y168 |                                        |
y176 |                                        |
y184 |                                        |
y192 |                                        |
      +----------------------------------------+
       x = 4 * colonne ; chaque cellule = un glyphe de 4 px
```

### STAGE SCORE + saisie — partie 1 -> 3, rang 3, 'AB' saisi, 'C' clignote

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  8 |                                     <o |
y 16 |    STAGE SCORE                         |
y 24 |                                        |
y 32 |    1 STAGE   12300                     |
y 40 |                                        |
y 48 |    2 STAGE   25650                     |
y 56 |                                        |
y 64 |    3 STAGE    8900                     |
y 72 |                                    <o  |
y 80 |   TOTAL SC   46850                     |
y 88 |                                        |
y 96 |                                        |
y104 |                                        |
y112 |                                        |
y120 |                                       <|
y128 |                                        |
y136 |                                        |
y144 |                                        |
y152 |                                      <o|
y160 |                                        |
y168 |                                        |
y176 |        ENTER YOUR INITIALS.            |
y184 |                                        |
y192 |               NO.3  A B C - - - -      |
      +----------------------------------------+
       x = 4 * colonne ; chaque cellule = un glyphe de 4 px
```

### STAGE SCORE — partie complete 1 -> 16

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  8 |                                     <o |
y 16 |    STAGE SCORE                         |
y 24 |                                        |
y 32 |    1 STAGE  174500    9 STAGE   15000  |
y 40 |                                        |
y 48 |    2 STAGE   90000   10 STAGE   45600  |
y 56 |                                        |
y 64 |    3 STAGE   61200   11 STAGE   78900  |
y 72 |                                    <o  |
y 80 |    4 STAGE   45000   12 STAGE   12000  |
y 88 |                                        |
y 96 |    5 STAGE  120000   13 STAGE   66000  |
y104 |                                        |
y112 |    6 STAGE   33300   14 STAGE   91000  |
y120 |                                       <|
y128 |    7 STAGE   98700   15 STAGE   30000  |
y136 |                                        |
y144 |    8 STAGE  210000   16 STAGE  250000  |
y152 |                                      <o|
y160 |                      TOTAL SC 1421200  |
y168 |                                        |
y176 |        ENTER YOUR INITIALS.            |
y184 |                                        |
y192 |               NO.1  A - - - - - -      |
      +----------------------------------------+
       x = 4 * colonne ; chaque cellule = un glyphe de 4 px
```

### RANKING — nouvelle entree au rang 3 (couleur distincte)

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  8 |                                        |
y 16 |              R A N K I N G             |
y 24 |                                        |
y 32 |          1.    174500   ABIKO..        |
y 40 |                                        |
y 48 |          2.    168600   SUMITA         |
y 56 |                                        |
y 64 |          3.    150000   AB       <=    |
y 72 |                                        |
y 80 |          4.    159700   AKIO.O         |
y 88 |                                        |
y 96 |          5.    117900   SHINJI.        |
y104 |                                        |
y112 |          6.    100500   MISAKO!        |
y120 |                                        |
y128 |          7.     98900   MASATO         |
y136 |                                        |
y144 |          8.     92000   HAMA...        |
y152 |                                        |
y160 |          9.     80000   KENT.K         |
y168 |                                        |
y176 |         10.     76000   JIJEE..        |
y184 |                                        |
y192 |                                        |
      +----------------------------------------+
       x = 4 * colonne ; chaque cellule = un glyphe de 4 px
```


## Variante retenue le 04/09/2026 : pas de 12 px

Le pas vertical du portage est l'echelle Y de la conversion arcade -> TO8 (0,75 :
16 px arcade = 12 px). Ancres = y arcade x 0,75, plus un decalage de 10 px pour
centrer les 180 px de terrain arcade dans les 200 px de l'ecran sans HUD.
Titres espaces comme le title. Rangs du RANKING : le numero en police ici, les
sprites 18 x 9 du title (5 cellules de large) si la demi-page les loge.

| Element | Arcade y | x 0,75 | + 10 |
|---|---|---|---|
| titres | 32 | 24 | 34 |
| stages 1..8 | 56..168 | 42..126 pas 12 | 52..136 |
| TOTAL (17e) | 184 | 138 | 148 |
| ENTER YOUR INITIALS. | 200 | 150 | 160 |
| NO.n | 216 | 162 | 172 |
| rangs 1..10 | 64..208 | 48..156 pas 12 | 58..166 |

### STAGE SCORE + saisie, pas 12 px — partie 1 -> 3, rang 3

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  4 |                                        |
y  8 |                                     <o |
y 12 |                                     .. |
y 16 |                                        |
y 20 |                                        |
y 24 |                                        |
y 28 |                                        |
y 32 |    S T A G E   S C O R E               |
y 36 |    . . . . .   . . . . .               |
y 40 |                                        |
y 44 |                                        |
y 48 |                                        |
y 52 |    1 STAGE   12300                     |
y 56 |    . .....   .....                     |
y 60 |                                        |
y 64 |    2 STAGE   25650                     |
y 68 |    . .....   .....                 <o  |
y 72 |                                    ..  |
y 76 |    3 STAGE    8900                     |
y 80 |    . .....    ....                     |
y 84 |                                        |
y 88 |   TOTAL SC   46850                     |
y 92 |   ..... ..   .....                     |
y 96 |                                        |
y100 |                                        |
y104 |                                        |
y108 |                                       <|
y112 |                                       .|
y116 |                                        |
y120 |                                        |
y124 |                                        |
y128 |                                        |
y132 |                                      <o|
y136 |                                      ..|
y140 |                                        |
y144 |                                        |
y148 |                                        |
y152 |                                        |
y156 |                                        |
y160 |        ENTER YOUR INITIALS.            |
y164 |        ..... .... .........            |
y168 |                                        |
y172 |               NO.3  A B C - - - -      |
y176 |               ....  . . . . . . .      |
y180 |                                        |
y184 |                                        |
y188 |                                        |
y192 |                                        |
y196 |                                        |
      +----------------------------------------+
       une rangee = 4 px ; un glyphe = 2 rangees (lettre puis '.') ; x = 4 * colonne
```

### STAGE SCORE, pas 12 px — partie complete 1 -> 16

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  4 |                                        |
y  8 |                                     <o |
y 12 |                                     .. |
y 16 |                                        |
y 20 |                                        |
y 24 |                                        |
y 28 |                                        |
y 32 |    S T A G E   S C O R E               |
y 36 |    . . . . .   . . . . .               |
y 40 |                                        |
y 44 |                                        |
y 48 |                                        |
y 52 |    1 STAGE  174500    9 STAGE   15000  |
y 56 |    . .....  ......    . .....   .....  |
y 60 |                                        |
y 64 |    2 STAGE   90000   10 STAGE   45600  |
y 68 |    . .....   .....   .. .....   ...<o  |
y 72 |                                    ..  |
y 76 |    3 STAGE   61200   11 STAGE   78900  |
y 80 |    . .....   .....   .. .....   .....  |
y 84 |                                        |
y 88 |    4 STAGE   45000   12 STAGE   12000  |
y 92 |    . .....   .....   .. .....   .....  |
y 96 |                                        |
y100 |    5 STAGE  120000   13 STAGE   66000  |
y104 |    . .....  ......   .. .....   .....  |
y108 |                                       <|
y112 |    6 STAGE   33300   14 STAGE   91000 .|
y116 |    . .....   .....   .. .....   .....  |
y120 |                                        |
y124 |    7 STAGE   98700   15 STAGE   30000  |
y128 |    . .....   .....   .. .....   .....  |
y132 |                                      <o|
y136 |    8 STAGE  210000   16 STAGE  250000..|
y140 |    . .....  ......   .. .....  ......  |
y144 |                                        |
y148 |                      TOTAL SC 1421200  |
y152 |                      ..... .. .......  |
y156 |                                        |
y160 |        ENTER YOUR INITIALS.            |
y164 |        ..... .... .........            |
y168 |                                        |
y172 |               NO.1  A - - - - - -      |
y176 |               ....  . . . . . . .      |
y180 |                                        |
y184 |                                        |
y188 |                                        |
y192 |                                        |
y196 |                                        |
      +----------------------------------------+
       une rangee = 4 px ; un glyphe = 2 rangees (lettre puis '.') ; x = 4 * colonne
```

### RANKING, pas 12 px — nouvelle entree au rang 3

```
      0         1         2         3         
      0123456789012345678901234567890123456789
      +----------------------------------------+
y  0 |                                        |
y  4 |                                        |
y  8 |                                        |
y 12 |                                        |
y 16 |                                        |
y 20 |                                        |
y 24 |                                        |
y 28 |                                        |
y 32 |              R A N K I N G             |
y 36 |              . . . . . . .             |
y 40 |                                        |
y 44 |                                        |
y 48 |                                        |
y 52 |                                        |
y 56 |          1.    174500   ABIKO..        |
y 60 |          ..    ......   .......        |
y 64 |                                        |
y 68 |          2.    168600   SUMITA         |
y 72 |          ..    ......   ......         |
y 76 |                                        |
y 80 |          3.    150000   AB       <=    |
y 84 |          ..    ......   ..       ..    |
y 88 |                                        |
y 92 |          4.    159700   AKIO.O         |
y 96 |          ..    ......   ......         |
y100 |                                        |
y104 |          5.    117900   SHINJI.        |
y108 |          ..    ......   .......        |
y112 |                                        |
y116 |          6.    100500   MISAKO!        |
y120 |          ..    ......   .......        |
y124 |                                        |
y128 |          7.     98900   MASATO         |
y132 |          ..     .....   ......         |
y136 |                                        |
y140 |          8.     92000   HAMA...        |
y144 |          ..     .....   .......        |
y148 |                                        |
y152 |          9.     80000   KENT.K         |
y156 |          ..     .....   ......         |
y160 |                                        |
y164 |         10.     76000   JIJEE..        |
y168 |         ...     .....   .......        |
y172 |                                        |
y176 |                                        |
y180 |                                        |
y184 |                                        |
y188 |                                        |
y192 |                                        |
y196 |                                        |
      +----------------------------------------+
       une rangee = 4 px ; un glyphe = 2 rangees (lettre puis '.') ; x = 4 * colonne
```
