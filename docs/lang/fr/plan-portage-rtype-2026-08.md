---
date: 2026-08-13
sujet: Plan de portage du jeu R-Type — du banc d'échange au jeu complet.
  Inventaire mesuré de l'état, ordre des chantiers, spec du title.
statut: plan actif ; l'inventaire est la mesure du 13/08, chaque chantier
  clos portera son annotation de preuve.
s'appuie sur: plan-migration-cible-2026-08.md (campagne close),
  analyse-frontiere-stage-2026-08.md, .claude/skills/v1-migration/SKILL.md
---

# Portage R-Type — le plan

## 1. L'état mesuré (13/08/2026)

**Ce qui tourne, prouvé sous toje** : banc 5/5 — boot → stage 1 complet
(132 colonnes, art réel, caméra à la borne) → stage 2 → retour stage 1,
état persistant, checkpoint sans disque. Musique YMM + soundFX sous IRQ,
collisions AABB + terrain, le joueur tire, les ennemis meurent.

**Le cast** (diff contre `game-mode/01/main.d7.properties` de la v1) :

- v1 mode 01 : 54 objets ; v2 : 45 ObjID (29 communs + 16 stage 1),
  zéro objet v2 sans équivalent v1 ;
- les 9 « manquants » sont les objets-artifice de la v1 (paginés en tant
  qu'objets faute de mieux — cas `main-private-object.md`) : `hud`,
  `mainext`, `checkpoint`, `levelinit`, `levelwave`, `mask`, `soundfx`,
  `starfield`, `ymm01` — tous résolus en v2 (unités et routines
  résidentes, câblées et chargées) ;
- les 10 ennemis du niveau 1 ont leur dossier, leurs fichiers et leurs
  entrées de tables : pata-pata, bug, bink, scant(+fire), p-staff,
  cancer, blaster, shell(+eraser), tabrok(+canon), et Dobkeratops
  entier (mâchoire, scie, monstre, queue, explosion, 4 bandes de
  nettoyage) ; la wave est la donnée arcade complète ;
- chaîne d'armes complète : force pod et ses trois tirs, bit device,
  option box, beams, missiles.

**Ce qui manque pour un R-Type minimal** :

1. le **title** (game mode 00) : sources présentes (`src/title/` —
   main 849 l. copie v1, logo, text, push_button, scores, musiques),
   zéro câblage config ; sa musique joue DEUX flux (ymm00 + vgc00) et
   le **player VGC est migré mais débranché** ;
2. le **flow de jeu** : le main actuel est le banc (`stage-main.asm`,
   verdicts + `invincible` + sondes dev) ; vies, game over, restart,
   continue, écran de chargement (`flow/loading` a ses sources),
   `v1-main.asm` gardé en référence ;
3. **stage 2 jouable** : données là, cast à porter (tables = 4 ObjID +
   bouchons) ;
4. relevés : `player/pending.stub.asm`, boss-follow terrain jamais
   exercé, stages 3-8 = données seules.

**Dettes enregistrées à solder pendant ce portage** :

- les 14 divergences `check_variants` (variantes de sprites v1↔v2) — à
  arbitrer ennemi par ennemi au moment où on le porte ;
- ~~l'arbitrage §24 (modèle de numérotation des objets : résident figé /
  clusters / local libre) — à trancher AVANT le cast du stage 2~~ —
  **RENDU le 14/08**, voir « Modèle de numérotation ACTÉ » plus bas ;
- les études ouvertes : normalisation `$`, nomenclature.

## 2. L'ordre des chantiers

1. **Title + flow** — transforme le banc en jeu (spec §3 ci-dessous) ;
2. **Dé-banc-ification du stage 1** — retirer `invincible`, les sondes,
   le main de banc → vrai main (v1-main comme référence) ;
3. **Stage 2 jouable** — cast porté, arbitrage §24 rendu au passage ;
4. **Stages suivants** au fil de l'eau (données déjà en place).

Méthode inchangée : import v1 en 1:1 (skill v1-migration, manifest),
preuve par le banc toje étendu à chaque chantier, identité binaire
partout où le mécanisme le permet, un cas de migration écrit dans le
commit qui le résout.

## 3. La spec du title

**Ce que fait le title v1** (lu dans `game-mode/00/main.asm`, 849 l.) :
7 objets (`fade`, `logo`, `push_button`, `scores`, `text`, `vgc00`,
`ymm00`), la boucle moteur standard (RunObjects/sprites/WaitVBL/
ReadJoypads/PalUpdateNow — tout est migré), une animation de logo par
phases, la musique à la phase 5, et la sortie par la chaîne LoadGameMode
(title → loading → level01).

**Les places** :

- le title ne coexiste JAMAIS avec un stage : son arène se déclare sur
  les pages des tuiles ($18-$1F) — des alternatives, exactement comme
  stage1.gfx/stage2.gfx entre eux ;
- **colocalisation VGC** : comme YMM, `_vgc.frame.play` tourne sous IRQ
  et ne monte qu'une page → le player et SES données partagent une page.
  Tailles mesurées : player ≈ 2,7 Ko (budget du modèle sound), données
  title 343 o, niveau 1 1 292 o, boss 609 o — le tout tient largement
  dans une page de title, et la décision pour le flux vgc du STAGE
  (fenêtre $1A trop courte de ~450 o pour le player) est découplée :
  elle se prendra au chantier 2 ;
- l'ancienne place commentée (`vgc.* page $19`) est morte : $19 est aux
  arènes de tuiles.

**Le flow** : boot → `scenes.title` (commun résident + fichiers title) ;
appui start → `scene.unload(title)`, `scene.load(stage1)`, saut sur le
stage — le mécanisme exact du banc d'échange, déjà validé 5/5. L'écran
de chargement v1 (`flow/loading`) s'insérera au chantier 2 ; le title
sort d'abord DIRECTEMENT sur le stage 1.

**Étapes, chacune prouvée** :

- T1 — le squelette : unité `title.main` (main v1 adapté : entrée
  d'unité, tables ObjID title en asm, équates RAM, palette), fichiers
  gfxcomp du logo/text/push_button/scores, scène `scenes.title`,
  chargée par un define de dev (le boot du banc reste par défaut).
  Preuve : build vert, banc r-type 5/5 inchangé sur les images
  annoncées, logo à l'écran sous toje ;

  **RÉALISÉ (13/08/2026)** en trois pas. T1a : graphismes (logo en
  collection de premier niveau — 21,8 Ko, coupé en 2 morceaux d'arène
  sur $18/$19 —, push_button et scores), arène `title` déclarée en
  alternative des tuiles de stage. T1b : unité squelette (entrée
  `stage.main` — le nom de fichier `title.main` en équate interdit un
  label homonyme —, 5 tables exportées, bouchons). T1c : les phases 0-4
  de l'attract v1 adaptées 1:1 sur le moteur résident (verrou gfxlock,
  imageset `titlelogo`, palette par png2pal du PNG du logo), l'objet
  logo intégré à l'unité. Le logo s'anime et tient à l'écran sous toje,
  vérifié par captures ET par diff des deux parités de tampon (zéro
  octet d'écart). Deux leçons payées : une ligne d'index oubliée sur
  `logo.Object` (l'objet monté ne fait RIEN — pas de plantage, l'index
  bouchonné est silencieux), et la répétition du cas
  `relative-toggles-on-shared-registers.md` — l'effacement d'ouverture
  fait avant toute pose de fenêtre données a effacé la page du loader
  et laissé un octet de boot en pixel fantôme (le cas est enrichi de ce
  symptôme « un octet »). Restent T2-T4.
- T2 — la musique : `engine.sound.vgc` + `title.music.ymm/vgc`
  colocalisés dans l'arène title, `resetym`/`resetsn` au démarrage.
  Preuve : données musicales relues en RAM, player vivant ;

  **RÉALISÉ (13/08/2026).** Les deux flux de la v1, chacun à sa place :
  les données YMM (`title.music.ymm`) vont avec le lecteur résident —
  donc en $1A/$20BC, l'alternative du bloc musical des stages, comme
  les graphismes du title occupent les pages des tuiles ; le VGC
  (`title.sound.vgc`) est rebranché pour son premier consommateur v2 —
  lecteur, tampons et données dans UN direntry coulé dans l'arène
  title, la colocalisation exigée par le montage unique sous IRQ est
  structurelle (un direntry tient sur une page). Le port SN passe par
  le lien (`engine.sound.sn.const`, variante 2 comme le modèle sound).
  Les resets v1 (`resetsn`/`resetym`) deviennent les init des lecteurs
  (`_sn76489.init`/`_ym2413.init`, dialecte kept-v2) au démarrage ;
  l'armement garde le moment ET le masque IRQ de la v1 (phase 5,
  l'arrêt du logo) ; l'IRQ joue une trame de chaque flux. Les sons
  sont cuits statiquement (fournisseur unique à destination connue —
  zéro coût de lien). Preuve sous toje : les deux blocs de données
  relus en RAM identiques aux sources octet pour octet, YMM vivant
  (`data.pos` avance, status=1, boucle), VGC vivant (58 octets d'état
  de flux changent en 37 trames, finished=0, loop=1), banc 5/5,
  corpus 59 images hors r-type identiques. Leçon de sonde : un
  échantillonnage à période fixe peut tomber sur la période de boucle
  d'un morceau court, et l'état du VGC vit dans les opérandes
  auto-modifiées, pas dans ses variables déclarées — diffuser large
  avant de conclure « gelé ». Restent T3-T4.
- T3 — la bascule : press start sous toje (injection clavier) →
  stage 1 tourne (caméra avance), et retour au title à la mort finale
  quand le flow du chantier 2 arrivera. Preuve : scénario complet
  title → stage 1 sous toje, banc 5/5 conservé ;

  **RÉALISÉ (13/08/2026).** La sortie du title est la séquence
  LaunchGame de la v1 (palette au noir, IRQ coupée, puces au silence)
  suivie du geste v2 de `stage.gameOver` : `game.stage` à zéro (une
  entrée depuis le title est une première entrée — vies et score
  resemés), `game.stage.unload` de SA scène, `game.stage.switch` vers
  `scenes.stage1` — le mécanisme du banc, déjà validé 5/5, sans une
  ligne nouvelle côté moteur. `scenes.stage1` recharge désormais
  `stage1.music.ymm` (le title a pris ses octets — alternatives en
  $1A/$20BC) : dédup-idempotent depuis le boot ou le stage 2, et c'est
  ce qui rend sa musique au stage en venant du title. Le déclencheur :
  la manette d'abord (v1 : `Fire_Press`), PLUS le bit KTEST du PIA
  avec son propre front (l'idiome du modèle sound, style R-Type) —
  découverte au passage : sans extension manette le port joypad se lit
  tout « tenu » (vécu sous toje), l'injection clavier de
  `joypad.readKbd` tombe dans un bit déjà à 1 et l'arête ne vient
  jamais ; le bit matériel, lui, fait front. Preuve sous toje :
  scénario complet title (logo tenu, musiques armées) → appui touche →
  stage 1 vivant — `bench.magic` $CA, stage 01, caméra 12→68 en 300
  trames (la vitesse R-Type), musique du stage 1 relue en RAM à la
  place de celle du title ; banc 5/5 conservé sur le boot par défaut.
  Reste T4.
- T4 — le boot par défaut passe au title, le banc reste accessible par
  define.

  **RÉALISÉ (13/08/2026)**, avec deux écarts au libellé, tous deux
  dans le sens du jeu réel. (1) Déclencheur élargi (demande auteur) :
  boutons A et B des DEUX ports manette (`joypad.x.A+joypad.x.B`), le
  clavier passant par le test intégré de `joypad.readKbd` (bouton B du
  port 0) plus le front KTEST posé en T3. (2) Pas de « boot banc par
  define » : le contenu d'une scène n'est pas conditionnel côté
  builder, et un second boot dupliquerait la liste stage 1 — le banc
  TRAVERSE le title à la place (son harnais presse une touche jusqu'à
  la levée du magic $CA) : une seule image, une seule vérité, et la
  chaîne d'attract est couverte par la même lane. `scenes.boot` charge
  le commun + les fichiers title et s'exécute sur le title ;
  `scenes.stage1` porte désormais le stage 1 ENTIER (cast, ouverture,
  plans, wave, collision, musique, main) — chargé au press start et
  aux retours, rechargements dédup-idempotents. Preuve : banc r-type
  5/5 à travers le title (passation mesurée), corpus 59 images hors
  r-type identiques.

**Pièges attendus** (du recueil de cas) : entrée d'unité à l'offset
zéro, `fill` v1 → équates, `setdp` interdit, pont `irq.on/off`
PRÉSERVANT (l'equ nu a mordu deux fois), coordonnées écran, palette du
game mode et non de l'art, `_gfxmode.setBM16` obligatoire.

## 3bis. La spec du chantier 2 — dé-banc-ification (13/08/2026)

**La mesure d'abord.** Le « main de banc » n'existe pas : la structure
réelle est en place (séquence endstage du niveau 1 — musique de boss par
marqueur de wave, bandes noires, jingle, autopilote, compte à rebours
d'arcade —, mort/READY/checkpoint, game over). Le banc vit dans QUATRE
endroits précis : les verdicts t1-t5 et le scénario forcé des deux
`stage.handOver` (aller simple + boucle infinie au retour), la
destination du game over (stage 1, V2-DEVIATION d'avant-title), la
graine de score de test ($1234), et le harnais de la lane qui lit ces
verdicts. Il n'y a pas de define `invincible` : le vaisseau du banc
survit parce que son tir continu (port flottant) fauche tout.

**Les gestes** :

- D1 — game over → **title** (le geste v1 restauré, la déviation
  documentée tombe) ;
- D2 — `handOver` du stage 1 : la séquence de fin décide, l'échange
  part sur le stage 2, sans verdicts ni second passage ni boucle ;
- D3 — `handOver` du stage 2 : retour au **title** (fin de la
  campagne à deux stages — la v1 enchaînait sur le niveau 3, non
  porté ; re-arbitrable au chantier 3) ;
- D4 — la graine de score passe à 0 (celle de la v1) ; les témoins
  (magic/stage/frames/camera/spawns) RESTENT — c'est la fenêtre
  d'observation de la lane, pas du banc — et le title s'y inscrit
  (magic + stage 0) : « qui tourne » devient observable de bout en
  bout ;
- D5 — la lane dérive ses cinq contrôles de l'état observable, plus
  aucun drapeau côté jeu : passation title→stage 1, progression
  caméra, bascule stage 01→02 par la vraie séquence de fin, bouchons
  du stage 2 exécutés (la preuve du re-link, ex-t2), retour au title
  (stage 00 + magic).

**Différé, à vérifier empiriquement** : la couverture du chemin de
mort par la lane (le vaisseau du banc ne meurt jamais — son tir
continu nettoie l'écran avant tout contact) ; l'écran de chargement
v1 (`flow/loading`) ; text/scores/push_button du title. Le banc
d'échange synthétique à deux stages reste disponible dans l'histoire
git si un besoin de re-couverture fine apparaît.

**text/scores/push_button RÉALISÉS (13/08/2026)** — l'attract v1
COMPLET tourne : trois unités paginées de l'arène title (le motif des
ennemis — export préfixé, INCLUDE du v1 tel quel, alias `Img_`),
atteintes par l'index d'objets ; la machine à écrire dessine en absolu
dans la fenêtre données et REDESSINE tout à chaque trame — compatible
double-tampon par construction ; le script d'animation du push_button
vient des properties v1 (durée avant l'étiquette). Le main porte les
phases 5-9 : frappe du texte, PUSH FIRE BUTTON, puis la boucle
d'attract extinction → tableau des scores → logo + texte rapide. La
palette des scores sort de png2pal sur 00.png (le geste v1 :
number_01.png) ; `Pal_game` v1 EST `Pal_title` (même PNG source).
L'arène title gagne la page $1B (l'attract complet dépasse 32 Ko) — le
contrôle de scène du builder a rejeté ma première page candidate ($06,
prise par l'arène commune) : le filet a payé. Preuves : RANKING et
écran complet (BLAST OFF… / PUSH FIRE BUTTON / FREE PLAY / © IREM)
vérifiés en captures, la boucle cycle, lane C1..C5 5/5 (départ pris en
pleine frappe : le déclencheur vit dans toutes les phases), corpus 59
images hors r-type identiques. Le fade v1 reste non porté (écran de
chargement, différé).

**Écran de chargement RÉALISÉ (13/08/2026)** — la v1 en faisait un
game mode entier (image épinglée sur la page visible pendant que son
loader saccageait l'autre) ; le loader v2 n'écrit pas dans les tampons
vidéo, un OBJET suffit : `title.loading` (unité paginée, motif ennemi,
image gfxcomp + `Pal_loading` par png2pal), dessiné par
`title.launchGame` dans les deux tampons après nettoyage, palette
rallumée — l'image reste visible pendant tout le `scene.load` synchrone
jusqu'à l'effacement d'ouverture du stage. Deux leçons payées : le
créneau d'échange fait 2010 octets UTILES ($8000-$87DA, la base du pool
d'objets est fixe) — title.main à 2037 octets a fait déborder ses
tables d'index SUR le pool, premier OST monté = tables écrasées =
saut sauvage (le builder n'a PAS de contrôle fichier-vs-reserved :
manque relevé) ; factorisation des quatre blocs d'effacement en
`title.clearBuffers` → 1876 octets. Et un DÉFAUT PRÉEXISTANT isolé au
passage : un appui unique à une trame précise (2300 au boot, image du
commit attract AUSSI) laisse le loader en attente FDC infinie dans le
moniteur (DP=$60, $E3xx) pendant l'échange — reproductible, la lane
(appuis répétés) ne le voit pas ; instruit le 14/08 : c'était le jar
toje périmé, voir « Gel FDC » plus bas. Preuves : écran LOADING (vaisseau + « LOADING... »)
vérifié en captures pendant le chargement, lane C1..C5 5/5, corpus 59
images hors r-type identiques.

**Couverture du chemin de mort RÉALISÉE (13/08/2026)** — le bloc
témoins gagne son pendant : une fenêtre de COMMANDE (`bench.request`,
bench.BLOCK+12), un octet que le harnais écrit et que `stage.loop`
consomme une fois par tour (7 cycles) — non nul = mort du joueur, le
geste exact de la fin d'explosion. C'est ce qui rend exerçable un
chemin de 467 octets qui ne tourne qu'à la mort : le vaisseau de la
lane ne meurt jamais (son tir continu fauche tout avant contact). La
lane passe à SEPT contrôles : mort → une vie perdue + caméra
rembobinée au checkpoint + retour RUNNING ; deux morts de plus → game
over → retour au TITLE ; press start → partie fraîche (vies ressemées
à 2) ; puis le tour complet stage 1 → stage 2 → title. Lane C1..C7
7/7 au premier passage (mort à caméra 1021 → reprise à 942), corpus
59 images hors r-type identiques. Limite documentée : la fenêtre
couvre la machine à états, pas la collision joueur-ennemi (le chemin
d'impact réel reste aux tests manuels).

**Gel FDC INSTRUIT ET RÉSOLU (14/08/2026)** — le « défaut
préexistant » relevé à l'écran de chargement n'était ni le jeu ni le
loader : c'était l'ÉMULATEUR. Le jar toje déployé (`teo-domain` du
09/08 dans `~/.m2`) était antérieur à un correctif déjà présent dans
les SOURCES de toje : dans `THMFC1.flushBus`, la position angulaire de
la disquette se calculait en multipliant le compteur de cycles brut
(non borné) par `trackSize*65536` — le produit déborde le 64 bits
signé après ~37 secondes de machine émulée (~1850 trames), la tête se
figeait et TOUTE lecture disque échouait ensuite. Le loader repartait
alors dans ses retries et son invite « I/O error » du moniteur —
invisibles pour la lane (headless + appuis répétés qui acquittent les
invites, exactement le masquage déjà noté). Le correctif source
(réduire la phase modulo la période de révolution AVANT la
multiplication) manquait juste au jar : `mvn -pl teo-domain clean
install` et vérification du bytecode (`lrem` présent dans `flushBus`).
Rien à changer dans le jeu, l'image commitée est saine. Preuves sur
l'émulateur reconstruit : boot SANS AUCUN appui jusqu'au titre vivant
(l'image de la couverture de mort ne bootait pas sans appuis sur le
jar périmé), attract déroulé au-delà des 37 s puis échange sur un
appui ISOLÉ (le scénario gelant exact), et lane C1..C7 7/7. Leçon,
même famille que « mesurer la référence » : quand la machine de test
elle-même est suspecte, vérifier que son BINAIRE porte bien les
correctifs de ses sources — un `git log` de l'outil ne prouve rien
sur le jar qui tourne.

**CŒUR RÉALISÉ (13/08/2026)** — D1 à D5 en un geste, prouvés
ensemble : lane **C1..C5 5/5 au premier passage** de l'image
dé-banc-ifiée — title → press start → stage 1 entier (1440 px, fin
par la vraie séquence endstage) → stage 2 sur ses propres données
(bouchons exécutés, la preuve du re-link) → retour au title, en
21 515 trames. Le vaisseau n'est pas mort du run, confirmant la
mesure : le chemin mort/READY/checkpoint/game-over reste hors-lane
pour l'instant. Corpus 59 images hors r-type identiques. Restent du
chantier : text/scores/push_button du title, l'écran de chargement,
et la décision de couverture du chemin de mort.

**Modèle de numérotation des objets ACTÉ (14/08/2026)** — l'arbitrage
§24, rendu sur MESURE avant le cast du stage 2. Les chiffres : le
game-mode 01 v1 complet déclare **55 ids** (source de vérité
`main.t2.properties`), qui se découpent selon la frontière v2 en ~31
communs (joueur 13, tirs/FX génériques 7, flow/HUD 10) et ~24
spécifiques au stage (infra 6, ennemis+tirs 12, Dobkeratops en 6
objets — le multiplicateur boss est réel). Côté arcade, les 8 waves
citent 46 types dédoublonnés sur les 51 slots de la table
(`re.arcade.r-type`, `data/routines.yaml` — le générateur de wave lit
désormais ce catalogue, commit 4276f7c de ce dépôt : 45 entrées
nommées sur 51 contre 16 avant). Le plafond : `RunObjects` monte l'id
dans B puis `aslb`+`abx` — **id ≤ 127**, au-delà le bit fort part dans
la retenue et l'index pointe ailleurs, silencieusement. Une
numérotation GLOBALE unique sur les 8 stages (~31 communs + 8×15-25
spécifiques ≈ 150-200) dépasse ce plafond : exclue d'office. Le modèle
acté est celui déjà en place dans les fichiers : **préfixe commun figé
(1..29) + spécifiques par ensemble co-chargeable à partir de 30,
réutilisés d'un ensemble à l'autre** (stage 1 à 45, stage 2 à 32,
title à 34 — le max attendu ~60 laisse deux fois la marge). Ce qui
manquait, ce sont les VERROUS, posés ce jour : `IFGE 30` sur
`objid.common.count` (un commun qui grossit collisionnerait le premier
spécifique de chaque ensemble) et `IFGT 127` sur `objid.count` de
chaque ensemble, avec l'instruction fautive citée en commentaire.
Les deux prouvés par cassage (le 213 de test aboutit à « Build
Aborted ! » depuis lwasm jusqu'au builder), image `to8.fd` inchangée
à l'octet après restauration — le verrou est purement compile-time.

**Chantier 3 OUVERT — squelettes du cast stage 2 (14/08/2026).** La
mesure d'ouverture a montré que « cast à porter » était mal nommé : la
v1 n'a AUCUN ennemi du stage 2 (`objects/enemies/` s'arrête au cast du
niveau 1 ; il ne reste que les équates de score et la wave extraite).
Le cast est donc à CRÉER depuis la référence arcade — pivot de méthode,
plus de 1:1 ni de manifest pour ces objets. Décision auteur : d'abord
des SQUELETTES — chaque objet de la wave a son unité, son id et ses
lignes de wave actives ; l'implémentation vide compte son spawn dans
les témoins puis se supprime (`UnloadObject_u`), le pool n'est jamais
bloqué. Réalisé : 5 unités (`src/enemies/{gouger,wick,brood,outslay,
gomander}/`, en-têtes portant le comportement bestiaire à implémenter,
la routine arcade — 1000:6f89/875d/7d68/915b/a22e — et l'entité
sprites du catalog), ids 33-37, 4×5 lignes d'index, 34 lignes de wave
dé-commentées (29 gouger, 1 wick, 2 brood, 1 outslay, 1 gomander —
`baldur` renommé `brood`, le nom du catalog), l'arène `stage1.enemies`
renommée `enemies` (elle cesse d'être propre au stage 1), 5 direntries
chargés par `scenes.stage2`. Le zoid (enfant de brood, jamais dans la
wave) viendra avec l'implémentation de brood. Restent du chantier :
les comportements réels ennemi par ennemi (fidélité à arbitrer au cas
par cas : bestiaire+observation d'abord, RE x86 si besoin), leurs
sprites depuis la ROM arcade via la chaîne gfxcomp, et le boss.

Le filet a payé À l'ouverture : la première image à squelettes gelait
la lane en C4 (game over → title), `tlsf.err=3` piégé dans le loader.
Bissection au worktree : l'état commité + 5 direntries TRIVIAUX
reproduit le gel à l'identique — le cast n'y était pour rien. La
cause : **le pool du loader fait 4060 octets** (`loader.ADDRESS-
memoryPool+$2000` — le commentaire « $307F » du config datait d'avant
le partage de la page 4 avec l'arène objects, corrigé), et le
RÉPERTOIRE y vit à demeure : une entrée = des slots de 8 octets
(principal + compression + linker), un fichier linkdata+zx0 en coûte
3 — l'image commitée était à 318 slots, un de moins que le seuil des
10 secteurs. +1 secteur de répertoire (256 o) = pool crevé au premier
échange qui tient deux scènes. Sortie immédiate : le cast en UN
direntry groupé (`cast.unit.asm`, exports fusionnés, chaque ennemi
garde son fichier source) SANS `linkdata` (tout est cuit — le banc de
pool l'a montré : zéro coût de lien) et `codec="none"` → 1 slot, le
répertoire revient à 10 secteurs. MARGE NULLE : le prochain fichier
refait déborder. Deux leviers structurels relevés pour la suite, par
ordre de rendement : (1) BUILDER — n'émettre les blocs compression/
linker que s'ils servent : **85 fichiers du disque paient un slot
linker pour zéro octet de lien** (mesure), soit ~85 slots rendus, le
format est déjà à blocs variables et l'assertion « ids réservés ==
blocs émis » verrouille — mais toutes les images du corpus changent ;
(2) LOADER — sortir le répertoire du pool (buffer fixe pris sur la
moitié arène de la page 4). À arbitrer avant le vrai cast.

**Répertoires partitionnés RÉALISÉS (14/08/2026)** — la spec
`analyse-repertoires-partitionnes-2026-08.md` (validée par l'auteur)
exécutée en trois commits. (1) BUILDER : la table des emplacements de
répertoires est générée depuis la configuration pure (une entrée par
`<directory>` : disquette physique, face, piste, secteur), chaque
scène gagne son equate `.dir`, et les entrées du média sont consommées
en fin de répertoire — corpus 63/63 identique à l'octet, r-type
reconstruit de zéro à l'ancien jar pour la contre-preuve. (2) LOADER :
les trois constantes DIR_DEFAULT_* remplacées par la table ; l'invite
« Insert disk » naît toujours du contrôle d'en-tête IDX+id, aucun état
nouveau — loader-ut 17/17 + T18 avec ses deux changements de
disquettes, collection 4/4, lane 7/7, les 62 images bootables changent
et la seule sans loader est identique. Leçon payée : la première table
était émise en DONNÉES avant l'org du loader — assemblée à l'adresse
0, hors du binaire brut, toutes les images bootaient dans le vide avec
un build vert ; c'est une MACRO désormais, invoquée dans la zone de
variables du loader. (3) R-TYPE : trois répertoires — n°0 commun+title
(5 secteurs, baseId 0), n°1 stage 1 entier (5 secteurs, baseId 130),
n°2 stage 2 (2 secteurs, baseId 281) — sections INDEX1/INDEX2 en face
1 de la piste 0 derrière le répertoire 0 rétréci (la piste 3 visée
d'abord était occupée : le contrôle d'occupation du média l'a refusée
au build — le filet de la preuve 8.5, rendu sans le provoquer) ;
`game.stage.switch` prend l'id de répertoire dans Y (la macro de
montage détruit A et B) et fait dir.load avant scene.load, les quatre
appelants passent l'equate `.dir` de leur cible. Découverte
structurante en chemin : les equates d'ids d'un répertoire nourrissent
des unités d'AUTRES répertoires (title→stage1→stage2→title, un cycle)
— la réservation des ids de TOUS les répertoires est donc partie dans
la pré-passe de placement (`DirectoryPlugin.reserve`, résultat dans
`ctx.dirReservations`, l'émission le relit), l'aboutissement du
mouvement du 09/08 « mesurer et ranger à la réservation ». Le pool du
loader ne porte plus que le répertoire courant : 1280 octets au pire
contre 2560, et un stage ajouté ne grossit que le sien.

Le filet a encore payé, et gros : la lane du build partitionné cassait
en C3 (mort → checkpoint), et l'instruction a déterré un bug LATENT
PRÉEXISTANT sans aucun rapport avec les répertoires. Après le premier
`DrawTiles`, `glb_Page` reste à zéro (mode spécial) et l'IRQ ne
restaure alors PAS la fenêtre cartouche ; le rejeu de la vague du
checkpoint (`ObjectWave_Init`) y marche pendant plus d'une trame —
l'interruption qui tombe au milieu laisse la page du SON montée, la
marche continue sur une page étrangère et le contenu de celle-ci
décide de la suite. Vécu, tracé au watchpoint : la vague est sortie de
la fenêtre ($2E68 → $8772), a semé des objets dans le bloc témoins
(magic $CA→$C8, culprit `std subtype_w,u` du spawner) et la machine
est partie dans le décor. Une ROULETTE de phase d'IRQ : la partition
n'a fait que déplacer le tirage — le build mono-répertoire gagnait par
chance de timing, données et layout parfaitement identiques des deux
côtés (prouvé par diff des pages en machine). La v1 n'a jamais eu le
problème : sa mort rechargeait tout le game mode et `checkpoint.load`
y tournait AVANT l'armement de l'IRQ ; l'entrée de stage v2 fait
pareil, seul le chemin de mort (checkpoint sans disque, main résident)
l'appelait IRQ allumée. Correctif fidèle v1 : IrqOff/IrqOn autour du
rechargement de checkpoint dans stage-main. Lane C1..C7 7/7.

**Stages 3-8 EN PLACE avec leurs tilemaps (14/08/2026)** — l'objet de
la demande, rendu possible par la partition. La réorganisation de
games/r-type portait déjà tout : cartes leanscroll (06 comprise),
waves v1 curées, musiques. Chaque stage suit le gabarit compact du
stage 2 : une arène `stageN.gfx` aux MÊMES pages que stage2.gfx (les
stages sont exclusifs à l'échange, jamais co-chargés), la chaîne
leanscroll → gfxcomp grid 12x12 → tilemap ND0, un main dérivé du 02
(STAGE_ID, scène, handOver vers le suivant — le 8 rend au title), un
index d'objets sans cast (count 32), et SON répertoire (2 secteurs,
sections INDEX3-8 sur la piste 79). Les waves gardent actives les
seules lignes des objets communs (pow/checkpoint/bossmusic) : les
lignes des ennemis de la bibliothèque (bink, patapata, cancer, bug,
pstaff, scant — 224 lignes) sont commentées en attendant le chantier
du cast par stage, décision auteur « implémentation plus tard,
tilemaps d'abord ». Le chaînage 1→2→…→8→title est réel (game.stage
porté de proche en proche). Au passage, le mystère de la piste 3
s'explique : la section LINK débordait déjà de sa piste 2 en silence,
et six stages de plus l'ont fait mordre DATA — refus du contrôle
d'occupation au build, DATA reculée à la piste 8 (LINK a les pistes
2-7). La lane étend C6/C7 au TOUR COMPLET : montée 2..8 suivie du
retour au title. Ce chantier ne touche ni builder ni engine — le
corpus hors r-type ne peut pas changer par construction.

Trois leçons payées pendant la validation. (1) Un « blocage au boot »
sur le build complet n'était PAS un défaut du chantier : un `gen/`
mélangé (restes d'un build précédent + `t.xml` périmé — le piège déjà
connu, frappé une troisième fois) fabriquait une image incohérente qui
plantait très loin de la cause. Un `rm -rf gen dist` + régénération de
`t.xml` juste avant le build a rendu une image saine du premier coup :
devant un symptôme absurde sur un build incrémental, prouver d'abord
le build PROPRE. (2) Un `git checkout --` de bissection avait annulé
en silence le handOver du stage 2 vers le stage 3 — la lane le voit
(top=2, retour au title), c'est exactement son travail. (3) La
dérivation des mains 03-08 depuis le 02 avait laissé les équates
`stage2.maps.page`/`stage2.wave.page` dans leur `stage.setup` : chaque
stage aurait monté les pages du stage 2 — dérivée d'un gabarit, une
copie se relit sur TOUTES ses références au modèle, pas seulement sur
les chemins et l'identifiant.

**La bibliothèque d'ennemis en LOTS (14/08/2026)** — décision auteur :
pas de duplication par stage, pas de « tout résident » — des lots taillés
au plus juste par la matrice arcade (routine×stage, 51 routines croisées
avec les 8 waves). Six lots (bink / patapata / cancer / bug+pstaff /
scant+scantfire / mid en squelette), données sur disque UNE fois dans le
répertoire commun, une scène par lot, un masque de bits par stage
(`cast.const.asm`) : la convergence résidente (`common.cast`, région
`cast` dans la marge de la page 1) décharge l'excédent et charge le
manquant à chaque échange — ce que deux stages consécutifs partagent
traverse sans relecture disque, et un retour au title décharge tout,
depuis n'importe quel stage. Les 240 lignes de waves des ennemis partagés
sont réactivées (03 : 5, 04 : 59, 05 : 17, 06 : 35, 07 : 124, dont mid
renommé depuis la routine 19) ; cyclingPalette ne sera jamais portée
(décision auteur). Le chantier a débusqué un défaut d'échange indépendant
des lots : la trame d'amorce de l'entrée de stage tournait sur le pool
résident encore peuplé des objets VIVANTS du stage sortant (la v1
rechargeait sa RAM objets à zéro ; le title v2 purgeait déjà) — purge
remontée avant la trame d'amorce dans stage-main. Lane tour complet 7/7,
stage 7 à ~530 spawns de bibliothèque, stage 8 à +0 exactement ; corpus
63/0, diff confiné aux 4 images r-type. Analyse et récit complets :
`analyse-lots-ennemis-2026-08.md`.

## 4. Ce que ce plan ne couvre pas

Le pipeline « projet de jeu » au-delà de ce que le modèle cible a déjà
donné (les tables s'écrivent en asm — décision actée), le renommage de
l'engine (phase finale post-jeux), MO6 pour r-type (TO8 d'abord), et
les média cartouche (backlog).
