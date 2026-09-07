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
