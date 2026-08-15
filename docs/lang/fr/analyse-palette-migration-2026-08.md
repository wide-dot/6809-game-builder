# Palette 12 communs + 4 par stage : ce que coûterait la migration

Statut : ÉTUDE (15/08/2026) — proposition de l'auteur, rien n'est réalisé.
Intention : réindexer les assets pour que **les index 0-11 soient communs aux
huit stages et les index 12-15 propres à chacun**. Les assets communs passent
du beige au gris ; les tuiles gagnent le contraste que la conversion ne peut
pas retrouver seule (le geste est manuel). Trois gestes annexes sont annoncés :
le masque du champ d'étoiles passe de l'index 15 à l'index 0, l'usage de
l'index 15 disparaît du fond du stage 1 (pas de changement de fond en cours de
stage), et la traînée des tuiles se gère en noir.

La palette proposée est dans le dépôt : `src/stages/01/palette/pal-next.png`
(même forme que `pal.png` — 1×1, seule sa table compte). Elle n'est branchée
sur rien : le config lit toujours `pal.png`, le build est inchangé.

Source des mesures : `games/r-type/tools/palette_usage.py` sur le build du
15/08/2026, cast du stage 1 replié dans les communs (`--avec-lots`).

## 1. La palette proposée, et ce qu'elle fait de l'ancienne

| ancien | | nouveau | | |
|---|---|---|---|---|
| 0 | `000` noir | **0** | `000` noir | inchangé |
| 1 | `FFF` blanc | **3** | `FFF` blanc | déplacé |
| 2 | `666` gris | **1** | `666` gris | déplacé |
| 3 | `987` beige foncé | **12** | `987` beige foncé | **devient propre au stage** |
| 4 | `CCA` beige clair | **13** | `CCA` beige clair | **devient propre au stage** |
| 5 | `068` bleu nuit | **4** | `068` bleu nuit | déplacé |
| 6 | `09C` cyan-bleu | **5** | `09C` cyan-bleu | déplacé |
| 7 | `600` rouge sombre | **7** | `600` rouge sombre | inchangé |
| 8 | `A00` rouge | **8** | `A00` rouge | inchangé |
| 9 | `C53` saumon | **9** | `C53` saumon | inchangé |
| 10 | `FA0` orange | **10** | `F96` saumon clair | **fusion de barreau** |
| 11 | `FF6` jaune pâle | **11** | `FF6` jaune pâle | inchangé |
| 12 | `670` olive | **14** | `670` olive | **devient propre au stage** |
| 13 | `0DE` cyan | **6** | `0DE` cyan | déplacé |
| 14 | `F96` saumon clair | **10** | `F96` saumon clair | rejoint le même |
| 15 | `000` noir (ciel) | **0** | `000` noir | **fusionne avec le noir** |
| — | | **2** | `AAA` gris clair | **nouveau** |
| — | | **15** | `9C0` vert clair | **nouveau** |

**Douze couleurs sur seize survivent à l'identique** : la migration est d'abord
une renumérotation, mécanisable et vérifiable au pixel près. Trois cas seulement
demandent la main, et deux couleurs neuves apparaissent — le gris clair `AAA`,
qui est précisément ce avec quoi les communs remplacent le beige, et le vert
clair `9C0`, propre au stage.

**L'orange n'est pas perdu, il est dédoublonné** (précision de l'auteur,
vérifiée). Classée par luminance, l'ancienne rampe chaude était
`600` 1,8 → `A00` 3,0 → `C53` 6,9 → `FA0` **10,4** → `F96` **10,5** → `FF6`
14,0 : l'orange et le saumon clair occupaient le MÊME barreau, à 0,1 de
luminance et 10,6 d'écart colorimétrique — moins que rouge↔saumon (11,6), deux
couleurs que personne ne songe à fusionner. La nouvelle rampe garde donc ses
cinq échelons, et son pas devient plus régulier : +5,7 / +11,6 / +10,4 / +12,0.
Les deux anciens index tombent sur le même nouvel index 10.

## 2. Le reste-à-faire dans le commun : 78 images, 2 580 px

Un commun ne peut plus utiliser que 0-11. Trois anciens index sortent de cette
plage : les deux beiges et l'olive, qui deviennent propres au stage.

| ancien index | devient | images | pixels |
|---|---|---|---|
| 4 `CCA` beige clair | propre au stage (13) | 68 | 1 157 |
| 3 `987` beige foncé | propre au stage (12) | 49 | 1 042 |
| 12 `670` olive | propre au stage (14) | 24 | 381 |
| **total (images distinctes)** | | **78** | **2 580** |

Par unité : `lib.scant` 592 px, `forcepod` 438, `pow` 329, `player` 231,
`lib.cancer` 219, `lib.bink` 173, `optionbox` 134, `bitdevice` 101,
`lib.pstaff` 94, `overlay` 92, `lib.bug` 91, `lib.patapata` 57, `missile` 25,
`hud` 4.

**Automatique mais à regarder** : les 689 px d'ancien orange (39 images, dont
353 px dans la grosse explosion) changent de teinte en gardant leur index — la
fusion de barreau du §1. Aucune décision à prendre, mais un coup d'œil vaut
mieux qu'une confiance aveugle, la saturation baissant un peu.

Une remarque que la mesure a rendue : **la police du relevé ne coûte rien.**
Elle peint les anciens index 0, 1, 5, 6 et 13, qui tombent tous dans 0-11 :
renumérotation automatique, pas une reprise. (Mon premier chiffrage, fait avant
d'avoir la palette, supposait qu'on viderait 12-14 et l'annonçait à repeindre —
c'était une hypothèse, pas une mesure.)

## 3. Le beige devient gris : qui le sent vraiment ?

La question n'est pas la teinte — un beige qui devient gris reste un gris de la
bonne valeur — mais **l'échelon perdu**. Un commun n'aura plus que quatre
neutres là où il en avait cinq, et la finesse se perdait justement dans les
clairs :

| avant, accessible à un commun | après |
|---|---|
| `000` 0,0 → `666` 6,0 → `987` 8,2 → `CCA` 11,8 → `FFF` 15,0 | `000` 0,0 → `666` 6,0 → `AAA` 10,0 → `FFF` 15,0 |
| pas : +6,0 / +2,2 / +3,6 / +3,2 | pas : +6,0 / +4,0 / +5,0 |

Mais **presque personne n'empilait les cinq**. Sur les 168 images communes qui
touchent au moins un neutre :

| neutres simultanés | images | |
|---|---|---|
| 1 | 87 | tiennent |
| 2 | 11 | tiennent |
| 3 | 17 | tiennent |
| 4 | 38 | tiennent |
| **5** | **15** | **perdent un échelon** |

**153 images sur 168 (91 %) ne perdent rien** : elles changent de teinte, pas de
modelé. Les quinze qui restent sont, hélas, les plus regardées — le **vaisseau**
du joueur (5 poses), le **POW** (4), l'**optionbox** (4) et le **scant** (2).

Reste à choisir COMMENT caser cinq niveaux dans quatre. Deux fusions possibles,
et le coût (le plus petit des deux tons fusionnés, qui disparaît dans l'autre)
se mesure sprite par sprite :

| | A : les deux beiges → `AAA` | B : beige foncé → `666`, beige clair → `AAA` |
|---|---|---|
| vaisseau (5 poses) | 91 px perdus | **19 px** |
| POW (4) | 111 px | **89 px** |
| optionbox (4) | 30 px | 30 px |
| scant (2) | **96 px** | 141 px |
| **total** | 328 px | **279 px** |

**B est le meilleur choix général, et il est excellent pour le vaisseau** : le
vaisseau n'utilise presque pas le gris `666` (1 à 6 px selon la pose), donc y
verser le beige foncé ne coûte quasiment rien — 3 à 6 px par pose. Le **scant
est le seul à préférer A**, parce qu'il est le seul à utiliser massivement le
gris moyen (82 px). Le choix est donc par sprite, ce qui est cohérent avec un
geste manuel assumé.

**Le vrai perdant est le scant**, et pas à cause du beige : il perd AUSSI son
olive (index 12, 236 px sur trois poses), qui devient propre au stage. Rendu
tout en gris, il perd son caractère organique. À noter puisque ça ouvre une
option : le scant n'apparaît **qu'aux stages 1 et 7** — si ces deux stages
réservaient le même index propre pour l'olive, il pourrait le garder. C'est le
seul cas du corpus où un ennemi de lot justifierait qu'on accorde deux stages
sur une couleur propre.

## 4. Le point dur : après la fusion, il n'y a plus qu'UN noir

C'est la contrainte à connaître avant de commencer, pas à découvrir à l'écran.

La palette du stage 1 porte aujourd'hui **deux noirs** — l'index 0 et l'index
15, tous deux `000`. Aucun autre stage n'a ça. Ce n'est pas un gaspillage :
c'est **ce qui rend le champ d'étoiles possible**.

Le champ d'étoiles ne dessine que sur le « ciel vierge », qu'il reconnaît au
nibble `$F` (`obj.asm`, macros `STAR_DH`/`STAR_DL`) ; le décor, lui, est en
nibble 0 et se trouve ignoré — ce qui est le rendu voulu, **pas d'étoile dans
la silhouette de la ville**. Les tampons sont donc effacés à `$FFFF` et non à
`$0000` (`checkpoint.unit.asm`, dont le commentaire raconte le bug : un
effacement à zéro et plus une étoile ne revenait après une mort).

Or les tuiles du stage 1 utilisent **les deux**, et la nouvelle palette les
envoie toutes deux sur le même index 0 :

| | ancien index | pixels | nouveau index |
|---|---|---|---|
| noir du décor, dans les tuiles | 0 | 6 793 | 0 |
| ciel, dans les tuiles | 15 | 8 037 | 0 |

**Conséquence : le décor doit cesser d'utiliser le noir.** Le nouvel index 0
appartient au ciel ; si les tuiles y peignent encore leurs ombres, les étoiles
scintilleront à l'intérieur des bâtiments. Et il n'y a plus de second noir où
se replier : le décor devra rendre ses noirs en `666` (gris), `068` (bleu nuit)
ou `600` (rouge sombre), ou avec une des quatre couleurs propres au stage si
l'une d'elles est choisie sombre — les quatre actuellement proposées
(`987`, `CCA`, `670`, `9C0`) ne le sont pas. Ce sont 6 793 px de tuiles, déjà
sur la table puisque leur contraste est repris à la main, mais c'est une
contrainte de conception, pas un détail de conversion.

En compensation, une fois le ciel à zéro le **champ d'étoiles se simplifie et
accélère**. Ses masques XOR sont aujourd'hui `$F0 ^ couleur` et `$0F ^ couleur` ;
avec un ciel à zéro le masque EST la couleur (`0 ^ c = c`, `c ^ c = 0`), donc la
table de plans se simplifie, le test du nibble haut passe de `cmpa #$F0 / blo`
à `cmpa #$10 / bhs`, et le nibble bas **perd ses deux `coma`** par étoile et par
passe.

## 5. Ce qui est automatique, ce qui ne l'est pas

**Automatique** — une table de correspondance appliquée aux PNG : les douze
couleurs conservées, soit la très grande majorité des pixels. Vérifiable au
pixel près (l'image reconstruite doit rendre exactement les mêmes couleurs).

**Manuel, par construction** :
- les 2 580 px du §2 : trois couleurs à réattribuer à l'œil ;
- les 6 793 px de noir du décor des tuiles, §4 ;
- le contraste des tuiles, que l'auteur a déjà annoncé ;
- rien dans le code de dessin écrit à la main : la police passe automatiquement.

**Code à toucher** (peu, et localisé) :
- `checkpoint.unit.asm` : les deux `ldx #$FFFF` d'effacement des tampons
  deviennent `#$0000` ;
- `starfield/obj.asm` : les quatre macros de test et la table de plans (§4) ;
- rien côté builder — `png2pal`, `gfxcomp` et le linker sont indifférents au
  choix des index.

**Le garde-fou existe déjà** : `palette_usage.py` sort en erreur si un index
gelé par un commun varie entre stages. Après migration il doit rendre
« index CONTRAINTS 0-11, LIBRES 12-15 » et zéro défaut. C'est le critère
d'acceptation de la campagne, vérifiable en une commande.

## 6. Les tuiles des autres stages, pour mémoire

Le schéma donne aux tuiles douze couleurs imposées et quatre choisies, là où
elles choisissaient les seize. Ce qu'elles utilisent aujourd'hui :

| stage | index distincts | index 0 | index 15 |
|---|---|---|---|
| 1 | **9** | 6 793 | 8 037 |
| 2 | **15** | 9 507 | 5 577 |
| 3 | 10 | 3 257 | 6 250 |
| 4 | 9 | 6 568 | 5 352 |
| 5 | 7 | 2 611 | 430 |
| 6 | 12 | 8 480 | 3 858 |
| 7 | 13 | 10 185 | 2 748 |
| 8 | 12 | 4 567 | 1 303 |

Le stage 1 est le plus sobre (9 index) parce que son art vient de la v1, où le
geste manuel avait déjà été fait. Le **stage 2 est le cas extrême** avec quinze
index distincts : sa palette est dérivée de son tileset, personne ne l'a
arbitrée. C'est lui qui dira si douze communs suffisent.

## 7. Ordre proposé

1. **Le stage 1 seul**, de bout en bout : remap automatique des douze couleurs
   conservées, puis les quatre à la main, le noir du décor des tuiles, le champ
   d'étoiles et l'effacement des tampons. Critère : visuel ET mesuré
   (`palette_usage.py` sans défaut, lane 7/7, corpus confiné aux images r-type).
2. **Le stage 2 ensuite**, parce qu'il est le pire cas : s'il passe, les six
   autres passent.
3. Les stages 3-8, qui n'ont aujourd'hui aucune palette authorée — la migration
   est l'occasion de leur en donner une au lieu de la dériver du tileset.
