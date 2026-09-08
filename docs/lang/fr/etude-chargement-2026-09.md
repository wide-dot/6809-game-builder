# Étude : un hook de chargement pour une barre de progression (07/09/2026)

Objet : le splash « WIDE DOT presents » doit porter une barre de progression.
(Deux correctifs sont sortis de l'étude le jour même, §3.4 et §3.5 ; le
reste du document est l'étude du hook, inchangée.)
Il faut pour cela un point d'accroche dans la routine de lecture disquette,
un calibrage (combien il y a à charger), et une garantie sur la performance :
la lecture est entrelacée, un hook trop lent fait perdre un tour de disque
par secteur. Cette étude mesure ce qu'on a avant de proposer. **Rien n'est
changé dans le loader.** Les sondes qui ont produit les chiffres sont dans
`games/r-type/tools/loading/`.

## 1. Ce qui existe déjà

- **Un hook par secteur, déjà en place.** `ldsec` (loader.asm) appelle
  `jsr >pulse` après chaque secteur lu ; `pulse` est un `jmp >return`, un
  vecteur de 3 octets qu'un jeu peut repointer. Coût actuel : jsr + jmp + rts,
  17 cycles. Il ne transmet rien (ni compteur, ni total).
- **Trois passes par scène** (`loader.scene.load.noLink`) : lecture disque de
  tous les fichiers (pour profiter de l'entrelacement), décompression ZX0,
  puis chargement des link data — dont la relocation, exécutée fichier par
  fichier juste après chaque lecture (`linkData.load` finit par
  `intern.link`). Une composition enchaîne les scènes puis fait UN lien
  global.
- **Aucune notion de total** : le loader ne sait pas, quand il commence, ce
  qu'une composition pèse.

## 2. Le disque : théorie

Géométrie fd640 (`engine/config/storage.xml`) : 80 pistes × 2 faces ×
16 secteurs × 256 octets. Lecteur 3,5" à 300 tr/min (toje : `FLOPPY_RPM =
300`), MFM.

| grandeur | valeur |
|---|---|
| un tour | 200 ms |
| un créneau secteur (1/16 de tour) | 12,5 ms ≈ 12 500 cycles à 1 MHz |
| une piste | 4 096 octets utiles |
| débit brut, entrelacement 1 (une piste par tour) | 20 Ko/s |
| débit à notre entrelacement 2 (une piste en deux tours) | 10 Ko/s |

**Notre entrelacement.** Le format Thomson place le secteur numéro n à la
position physique `((n−1)×7) mod 16` (`hardskip="7"`, et toje fait de même :
`DiskImage.sectorPosition`). Le builder range les secteurs logiques par-dessus
avec `softskip="2"` : l'ordre de lecture est `sclist` du loader
(1, 15, 13, 11, 9, 7, 5, 3, 8, 6, 4, 2, 16, 14, 12, 10), soit les positions
physiques 0, 2, 4 … 14 puis 1, 3 … 15 : **huit secteurs par tour, un créneau
libre entre deux lectures**, deux tours par piste. `softskew="4"` décale le
départ de deux entrées de `sclist` par piste (quatre créneaux, 50 ms) pour
laisser à la tête le temps de passer à la piste suivante.

**Le budget entre deux secteurs.** Entre le retour de DKCONT et l'appel
suivant, le loader fait `ldsec1` + `pulse` + la boucle `ld4`/`ldsec` :
environ 150 cycles. Le créneau libre en fait 12 500, moins ce que DKCONT
consomme lui-même avant de retrouver l'en-tête du secteur (recherche de
l'ID, quelques centaines de cycles). Un hook a donc, en théorie, de l'ordre
de **10 000 cycles** par secteur. Il ne faut pas les prendre : la sanction
d'un dépassement n'est pas proportionnelle, c'est un tour complet, 200 ms,
huit fois le prix du secteur. Règle proposée plus bas : 2 000 cycles.

## 3. Le disque : ce qu'on consomme (mesuré sous toje)

Mesures sur `dist/to8.fd` du 07/09, toje en cadence réelle. **Toje modélise
la rotation à l'octet près (modèle teo-wd), pas la mécanique de la tête ni
les tolérances moteur : les ordres de grandeur sont fiables, les
événements de pas de tête sont à confirmer sur machine.**

### 3.1 Où passe le temps (`tools/loading/phases.py`)

| séquence | durée | ROM (DKCONT : attente + lecture) | ZX0 | lien | reste |
|---|---|---|---|---|---|
| amorçage → title (fondu, splash, boot, title) | 37,7 s | 71 % | 25 % | 1 % | 3 % |
| title → stage 1 (composition stage1, lots compris) | 43,7 s | 72 % | 25 % | 1 % | 2 % |

Le lien global, qu'on croyait cher (références × exports), ne pèse rien.
Tout est dans le disque et dans ZX0.

### 3.2 Ce qu'il y a à charger (`tools/loading/scene_volumes.py`)

Décodé depuis les répertoires de l'image (secteurs comptés fichier par
fichier, link data compris).

| scène | fichiers | secteurs lus | dont partiels | octets disque | octets RAM |
|---|---|---|---|---|---|
| scenes.boot | 42 | 293 | 92 | 62 382 | 138 440 |
| scenes.title | 8 | 45 | 16 | 9 221 | 22 503 |
| scenes.stage1 | 37 | 382 | 84 | 85 182 | 213 858 |
| scenes.stage2 | 34 | 391 | 70 | 90 254 | 228 037 |
| scenes.stage3 | 21 | 184 | 43 | 40 658 | 150 466 |

(`nsector` d'une entrée compte tous les secteurs touchés, partiels compris :
`FdUtil.cwrite` incrémente par secteur écrit.) À 25 ms le secteur,
`scenes.boot` devrait coûter 7,3 s de disque. On en mesure environ 27 (ROM
de la séquence entière, dont le title). Le ZX0 sort 138 Ko en 9,5 s, soit
**14,5 Ko/s**.

### 3.3 Le secteur, un par un (`tools/loading/sector_gaps.py`)

Écart entre deux lectures pendant l'amorçage, échantillonné à la trame
(20 ms — un secteur normal fait 25 ms, deux secteurs tombent parfois dans
la même trame, le compte est un minorant) :

| écart | secteurs | lecture |
|---|---|---|
| 20 à 40 ms | 222 | l'entrelacement 2 tient |
| 180 à 200 ms | 50 | **un tour perdu** |
| 440 à 880 ms | 15 | un par piste et par face, non expliqué |
| 4 à 5 s | 2 | les passes ZX0 et lien entre deux scènes |

Bilan sur les 459 secteurs de la séquence : idéal 11,5 s ; mesuré 26,6 s
en ROM. La différence tient à **environ 75 tours perdus** (15 s) et aux
quinze événements longs (6 s).

### 3.4 D'où viennent les tours perdus

Ce ne sont pas les link data (la chronologie les place dans la passe de
lecture, pas dans la passe de lien). Ils tombent aux **frontières de
fichiers**. Le builder écrit les fichiers bout à bout (`FdUtil.cwrite`
reste dans le secteur courant tant qu'il y a de la place) : le dernier
secteur partiel de A EST le premier secteur partiel de B, décrits chacun
dans le répertoire (`sizea`, `sizez`), lus dans `ptsec` puis copiés. Le
loader lit donc **le même secteur deux fois de suite** — la fin de A, puis
le début de B — et la seconde lecture attend par construction un tour
complet. `scenes.boot` compte 92 secteurs partiels sur 293 lus, et ses 41
link data, 468 octets en tout, se serrent sur deux ou trois secteurs lus
41 fois. C'est le poste numéro un.

**Remède, fait le même jour (décision auteur : « le cache d'abord »).**
Le loader garde la clé [piste/face][index] du secteur que `ptsec` contient
(`ptsec.key`) ; `ldsec`, quand la destination est `ptsec` et que la clé
est celle demandée, saute la lecture et ne fait que la comptabilité et le
`pulse`. `loader.dir.load`, qui lit son premier secteur dans `ptsec` sans
passer par `ldsec` (et peut-être depuis une autre disquette), invalide la
clé. Coût : 12 cycles par secteur plein, 27 octets de code. Mesuré sous
toje, même sonde, même image :

| séquence | avant | après |
|---|---|---|
| amorçage → title, total après le menu | 37,7 s | **10,5 s** |
| amorçage → title, dont ROM | 26,6 s | 3,9 s |
| title → stage 1, total | 43,7 s | **31,5 s** |
| title → stage 1, dont ROM | 31,3 s | 19,3 s |
| secteurs à 180–200 ms, amorçage | 50 | **0** |
| title à l'écran, depuis le secteur de boot (vidéo) | trame 3100, 62 s | **trame 1700, 34 s** |
| banc loader-ut, temps mur | 25 s | 7 s |

Le gain dépasse l'estimation : les link data se relisaient bien plus que
prévu (41 fichiers sur deux secteurs, chaque lecture un tour perdu) et le
title en faisait autant. Un `loader-ut` et un `rtype_bench` verts
derrière. L'alternative — aligner les fichiers au secteur côté builder,
128 octets de disque par fichier — n'a plus d'objet.

Les événements de 440 à 880 ms, un par piste et par face, ne sont pas
compris : ce n'est pas le changement de piste (il arrive en milieu de
piste), c'est peut-être le moniteur ou le modèle de toje. À mesurer sur
machine avant d'en tirer quoi que ce soit.

### 3.5 Le profil complet, et la scène de boot chargée deux fois

Profil de la touche B au title (`tools/loading/fullboot.py`, cache de
secteur en place) : 34,4 s, dont 19,6 s de disque et 12,1 s de ZX0. Or le
ZX0 de `scenes.boot` fait 5,4 s. La chronologie montre **deux fois** la
paire disque puis ZX0 : `scenes.boot` était chargée deux fois. Le splash la
charge par `scene.load`, qui ne pose pas `composition.current` ; puis
`boot.entry` demande le title par `composition.load`, dont la cible nomme
boot + title, et le loader, voyant un état courant nul, recharge tout.
Défaut présent depuis la séparation boot/title (01/09), sans rapport avec
le fondu ni le splash.

Corrigé le même jour (décision auteur) : `loader.composition.set`, entrée
39 de la table de saut, déclare l'état résident sans charger ;
`boot.entry` l'appelle avec `compositions.boot`. Mesure après : voir §3.6.

### 3.6 Où on en est, de la touche B au title

| poste | avant (07/09 matin) | cache de secteur | + `composition.set` |
|---|---|---|---|
| title à l'écran | trame 3100, 62 s | trame 1700, 34 s | **trame 1020, 20 s** |
| disque (ROM) | ~47 s | 19,6 s | 11,5 s |
| ZX0 | 12,1 s | 12,1 s | 6,6 s |
| menu, boot, loader | 1,0 s | 1,0 s | 1,0 s |
| fondu, splash, lien, reste | ~2 s | 1,7 s | 1,3 s |

Ce qui reste : 293 + 45 secteurs en 11,5 s, soit 34 ms le secteur contre
25 en théorie — l'écart, ce sont les changements de piste et les
événements de 440–880 ms du §3.3 ; et 6,6 s de ZX0 pour 160 Ko. Le
prochain poste est le ZX0 (un tiers), puis les pistes.

## 4. Le hook : quelle granularité

| événement | fréquence | régularité | budget disponible | verdict |
|---|---|---|---|---|
| **secteur** (`pulse`, existant) | toutes les 25 ms | régulière | ~10 000 cycles, à ne pas prendre | **la source d'événements** |
| fichier | 1 à 60 secteurs, 42 fichiers au boot | irrégulière | large (le fichier suivant attend de toute façon) | un second signal, pour la calibration |
| piste | toutes les 400 ms | régulière mais rare | large (la tête bouge) | trop grossier pour une barre |

Le secteur est le seul signal assez fin pour une barre qui bouge. Mais
**rien de coûteux ne doit s'exécuter dedans**, et il n'y a pas
d'« ailleurs » : pendant DKCONT le moniteur lit les octets par scrutation,
32 cycles chacun, les interruptions sont masquées — un effet ne peut
tourner qu'entre deux secteurs, dans le même créneau. Un effet piloté par
l'IRQ 50 Hz du jeu n'y échapperait pas : il s'exécuterait au même endroit,
avec un budget invisible.

Proposition :

1. **Le loader ne fait qu'un compteur.** `pulse` incrémente un mot
   `loader.progress` (une vingtaine de cycles) et décrémente un pas
   `loader.progress.step` ; quand le pas tombe à zéro, il le recharge et
   appelle l'effet **une fois**. L'effet ne voit donc qu'un événement
   « avance d'un cran », jamais une division.
2. **L'engine est le référentiel des effets**, chacun avec son coût déclaré
   et tenu : barre pleine d'une colonne BM16 (une colonne de 8 lignes ≈
   150 cycles), barre d'une cellule 7 × 6 comme l'anneau du logo, point
   qui pulse par la palette (deux écritures EF9369, mais en plein écran :
   de la neige, à réserver à la bordure), etc. Le jeu choisit l'effet, sa
   place et sa palette ; il ne réécrit pas le hook.
3. **Budget** : 2 000 cycles par appel d'effet, un cran au plus par
   secteur. Contrôle : la sonde `sector_gaps.py` est le banc de
   non-régression — l'histogramme ne doit pas gagner un seul secteur à
   200 ms par rapport à la référence sans effet.
4. L'effet écrit en page 3 (la page montée à l'écran pendant les
   chargements, plan `plan-ecran-loading-2026-09.md`) à travers la fenêtre
   cartouche : il sauve et restaure `$E7E6`, le loader tourne sur DP $60.

## 5. Le calibrage : quantité, pas durée

Une approximation suffit, et la quantité est la seule chose que le builder
connaît sans mesurer. Ce que le temps mesuré dit de la bonne unité :

| poste | part du temps | ce qui le pilote | unité |
|---|---|---|---|
| disque | 72 % | secteurs lus, relectures comprises | 1 secteur ≈ 58 ms aujourd'hui (25 ms sans tour perdu) |
| ZX0 | 25 % | octets décompressés | 1 Ko de RAM ≈ 69 ms |
| lien | 1 % | références × exports | négligeable |

Une **unité = un secteur**, et un kilo-octet décompressé vaut 1,2 secteur
(avec le cache de secteur, ce serait 2,8 : la constante doit rester dans la
configuration, pas dans le code). Le builder calcule par composition
`unités = secteurs + Ko_RAM × k` et l'écrit dans la table de composition
(un mot). `pulse` compte les secteurs ; un second hook, appelé par
`loader.file.decompress` avec la taille produite, avance du reste. Deux
hooks, deux compteurs, un seul pas.

Ce que le builder sait déjà : les secteurs par fichier (répertoire), la
taille RAM (`sizeu`), la liste des scènes d'une composition. Il manque
seulement l'addition et l'écriture du mot — et la règle des scènes déjà
résidentes (une convergence ne recharge pas ce qui est là : le total est
celui des arrivantes, `composition.load` le connaît au même moment que le
loader).

## 6. Ce que l'auteur doit trancher

1. ~~Le cache de secteur dans le loader (§3.4) : avant ou après la barre ?~~
   Tranché et fait : avant. Les constantes de calibrage du §5 sont à
   remesurer sur ce loader (le secteur revient vers 25 ms, le kilo-octet
   ZX0 vaut alors près de 3 secteurs).
2. Le budget de 2 000 cycles par cran : à confirmer sur machine réelle,
   toje ne modélise pas la mécanique.
3. Deux hooks (secteur + décompression) ou un seul (secteur, et une
   barre qui s'arrête pendant ZX0 — 25 % du temps immobile) ?
4. Où vit la table des effets : `engine/system/thomson/bootloader/` (le
   loader les appelle) ou `engine/graphics/` (ce sont des effets vidéo) ?

## 7. Et sans entrelacement ? (expérience du 07/09, non retenue en l'état)

Question de l'auteur : à l'entrelacement 1, perd-on forcément un tour, ou
sommes-nous assez rapides pour enchaîner deux secteurs physiques
consécutifs ? Le raisonnement ne suffit pas : entre la fin des données
d'un secteur et l'en-tête du suivant, le format laisse environ 80 octets
MFM, soit 2,5 ms ou 2 500 cycles ; le loader en prend 150, et le reste
est le prologue de DKCONT, du code ROM dont on ne connaît pas le coût.
L'expérience, dans une copie de travail remise en l'état ensuite :
`softskip="1"` dans `storage.xml`, la table `sclist` du loader et `blist`
du secteur de boot passées à l'ordre physique (1, 8, 15, 6, 13, 4, 11, 2,
9, 16, 7, 14, 5, 12, 3, 10), et la règle de skew adaptée
(`(piste×4) & 12` au lieu de `(piste×2) & 6`, quatre positions physiques
faisant quatre entrées de table et non plus deux). Toje exécute le code ROM
au cycle près et modélise la rotation à l'octet (modèle teo-wd).

| | entrelacement 2 | entrelacement 1 |
|---|---|---|
| touche B → title | 20,4 s | **17,0 s** |
| dont disque (ROM), 338 secteurs | 11,5 s | 8,1 s |
| title → stage 1 | 31,5 s | **26,9 s** |
| dont disque (ROM) | 19,3 s | 14,5 s |
| écarts entre secteurs à l'amorçage, ≤ 20 ms | 222 sur 306 | 210 sur 238 |
| écarts ≥ 160 ms | 0 | 5 |

**Sous toje, les secteurs s'enchaînent** : le loader et DKCONT tiennent dans
l'intervalle entre deux secteurs physiques. Le disque ne passe pourtant pas
de 34 à 12,5 ms le secteur mais à 24 : ce qui reste est le changement de
piste (une piste se lit désormais en un tour, on en change deux fois plus
souvent par seconde) et l'événement de 440–880 ms par piste et par face du
§3.3, toujours inexpliqué, qui pèse désormais la moitié du temps disque.

**Pourquoi ce n'est pas retenu en l'état.** L'entrelacement est une
propriété du média entière : trois tables à changer ensemble (`storage.xml`,
`sclist`, `blist`) et une règle de skew, toutes les images du corpus
changent, et toje ne modélise pas la mécanique de la tête ni la vraie
longueur des intervalles du format — c'est exactement ce que l'entrelacement
1 met à l'épreuve. À valider sur machine avant de décider, avec la sonde
`sector_gaps.py boot` : si les écarts à 200 ms restent rares, c'est
3,4 s de gagnées à l'amorçage et 4,6 s par stage. Et le prochain poste,
quel que soit le verdict, est l'événement par piste : à lui seul il vaut
autant que l'entrelacement.

## 8. L'événement de 440–880 ms par piste : expliqué (07/09, soir)

Instrumentation trame par trame (`tools/loading/trackevent.py`) : état du
loader, PC en ROM, compteurs et drapeaux du contrôleur. Pendant chaque trou
la machine tourne dans la boucle ROM `$E45A–$E473` — attente du bit READY
de STAT1, en pulsant le bit moteur de CMD2, jusqu'à $8000 tours — et le
moteur est **à l'arrêt** juste avant. Les trous reviennent toutes les
101 trames, soit **2,0 s**, quel que soit le secteur.

Un point de surveillance sur CMD2 (`$E7D2`, `tools/loading/motoroff.py`)
attrape l'auteur de l'arrêt : la routine ROM `$E0B9` (`LDA #$40 ; STA
2,X`), appelée par `$E08A`… qui est **l'épilogue de DKCONT lui-même**
(`BSR $E0A7 ; BSR $E0C2 ; BSR $E0B9 ; PULS A,B,DP,X,Y,U,PC`). Le moniteur
coupe le moteur à la fin de CHAQUE appel, et l'appel suivant le rallume
dans sa boucle READY. C'est du code ROM, donc vrai sur machine.

Ce qui fait le trou de 0,4 s toutes les 2 s, en revanche, est dans le
modèle du contrôleur de toje (hérité de teo-wd) : à la remise en marche,
si la dernière MISE EN MARCHE date de plus de 2 s, l'inertie moteur est
rejouée — `0x33A8 × 29` cycles, 0,38 s, avant que READY revienne. La règle
compare à la dernière mise en marche et non à la durée d'arrêt : en
lecture continue, le moteur tourne depuis plus de 2 s, chaque arrêt de
quelques centaines de microsecondes redevient un démarrage. Sur machine,
un lecteur dont la ligne moteur retombe 100 µs entre deux secteurs ne
ralentit pas ; ce que fait son signal READY (immédiat, ou deux impulsions
d'index) est **la vraie inconnue, et elle ne se mesure que sur le TO8**.
Si READY revenait lentement, le loader v1 n'aurait jamais enchaîné deux
secteurs, ce qu'il fait depuis des années. MAME (`thmfc1.cpp`) modélise
l'inverse de toje : la coupure du bit moteur arme un temporisateur de 2 s
(`m_timer_motoroff`), la remise en marche l'annule, et le moteur ne
s'arrête que si la ligne reste basse 2 s — en lecture continue, il ne
s'arrête jamais.

Conséquences :

- les chiffres de temps disque de cette étude portent cet artefact :
  environ 20 % du temps ROM (0,4 s par 2 s), soit ~2 s sur les 11,5 du
  boot et ~4 s sur les 19 du stage 1. Ils sont **à corriger sur machine** ;
- le pas de tête n'est pas modélisé du tout par toje (le `STEP` change la
  piste instantanément) : le skew ne peut pas s'optimiser en émulation ;
- le seul moyen d'éviter l'arrêt moteur à chaque secteur serait de ne
  plus passer par DKCONT : un lecteur de secteurs à nous, qui parle au
  THMFC1. C'est un autre chantier, et il n'a de sens qu'après la mesure
  sur machine.

## 9. Les réglages, et les deux images pour la machine

Ce que l'émulation a tranché : l'entrelacement secteur 2 suffit largement
(aucun tour perdu sur les secteurs pleins), et l'entrelacement 1 tient
aussi sous toje. Ce qu'elle ne peut pas trancher : le skew de piste (pas
de tête non modélisé) et le comportement READY du lecteur réel.

Le skew aujourd'hui : `softskew="4"`, quatre positions physiques par
piste, appliqué au numéro de piste — donc identique sur les deux faces
d'un cylindre. Le changement de face ne coûte aucune mécanique : après le
dernier secteur de la face 0 (position 15), le premier de la face 1 est en
position 0, un créneau plus loin, et l'enchaînement tient (c'est le même
budget qu'entre deux secteurs à l'entrelacement 1). Le changement de
cylindre a quatre positions, 50 ms, pour le pas et la stabilisation de la
tête ; un 3,5" Thomson fait le pas en quelques millisecondes et se
stabilise en 15 à 20 : quatre positions est la bonne valeur si READY
revient tout de suite, insuffisant sinon — et c'est ce que la machine dira.

Proposition pour l'essai :

| image | entrelacement secteur | skew | ce qu'elle teste |
|---|---|---|---|
| A | 2 (actuel) | 4 | la référence : cache de secteur + `composition.set` |
| B | 1 | 4 | l'enchaînement réel des secteurs et le comportement READY |

Mesure : chronomètre de la touche B au title, puis du départ au stage 1.
Attendus sous toje : A 20,4 s et 31,5 s ; B 17,0 s et 26,9 s. Si B est
proche de A ou meilleure, l'entrelacement 1 est acquis ; si B décroche
(plusieurs secondes de plus, des dizaines), READY ou l'intervalle réel du
format ne suivent pas. Si les deux sont nettement plus rapides que toje,
l'artefact d'inertie est confirmé.

**Fait le 07/09 (soir).** Le builder génère les tables dans
`gen/directories/locations.asm` depuis l'`Interleave` même avec lequel il
écrit l'image : `_loader.interleave.sclist` (l'ordre de lecture) et
`_loader.interleave.skew` (l'index de départ par piste, `track &
SKEW_MASK`), le loader et les deux secteurs de boot (TO8, MO6) les
invoquent — plus de copie à la main. Et `<floppydisk>` accepte
`softskip`, `softskew`, `hardskip` pour surcharger le storage : l'image B
est la config nominale plus `softskip="1"` sur son `<floppydisk>`, rien
d'autre (§ config.md). Vérifié : tables générées identiques aux anciennes
pour l'entrelacement 2, loader-ut 17/17 + T18, rtype_bench 7/7, B amorce
sous toje au même chiffre que l'expérience manuelle (17,0 s).

Les deux jeux d'images (`to8.fd`, `to8.sd`, `to8_0.sap`, `to8_1.sap`)
sont livrés à l'auteur pour l'essai sur machine : A = entrelacement 2, B =
entrelacement 1, skew 4 dans les deux cas.

## 10. La barre, faite (07/09, soir)

Ce qui est en place, sur l'entrelacement 2 nominal :

- **Le loader compte** (`loader.progress.done`) : une unité par secteur lu
  — `pulse`, relectures servies par le cache comprises, puisque le
  répertoire les compte — et une unité par 512 octets qu'un fichier
  compressé produit (`loader.file.decompress`). Il **mesure** le total au
  répertoire avant les lectures qu'il couvre : `loader.file.measure`
  (secteurs du fichier, de ses link data, tranches de 512 octets s'il est
  compressé) et `loader.scene.measure` (la même marche que l'application
  d'une scène, `scene.apply` avec la mesure pour routine). `scene.load`
  mesure sa scène juste après avoir lu sa table ; `composition.load`
  mesure toutes les arrivantes AVANT la première lecture, si un hook
  écoute — une lecture de table par scène, relue par le chargement. Les
  lectures de tables ne sont ni comptées ni mesurées (`progress.mute`) :
  une unité comptée contre un total pas encore connu remplissait la barre
  d'un coup, vu.
- **L'API** : `loader.progress.hook.set` (table de saut 42, X = routine ou
  0) installe le hook et remet les compteurs à zéro. Le hook reçoit B = les
  unités ajoutées et X = les compteurs (mot fait, mot total), tourne sur la
  pile du loader et son DP, adressage étendu seulement, budget 2 000 cycles.
  Contrat dans `loader.const.asm`.
- **L'effet** : `engine/graphics/loadbar/loadbar.asm`, une barre BM16 en
  colonnes de quatre pixels, sans division — un accumulateur gagne
  unités × largeur, une colonne par dépassement du total, jamais en
  arrière. Mesuré : 27 cycles par secteur sans colonne, une colonne = 3
  lignes × 2 plans. Le bloc est **relogeable** (adressage relatif au PC),
  parce que le hook tourne pendant que la scène de boot recouvre l'unité
  qui l'a apporté (le moteur en est le premier fichier) : le splash le
  recopiait dans `loading.fx`, un `<reserved>` de 242 octets en page 1, et
  installait la copie. *Depuis le 08/09 (bilan §13) l'effet est assemblé
  dans le loader, après son code, et s'installe par `loader.loadbar.set`
  (X = ses sept paramètres) : plus de bloc réservé dans le layout.*
- **Le résultat** : sur le splash, la barre part à la première lecture et
  finit à 573 unités sur 584 (l'arrondi des tranches ZX0), sans à-coup
  entre la passe disque et la passe ZX0. Histogramme des écarts secteur
  inchangé (aucun secteur à 200 ms), title à la même trame (1000).
  `boot.entry` retire le hook avant de demander le title.

Coût sur le loader : 4 744 octets, soit 279 de plus que ce matin (cache,
`composition.set`, tables d'entrelacement, mesure et compteurs). Le loader
a dépassé les 18 secteurs de la piste 0 : `INDEX` passe du secteur 4 au 5
en face 1 dans `storage.xml`, et r-type décale `INDEX1` en 11 et `INDEX9`
en 15. Le tas du loader perd d'autant ; les bancs tiennent.

Le poids d'une tranche ZX0 : 512 octets à 14,5 Ko/s font 35 ms, un
secteur en fait 25 à 34 ; une unité pour chacun est juste à 10 % près, le
poids ne se retouche que si la machine donne d'autres temps. Reste
l'effet pour les transitions de stage, qui attend l'écran de chargement du
plan.

Coût mesuré au listing, par secteur lu : 77 cycles sans hook installé
(le compteur), 174 avec la barre quand aucune colonne n'est due, environ
350 quand une colonne l'est (une fois sur vingt unités) — sur les 12 500
du créneau. Mesure d'une scène : ~150 cycles par fichier, 6 ms pour les
42 de `scenes.boot`. Passe de mesure de `composition.load`, seulement si
un hook écoute : une lecture de table par scène arrivante, 25 à 200 ms
chacune. Code : +105 octets de loader, autant de tas en moins ; l'effet,
100 octets, hors du loader.

## 11. Le tampon de répertoire redevient un bloc du tas (07/09, nuit)

Décision auteur : un loader générique n'a pas de tampon statique. Le
tampon de répertoire, statique depuis le 15/08 après un gel du game over
imputé à la fragmentation, est de nouveau **alloué par TLSF à la taille
exacte du répertoire lu** : `dir.load` le **redimensionne sur place** par
`tlsf.realloc` quand un autre répertoire le remplace (un rétrécissement
garde sa place, une croissance dans la queue qu'il a laissée aussi : le
répertoire ne se promène pas dans le pool), et `loader.dir.unload` (table
de saut 45) le rend pour de bon à qui veut la place entre deux
chargements. Le pool TLSF reprend la totalité du tas du loader. Une
allocation qui échoue passe par le callback d'erreur dans le bloc de log
— un diagnostic, plus un gel muet.

Deux essais ont réglé le geste. Libérer puis réallouer laissait le tampon
se promener au gré des trous : loader-ut le voyait au milieu du pool.
Et le rendre en fin de convergence, comme je l'avais d'abord fait, était
faux : un chargement direct par `scene.load` qui suit une convergence
lisait ses entrées à l'adresse zéro (T18, « plus de mémoire » avec 2 734
octets libres — le parcours du pool ajouté au harnais l'a montré). Le
tampon reste ; le gain est pendant les convergences, pas entre elles.

Le gel du 14/08 s'explique très probablement par le bug de `realloc`
corrigé ce jour (§3, `tlsf-realloc.asm`) : l'index de lien grandit par
realloc au premier stage, un slot revenait rempli d'un en-tête de bloc
libre, et au game over la convergence libérait ces faux pointeurs — un
tas corrompu ressemble en tout point à un tas fragmenté, et à l'époque
personne n'a lu l'index.

**Ce que ça rend.** Le tampon statique gardait 1 536 octets, la taille du
plus gros répertoire, en permanence. Or ce répertoire-là n'est vivant qu'à
l'amorçage, quand les link data pèsent 512 octets ; pendant un stage le
répertoire courant fait 512 à 1 024 octets et les link data culminent à
1 140. Les deux maximums ne coïncident jamais.

**Ce que ça exige : l'ordre des tailles.** Un répertoire monté au milieu
d'une convergence, après les link data du stage, doit tenir dans le trou
du répertoire qu'il remplace. Le premier essai l'a démontré : `rtype_bench`
et loader-ut ont piégé une erreur TLSF ($8101) au passage du répertoire du
stage 1 (4 secteurs) à celui des lots, qui était le 0 (6 secteurs, 1 536
octets contigus introuvables). D'où la **scission du répertoire 0** : le
résident et `scenes.boot` restent dans le 0 (43 entrées, 4 secteurs) ; le
title et la bibliothèque d'ennemis partagée passent dans un **répertoire
10** (26 entrées, 2 secteurs, piste 79 face 1). Le plus gros répertoire
fait 4 secteurs, celui des lots 2 : il tient toujours dans le trou. Le
title coûte un changement de répertoire de plus, deux secteurs, une fois
par partie. Le banc du classement reprend le répertoire 9 renuméroté 1
(les ids doivent se suivre) et loader-ut gagne les 16 octets d'en-tête
TLSF que son tampon coûte désormais dans son pool.

Résultat : loader-ut 17/17 + T18, rtype_bench 7/7 — dont les convergences
stage → lots → stage suivant, celles qui échouaient sans la scission.

**Et deux bugs de plus dans le realloc**, réveillés par le tampon de
répertoire qui grandit de 512 à 1 024 octets sur place : la croissance
sans découpage écrivait la taille entière au lieu de taille − 1 (un bloc
un octet trop long, la chaîne du pool dérive), et ne réécrivait pas le
`prev.phys` du bloc suivant (le `free` de ce bloc remontait dans des
données). La sonde qui l'a trouvé, `c1/catch6.py` du scratch, vérifie la
chaîne physique du pool toutes les deux trames pendant une convergence ;
son parcours du pool est désormais dans le harnais loader-ut, affiché sur
tout échec. Ce sont les troisième et quatrième bugs de `tlsf-realloc.asm`
de la journée : le realloc n'avait jamais servi avant l'index de lien, et
sa croissance sur place jamais avant le répertoire.

**Bilan du tampon dynamique.** loader-ut 17/17 + T18, rtype_bench 7/7,
le banc du classement cinq tours de game over sans erreur TLSF et avec
une chaîne de pool intacte à chaque tour — le scénario du gel du 14/08,
vérifié cette fois en lisant le tas. Le tas : pool de 3 448 octets tout
entier ; à l'état stage 1, répertoire des lots compris (512), la marge
est de l'ordre de 800 octets. Touche B → title sous toje : trame 1100,
contre 1020 avant, l'écart étant du même ordre que les décrochages
moteur de 0,4 s du §8, qui tombent ailleurs dès que la chronologie bouge
(le répertoire 0 est passé de six à quatre secteurs, le title en lit deux
de plus). Le loader fait 4 797 octets.

## 12. Les répertoires sur la route de la tête (08/09)

La position des répertoires interpellait l'auteur : le loader relit un
répertoire à chaque scène qui arrive d'un autre répertoire ou qui en part,
la table d'une scène et les données de lien de ses fichiers à chaque
scène — et tout cela vivait ailleurs que les données. Piste 0 pour les
répertoires 0, 1, 9 ; piste 79 pour les répertoires des stages et de la
bibliothèque ; piste 1 pour les tables (`SCENE`), piste 2 pour les liens
(`LINK`) ; les données à partir de la piste 8. Un chargement de stage
était donc : piste 79 (répertoire), piste 1 (table), pistes 20-30
(données), piste 2 (liens) — puis la même chose pour chaque lot, avec le
répertoire 10 en piste 79 entre deux.

**Le modèle.** Pour le voir, le builder simule désormais le parcours de la
tête (`report/HeadPath.java`, onglet *Parcours* de la page d'occupation,
et `seek-report-<cible>.txt` en texte) : pour chaque état déclaré, convergé
depuis le précédent dans l'ordre de déclaration, chaque lecture du loader
dans son ordre (`composition.load` : les partantes, puis pour chaque
arrivante son répertoire s'il n'est pas monté, sa table, les données de ses
fichiers dans l'ordre de la table, puis leurs liens), secteur par secteur,
avec le créneau physique de chaque secteur tiré de l'entrelacement même
qui écrit l'image. Le coût : un déplacement = `pistes × pas +
stabilisation` (4 ms et 25 ms par défaut, à calibrer sur machine), un
changement de face gratuit, le disque qui continue de tourner pendant
tout (un déplacement plus long que le skew perd un tour, comme sur la
machine), un secteur lu quand son créneau passe, le cache `ptsec` modélisé.
Cinq paramètres modifiables sur la page, les totaux suivent. Un tour
« perdu » est une attente de plus d'un demi-tour sur une tête qui n'a pas
bougé ; après un déplacement c'est de la latence, la phase est quelconque.

**Ce que ça mesurait, disposition d'avant** (défauts du modèle) :

| passage | temps | dont déplacements | pistes parcourues |
|---|---|---|---|
| amorçage → title (4 états) | 10,2 s | 1,5 s | 242 |
| title → stage 1 | 15,4 s | 2,4 s (33 déplacements) | 392 |
| stage 1 → stage 2 | 12,4 s | 2,4 s | 471 |
| stage 4 → stage 5 | 8,2 s | 3,8 s | 832 |
| stage 5 → stage 6 | 7,3 s | 3,9 s | 872 |
| chaîne complète | 90,1 s | | |

Sur les petits stages la tête passe **la moitié du temps à se déplacer**.

**L'option.** `<directory colocate="true">` : le répertoire est écrit dans
sa section juste AVANT ce qu'il liste — ses secteurs réservés au curseur
quand ses entrées sont complètes (leur taille ne dépend pas des
emplacements), le contenu écrit derrière dans l'ordre de lecture du loader
(la table d'une scène, les données de ses fichiers, puis leurs liens — cet
ordre d'écriture vaut pour tous les builds, il ne change rien quand les
sections sont distinctes, vérifié à l'octet sur r-type et loader-ut), le
répertoire écrit en dernier dans ses secteurs réservés. Les tables de
scènes et les données de lien passent dans la même section. r-type n'a plus
qu'une section, `DATA` en piste 1 (les pistes 1-7 de `SCENE` et `LINK` sont
rendues), onze répertoires colocalisés.

La difficulté : la table des emplacements est **dans le loader**, assemblé
avant que les répertoires soient émis — et l'emplacement d'un répertoire
colocalisé n'est connu qu'à son émission. Réponse : `locations.asm` est un
registre (`ctx.dirLocations`) réécrit à chaque émission ; une ligne non
résolue s'écrit `ERROR directory N is colocated and not emitted yet…`, donc
un `<data>` du loader déclaré avant les répertoires échoue à l'assemblage
en nommant le coupable. Toutes les configs du corpus déclarent le loader
après. Le cache de build suit les INCLUDE (`hashTree`) : le loader se
réassemble quand la table change.

**Ce que ça donne, même modèle :**

| passage | temps | dont déplacements | pistes parcourues |
|---|---|---|---|
| amorçage → title | 7,6 s | 0,3 s | 10 |
| title → stage 1 | 12,4 s | 0,7 s (19 déplacements) | 47 |
| stage 1 → stage 2 | 10,6 s | 0,6 s | 44 |
| stage 4 → stage 5 | 5,5 s | 1,0 s | 158 |
| stage 5 → stage 6 | 4,2 s | 1,0 s | 166 |
| chaîne complète | 63,7 s | | |

Ce qui reste de déplacements, c'est la structure : les lots partagés
(bibliothèque d'ennemis, répertoire 10 en piste 9) que chaque stage
recharge depuis son propre bout de disque. Sous toje, l'amorçage arrive au
title à la **trame 952** (19,0 s) contre 1100 la veille — 3 s de mieux, le
modèle en prédisait 2,6.

Le banc du classement (`bench/ranking/gen-config.py`) suit : une section,
répertoires colocalisés copiés avec leurs lignes. Le corpus des autres
configs est identique à l'octet (aucune n'utilise `colocate`, et le
réordonnancement d'écriture n'y change rien).

## 13. Le realloc sort du loader (08/09)

*(Voir aussi le bilan de place, `bilan-loader-8ko-2026-09.md`, dont les
mesures 1, 6 et 7 sont faites : TLSF à 4 classes, tampons dimensionnés
par le builder, et le total de la barre écrit par le builder dans
l'entrée de répertoire de chaque scène — la mesure du §10 est remplacée.)*

Le bilan de place de la demi-page (`bilan-loader-8ko-2026-09.md`) a
montré ce que le tampon dynamique du §11 coûtait : 522 octets de
`realloc` et `memcpy` pour rendre 512 octets de pool dans les seuls états
dont le répertoire est petit. Décision auteur : les deux blocs que le
loader garde — le tampon de répertoire et l'index de lien — sont alloués
une fois, à des tailles que le builder calcule (le plus gros répertoire
de la cible ; le plus grand nombre de fichiers porteurs de link data
qu'un état déclaré indexe, 24 pour r-type, `<define>` pour un banc qui
charge à la main). Rien ne change au runtime : mêmes lectures, mêmes
répertoires montés aux mêmes moments ; ce qui disparaît, c'est la copie
et le découpage de blocs, et la contrainte « un répertoire monté en
pleine convergence doit tenir dans le trou du précédent ». Loader 4 817
→ 4 264 octets, pool 3 375 → 3 928, marge à l'état stage 1 ~1 000 →
~1 560 octets. Validé : loader-ut 17/17 + T18, rtype_bench 7/7.

