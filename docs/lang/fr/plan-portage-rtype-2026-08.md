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
- l'arbitrage §24 (modèle de numérotation des objets : résident figé /
  clusters / local libre) — à trancher AVANT le cast du stage 2 ;
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

## 4. Ce que ce plan ne couvre pas

Le pipeline « projet de jeu » au-delà de ce que le modèle cible a déjà
donné (les tables s'écrivent en asm — décision actée), le renommage de
l'engine (phase finale post-jeux), MO6 pour r-type (TO8 d'abord), et
les média cartouche (backlog).
