# Palette 12 communs + 4 par stage : ce que coûterait la migration

Statut : ÉTUDE (15/08/2026) — proposition de l'auteur, rien n'est réalisé.
Intention : réindexer les assets pour que **les index 0-11 soient communs aux
huit stages et les index 12-15 propres à chacun**. Les assets communs passent
du beige au gris ; les tuiles gagnent le contraste que la conversion ne peut
pas retrouver seule (le geste est manuel). Trois gestes annexes sont annoncés :
le masque du champ d'étoiles passe de l'index 15 à l'index 0, l'usage de
l'index 15 disparaît du fond du stage 1 (pas de changement de fond en cours de
stage), et la traînée des tuiles se gère en noir.

Source des mesures : `games/r-type/tools/palette_usage.py` sur le build du
15/08/2026, cast du stage 1 replié dans les communs (`--avec-lots`).

**Donnée manquante à la rédaction** : les seize valeurs exactes de la nouvelle
palette du stage 1. La pastille a été montrée en image mais n'est pas dans le
dépôt ; tout ce qui suit porte donc sur la STRUCTURE (quels index bougent, à
quel coût, quel code en dépend), jamais sur le choix des teintes. Poser le PNG
dans `src/stages/01/palette/` permettra de chiffrer les fusions pour de bon.

## 1. La contrainte, en un chiffre

Les objets communs — résidents, plus le cast d'ennemis que le stage 1 charge —
consomment aujourd'hui **quinze index sur seize** (0 à 14). Le seul libre est
le 15, et il ne l'est que depuis le correctif de la police du relevé
(15/08/2026). Leur rendre douze index, c'est leur en retirer trois.

| ce qu'il faut vider | images distinctes | pixels |
|---|---|---|
| index 12, 13 et 14 dans le commun | **96** | **2 172** |
| + la police du relevé, en code (`hud.asm`, index 13) | — | 84 |

Réparti par unité, du plus lourd au plus léger : `explosion.imgBig` 470 px,
`beamp` 354, `lib.bug` 318, `lib.scant` 254, `lib.pstaff` 205, `player` 99,
`lib.patapata` 98, `hud` 86, `lib.scantfire` 82, `optionbox` 50, `emflash` 39,
`engineflames` 37, `simplefire` 35, `missileflame` 34, `explosion.imgSmall` 28,
`lib.bink` 27, `foefire` 24, `missile` 10, `lib.cancer` 6.

C'est **11 % des pixels du commun**. Le geste n'est pas énorme, mais il touche
presque toutes les unités : ce n'est pas un objet à reprendre, c'est une passe.

## 2. Deux des trois fusions sont quasi gratuites, la troisième ne l'est pas

Écarts dans la palette du stage 1 ACTUELLE (distance pondérée grossière ;
échelle de lecture : rouge↔saumon, deux couleurs qui coexistent sans gêne,
valent 11,6 — et noir↔gris valent 18).

| index à vider | meilleur accueil | écart | verdict |
|---|---|---|---|
| **13** cyan `0DE` | **6** cyan-bleu `09C` | **8,7** | plus proche que rouge↔saumon : fusion propre |
| **14** saumon clair `F96` | **3** beige foncé `987` (ou 9 saumon, 10,4) | **8,9** | fusion propre |
| **12** olive `670` | 2 gris `666` | 10,6 | **la seule qui se voit** |

L'index 12 est le cas difficile, et on sait pourquoi : **62 % de son usage est
le corps du scant** (86+81+69 px sur ses trois poses), le reste n'étant que des
éclats sur bug, patapata, cancer et l'optionbox. Or le scant n'apparaît qu'aux
**stages 1 et 7**. Deux stages imposent donc une teinte aux huit palettes.

Le passage annoncé « du beige au gris » des communs change ces distances : à
refaire sur les vraies valeurs.

## 3. Le point dur : les deux noirs du stage 1 ne sont pas un doublon

C'est la découverte de l'étude, et elle conditionne le reste.

La palette du stage 1 porte **deux noirs** : l'index 0 et l'index 15, tous deux
`000`. Aucun autre stage n'a ça (leur index 15 est une vraie couleur). Ce n'est
pas un gaspillage — c'est **ce qui rend le champ d'étoiles possible**.

Le champ d'étoiles ne dessine que sur le « ciel vierge », qu'il reconnaît au
nibble `$F` (`obj.asm`, macros `STAR_DH`/`STAR_DL`) ; le décor, lui, est en
nibble 0 et se trouve ignoré — ce qui est le rendu voulu, **pas d'étoile dans
la silhouette de la ville**. Les tampons sont donc effacés à `$FFFF` et non à
`$0000` (`checkpoint.unit.asm`, avec le commentaire qui raconte le bug : un
effacement à zéro et plus une étoile ne revenait après une mort).

Et les tuiles du stage 1 utilisent **les deux** :

| | index 0 (noir décor) | index 15 (ciel) |
|---|---|---|
| tuiles stage 1 (deux plans) | 6 793 px | 8 037 px |

**Conséquence directe** : déplacer le ciel sur l'index 0 sans rien faire
d'autre confond le ciel et le noir du décor — les étoiles se mettraient à
scintiller à l'intérieur des silhouettes. Il faut donc que **le noir du décor
quitte l'index 0** : soit vers un des quatre index propres au stage, soit vers
un gris très sombre parmi les communs. Ce sont 6 793 px de tuiles à réindexer —
mais elles sont déjà sur la table, puisque le contraste des tuiles est repris à
la main.

Bonne nouvelle en compensation : une fois le ciel à 0, **le champ d'étoiles
devient plus simple ET plus rapide**. Ses masques XOR sont aujourd'hui
`$F0 ^ couleur` et `$0F ^ couleur` ; avec un ciel à zéro le masque EST la
couleur (`0 ^ c = c`, `c ^ c = 0`), donc la table de plans se simplifie
(`$B0→$40`, `$D0→$20`, `$A0→$50`), le test du nibble haut passe de
`cmpa #$F0 / blo` à `cmpa #$10 / bhs`, et le nibble bas **perd ses deux
`coma`** par étoile et par passe.

## 4. Ce qui est automatique et ce qui ne l'est pas

**Automatique** (une table de correspondance ancien→nouveau index, appliquée
aux PNG) : tout ce qui est une simple renumérotation sans perte, c'est-à-dire
les index que l'on garde. Un script de remap est trivial et vérifiable au
pixel près.

**Manuel, par construction** :
- les trois fusions du §2 — décider qu'un cyan devient l'autre cyan est un
  jugement, pas un calcul ;
- le contraste des tuiles (l'auteur l'a déjà dit) ;
- le noir du décor des tuiles, §3 ;
- la police du relevé (`hud.asm`), qui n'est pas une image mais du code : ses
  84 px d'index 13 sont des immédiats `LDA #$xy` à retoucher — le même geste
  que la transformation F→0 du 15/08, donc mécanisable.

**Le garde-fou existe déjà** : `palette_usage.py` sort en erreur si un index
gelé par un commun varie entre stages. Après migration il doit rendre
« index CONTRAINTS 0-11, LIBRES 12-15 » et zéro défaut. C'est le critère
d'acceptation de toute la campagne, et il est vérifiable en une commande.

## 5. Les tuiles des autres stages, pour mémoire

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

## 6. Ordre proposé

1. **Poser la nouvelle palette du stage 1** dans le dépôt (le PNG), et rejouer
   le §2 sur ses vraies valeurs — les trois fusions peuvent changer d'accueil.
2. **Le stage 1 seul**, de bout en bout : remap automatique, fusions à la main,
   tuiles et noir du décor, champ d'étoiles, effacement des tampons, police.
   Le critère est visuel ET mesuré (`palette_usage.py` sans défaut, lane 7/7,
   corpus confiné aux images r-type).
3. **Le stage 2 ensuite**, parce qu'il est le pire cas : s'il passe, les six
   autres passent.
4. Les stages 3-8, qui n'ont aujourd'hui aucune palette authorée — la migration
   est l'occasion de leur en donner une au lieu de la dériver du tileset.

Rien ici ne demande de toucher au builder : `png2pal`, `gfxcomp` et le linker
sont indifférents au CHOIX des index. C'est une campagne d'assets, plus deux
poignées de lignes d'ASM.
