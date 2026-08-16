# Palette 12 communs + 4 par stage : ce que coûterait la migration

Statut : ÉTUDE (15/08/2026) — **rien n'est réalisé, et rien ne doit l'être sans
le protocole du §7**. Les arbitrages de l'auteur pris en séance sont consignés
au fil du texte et récapitulés ici :

1. **Le vert du scant est accordé** : l'olive reste, sur un index propre au
   stage, réservé par les stages 1 et 7 seulement (§3).
2. **L'index 15 est abandonné pour le fond du stage 1**, et avec lui la
   possibilité de changer la couleur de fond en cours de stage — perte assumée.
3. **Le champ d'étoiles a le droit de scintiller sur les pixels noirs des
   tuiles** : l'effet est jugé peu visible, le décor n'a donc PAS à quitter
   l'index 0. Ce qui était le point dur de l'étude devient un compromis accepté
   (§4).
4. En cas de migration : **un mapping par objet**, une **planche PNG de
   prévisualisation par objet**, et **validation manuelle de l'auteur** avant
   de rien graver (§7).
5. **Tout se fait sur une branche `new-color`, jamais fusionnée vers `master`
   avant la fin** — la migration prendra du temps et `master` doit rester
   jouable. C'est une suspension explicite de la règle de campagne qui veut
   que chaque commit parte aussi sur `master` (§7).

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

### Le scant : ARBITRÉ — il garde son vert, et ne perd que 4 px

Le scant était le cas le plus lourd : il perdait le beige comme les autres,
mais AUSSI son olive (236 px, sa teinte de corps), qui devient propre au stage.
Rendu tout en gris il perdait son caractère organique.

**Décision de l'auteur : l'olive est accordée**, sur un index propre au stage.
Le scant n'apparaissant qu'aux **stages 1 et 7**, seuls ces deux-là ont à la
réserver ; les six autres gardent leurs quatre couleurs propres intactes.

Reste sa rampe neutre : quatre valeurs pour trois gris disponibles, une fusion
est donc inévitable. La moins chère saute aux yeux une fois les comptes posés —
le scant n'utilise le blanc que sur **4 px**. En faisant monter le beige clair
(135 px) jusqu'au blanc, la fusion ne coûte que ces 4 px et la rampe garde ses
trois marches réelles :

| rôle | actuel | après |
|---|---|---|
| corps | olive `670`, 236 px | **olive, index propre au stage** |
| médian sombre | gris `666`, 197 px | `666` |
| médian clair | beige `987`, 221 px | `AAA` |
| clair | beige `CCA`, 135 px | `FFF` |
| plus clair | blanc `FFF`, 4 px | `FFF` — fusionné, **4 px** |

Soit olive + trois gris + noir : **la même structure tonale qu'aujourd'hui**.
Le scant passe donc de « le plus dégradé du lot » à « le moins abîmé ».

## 4. Le fond du stage 1 et le champ d'étoiles : ce qu'on accepte de perdre

Ce paragraphe était le point dur de l'étude. **Deux décisions de l'auteur le
referment**, en assumant les pertes plutôt qu'en les évitant.

Le contexte, d'abord, parce qu'il explique pourquoi la question se posait. La
palette du stage 1 porte aujourd'hui **deux noirs** — l'index 0 et l'index 15,
tous deux `000`, et aucun autre stage n'a ça. Ce n'était pas un gaspillage :
le champ d'étoiles ne dessine que sur le « ciel vierge », qu'il reconnaît au
nibble `$F` (`starfield/obj.asm`, macros `STAR_DH`/`STAR_DL`), et ignore le
décor qui est en nibble 0 — d'où l'effacement des tampons à `$FFFF` et non
`$0000` (`checkpoint.unit.asm`, dont le commentaire raconte le bug : un
effacement à zéro, et plus une étoile ne revenait après une mort).

Or les tuiles du stage 1 utilisent **les deux**, et la nouvelle palette les
envoie sur le même index 0 :

| | ancien index | pixels | nouveau |
|---|---|---|---|
| noir du décor, dans les tuiles | 0 | 6 793 | 0 |
| ciel, dans les tuiles | 15 | 8 037 | 0 |

**Décision 1 — l'index 15 quitte le fond du stage 1.** On perd avec lui la
possibilité de changer la couleur de fond en cours de stage. Assumé : le
stage 1 n'en use pas.

**Décision 2 — les étoiles ont le droit d'apparaître sur les pixels noirs des
tuiles.** Le décor n'a donc PAS à quitter l'index 0, et les 6 793 px de noir
des tuiles ne sont plus un chantier. L'effet est jugé peu visible : le décor du
niveau 1 est majoritairement clair, ses aplats noirs sont des ombres étroites,
et une étoile qui y passe le fait à la vitesse du plan le plus lent.

Ce qui reste à faire de ce côté est donc **mécanique et petit** :

- `checkpoint.unit.asm` : les deux `ldx #$FFFF` d'effacement deviennent `#$0000` ;
- `starfield/obj.asm` : le test du ciel passe du nibble `$F` au nibble 0. Le
  code y **gagne** — les masques XOR valent aujourd'hui `$F0 ^ couleur` et
  `$0F ^ couleur` ; avec un ciel à zéro le masque EST la couleur (`0 ^ c = c`,
  `c ^ c = 0`), donc la table de plans se simplifie (`$B0→$40`, `$D0→$20`,
  `$A0→$50`), le test du nibble haut passe de `cmpa #$F0 / blo` à
  `cmpa #$10 / bhs`, et le nibble bas **perd ses deux `coma`** par étoile et par
  passe.

## 5. Ce qui est automatique, ce qui ne l'est pas

**Automatique** — une table de correspondance appliquée aux PNG : les douze
couleurs conservées, soit la très grande majorité des pixels. Vérifiable au
pixel près.

**Manuel, par construction** :
- les 2 580 px du §2 : trois couleurs à réattribuer à l'œil ;
- le contraste des tuiles, que l'auteur reprend de toute façon à la main ;
- les tuiles sont à **régénérer** (leanscroll → `<gfxcomp grid>` → `<tilemap>`),
  pas seulement à remapper : la chaîne repart de l'image du niveau.

### Le code de dessin écrit en dur — le piège d'un remap global

Un remap qui ne toucherait que les PNG **raterait quatre fichiers**, et un
remap qui toucherait tout indistinctement en **casserait un**. Relevé exhaustif
(idiome `LDA #$xy` suivi d'un `STA <nombre>,U`) :

| fichier | px | index employés | verdict |
|---|---|---|---|
| `src/common/hud/hud.asm` — police du relevé | 796 | 0, 1, 5, 6, 13 | **automatique** : tous tombent dans 0-11 |
| `src/enemies/dobkeratops/tailmgr_blits.asm` | 102 | 1, 7, 9, 11, 12, 13, 14 | **à traiter** : l'index 12 (2 px) et l'index 14 (31 px) |
| `src/title/text/text.asm` — machine à écrire | 796 | 0, 1, 4, 8, 9, **15 (419 px)** | **NE PAS TOUCHER** : le title a sa palette |
| `src/common/hud/mask/Img_mask_0_ND0.asm` | 18 | 0 | mort — aucun INCLUDE ne l'atteint |

Le title est le piège : il se dessine sur `Pal_title`, une palette
complètement distincte (`0DD DDD C9C CFF …`), et son index 15 y est SA couleur.
Il est chargé au boot comme les communs, mais il ne participe pas à la palette
de jeu — un outil de migration doit l'exclure explicitement, pas par oubli.

`tailmgr_blits.asm` est le seul vrai travail : les queues du boss, dont
31 px d'ancien index 14 (renumérotation simple vers 10) et 2 px d'olive à
arbitrer. Le boss n'appartenant qu'au stage 1, il pourrait prendre l'index
propre — pour 2 px, le gris fera l'affaire.

**Rien côté builder** : `png2pal`, `gfxcomp` et le linker sont indifférents au
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

## 7. Protocole de migration — décidé, à respecter

L'auteur a tranché la MÉTHODE avant le contenu, et c'est elle qui gouverne :

> **Un mapping par objet, une planche PNG de prévisualisation par objet, et
> validation manuelle de l'auteur avant de graver quoi que ce soit.**
>
> **Tout vit sur une branche dédiée — `new-color` — dans laquelle les
> modifications sont fusionnées au fur et à mesure. JAMAIS de fusion vers
> `master` tant que la migration n'est pas finie : elle prendra du temps, et
> `master` doit rester jouable pendant ce temps.**

Cette seconde règle **suspend la pratique courante de la campagne**, où chaque
commit part sur la branche de travail ET sur `master` dans la foulée. Pour la
palette, c'est l'inverse : `master` ne voit rien jusqu'au bout.

Deux conséquences pratiques à ne pas découvrir en route :

* **`master` continue d'avancer** sur le reste du portage. La branche doit donc
  ravaler `master` régulièrement (fusion ou rebasage), sinon la réunification
  finale se fera sur des mois d'écart. Le coût d'un ravalement régulier est
  faible ; celui d'un seul à la fin ne l'est pas.
* **Le banc d'identité change de sens sur cette branche.** Notre critère
  habituel — « les images du corpus sont inchangées, ou le mouvement est
  expliqué » — ne veut plus rien dire quand le but même est de changer toutes
  les images. Sur `new-color`, la preuve devient : la planche validée par
  l'auteur pour chaque objet, `palette_usage.py` sans défaut, et la lane
  r-type 7/7 (qui, elle, garde tout son sens : elle vérifie que le jeu tourne,
  pas qu'il est identique). Le corpus reprend son rôle de garde-fou au moment
  de la réunification, contre l'état de `master`.

Ce n'est pas une précaution de style. Le §3 l'a montré trois fois : le meilleur
mapping n'est PAS le même d'un objet à l'autre — le vaisseau veut le beige
foncé versé dans le gris (19 px perdus contre 91), le scant veut l'inverse plus
son olive conservé, le POW est indifférent. Une table globale trancherait mal
pour presque tout le monde.

La forme de la planche existe déjà : `palette_usage.py --contact` sait aligner
un sprite tel quel à gauche et sa version transformée à droite. Il lui manque
de prendre une table de mapping en entrée — c'est l'outil à écrire le jour où
la campagne démarre, pas avant.

Le reste-à-faire, dans l'ordre :

1. **Le stage 1 seul**, objet par objet, avec sa planche et sa validation.
2. **Les tuiles du stage 1**, régénérées depuis l'image du niveau (leanscroll →
   `<gfxcomp grid>` → `<tilemap>`), contraste repris à la main.
3. **Le code écrit en dur** du §5 — deux fichiers à toucher, un à laisser.
4. **Le stage 2 ensuite**, parce qu'il est le pire cas (quinze index distincts
   dans ses tuiles) : s'il passe, les six autres passent.
5. Les stages 3-8, qui n'ont aujourd'hui aucune palette authorée — la migration
   est l'occasion de leur en donner une au lieu de la dériver du tileset.

Critère à chaque étape : validation visuelle de l'auteur, `palette_usage.py`
sans défaut, lane r-type 7/7, corpus confiné aux images r-type.
