# EN COURS — le champ de gommes du stage 4

*22/08/2026. Les phases 1, 2 et 3.1/3.2 sont livrées ; la passe DESSINE JUSTE à
l'écran. Il reste à la rendre rapide.*

Les deux documents de fond restent la référence :
[`analyse-gommes-stage4.md`](analyse-gommes-stage4.md) (mesures, extraction
arcade, structure) et [`plan-gommes-stage4.md`](plan-gommes-stage4.md) (le
découpage en phases). Ce fichier-ci ne dit que : où on en est, et par quoi
reprendre.

---

## L'état, en une table

| phase | état | preuve |
|---|---|---|
| 1 — les gommes sortent du décor | **faite** | validée à l'écran ; DrawTiles sur la salle 120 597 → 11 841 cy |
| 2 — la carte mutable + primitives | **faite** | logique rejouée sur les vraies cartes, 11 520 cellules |
| 2b — remise à neuf au checkpoint | **faite** | RLE 263 o, crochet `stage.checkpointReset` |
| 3.1 — les tables de rendu | **faite** | 622 080 px comparés à l'art, 0 divergence |
| 3.2 — la passe, premier jet | **faite** | **validée à l'écran par l'auteur** : position, couleurs, scroll |
| 3.2b — le blast | **à écrire** | ← reprendre ici |
| 3.4 — fusionner avec l'effacement | différée | optimisation, pas prérequis |
| 4 — creuser | à faire | |
| 5 — cytron et la repousse | à faire | cytron est au budget (décision auteur) |
| 6 — profondeur par objet | bloquée | dépend de l'ordre global sprite/plan avant, §8 de l'analyse |

**C'est lent, et c'est attendu** : la v1 écrit octet par octet, sans blast.

---

## Par quoi reprendre : le blast

Le seul travail restant sur la phase 3. L'intérieur d'une plage passerait
d'environ 900 cycles à ~116 par (ligne, plan) — la salle de ~300 000 cycles à
~33 000, ce que la simulation annonce.

### Le fichier

`src/stages/04/pellet-blast.asm`, routine `pellet.drawPlane`. Elle écrit
aujourd'hui tous ses octets un par un dans une boucle unique. Il faut y insérer
un chemin rapide.

### Deux simplifications déjà trouvées — les garder

**Un seul jeu de registres au lieu de trois.** Un bloc `PSHS A,B,DP,X,Y,U`
écrit 9 octets = exactement 3 périodes du motif. Si le bloc **finit toujours à
un indice ≡ 2 (mod 3)**, ses neuf octets commencent invariablement à la
rotation 0 : `p0,p1,p2` répété trois fois. Un seul jeu par (ligne, plan) donc,
précalculé une fois par trame — 108 octets — au lieu d'une rotation à
recalculer par plage.

L'ordre mémoire d'un `PSHS A,B,DP,X,Y,U`, en montant depuis `S-9` :
`A B DP Xh Xl Yh Yl Uh Ul`. Avec le motif `p0,p1,p2` :
`A=p0 B=p1 DP=p2 X=(p0<<8)|p1 Y=(p2<<8)|p0 U=(p1<<8)|p2`.

**L'entrée dans le déroulé se calcule AVANT de charger les registres.** Une
fois `A,B,DP,X,Y,U` chargés il ne reste plus rien pour compter les blocs :
l'opérande auto-modifiée du `JMP` doit être posée en premier, exactement comme
`playfield.clearWindow` le fait pour `clearblast`. Au plus 4 blocs (36 octets
d'intérieur / 9), donc une chaîne de 4 `PSHS` et une entrée calculée à
`chaîne + (4-n)*2`.

### Les trois pièges de clearblast, qui s'appliquent tels quels

Ils sont documentés dans l'en-tête de `src/common/fx/clearblast.asm` — les
relire avant d'écrire :

1. **aucun `bsr`/`rts` tant que `S` est le pointeur d'écriture** ; sauver `S`
   dans une variable, le restaurer avant de sortir ;
2. **`CC` est impoussable sous IRQ ouvertes** (l'IRQ matérielle force `E=1`
   dans le CC empilé) — d'où 9 octets et pas 10 ;
3. **`DP` fait partie des octets poussés** : il est détruit par le blast et
   doit être restauré. Le contrat engine est `$9F` (globales) — voir
   `docs/lang/en/direct-page.md`.

`S` dans la VRAM est légal : l'IRQ v2 bascule `S` en première instruction, et
seul le push matériel touche la zone pas encore écrite — le blast descendant,
elle est de toute façon sur le point d'être réécrite.

### Ce qui a fait échouer ma tentative

J'ai écrit le blast en fin de session et je l'ai raté : `S` n'était jamais
positionné sur l'adresse cible, il restait un `pshs a`/`puls a` sans objet, et
la boucle des octets restants était à moitié écrite. **Le brouillon a été
jeté**, pas commité. Écrire cette partie au calme, c'est là que `S` pointe dans
la VRAM.

Découpe suggérée, dans `drawPlane`, une fois `ja`/`jb` calculés :

```
ji = ja + (1 si le pixel gauche de ja sort a gauche)
jf = jb - (1 si le pixel droit de jb sort a droite)
jt = le plus grand indice <= jf avec jt = 2 (mod 3)
n  = (jt - ji + 1) / 9
si n > 0 : poser l'operande du JMP, charger les registres, sauver S,
           S = base + jt + 1, sauter dans la chaine, restaurer S et DP
le reste ([ja .. jt-9n] et [jt+1 .. jb]) part dans la boucle octet par octet
```

---

## Le filet : la simulation

**`tools/gen_pellet_tables.py` rejoue exactement ce que fait le 6809** et
compare le résultat à l'art, au pixel. C'est ce qui a permis de valider le
rendu avant de l'écrire — et ce qui a pris en défaut deux bugs que 622 080
pixels « vérifiés » avaient laissés passer.

```bash
python3 tools/gen_pellet_tables.py --verifier-seulement   # ne réécrit rien
python3 tools/gen_pellet_tables.py                        # régénère les tables
```

La fonction `passe()` du module est le modèle de la routine ; toute
modification de l'algorithme doit y être rejouée d'abord. Résultats attendus :
0 divergence sur les 12 phases, champ intact, 20 tunnels et 50 % de grignotage
aléatoire.

Le blast ne change PAS l'algorithme — seulement la façon d'écrire les mêmes
octets. La simulation reste donc valide telle quelle, et sert de référence si
l'écran diverge.

---

## Ce qu'il faut savoir sur la mémoire

- **La passe est RÉSIDENTE**, page 1, arène `stage4.res` à `$92DB` (2 800 o,
  elle en prend 1 117). En RAM fixe, elle lit la page collision montée
  (`$0000-$3FFF`) ET écrit l'écran (`$A000`/`$C000`) en même temps : trois
  fenêtres indépendantes, aucune bascule.
- Les huit arènes `stageN.res` à la même adresse (changement auteur du 22/08)
  remplacent le `<reserved>` qui bloquait la bande pour tous les stages : la
  zone ne porte que le stage EN COURS, les réservations sont des alternatives.
- **`$4000-$5FFF` reste le filet** si la passe grossit : 8 Ko, l'autre moitié
  de la page 0, libre depuis que l'overlay a supprimé les cellules de fond. Se
  bascule par `$E7C3` bit 0 — mais rend le pool d'objets inadressable pendant
  la bascule, donc à éviter tant qu'on tient dans la bande.

---

## Les pièges payés cette session

- **La différence de deux symboles `EXTERNAL` n'existe pas à l'assemblage** :
  ils sont résolus séparément au chargement. L'écart entre les deux cartes est
  figé à 1440 dans `pellet-blast.asm`, avec un garde-fou `IFNE` dans
  `collision.asm` qui refuse d'assembler si elles cessent d'être contiguës.
- **Les index de l'`in.png` sont ceux du PNG, pas du matériel** : la chaîne
  numérote la palette à partir de 1, l'index 16 existe et ne tient pas dans un
  quartet. `matériel = PNG − 1`. Vérifiable sur une tuile compilée : la ligne
  PNG (13,13,16) y sort en `$cc` puis `$f0`.
- **`LEAS` ne touche pas `CC`** (contrairement à `LEAX`/`LEAY`) : le `Z` posé
  par le dernier `ANDB`/`CLRB` survit jusqu'au `RTS`. Les primitives de
  `pellet.asm` en dépendent.
- **Une ligne vide termine la portée des labels locaux `@` de lwasm** — ne pas
  en mettre à l'intérieur d'une routine qui en utilise.
- **`gen/` empoisonné** : un build raté fausse le suivant. `rm -rf gen` avant
  toute conclusion.

---

## Deux écarts assumés, à trancher à l'écran

1. **32 gommes sur 1 618** (rangée 5, colonnes 296-327) portent une variante
   en miroir vertical qui n'est pas traitée — 2 % du champ, un seul ruban
   horizontal. Le traiter demande un second motif et une coupure de plage.
2. **La passe déborde d'un ou deux pixels sur la bordure** (x 6..153, l'écran
   fait 0..159), que le masque du champ recouvre en fin de trame. C'est ce que
   fait déjà `DrawTiles` avec sa marge gauche.

---

## Construire et vérifier

```bash
cd games/r-type-overlay
rm -rf gen dist
java -Dbasedir=<racine du repo> -cp "../../repo/*" \
     com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Les tests sont à la main de l'auteur : livrer le build et rendre la main ; toje
seulement sur demande explicite.

---

## Git

Tout est sur `overlay-render`, poussé. Le dernier commit du chantier gommes est
`7815f92a` (la passe) ; `31152a44` (auteur) a basculé la bande par-stage en
arènes. `master` est en retard de plusieurs commits — c'est l'état voulu par
l'auteur, ne pas le faire avancer sans le lui demander.

Côté `re.arcade.r-type` (`main`, poussé) : les extracteurs `BallField`
(`--extract-ballfield`) et `SpriteAttr` (`--extract-spriteattr`) produisent les
masques, les métadonnées de cellule et le recensement d'attributs de sprite.
