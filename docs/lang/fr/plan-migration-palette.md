# Migration palette — plan de travail et suivi

Le TODO de la campagne. L'étude qui le fonde :
[`analyse-palette-migration-2026-08.md`](analyse-palette-migration-2026-08.md) —
la nouvelle palette, la table de correspondance, les arbitrages et le protocole
y sont ; on ne les redit pas ici.

**Branche `new-color`, jamais fusionnée vers `master` avant la fin.** Chaque
ressource se termine par une planche PNG soumise à l'auteur ; rien n'est
committé sans sa validation.

## Les règles du protocole

**0. Une planche pour chaque décision, et une planche seulement là où l'œil a
quelque chose à voir** (auteur, 16/08). Rien ne se valide sans planche — mais
mesure faite, **seuls quatre anciens index changent de couleur** :

| ancien | | |
|---|---|---|
| 3 `#9E8F7A` | beige foncé | pas de cible : à trancher, ressource par ressource |
| 4 `#CCC2AB` | beige clair | idem |
| 12 `#617A00` | olive | idem (index propre au stage) |
| 10 `#F2AB00` | orange | devient le saumon `#F99B68` |

Tout le reste de la migration est une **renumérotation pure** : mêmes couleurs
rendues, au pixel près. L'outil le dit dans `--liste`, et pour ces
ressources-là il ne demande pas de planche — il **prouve** l'égalité, en
comparant le rendu RVB de l'original et celui du migré pixel par pixel. C'est
plus fort qu'un coup d'œil, et ça a été vérifié en cassant la table de report
exprès : le contrôle s'arrête sur la première image. Les douze ressources du
groupe A sont dans ce cas — leurs planches n'ont validé que l'outil.

**0 bis. Une recette retenue vaut pour SA ressource, pas pour les autres**
(auteur, 16/08). Ce qui convient au vaisseau ne convient pas forcément au pow :
une décision s'écrit toujours sous le **nom** de la ressource, jamais sur la
ligne `defaut`. Les fichiers de `tools/palette-variantes/` expriment une
*recette* (quel neutre fusionne) avec la clé `*`, « la ressource en cours » :
ils servent à comparer, ils ne décident pour personne.

## Les deux règles de conversion

**1. Conserver les niveaux de dégradé** (auteur, 16/08). Une ressource qui
montre N valeurs doit en montrer N après migration. Deux index employés qui
tombent sur le même sont une marche de rampe perdue, et l'outil **arrête**
plutôt que de la laisser passer : il nomme les coupables et liste les marches
encore libres dans la nouvelle palette. La méthode, quand la table par défaut
provoque une collision : classer les index *employés par cette ressource* par
luminance et les poser sur autant de marches de la nouvelle palette, dans le
même ordre — une bijection par rang, pas une fusion. Une fusion réellement
voulue et mesurée se déclare par le mot `fusion-ok` sur la ligne de la
ressource ; jamais par omission.

*Limite trouvée sur `common.player` le 16/08 :* le classement par luminance ne
vaut **qu'à l'intérieur d'une famille de teinte**. Appliqué en bloc à une
ressource qui mêle bleus, chauds et neutres, il enverrait le bleu `00618F` sur
le rouge `AC0000` — même rang, autre monde. Les trois familles sont énumérées
en tête de `palette-map.txt`. Une seule est en déficit : les **neutres**, six
anciennes valeurs (dont les deux beiges) pour quatre gris.

**2. Toute conversion est un script** (auteur, 16/08). Rien ne se fait à la
main. Deux fichiers portent la campagne, et rien d'autre :

| fichier | ce qu'il porte |
|---|---|
| `tools/palette-map.txt` | **les paramètres** — ce que devient chaque index, ressource par ressource, avec le pourquoi |
| `tools/palette-replay.sh` | **les commandes** — quelles ressources ont été validées, dans quel ordre |

Une ligne dans la table sans sa ressource dans le script est une *proposition* ;
elle devient une décision appliquée quand l'auteur valide et que le script la
nomme. L'ordre du script compte : une image déclarée par deux ressources est
décidée par la première nommée.

`sh tools/palette-replay.sh --verifier` est la preuve que ce couple **est** la
campagne et non son récit : il crée une copie fraîche de `origin/master`, y
rejoue tout, et compare `src/` à l'arbre courant. Un écart signifie qu'un geste
manuel s'est glissé quelque part. À rejouer avant chaque commit de migration.

Ordre général : l'outil d'abord, puis les ressources qui ne demandent aucune
décision (elles valident la chaîne), puis celles qui en demandent, **les tuiles
en dernier** (décision auteur).

## État

- [x] **0. L'outil** — `tools/palette_migrate.py`, qui **importe** le relevé de
      `palette_usage.py` (une seule source pour la liste des ressources et de
      leurs images) et y ajoute les deux pièces qui manquaient : une **table de
      correspondance en entrée** (`tools/palette-map.txt`) et l'**écriture des
      PNG migrés**. Outil séparé assumé : le relevé reste en lecture seule.
      Trois modes — `--liste` (le reste à faire), `--apercu` (la planche, rien
      d'écrit), `--ecrire` (applique, puis **relit chaque fichier** pour vérifier
      que la table et les index sont bien ceux prévus). Un index présent dans une
      image mais absent de la table **arrête** l'outil : aucune couleur ne peut
      être migrée par inadvertance.
      Une image déjà migrée par une autre ressource est **héritée**, pas refusée
      ni ré-appliquée (cas des deux impacts partagés `weapon`/`simplefire`) —
      y compris entre deux ressources d'une même commande, où la première
      nommée décide.
      Plusieurs ressources en une commande donnent **une seule planche**, une
      section par ressource : un tour de validation = un fichier à regarder.
      Les deux règles du protocole ci-dessus sont dans l'outil : la collision
      de rampe arrête, et `palette-replay.sh --verifier` prouve le rejeu.

### Groupe A — renumérotation pure, aucune décision (12 ressources, 75 images)

Ces ressources n'emploient que des couleurs conservées : la table de
correspondance suffit, la planche ne sert qu'à confirmer que l'outil ne ment
pas. À traiter d'un bloc, en un seul aller-retour de validation.

**Validé par l'auteur le 16/08/2026, appliqué** (73 fichiers distincts réécrits,
dont 2 hérités) :

- [x] `common.weapon` (3 img) · `common.beamcharge` (8) · `common.beamp` (12)
- [x] `common.reboundlaser` (17) · `common.counterairlaser` (8) · `common.simplefire` (7)
- [x] `common.emflash` (4) · `common.foefire` (4) · `common.missileflame` (4)
- [x] `common.engineflames` (2) · `common.explosion.imgFwk` (4) · `lib.scantfire` (2)

### Groupe B — l'orange, et la première application de la règle 1 (2 ress., 9 img)

Ces deux-là emploient **à la fois** l'ancien orange `F2AB00` et l'ancien saumon
`F99B68`, les deux barreaux que la nouvelle palette réduit à un. C'est le
premier cas où la table par défaut ferait perdre une marche, et c'est ce qui a
fait naître la règle 1. La rampe chaude compte cinq marches de chaque côté —
`610000` `AC0000` `CC5A3C` `F99B68` `FAF261`, plus le blanc au-dessus — donc
la place existe : il suffit de re-répartir.

**Trois candidats comparés sur une planche à quatre colonnes**, arbitrés à l'œil
par l'auteur le 16/08 :

| candidat | ce qu'il fait | verdict |
|---|---|---|
| *perte de l'orange* | les deux barreaux fusionnent — **5** valeurs au lieu de 6 | écarté |
| *descente de l'orange* | `10>9 14>10` — l'orange descend (353 px sur imgBig) | écarté |
| *descente du rose* | `10>10 14>9` — c'est le saumon qui descend (470 px) | **retenu** |

Le retenu avait été demandé sous la forme « inverser orange et rose dans les
images source, puis appliquer la conversion qui conserve les niveaux ». C'est
la même chose écrite en une passe — un pixel 10 devient 14 puis 10, un pixel 14
devient 10 puis 9, soit `10>10 14>9` — et il vaut mieux l'écrire ainsi : **les
sources ne sont pas touchées**, donc le rejeu depuis `origin/master` reste une
seule transformation et les PNG d'origine gardent leur sens.

L'alternative rejetée survit dans `tools/palette-variantes/b-fusion.txt`, qui
permet de rejouer la comparaison.

- [x] `common.explosion.imgBig` (5 img) — `10>10 14>9`
- [x] `common.explosion.imgSmall` (4 img) — même rampe, mais cette ressource
      **emploie déjà** `CC5A3C` (39 px) : tout le bas glisse d'un cran pour
      dégager la marche et prend appui sur le `610000` qu'elle n'utilisait pas
      (`8>7 9>8 10>10 14>9`).

*Vérifié avant de s'en inquiéter : les douze ressources du groupe A, déjà
écrites, n'emploient aucune paire en collision — la règle 1 ne les aurait pas
arrêtées. Rien à refaire derrière.*

### Groupe C — CLOS le 16/08/2026 (14 ressources, 98 images)

Trois planches, une décision par ressource. Les recettes retenues et les
alternatives écartées sont dans `tools/palette-map.txt`, à côté de chaque
ligne ; les surcouches de comparaison survivent dans
`tools/palette-variantes/` pour rejouer les arbitrages.

Ordre choisi : **les deux ancres d'abord** — ce qui est à l'écran en
permanence et contre quoi tout le reste sera jugé — puis les communs par poids
décroissant, puis les lots.

**Les ancres**

- [x] `common.player` (13 img, 231 px sur 5) — le vaisseau. Le §3 de l'étude
      recommande d'y verser le beige foncé dans le gris `666` : 19 px perdus
      contre 91 par l'autre fusion.
- [x] `common.hud` (12 img, 4 px) — recette A. Une seule de ses douze images
      porte du beige (`01-life`) : les onze autres sont une renumérotation pure.

*Découverte du 16/08, à garder en méthode :* quand les gris sont en déficit,
un **barreau chaud inutilisé peut servir de rallonge**. `common.pow` n'emploie
aucun chaud au-dessus de `CC5A3C`, donc le jaune `FAF261` (luminance 224) est
libre chez elle et s'intercale entre `A8A8A8` (168) et le blanc (249) — cinq
marches claires au lieu de quatre, aucune perte. C'est le premier cas où on
sort de la famille de teinte pour récupérer une marche.

**Les communs, par poids**

- [x] `common.forcepod` (16 img, 438 px)
- [x] `common.pow` (6 img, 329 px) — **recette A écartée par l'auteur** ;
      candidat en cours : le beige clair sur le **jaune** `FAF261`, qui
      rallonge la rampe claire à cinq marches et ne perd rien
- [x] `common.optionbox` (5 img, 134 px)
- [x] `common.bitdevice` (6 img, 101 px)
- [x] `common.overlay` (1 img, 92 px) — le masque du champ de jeu — recette A
- [x] `common.missile` (5 img, 25 px) — recette A

**Les lots** (chargés par combinaison de stage, mêmes règles)

- [x] `lib.scant` (3 img, 592 px) — **le cas arbitré** : garde son olive sur
      l'index propre au stage, beige clair monté au blanc, 4 px perdus en tout.
- [x] `lib.cancer` (3 img, 219 px)
- [x] `lib.bink` (6 img, 173 px)
- [x] `lib.pstaff` (6 img, 94 px) — recette A
- [x] `lib.bug` (8 img, 91 px)
- [x] `lib.patapata` (8 img, 57 px)

### Groupe D — le code de dessin écrit en dur — FAIT le 16/08/2026

Ni un remap de PNG ni un remap global ne les traitent : ce sont des immédiats
`LDA #$xy` à réécrire nibble par nibble.

- [x] `src/common/hud/hud.asm` — 796 px, renumérotation pure (indices 0, 1, 5,
      6, 13, tous conservés). Mécanisable comme la transformation F→0 du 15/08.
- [x] `src/enemies/dobkeratops/tailmgr_blits.asm` — 102 px, dont 31 px d'ancien
      index 14 (renumérotation) et 2 px d'olive, gardée sur l'index propre au
      stage. **Un troisième site est apparu au groupe E** : les tables de
      masques du starfield (`src/common/fx/starfield/obj.asm`), invisibles aux
      deux relevés parce qu'elles ne sont ni un PNG ni un `LDA #$xy`.

**À NE PAS TOUCHER** : `src/title/text/text.asm` (796 px dont 419 d'index 15).
Le title se dessine sur `Pal_title`, une palette distincte ; il ne participe pas
à la palette de jeu. `src/common/hud/mask/Img_mask_0_ND0.asm` est mort — aucun
INCLUDE ne l'atteint.

### Groupe E — la palette et le fond (bascule) — FAIT le 16/08/2026

- [x] le stage 1 charge **la nouvelle palette telle quelle**, entière et sans
      dérivation — depuis le 17/08 dans `src/stages/01/palette/pal.png`, comme
      les sept autres stages (groupe G)
- [x] le **ciel du niveau passe sur l'index 0** : les quatre macros du
      starfield testent le ciel sur 0, ses six tables de masques sont
      ré-encodées par `palette_code.py` (`cible=$0`), les deux effacements de
      tampon passent de `$FFFF` à `$0000`, l'effaceur de shells tamponne `$0000`
- [x] le **fondu de tunnel est retiré** : les deux fichiers de l'objet, ses
      9 lignes de wave, son bloc de config, son `<load>`, les 8 `Pal_tunnel`
      et les quatre `pal-inside*.png`

**Décision auteur (16/08)** : la case 15 est un **vert clair**, réservé à des
sprites propres au stage 1. Elle ne peut donc plus héberger le ciel.

L'ancienne palette avait **deux noirs** et le ciel du niveau occupait le second
(index 15) — l'image du niveau y pose 234 652 px. Cette case dédiée était ce
qui faisait marcher le fondu de tunnel : `pal.png` et `pal-inside.png` ne
diffèrent que d'une entrée, la 15 (`#000000` → `#617A7A`), autrement dit le
fondu **était** le recoloriage du ciel. La nouvelle palette n'ayant qu'un noir,
les deux vont ensemble : le ciel devient le nibble 0, et le fondu de tunnel
n'a plus d'objet.

**Ce que ça coûte, mesuré et assumé** : le décor peint aussi son noir en
nibble 0. Ciel et noir de décor sont donc le même index, et une étoile peut
désormais s'allumer dans une zone noire du décor ou d'un sprite — ~0,8 % de la
bande d'étoiles côté décor, 26 px noirs sur les 1561 px du vaisseau. Petit,
mais pas nul ; à revoir au groupe F si ça se voit, puisque les tuiles y sont
reprises à la main.

**L'id d'objet 34 n'est pas recyclé.** `objid.index.asm` est indexé *par id* :
renuméroter les suivants casserait les cinq tables. La rangée 34 prend donc le
motif réservé de la rangée 0, et `objid.const.asm` déclare l'id libre.

**Trou du groupe D révélé par la bascule.** Le starfield ne charge pas ses
couleurs, il les XOR-e sur le ciel : ses six `fcb` rangeaient `$F ^ couleur`.
Ni `palette_code.py` (qui lisait les immédiats) ni le relevé de
`palette_usage.py` (qui cherche `LDA #$xy` suivi d'un `STA ,U`) ne pouvaient le
voir — un **troisième** site de couleur en dur, d'une forme que rien
n'inspectait. L'outil sait désormais le traiter, déclaré par
`masque <opcode> ciel=$X [cible=$Y] lignes=N` ; `cible` est ce qui a permis de
décoder sur l'ancien ciel et de ré-encoder sur le neuf **en une passe depuis
`master`**. Le compte de lignes est là pour qu'une table ne puisse pas cesser
d'être reconnue en silence, et les garde-fous ont été cassés exprès avant
d'être crus — dont le contrôle de relecture, qui a attrapé une vraie erreur de
ma part (il relisait avec l'ancien ciel). Décision appliquée `4>2` : le beige
clair des étoiles prend le gris clair, la recette A des quatre autres communs.
`palette_usage.py` reste aveugle à cette forme — il ne lit pas
`palette-code.txt`.

**Le ledger a désormais trois natures d'acte**, et c'est complet : les
commandes d'outil, un patch (`tools/palette-edits.patch`) pour ce que les
outils ne savent pas écrire — du code et de la prose — et des `rm` pour les
suppressions. `--verifier` garde donc son sens exact : `src/` entier est
reproductible depuis `master`.

### Groupe F — les tuiles, EN DERNIER (décision auteur)

- [x] carte du stage 1 — renumérotation pure prouvée au pixel (`stage1.map`
      dans le ledger), `nbsteps=6` mesuré comme seul réglage qui tient dans
      l'arène (réglage auteur, courbe complète au commit 3f5ea49f)
- [x] **stages 2-8 CONVERTIS le 17/08** depuis les plans arcade, avec leurs
      palettes dédiées. Étude fondatrice :
      [`analyse-palettes-stages-2026-08.md`](analyse-palettes-stages-2026-08.md).

      Ce que la reconversion a apporté par rapport au remap envisagé :

      * **les 12 index communs sont enfin STABLES sur les huit stages**
        (`palette_usage` : « Aucun index gelé ne varie »). C'était le défaut de
        fond signalé depuis le 15/08 — un objet commun changeait de couleur
        selon le stage. Il est fermé ;
      * **les deux déficits annoncés (3 et 4) ne se sont pas produits comme
        prévu.** L'algorithme de coût attribue les cases aux teintes les plus
        chères et quantifie le reste : sur le stage 3 les verts secondaires
        tombent sur les gris communs, sur le stage 4 deux verts fusionnent
        (5296 px à distance 39). Ce sont des pertes réelles mais mesurées, pas
        des arbitrages à faire à la main ;
      * **la planche « orange du stage 8 » n'a plus lieu d'être.** La vraie
        couleur arcade est `#F8A068`, à distance **5** du saumon commun ;
        l'ancienne conversion la forçait sur `F2AB00`, à distance 104. La
        nouvelle palette rend cette zone plus juste, pas moins ;
      * **le stage 8 se convertit depuis son plan ARRIÈRE** — son plan avant
        réduit n'a qu'une couleur (tout noir). Mesuré, pas supposé.

      L'olive est gelée en 14 sur 3, 4, 5, 7 — lue dans le cast à chaque
      exécution, jamais dans une liste. Les stages 2, 6 et 8 disposent de leurs
      quatre cases.
- [x] **deux constats de l'auteur sur planche, corrigés le 17/08** — détail
      mesuré en [§7 de l'étude](analyse-palettes-stages-2026-08.md). Les deux
      venaient du critère d'attribution, pas du stage :

      * *« le boss du stage 8 devient gris »* → la distance **RGB** mettait sur
        le même pied « un orange un peu faux » et « un vert qui devient gris ».
        La métrique passe en **CIE Lab ΔE76** : le boss récupère deux cases
        vertes, et l'écart moyen baisse sur les **sept** stages (11,2→9,7 ·
        6,8→6,3 · 6,7→5,0 · 4,8→4,1 · 7,4→6,1 · 3,6→3,3 · 11,4→9,1). Le
        `--plancher` de 0,1 % vient avec : en Lab, 89 px de magenta au stage 6
        raflaient une case ;
      * *« le stage 3 doit prendre en compte en priorité le battleship de
        l'autre plan… vert et jaune avant tout »* → deux mécanismes, parce
        qu'un seul ne suffit pas. **`--plan`** fait entrer le plan arrière dans
        le choix des couleurs sans toucher l'`in.png` (poids 3, stable de 2 à
        5) ; **`--epingle`** réserve la case du jaune, que ~1 200 px ne font
        gagner à aucun poids balayé de 1 à 5. Coût mesuré et assumé : les trois
        teintes du terrain (71 % des pixels opaques) perdent leurs cases.

      Ce que ces deux constats disent du reste de la campagne : **les trois
      prédictions du §3 de l'étude étaient fausses**, et une planche a suffi à
      le montrer là où trois relevés chiffrés ne l'avaient pas vu. Le pixel
      compte les surfaces ; il ne dit pas ce que le joueur regarde.

### Groupe G — les huit palettes dédiées — FAIT le 17/08/2026

- [x] **sept l'étaient déjà** (groupe F) : `arcade_to_in.py` écrit
      `src/stages/NN/palette/pal.png` depuis la MÊME affectation que l'`in.png`,
      donc les deux ne peuvent pas diverger.
- [x] **le stage 1 rejoint la convention.** Il était seul dehors parce que
      `src/stages/01/palette/pal.png` portait l'ANCIENNE palette — l'entrée de
      `palette_migrate.py` — pendant que le stage lisait la sienne dans
      `pal-next.png`. Un fichier, deux rôles, et le rôle visible depuis le
      config était le faux. Les deux palettes de référence de la campagne vont
      dans `tools/palette-reference/{ancienne,nouvelle}.png`, avec le reste du
      paramétrage ; le `cp -R tools/palette*` du vérificateur les sème déjà.
      Détail et pièges dans [§8 de l'étude](analyse-palettes-stages-2026-08.md).
- [x] preuve : l'étape neuve du ledger **cassée exprès** sort `ECART` en
      nommant `src/stages/01/palette/pal.png` ; remise, `--verifier` sort
      `IDENTIQUE`. L'image ne bouge pas d'un octet — le fichier change de nom,
      pas de contenu (`cmp` le dit, et le build repart à 100 % de cache).

**Dette relevée au passage, PAS traitée** (elle dépasse la campagne) :
`games/r-type/v1-map.csv` annonce 1308 fichiers « contenu byte-identique » à la
v1. C'est faux depuis le groupe A — la campagne a réécrit une centaine de PNG.
Les lignes que ce commit invalidait directement sont corrigées (les quatre
`pal-inside*` supprimés au groupe E, et `pal.png` qui pointe maintenant vers
`tools/palette-reference/ancienne.png`) ; le reste du fichier reste à statuer :
**Tranché par l'auteur le 17/08 : on abandonne la promesse.** La migration v1
est finie et `new-color` est une branche d'expérimentation — l'identité octet
pour octet avec la v1 n'y a plus de sens pour les images. Le CSV garde son rôle
de **traçabilité** (quel fichier v1 est devenu quel fichier v2) ; la mention
« contenu byte-identique » est à retirer du CSV et de `CLAUDE.md`.

### Groupe H — les sprites arcade des ennemis — EN COURS (17/08/2026)

- [x] **`tools/arcade_to_sprites.py`** — cadre = union des boîtes de
      l'animation, réduit 3/8 × 3/4 (ratio prouvé exactement sur le `pow` :
      union arcade 32×32, PNG TO8 12×24), calé sur la **demi**-étendue pour que
      l'ancre tombe juste. Palette `communs` par défaut (objet partagé) ou
      `NN` (objet exclusif à un stage). Garde-fou de transparence cassé exprès.
- [x] **cast du stage 2 converti** — gouger, wick, brood, outslay : 111 sprites.
      `gomander` n'a pas d'export arcade.
- [x] **les sprites votent pour la palette de leur stage** (constat auteur sur
      planche : le brood perdait ses six verts d'un coup). `--plan
      sprites:<objet>`, poids 1 —
      [§9 de l'étude](analyse-palettes-stages-2026-08.md).
- [ ] **les 15 autres ennemis exportés attendent leur stage.** L'affectation
      ennemi → stage n'existe que pour le stage 2 (`objid.const.asm` le nomme) ;
      les stages 3 à 8 citent encore des ObjID **numériques** sans ennemi
      derrière. Les convertir à l'aveugle serait à refaire. **Prochain point de
      décision auteur.**

## Ce qu'il faut savoir avant de commencer

**Deux images sont déclarées par deux ressources** — `weapon/images/impact/00.png`
et `01.png`, partagées par `common.weapon` et `common.simplefire`. Aucune
décision n'y est attachée (elles n'emploient que des couleurs conservées), donc
le partage est sans danger ici ; mais la règle vaut d'être posée : **une image
partagée se décide une fois**, la seconde ressource hérite.

**Une ressource ≠ un fichier.** Une ligne `<images>` miroir redéclare le même
PNG : les comptes ci-dessus sont en fichiers distincts par ressource. Sur les
28 ressources, 180 fichiers distincts au total.

**La preuve, sur cette branche.** Le corpus ne sert plus à « rien n'a bougé » —
tout doit bouger. À chaque ressource : la planche validée par l'auteur,
`palette_usage.py` sans défaut, et la lane r-type 7/7 dès que l'image est
jouable. Le corpus reprend son rôle à la réunification, contre `master`.

**Conséquence de l'ordre choisi : le jeu est FAUX à l'écran entre A et E.**
La bascule de palette est en groupe E ; d'ici là les images migrées portent les
nouveaux index face à l'ancien `pal.png`, donc de mauvaises couleurs en jeu. Le
verdict visuel se lit sur les **planches** (rendu contre la palette cible), pas
sous toje, et la lane r-type ne juge sur cette période que la mécanique (7/7),
pas les couleurs. Alternative écartée : basculer la palette dès maintenant
rendrait chaque ressource validée immédiatement juste, mais rendrait fausses
toutes celles qui ne sont pas encore migrées — dont les tuiles, c'est-à-dire
tout l'écran. Mieux vaut un écran faux et des planches justes qu'un écran à
moitié faux tout du long.
