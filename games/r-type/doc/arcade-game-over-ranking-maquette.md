# Maquette ASCII — game over, STAGE SCORE, RANKING (arcade)

Generee depuis le releve `arcade-game-over-ranking-reference.md` (04/09/2026), a comparer a la video arcade. Grille 48 x 30 cases de jeu + 2 cases de HUD.

Legende : une case = 8 x 8 px ; `y` = pixel de la ligne, `lNN` = ligne tilemap.
`GGAAMMEE` = huit sprites 16 x 16 (deux cases par lettre, deux lignes de haut).
`%%%%` + numero = graphisme de rang 6 x 2 cases (tuiles 0x38A.., palette 8), contenu inconnu.
`<o` = Pata-Pata (positions aleatoires parmi 16 hauteurs, entrent par la droite).
Les deux lignes HUD (tilemap 0-1) sont affichees en bas de l'ecran et sont vides ici.

### GAME OVER (0x11F trames fige, puis fondu au noir)

```
      0         1         2         3         4       
      012345678901234567890123456789012345678901234567
      +------------------------------------------------+
y  0 |~ terrain du stage, fige, sous les 8 sprites ~  | l16
y  8 |                                                | l17
y 16 |                                                | l18
y 24 |                                                | l19
y 32 |                                                | l20
y 40 |                                                | l21
y 48 |                                                | l22
y 56 |                                                | l23
y 64 |                                                | l24
y 72 |                                                | l25
y 80 |                                                | l26
y 88 |                                                | l27
y 96 |                                                | l28
y104 |              GGAAMMEE    OOVVEERR              | l29
y112 |              GGAAMMEE    OOVVEERR              | l30
y120 |                                                | l31
y128 |                                                | l32
y136 |                                                | l33
y144 |                                                | l34
y152 |                                                | l35
y160 |                                                | l36
y168 |                                                | l37
y176 |                                                | l38
y184 |                                                | l39
y192 |                                                | l40
y200 |                                                | l41
y208 |                                                | l42
y216 |                                                | l43
y224 |                                                | l44
y232 |                                                | l45
HUD  |                                                | l00
HUD  |                                                | l01
      +------------------------------------------------+
```

### STAGE SCORE + saisie — partie 1 -> 3, rang 3, 'AB' saisi, 'C' clignote

```
      0         1         2         3         4       
      012345678901234567890123456789012345678901234567
      +------------------------------------------------+
y  0 |                                                | l16
y  8 |                                            <o  | l17
y 16 |                                                | l18
y 24 |                                                | l19
y 32 |     STAGE SCORE                                | l20
y 40 |                                                | l21
y 48 |                                                | l22
y 56 |     1 STAGE   12300                            | l23
y 64 |                                                | l24
y 72 |     2 STAGE   25650                            | l25
y 80 |                                          <o    | l26
y 88 |     3 STAGE    8900                            | l27
y 96 |                                                | l28
y104 |    TOTAL SC   46850                            | l29
y112 |                                                | l30
y120 |                                                | l31
y128 |                                                | l32
y136 |                                               <| l33
y144 |                                                | l34
y152 |                                                | l35
y160 |                                                | l36
y168 |                                                | l37
y176 |                                                | l38
y184 |                                                | l39
y192 |                                         <o     | l40
y200 |          ENTER YOUR INITIALS.                  | l41
y208 |                                                | l42
y216 |                NO.3  A B C - - - -             | l43
y224 |                                                | l44
y232 |                                                | l45
HUD  |                                                | l00
HUD  |                                                | l01
      +------------------------------------------------+
```

### STAGE SCORE — partie complete 1 -> 16 (deux colonnes, TOTAL en 17e)

```
      0         1         2         3         4       
      012345678901234567890123456789012345678901234567
      +------------------------------------------------+
y  0 |                                                | l16
y  8 |                                            <o  | l17
y 16 |                                                | l18
y 24 |                                                | l19
y 32 |     STAGE SCORE                                | l20
y 40 |                                                | l21
y 48 |                                                | l22
y 56 |     1 STAGE  174500       9 STAGE   15000      | l23
y 64 |                                                | l24
y 72 |     2 STAGE   90000      10 STAGE   45600      | l25
y 80 |                                          <o    | l26
y 88 |     3 STAGE   61200      11 STAGE   78900      | l27
y 96 |                                                | l28
y104 |     4 STAGE   45000      12 STAGE   12000      | l29
y112 |                                                | l30
y120 |     5 STAGE  120000      13 STAGE   66000      | l31
y128 |                                                | l32
y136 |     6 STAGE   33300      14 STAGE   91000     <| l33
y144 |                                                | l34
y152 |     7 STAGE   98700      15 STAGE   30000      | l35
y160 |                                                | l36
y168 |     8 STAGE  210000      16 STAGE  250000      | l37
y176 |                                                | l38
y184 |                          TOTAL SC 1421200      | l39
y192 |                                         <o     | l40
y200 |          ENTER YOUR INITIALS.                  | l41
y208 |                                                | l42
y216 |                NO.1  A - - - - - -             | l43
y224 |                                                | l44
y232 |                                                | l45
HUD  |                                                | l00
HUD  |                                                | l01
      +------------------------------------------------+
```

### RANKING — nouvelle entree au rang 3 (palette 7)

```
      0         1         2         3         4       
      012345678901234567890123456789012345678901234567
      +------------------------------------------------+
y  0 |                                                | l16
y  8 |                                                | l17
y 16 |                                                | l18
y 24 |                                                | l19
y 32 |                 R A N K I N G                  | l20
y 40 |                                                | l21
y 48 |                                                | l22
y 56 |           %%%% 1                               | l23
y 64 |           %%%%%%   174500   ABIKO..            | l24
y 72 |           %%%% 2                               | l25
y 80 |           %%%%%%   168600   SUMITA             | l26
y 88 |           %%%% 3                               | l27
y 96 |           %%%%%%   150000   AB       <= pal 7  | l28
y104 |           %%%% 4                               | l29
y112 |           %%%%%%   159700   AKIO.O             | l30
y120 |           %%%% 5                               | l31
y128 |           %%%%%%   117900   SHINJI.            | l32
y136 |           %%%% 6                               | l33
y144 |           %%%%%%   100500   MISAKO!            | l34
y152 |           %%%% 7                               | l35
y160 |           %%%%%%    98900   MASATO             | l36
y168 |           %%%% 8                               | l37
y176 |           %%%%%%    92000   HAMA...            | l38
y184 |           %%%% 9                               | l39
y192 |           %%%%%%    80000   KENT.K             | l40
y200 |           %%%%10                               | l41
y208 |           %%%%%%    76000   JIJEE..            | l42
y216 |                                                | l43
y224 |                                                | l44
y232 |                                                | l45
HUD  |                                                | l00
HUD  |                                                | l01
      +------------------------------------------------+
```
