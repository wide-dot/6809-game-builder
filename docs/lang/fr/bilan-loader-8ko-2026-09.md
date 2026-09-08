# Bilan de place : la demi-page du loader (08/09/2026)

Objet : les 8 Ko de la page 4 (`$C000–$DFFF`) partagés entre le loader et
son pool TLSF. Le loader fait 4 817 octets, le pool 3 375. Le but : rendre
de la place au pool et loger la barre de progression sans regret. Rien
n'est modifié par ce bilan — l'auteur arbitre, poste par poste.

Mesures : listing `gen/bootloader/build/loader.lst` de r-type (build du
08/09), octets attribués par symbole du `.lwmap`, coût des options par
plages de lignes source.

## 1. Où vont les 4 817 octets

| poste | octets | part |
|---|---|---|
| TLSF : code (`tlsf.asm`) | 817 | 17 % |
| TLSF : matrice des têtes de listes + bitmaps + variables | ~420 | 9 % |
| TLSF : `realloc` (`tlsf-realloc.asm`) + `memcpy` | 522 | 11 % |
| loader : répertoires, secteurs, fichiers, scènes, compositions, lien | ~2 070 | 43 % |
| loader : barre de progression (compteur, mesure, passe de mesure, hook) | ~250 | 5 % |
| `ptsec`, le tampon de secteur partiel | 256 | 5 % |
| zx0 (`mega`, la variante compacte) | 128 | 3 % |
| `ram.set` (fenêtres) + `log.write` | 112 | 2 % |
| table de saut (16 entrées), emplacements des répertoires (11×4), `sclist`/`skewtab`, messages | ~160 | 3 % |
| variables | ~60 | 1 % |

Le TLSF pèse **1 760 octets, 36 % du loader**, pour tenir une trentaine de
blocs de 20 à 1 140 octets.

Les routines les plus grosses : `loader.file.linkData.load` 245,
`loader.dir.load.do` 243, `tlsf.realloc.do` 235, `loader.composition.load`
200 (dont 78 de passe de mesure), `tlsf.malloc` 131, `tlsf.free` 123,
`linkData.symbol.search` 117, `tlsf.realloc.growth` 111, `tlsf.init` 100.

## 2. Code déroulé

| quoi | octets | version bouclée | gain | prix |
|---|---|---|---|---|
| `memcpy.uyd` (copie par blocs de 8, trois entrées) | 54 | ~20 | −34 | copie plus lente, ne sert qu'à `realloc.do` |
| `tlsf.bsr` / `tlsf.ctz` (nibbles déroulés) | 73 | ~35 | −38 | quelques dizaines de cycles par malloc |
| `tlsf.map.mask` / `tlsf.map.bitset` (tables de bits) | 64 | décalages | −50 | idem |
| les trois marcheurs de scène `type01` / `type10` / `type11` | 144 | un marcheur paramétré | −50 | à écrire soigneusement, `%11` a ses calculs d'id |
| les quatre lieurs `intern` / `extern8` / `extern16` / `externPg` | 179 | un lieur à mode | −70 | voir §4 : trois des quatre sont morts pour r-type |
| zx0 | 128 | — | 0 | `mega` est déjà la variante taille |

Total réaliste : **−150 à −240**, en échange de cycles au chargement
(négligeable devant le disque) et d'une réécriture des marcheurs.

## 3. Variables qu'on pourrait fondre dans le code

Une soixantaine d'octets de variables (`nsect`, `track`, `sector`,
`diskId`, `dirSector`, `dirSkew`, `loader.scene.routine`,
`loader.scene.fileCount`, `composition.count/target`, les huit de la
progression, `linkData.current*`, `tlsf.fl/sl`, `tlsf.bsr.in`,
`tlsf.ctz.in`). Fondre une variable dans une instruction (opérande immédiat
auto-modifié, comme `@page`/`@addr` de `type11`) ne rend que son stockage
et un octet par accès étendu remplacé par un immédiat, contre une écriture
dans le code à chaque changement : le gain net est **de 20 à 40 octets**,
pour une fragilité réelle. Un cas net : `tlsf.bsr.in` / `tlsf.ctz.in`,
paramètres passés par mémoire — les passer dans D rend 4 octets de
stockage et une dizaine d'octets de `std`/`ld`, et va plus vite. Le reste
n'en vaut pas la peine.

## 4. Code mort pour r-type (vivant dans l'engine)

Ce que le rapport de lien dit du jeu : 0 relocation `intern` (cuites par
le builder), 0 `extern8`, 0 `externPg`, 138 `extern16`, 199 exports.
Aucune table de scène n'emploie le bloc `%10` (les lots s'enchaînent tous
en `%11`). Le jeu n'appelle que `scene.load`, `dir.load`,
`composition.load/set` et `progress.hook.set`.

| quoi | octets | comment le retirer |
|---|---|---|
| lieurs `intern`, `extern8`, `externPg` + `getPageID` | 168 | le builder sait quels genres une cible emploie : un `define` généré par genre (`loader.LINK_INTERN`…), chaque lieur sous `IFDEF` |
| marcheur `type10` | 48 | le builder refuse un lot dont les ids ne s'enchaînent pas (aujourd'hui il retombe en `%10` en silence), le loader perd `type10` |
| `linkData.count` + son entrée de table | 17 | observabilité de loader-ut seulement : sous `IFDEF loader.DEBUG` |
| `dir.unload` + son entrée | 28 | API que personne n'appelle : la garder sous `IFDEF`, ou la retirer |
| invite « Insert disk » (contrôle d'id, chiffre ASCII, `info`, message) | ~70 | `IFDEF loader.MULTIDISK`, que le builder pose quand la cible a plus d'une disquette |
| affichage « I/O Error » (`err`, `messloc`, `messIO`) | ~60 | sur machine, invisible sous une palette noire ; un `log.halt` trace mieux |
| piège `LOAD_OVERLAP` (`findOverlap` + son site) | 116 | `IFDEF loader.DEBUG` — il a payé une fois (le lot cancer sur les tilesets), un build de dev le garde |
| `log.write` + trap + sites (`_log.error`) | ~75 | ne sert plus qu'aux pièges ci-dessus et à `ram.set` : suit `loader.DEBUG` |
| entrées de la table de saut que r-type n'appelle pas (11 sur 16) | 33 | c'est l'ABI du loader ; loader-ut les appelle. À ne toucher qu'en dernier |

Total : **−330 sans les diagnostics, −520 avec**, sans rien perdre pour
r-type, tout restant disponible par `define` aux autres cibles.

## 5. Superflu ou peu utilisé

**`realloc` + `memcpy` : 522 octets pour deux appelants.** L'index de
lien (8 → 16 → 24 slots) et le tampon de répertoire (512 ↔ 1 024).
Le builder connaît les deux maximums de la cible : 24 fichiers indexés à
l'état de pointe (pool-map), 4 secteurs pour le plus gros répertoire
(`loader.dir.buffer.SECTORS`, déjà généré). Un index alloué une fois à sa
taille de pointe (200 octets au lieu de 68 au boot, identique à la
pointe) et un tampon de répertoire alloué une fois dans le pool à la
taille du plus gros répertoire suppriment les deux appels : `realloc` et
`memcpy` sortent du loader (ils restent des fichiers de l'engine, inclus
sur demande). Bilan pour le pool à l'état stage 1 : aujourd'hui 3 375 −
1 028 (répertoire) − 1 140 − 200 ≈ **1 000 libres** ; après, 3 897 −
1 028 − 1 140 − 200 ≈ **1 530 libres**, et la même marge dans tous les
états (le tampon ne rétrécit plus à 516 quand les lots sont montés, mais
le code rendu vaut plus que ce que le rétrécissement rendait). Ce n'est
pas le tampon statique d'avant : il est dimensionné par le builder et vit
dans le pool ; c'est la contrainte « un répertoire monté en pleine
convergence doit tenir dans le trou » qui disparaît avec lui.

**La matrice TLSF : `SL_BITS = 4`, 16 sous-classes par puissance de deux.**
Matrice de 378 octets + 26 de bitmaps + 64 de tables, pour un pool de
3,4 Ko et trente blocs. Avec `SL_BITS = 2` (4 sous-classes) : matrice
d'environ 120 octets, bitmaps et tables réduites d'autant, **−250 à −290
octets**, code inchangé. Prix : des classes de taille plus grossières,
donc un peu plus de fragmentation interne — sans effet mesurable à cette
échelle (les blocs sont de tailles très diverses, le pool n'est jamais
plein à 90 %). C'est un paramètre de configuration, pas une modification
de l'allocateur ; il peut rester un `define` par cible.

**La barre de progression : ~250 octets**, dont 156 pour la *mesure*
(`file.measure`, `scene.measure`, la passe de mesure de
`composition.load`) qui n'existe que pour connaître le total avant le
premier secteur. Alternative : le builder écrit le total de chaque
composition dans sa table (2 octets par composition, en RAM résidente,
pas dans le loader) ; la barre prend ce total comme échelle et s'arrête
un peu avant le bout quand une partie est déjà résidente. La barre
tombe à **~95 octets**. Ou garder la mesure exacte pour 156 octets.

**`ptsec`, 256 octets** : incompressible tant que le moniteur lit des
secteurs entiers ; il n'y a pas de place ailleurs dans la page (l'arène
de l'autre moitié a 44 octets libres).

## 6. Bilan chiffré, du plus sûr au plus engageant

| n° | mesure | gain | ce que ça engage |
|---|---|---|---|
| 1 | `tlsf.SL_BITS` 4 → 2 | −250 à −290 | un paramètre ; fragmentation interne un peu plus grossière |
| 2 | genres de relocation par `define` généré | −168 | builder : un define par genre employé |
| 3 | invite multi-disquette et affichage d'erreur sous `define` | −130 | plus de message à l'écran en cas d'erreur d'E/S, un trap |
| 4 | `dir.unload`, `linkData.count` sous `define` | −45 | loader-ut construit avec le define |
| 5 | diagnostics (`LOAD_OVERLAP`, `log`) sous `loader.DEBUG` | −190 | le build de dev les garde, le build livré non |
| 6 | plus de `realloc` : index et tampon dimensionnés par le builder | −522 | le tampon ne rétrécit plus (516 → 1 028 dans l'état lots) ; réécriture de `dir.load` et de l'index |
| 7 | totaux de progression écrits par le builder, plus de passe de mesure | −156 | barre à l'échelle de la composition entière |
| 8 | `%10` refusé par le builder, marcheurs fusionnés | −100 | générateur + réécriture des marcheurs |
| 9 | `bsr`/`ctz` par registres, boucles au lieu du déroulé | −80 | cycles au malloc |
| 10 | variables fondues dans le code | −30 | fragilité, pour rien |
| 11 | table de saut élaguée | −33 | ABI |

Les six premières, sans toucher à l'architecture : **−1 300 octets
environ**, le pool passe de 3 375 à ~4 700, la marge à l'état stage 1 de
~1 000 à ~2 300 octets, la barre payée dix fois. Les mesures 1 à 5 sont
des `define` ou des paramètres : réversibles, sans réécriture ; la 6 est
la seule qui change une décision prise (le tampon dynamique du 07/09),
et c'est celle qui rend le plus.

## 7. Fait (08/09, mesure 6)

`realloc` et `memcpy` sortent du loader ; le tampon de répertoire est un
bloc du pool alloué une fois à `loader.dir.buffer.SECTORS × 256`, l'index
de lien un bloc de `loader.file.linkData.SLOTS` entrées, compté par le
builder sur les compositions (24 pour r-type) et surchargeable par
`<define>` (loader-ut : 32). Un slot de plus = `log.scene.INDEX_FULL`.
Loader 4 817 → **4 264 octets**, pool 3 375 → **3 928** ; à l'état
stage 1 : 3 928 − 1 028 (répertoire) − 1 140 (liens) − 200 (index) ≈
**1 560 libres** contre ~1 000. Les mesures 1 à 5 et 7 à 11 restent à
arbitrer.

## 8. Fait (08/09, mesure 1)

`tlsf.SL_BITS` est sous `IFNDEF` dans `tlsf.asm` (défaut 4) ; le loader le
pose à 2 avant l'inclusion. La matrice et les coins inutiles sont écrits
en fonction de `SL_SIZE` et `MIN_BLOCK_SIZE` (les deux lignes en dur pour
seize classes sont généralisées, neutre à l'octet à 16 classes) ; les
bitmaps de second niveau restent des mots, comme le code les lit.
`examples/tlsf-ut` a deux cibles, `fd` à 16 classes et `fd-sl2` à 4, les
assertions et la table des `(fl, sl)` attendus sont conditionnelles.
Validé : tlsf-ut PASS aux deux finesses (test aléatoire compris), r-type
reconstruit à l'octet près à 16 classes, rtype_bench 7/7 et loader-ut
17/17 + T18 avec le loader à 4 classes. Loader r-type : 4 264 → 3 996
octets, pool 3 928 → 4 196. Chemin de traverse : loader-ut se figeait en
plein transfert de secteur sous toje avec cette image — un artefact de la
longue stabilisation de `boot_floppy` (séquence DKCONT identique à l'image
qui passe, absent avec une stabilisation d'une trame) ; le harnais amorce
désormais avec `settle=1`.

## 9. Décision auteur sur les mesures 2 à 5 (08/09)

Le loader reste **générique** : pas de `define` par capacité de la cible
(genres de relocation, multi-disquette, diagnostics). L'espace se gagne
sur ce qui est superflu pour tous, pas sur ce que r-type n'emploie pas.
Et l'affichage « I/O Error » n'est pas retiré mais **rendu lisible** :
erreur terminale, on y met quelques octets. Avant d'écrire, `err` masque
les interruptions, repasse en 40 colonnes, remet la page 0 à l'écran, et
force les deux entrées de palette du message (encre 7, papier 1) en blanc
sur rouge — le registre d'adresse du EF9369 compte des OCTETS, l'entrée n
est à 2n — puis efface tout l'écran avant la fenêtre du message. L'erreur
de lecture d'un fichier (`dskerr`, qui faisait un reset) y passe aussi ;
l'invite « Insert disk » garde son effacement local. Vérifié sous toje en
forçant la retenue après les deux appels DKCONT de `ldsec` pendant le
splash (BM16, page 3, palette du logo) : écran rouge, message blanc.
Loader 3 996 → 4 044 octets.

## 10. Fait (08/09, mesure 7)

Le total de la barre n'est plus mesuré par le loader : l'entrée de
répertoire d'une scène porte un **second bloc** (bit 5 de `bitfld`,
`dir.entry.units`) où le builder écrit, une fois tous les fichiers sur le
média, ce que le chargement de la scène ajoutera au compteur — secteurs
de la table, des données et des liens de ses fichiers (partiels compris),
une unité par 512 octets décompressés. `scene.load` lit ce mot dans
l'entrée avant sa première lecture (pas de bit de drapeau : les bits 7-6
sont pris et le reste est la taille sur 14 bits ; le loader n'y accède
que par un id de scène, les décodeurs reconnaissent le bloc à sa
signature $FFFF en piste/secteur), `composition.load` l'additionne pour
les scènes qui arrivent sans lire un secteur (le répertoire est monté de
toute façon). `file.measure`, `scene.measure` et le `mute` disparaissent,
les tables ne sont plus relues pour être mesurées, et elles comptent
désormais dans le total. Prix : 8 octets par scène dans son répertoire
(`loader.dir.buffer.SECTORS` reste à 4 sur r-type). Loader 4 044 → 3 947
octets, pool 4 245. Vérifié sous toje : `done` = total = 44 à la pose du
hook par le splash, 585 = 585 quand `boot.entry` le retire.

## 11. Fait (08/09, mesure 8, première moitié)

Le bloc `%10` disparaît : le générateur émet un bloc `%11` par suite d'ids
consécutifs (7 octets chacun) et signale au build une scène qui en a
plus d'un — les ids sont l'œuvre du builder, l'incertitude que le `%10`
absorbait n'existe pas. Le loader perd `type10` et sa branche ; un bloc
`%10` d'une image périmée tombe sur `log.scene.BLOCK_TYPE`. Les deux
autres marcheurs restent tels quels (décision auteur). r-type n'avait
aucune table en `%10` : images inchangées hors loader.

## 12. Fait (08/09, mesure 9, la part qui gagne des cycles)

`tlsf.bsr` et `tlsf.ctz` prennent leur valeur dans D (elle y est toujours
au moment de l'appel) au lieu d'une variable ; `ctz` répond dans A et
balaie l'octet bas là où il est, dans B. Trois `std` de moins, deux
remplacés par `subd #0` (Z sur le mot, 4 cycles contre 6), deux `lda`
étendus par un `tst` ou un `tfr`. Par `malloc` : −11 à −24 cycles selon le
chemin, par `free` −2 ou −3, aucun chemin ne perd un cycle ; −14 octets.
Les balayages restent déroulés (décision auteur : pas un cycle contre des
octets). Validé : tlsf-ut aux deux finesses, rtype_bench 7/7, loader-ut.
Loader r-type 3 885 octets, pool 4 307.

## 13. La barre dans l'espace du loader (08/09)

Décision auteur : l'effet `loadbar` (100 octets, relogeable) est assemblé
dans le loader après son code, en bloc fixe, et s'installe par une entrée
de la table de saut, `loader.loadbar.set` (48), qui copie les paramètres
(et, depuis la pulsation, la table de teintes elle-même — 16 octets de
plus dans le loader : un pointeur vers l'unité du splash lisait le code
du moteur qui venait de la recouvrir, barre verte au boot le 08/09) et
pose le hook — le splash de r-type n'a plus qu'un enregistrement et un
`jsr`, et le layout perd son `<reserved loading.fx>` de 242 octets en
page 1. Ce que le loader reprend : les 100 octets de
l'effet, l'entrée et la routine d'installation (~25) ; la page 1 en rend
242 au jeu.

