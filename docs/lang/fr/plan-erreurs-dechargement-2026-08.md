---
date: 2026-08-07
sujet: Gestion d'erreurs moteur (trap + code normalisé), puis déchargement
       déclaré par scène — plan en six phases
statut: phase 1 IMPLÉMENTÉE le 2026-08-07 (lib engine/log/, traps migrés,
        layout corrigé) — phases 2-6 à l'étude
---

# Gestion d'erreurs et déchargement explicite — le plan

Deux chantiers liés. Le déclencheur est la décision de retirer le déchargement
implicite du loader (chargement à une destination occupée) au profit d'un
déchargement déclaré par le développeur, avec un **trap** à l'exécution si la
règle est violée. Mais un trap suppose un socle : aujourd'hui le moteur n'a
**aucun système d'erreurs commun**, et chaque incident l'a montré.

La phase 1 — le socle — se conçoit ici en entier, lib comprise. Les phases
suivantes reprennent les points actés en discussion (2026-08-07) et
s'appuient dessus.

## État des lieux : trois façons de mourir, toutes muettes

| Site | Mécanisme actuel | Défaut |
|---|---|---|
| `tlsf` (malloc) | `tlsf.err` (1 octet) + `tlsf.err.callback`, défaut = boucle infinie `tlsf.err.loop` | Silencieux. Vécu : écran noir d'une heure dont la cause était un pool plein — rien ne le disait |
| loader disque | `err` : message via PUTC moniteur + boucle ; `dskerr` : `jmp [$fffe]` (reset) | Fonctionne au boot seulement — en jeu, l'espace de travail moniteur ($6000-$60CC) est écrasé, PUTC n'est plus utilisable |
| `mub` (son) | codes de retour `mub.ERR_*` | Correct pour du non-fatal, mais convention locale au module |

Trois vocabulaires, aucun lisible de l'extérieur, aucun qui dise *quoi* et
*où*. Le banc d'échange de stages a montré la bonne direction — des témoins
écrits en RAM à adresse fixe, lus par l'émulateur — mais il est ad hoc.

---

# Phase 1 — la lib de log moteur (`engine/log/`)

## Objectifs

1. **Un seul geste** pour signaler une erreur fatale depuis n'importe quel
   code moteur ou jeu, quel que soit le contexte (page cartouche montée
   quelconque, IRQ actives ou non).
2. **Un code normalisé sur 2 octets** : l'octet haut identifie le domaine,
   l'octet bas la cause. Un registre central, pas de collisions.
3. **Des données** : le code seul ne suffit pas (« pool plein » — lequel ?
   quel fichier ? quelle destination ?).
4. **Diagnosticable des deux côtés** : depuis l'émulateur (MCP toje :
   breakpoint sur symbole, lecture mémoire non-intrusive) et sur machine
   réelle (signal visuel, sans dépendre du moniteur).

Non-objectifs : pas de reprise après erreur fatale (un trap est terminal),
pas d'affichage texte (le moniteur n'est pas fiable en jeu), pas de journal
multi-erreurs (la première suffit, c'est elle la cause racine).

## Le code d'erreur : `$DDCC`

```
octet haut DD = domaine          octet bas CC = cause, locale au domaine
$01  tlsf (allocateur)           reprend les 7 codes existants tels quels
$02  loader (fichiers, disque)
$03  scene (chargement/déchargement)
$04  objects (pool, index, RunObjects)
$05  sound
$06  gfx (gfxlock, scroll)
$0E  engine divers
$F0+ réservé au JEU (r-type ou autre) — le moteur n'y touche jamais
```

Registre unique : `engine/error/error.const.asm`. Équates de la forme
`err.tlsf.OUT_OF_MEMORY equ $0103`. La reprise des codes tlsf à l'identique
dans l'octet bas rend la migration mécanique et garde les habitudes
(`3 = out of memory` reste vrai, préfixé du domaine).

Règle de nommage : `err.<domaine>.<CAUSE>`. Le fichier est LA référence —
un code n'existe que s'il y est déclaré, avec un commentaire d'une ligne.

## La convention d'appel

```
; D = code d'erreur, X = pointeur sur les données (0 si aucune)
        jsr   error.raise            ; ne revient JAMAIS
```

Macro de confort :

```
 _error.raise err.scene.LOAD_OVERLAP,#trapdata
```

Pourquoi X pointe plutôt que de porter : les données utiles dépassent
souvent 2 octets (identifiant de fichier + destination + occupant = 6).
L'appelant les pose où il veut — souvent dans ses propres variables, déjà
écrites — et `error.raise` **copie** les 8 premiers octets dans le bloc
trap. La copie est essentielle : le pointeur peut viser une page cartouche,
illisible une fois le contexte perdu.

## Le bloc trap : RAM résidente, adresse fixe

Layout (15 octets — révisé le 2026-08-07 avec le système de sondes,
voir « Le système complet » plus bas : la classe fait office de magic,
et l'octet de libération est le canal de retour du superviseur) :

```
probe.class    fcb  ($00 = libre ; sinon la CLASSE de l'évènement — écrite
                     EN DERNIER : le bloc est complet quand elle apparaît,
                     c'est elle que le watchpoint surveille)
probe.code     fdb  (le code $DDCC)
probe.pc       fdb  (adresse de l'appel, dépilée par la sonde)
probe.page     fcb  (page cartouche montée au moment de l'appel, $E7E6)
probe.data     8×fcb (copie des données pointées par X)
probe.release  fcb  (écrit par le superviseur : libère une sonde bloquante)
```

`pc` et `page` valent de l'or : ensemble ils disent *qui* a appelé depuis
*quel* contexte — indispensable quand l'appelant est un objet paginé dont
l'adresse seule est ambiguë.

**Placement : $9EF0-$9EFF, 16 octets verrouillés sous la page directe.**
La cartographie réelle du haut de la page 1, relevée sur le code
(constants.asm : `dp equ $9F00`, `glb_system_stack equ dp`) :

```
$9E40-$9ECE  variables inter-main (globals, traînée du joueur comprise)
$9ECF-$9EFF  la PILE S, qui plonge depuis $9F00 (~49 octets de fond)
$9F00-$9FFF  la PAGE DIRECTE moteur (OST du joueur, dp_engine, glb_*)
```

Le `<reserved name="stack" $9F00>` du layout est donc **mal nommé** — cette
page est la DP, la pile vit sous elle, dans le haut du bloc `globals`, sans
être déclarée nulle part. La phase 1 corrige la carte : le réservé `$9F00`
devient `dp`, et deux réservés explicites apparaissent — `error.trap` en
`$9EF0-$9EFF` (16 octets : 14 utiles + 2 de réserve) et `stack` pour ce qui
reste sous lui. La pile est déplacée d'une équate :
`glb_system_stack equ dp-16` — un seul point d'init (`lds` du loader).

**Coût : 16 octets de fond de pile (49 → 33).** Tenable a priori — l'IRQ
n'empile que ses 12 octets d'état machine avant de basculer sur sa propre
pile temporaire (`lds #Irq_sys_stack`, Irq.asm:129) — mais c'est un budget
à MESURER, pas à croire : un témoin de crue (la zone pile peinte d'un
sentinelle au boot, le point bas relevé par l'émulateur) fait partie de la
lib. C'est le même service que le bloc trap, au même endroit, pour deux
octets de plus.

**L'alternative écartée : la zone moniteur $6031-$6037.** Ces sept octets —
les registres de la routine de notes de musique du BASIC, que le moteur
n'invoque jamais — sont déjà réquisitionnés par le loader comme scratch DP
de son décodeur zx0 (`ZX0_DP equ $6031`, avec la preuve d'innocuité en
commentaire). Trois raisons de ne pas y mettre le trap : sept octets quand
il en faut quatorze, et chaque octet gagné au-delà demanderait une nouvelle
preuve sur la ROM moniteur, par version de machine ; le partage avec le
scratch zx0 rend le bloc effaçable par tout chargement compressé dès que le
callback n'est pas `halt` (tests, banc) ; et la zone n'existe que tant que
le moniteur est celui qu'on croit — `$9EF0` est à nous par construction.

**Un piège découvert en cherchant la place.** `bench.magic` et ses témoins
occupent `GLOBAL_VARIABLES+13..+28` (bench.const.asm) tandis que
`player_pos_ring_buffer` — la traînée du joueur, 128 octets — est déclarée
**aussi** à `GLOBAL_VARIABLES+13` (variables.asm). Les deux fichiers
s'étendent l'un l'autre sans se voir. Les témoins écrits chaque trame
(bench.frames, bench.camera) corrompent la traînée que le force pod relit.
À corriger en préalable de la phase 1, et c'est l'argument pour la garde
ci-dessous.

**Garde d'assemblage.** Le bloc `globals` est rempli par deux fichiers en
équates manuelles, et rien ne vérifie ni les recouvrements internes ni le
débordement des $C0 octets. La lib ajoute un fichier de garde :

```
 IFGT globals.END-($9E40+$C0)     ; globals.END = premier octet libre,
   ERROR "bloc globals deborde"    ; maintenu par les déclarants
 ENDC
```

et le passage des équates dispersées à un chaînage `equ *`-style (chaque
symbole défini à partir du précédent) rend les recouvrements impossibles
par construction. C'est le même esprit que « les trois valeurs du pool
bougent ensemble », mais outillé cette fois.

## Le comportement : callback, défaut halt

```
error.callback   fdb  error.halt   ; remplaçable (tests unitaires, banc)
```

`error.raise` : `orcc #$50` (IRQ coupées — l'état ne doit plus bouger),
remplit le bloc trap, saute `[error.callback]`.

`error.halt` (défaut) :

1. **Bordure** : écrit `map.CF74021.SYS2` avec bit 7 = 1, bit 6 repris de
   `gfxlock.backBuffer.status` (ne pas basculer la page visible), bits 0-3 =
   couleur d'erreur. Alternance deux couleurs sur une boucle de temporisation
   — une bordure qui **clignote** ne peut pas être confondue avec un état de
   jeu, contrairement à une couleur fixe.
2. **Boucle infinie sur un label exporté** : `error.halt.loop bra
   error.halt.loop`. C'est le point d'ancrage émulateur.

## L'observabilité

**Émulateur (MCP toje)** : `load_symbols` connaît `error.halt.loop` et
`error.trap.magic`. Deux gestes suffisent : un breakpoint sur le label, ou
— sans breakpoint — lire l'octet magic périodiquement. Un outil de
diagnostic (skill ou commande) peut décoder le bloc entier : code, domaine
en clair, PC, page, données. Les tests d'intégration posent
`error.callback` sur leur propre routine pour transformer un trap en échec
de test propre au lieu d'un timeout.

**Machine réelle** : la bordure clignotante signale le trap. Le décodage
fin demande un débogueur — assumé : l'alternative (affichage texte) dépend
de ressources que le jeu a pu détruire, et un handler d'erreur qui peut
lui-même planter ne vaut rien. Le handler n'utilise que : la bordure
(un registre), le bloc trap (RAM réservée), sa boucle. Zéro dépendance.

## Implantation et budget

**Le système est COMMUN — les contraintes de place sont propres à chaque
jeu et se gèrent à part** (décision 2026-08-07). La lib se conçoit sans
compromis de design pour un budget particulier ; r-type décidera où loger
les 60-80 octets résidents (`error.raise` + `error.halt` doivent être dans
$6100-$9FFF, toujours mappé) le moment venu — pool, dégraissage, ou
ailleurs. Le fond de pile à 33 octets après le verrou `$9EF0` est jugé
suffisant pour tester (même décision) ; le témoin de crue le vérifiera.

---

## Le système complet — des SONDES dans le source

> **Décisions finales du 2026-08-07 — voir « Le modèle retenu » plus bas,
> qui est LA spécification.** Le système s'appelle `log.` ; il n'a que DEUX
> niveaux (info/error), la classe est le bit 15 du code, et une routine
> unique sert les deux. Les sections intermédiaires (quatre classes, clé,
> masque, release, données pointées) racontent le chemin — chaque pièce
> retirée l'a été pour une raison qui y est consignée.

Recadrage (2026-08-07, idées de Benoit structurées ici). Le besoin réel
n'est pas une boîte à commandes : c'est de **placer des points d'arrêt
DANS le code source**, et d'en finir avec le rituel actuel — ouvrir le
.lst, retrouver l'adresse de la ligne, deviner la page RAM montée, poser
un breakpoint ambigu. Le trap d'erreur et le breakpoint de débogage sont
LE MÊME GESTE : écrire un évènement identifié dans la zone normalisée.
Seule la *classe* change ce qui se passe ensuite.

### Le principe

Une **sonde** est un appel écrit dans le source :

```
        _probe.info  code[,#données]   ; écrit le bloc et REPART aussitôt
        _probe.warn  code[,#données]   ; idem, classe distincte
        _probe.break code[,#données]   ; écrit le bloc et ATTEND la libération
        _probe.error code[,#données]   ; écrit le bloc et se fige (fatal)
```

Le superviseur (Claude + plugin toje) ne pose **qu'un seul watchpoint,
une fois pour toutes** : sur l'écriture de `probe.class`, l'octet résident
écrit en dernier. Chaque sonde du programme — quelle que soit sa page,
quel que soit le fichier — déclenche ce watchpoint avec un bloc complet :
classe, code, PC de l'appelant, page montée, données. Plus de .lst, plus
d'adresses, plus d'ambiguïté de pagination : **le point d'arrêt
s'auto-identifie**.

La libération est le canal entrant, réduit à sa plus simple expression :
le superviseur écrit `probe.release`, la sonde bloquante rend la main au
PC appelant. Pas de boîte à commandes, pas de dispatch — un octet.

### Les deux sémantiques : supervisé et non supervisé

La subtilité qui rend le design cohérent : sous émulateur, le watchpoint
fige la machine à CHAQUE écriture de sonde, quelle que soit la classe.
Le comportement machine n'est donc que le **repli non supervisé** ; la
politique fine appartient au superviseur.

| classe | non supervisé (matériel réel, ou pas de watchpoint) | supervisé (watchpoint émulateur) |
|---|---|---|
| info  | écrit, repart — quelques cycles | machine figée : le superviseur logue et reprend, ou inspecte |
| warn  | idem | idem, politique distincte (compter, alerter) |
| break | **si la clé est armée** : attend `probe.release` ; sinon repart comme info | superviseur inspecte, écrit release, reprend |
| error | se fige : bordure clignotante, boucle sur label exporté | superviseur inspecte ; libération possible (bancs de test) mais terminal par défaut |

La règle de la clé règle le cas du `_probe.break` oublié dans un build
qui tourne sur machine réelle : sans superviseur (clé `probe.key` non
armée), il dégénère en info — le jeu ne gèle pas. La clé est écrite par
le pilote, jamais par le jeu : leçon de reserved-ram-is-not-zeroed, aucun
octet de contrôle n'est interprété sans elle.

### Ce que le superviseur voit et fait (outils MCP existants)

1. `load_symbols` → adresses de `probe.class` et du bloc.
2. `set_watchpoint` écriture sur `probe.class` — une fois.
3. `run_frames` ; l'émulateur s'arrête sur toute sonde.
4. `read_memory` du bloc : classe, code (décodé via le registre
   `error.const.asm`), PC, page, données. La machine est figée à un point
   **choisi par le développeur** — par construction un état cohérent, ce
   qu'un breakpoint d'adresse ne garantit jamais.
5. Selon la classe et la politique : reprendre ; ou `write_memory`
   release puis reprendre ; ou inspecter tout le reste de la machine.

Rien à construire côté plugin pour commencer — une skill d'habillage
(« surveille les sondes, logue les infos, arrête-toi sur break/error et
analyse ») viendra rendre le tour de main automatique.

### Filtrage : les bits de contrôle

Une sonde info dans une boucle chaude déclencherait le watchpoint à
chaque trame — coûteux sous émulateur. Le filtre est machine-côté, piloté
sans reconstruire : un octet `probe.mask` (quelles classes écrivent), posé
par le superviseur. Classe masquée = la sonde repart sans RIEN écrire —
le watchpoint ne voit rien. C'est le rôle des « bits de contrôle » :
`probe.key` (superviseur présent), `probe.mask` (classes actives),
`probe.release` (libération). Trois octets, tout le canal entrant.

### Concurrence et discipline

- La sonde masque les IRQ le temps d'écrire le bloc (une IRQ qui sonde au
  milieu d'une sonde le corromprait) ; une sonde bloquante les laisse
  masquées pendant l'attente — la machine est à l'arrêt, c'est cohérent.
- Première erreur gagnante : une classe error déjà posée n'est jamais
  réécrite — la cause racine est préservée. Les infos, elles, s'écrasent
  librement (sous watchpoint, le superviseur a lu avant la suivante).
- En release, les sondes info/warn/break se compilent à VIDE (`<define>`
  DEBUG) ; les sondes error RESTENT — ce sont les contrôles fatals, la
  raison d'être de la phase 1. Coût d'un site : ~9 octets (ldx/ldd/jsr).

### Ce qui change par rapport à l'esquisse « agent à commandes »

L'idée d'une boîte aux lettres à commandes (SPAWN, WARP, EXEC…) est
**remisée** : les sondes couvrent le besoin réel avec un mécanisme bien
plus petit, et une sonde bloquante donne déjà au superviseur une machine
figée à un point sûr — d'où il lit et écrit tout ce qu'il veut. Si un
besoin de commandes émerge (forcer un spawn sans reconstruire), il se
greffera sur la même zone, plus tard, comme couche séparée. Rien dans le
contrat ne l'interdit, rien ne l'exige aujourd'hui.

### Syntaxe et nomenclature — vérifié sur lwasm et sur le code (2026-08-07)

Test assemblé réellement (lwasm du dépôt, `--format=raw`) : les symboles
peuvent commencer par `_`, contenir des points, doubler l'underscore ;
les macros acceptent `_nom.pointé` ; `IFGE expr` assemble si expr ≥ 0 et
un bloc sous le niveau émet **zéro octet** (constaté au binaire près).
L'underscore n'a AUCUN sens spécial pour lwasm — c'est une pure
convention de ce dépôt, et elle est nette :

| forme | usage v2 constaté | pour la lib |
|---|---|---|
| `_nom.pointé` | MACROS natives v2 (`_ymm.frame.play`, `_palette.update`, `_random.a`) | `_probe.info`, `_probe.error` ✓ |
| `nom.pointé` | labels et routines (`gfxlock.bufferSwap.do`, `error.raise`) | `probe.raise`, `probe.class` ✓ |
| `nom.SEGMENT_FINAL` | constantes (`mub.ERR_NONE`, `endstage.STATUS_JINGLE`, `ymm.LOOP`) | `probe.class.ERROR`, `err.tlsf.OUT_OF_MEMORY` ✓ |
| `@nom`, `!`/`<`/`>` | labels locaux lwasm | usage interne lib |

Les macros v1 importées (`_MountObject`, `_Collision_AddAABB`) gardent
leur casse d'origine — la lib est du v2 natif, elle suit la première
ligne. Cohérence : acquise, rien à inventer.

### Activer, désactiver — le modèle à trois étages

Trois filtres, du plus tôt au plus tard, chacun avec son coût nul propre :

**Étage 1 — la compilation (`PROBE_LEVEL`).** Un ordre total sur les
classes, l'error au plancher parce qu'il n'est PAS du débogage :

```
probe.LEVEL.ERROR equ 0    ; toujours compilé — les contrôles fatals
probe.LEVEL.BREAK equ 1
probe.LEVEL.WARN  equ 2
probe.LEVEL.INFO  equ 3

 IFNDEF PROBE_LEVEL
PROBE_LEVEL equ 0          ; défaut : release, error seul
 ENDC

_probe.info MACRO           ; le site émet ZÉRO octet sous le niveau
 IFGE PROBE_LEVEL-probe.LEVEL.INFO
        ldx   #\2
        ldd   #\1
        jsr   probe.raise.info
 ENDC
 ENDM
```

Côté builder, c'est un attribut existant : `<define symbol="PROBE_LEVEL"
value="3"/>` (le `value` est déjà au contrat de l'élément, vérifié dans
Handlers.java:158). Un target de dev le pose, la release ne pose rien.

**Décision (2026-08-07) : les macros embarquent elles-mêmes leur garde.**
Le conditionnel vit DANS `_probe.*`, jamais au site d'appel — un site est
UNE ligne, identique en dev et en release, et la politique de niveaux
tient en un seul fichier (celui des macros). L'auteur n'écrit jamais un
IFDEF autour d'une sonde ; s'il en ressent le besoin, c'est que la lib a
un manque.
**La lib maigrit avec les sites** : les entrées `probe.raise.info/warn/
break` sont gardées par le même `IFGE` — une release ne lie que
`probe.raise.error` et son halt. Note d'écriture : une table de données
qui n'existe QUE pour une sonde se met sous la même garde, sinon elle
survit orpheline au site compilé à vide.

**Étage 2 — le runtime machine (`probe.mask`).** Un octet, un bit par
classe, posé par le superviseur sans reconstruire : classe masquée = la
sonde repart sans rien écrire, le watchpoint ne voit rien. C'est le
filtre des boucles chaudes. Coût d'une sonde masquée : le test du bit,
~10 cycles.

**Étage 3 — la politique superviseur.** Sous watchpoint, TOUTE sonde
non masquée fige la machine ; c'est le superviseur qui décide de loguer
et reprendre (info), compter (warn), analyser (break), ou déclarer
l'échec (error). Ce filtre-là se change en cours de session, sonde par
sonde, code par code — c'est le plus fin et le plus tardif.

La règle qui tient les trois ensemble : **on ne demande jamais au filtre
d'amont ce qu'un filtre d'aval sait faire.** Reconstruire pour faire
taire une sonde bavarde est un échec de design ; masquer une classe que
la release aurait dû décompiler en est un autre.

### Les références — ce que les autres systèmes ont déjà tranché

| Système | Ce qu'on lui reprend | Ce qu'on fait autrement |
|---|---|---|
| C `assert` / `NDEBUG` | la compilation à vide des contrôles de dev | `assert` disparaît en release ; notre classe error RESTE — c'est le partage Rust `assert!` (garde) / `debug_assert!` (dev), ou noyau Linux `BUG_ON` / `WARN_ON` |
| syslog RFC 5424 | facility × severity → notre $DD (domaine) × classe ; `setlogmask` → `probe.mask` | 4 classes, pas 8 : chaque classe a un COMPORTEMENT machine distinct (repartir, attendre, se figer) — un rang qui ne change pas le comportement est une politique superviseur, pas une classe |
| Linux : tracepoints, static keys | des sondes compilées DANS le binaire de production, quasi gratuites éteintes, activées de l'extérieur | eux patchent des NOP à chaud ; nous testons un octet — l'auto-modification de sites PAGINÉS (N copies) ne vaut pas les cycles gagnés |
| DTrace / USDT | le cousin philosophique : sondes en prod, `is-enabled` avant tout travail, consommateur externe, prédicats côté consommateur | notre transport est la RAM partagée + watchpoint, pas un canal noyau |
| GDB stub | le superviseur qui fige, lit, écrit, relâche | notre stub tient en 3 octets de contrôle + 15 de bloc ; le transport est l'émulateur lui-même |
| ARM BKPT #imm / x86 `int3` / RISC-V `ebreak` | l'instruction-piège à opérande inline | c'est la variante SWI ci-dessous — et sur cette machine elle a un pedigree |
| ASSIST09 (Motorola, 1979) et… le moniteur MO6 | `SWI / fcb fonction` : l'appel de service à octet inline est L'ABI NATIVE du 6809 — et elle est DÉJÀ dans ce dépôt : `_monitor.jsr.putc` = `swi / fcb map.JSR_PUTC` (mo6/monitor.macro.asm) | voir l'analyse dédiée |

### La variante SWI — étudiée, différée

Un site `swi / fcb classe / fdb code` coûte **4 octets** contre ~9, et
SWI empile TOUS les registres — le bloc pourrait capturer le contexte
registre complet de l'appelant gratuitement. C'est BKPT#imm sur 6809,
avec quarante-cinq ans d'antériorité (ASSIST09).

Contre, et c'est rédhibitoire aujourd'hui : les 12 octets d'empilement
mordent un fond de pile qui n'en a que 33 ; le vecteur SWI est l'ABI du
moniteur MO6, que le boot et le loader utilisent encore (`_monitor.jsr.*`)
— le réquisitionner en jeu impose une bascule de vecteur par machine, à
l'endroit exact où l'on veut du commun ; et la redirection est
spécifique à chaque moniteur. **La façade `_probe.*` rend l'encodage
interchangeable sans toucher un site** — c'est l'argument décisif pour
la façade macro : si un jeu a un jour besoin des 5 octets par site, la
variante SWI se branche derrière les mêmes macros, pour cette machine-là.

### La variante LBRN — explorée, écartée (2026-08-07)

Écartée après analyse, et la raison compte plus que l'idée : le modèle
bloc + watchpoint fonctionne AUJOURD'HUI avec les outils MCP existants
(`set_watchpoint` est au contrat du plugin), là où LBRN exige un
développement émulateur — crochet d'opcode, raison d'arrêt, filtre — et
ne couvre de toute façon pas la classe error, qui doit capturer sans
superviseur : on aurait maintenu DEUX mécanismes au lieu d'un. L'étude
reste ci-dessous pour mémoire ; l'idée du mode trace (consigner sans
s'arrêter) pourra être reprise un jour côté TOJE, indépendamment du
porteur.

Idée de Benoit. `LBRN nnnn` — long branch
never — est une instruction de **4 octets et 5 cycles qui ne fait RIEN** :
pas de saut, pas de registre touché, pas de drapeau CC modifié, pas de
pile, pas de RAM. Ses deux octets d'opérande sont donc un **canal de
données gratuit dans le flux d'instructions** : on y met le code `$DDCC`.

```
_probe.info MACRO               ; un site : 4 octets, 5 cycles, AUCUN effet
        fcb   $10,$21           ; LBRN
        fdb   \1                ; l'operande EST le code de sonde
 ENDM
```

Sur machine réelle, la sonde est un fantôme de 5 cycles. Sous TOJE,
l'émulateur — qui décode déjà LBRN — reconnaît l'opcode et lève
l'évènement : PC, page montée, opérande. C'est exactement la philosophie
du **semihosting RISC-V** (une séquence que le vrai matériel exécute sans
dommage et que l'outillage intercepte), du **magic breakpoint de Bochs**
(`xchg bx,bx`, un no-op que l'émulateur reconnaît) ou de la porte dérobée
VMware — et c'est plus propre que BKPT/int3, qui, eux, pièglent AUSSI le
vrai matériel.

**Ce que ça simplifie — beaucoup :**

- Les classes info/warn/break n'ont **plus besoin de lib du tout** : pas
  de `probe.raise`, pas d'écriture du bloc, pas de masquage d'IRQ. Le
  comportement non supervisé (« continuer sans effet ») est celui de
  l'instruction elle-même.
- `probe.key` et `probe.mask` **disparaissent** : plus rien à garder
  contre la RAM non initialisée (rien n'est lu), et le filtrage des
  boucles chaudes se fait DANS l'émulateur (par plage de codes, sans
  aller-retour superviseur) — mieux placé que le test machine à ~10
  cycles.
- Les 8 octets de données copiées deviennent inutiles pour ces classes :
  à l'arrêt sur la sonde, le superviseur lit la machine ENTIÈRE, en
  direct — plus riche que toute copie. `pc` et `page` aussi : l'émulateur
  les a nativement.
- Une classe break « bloquante » est bloquée par l'ÉMULATEUR, pas par la
  machine — non supervisée elle passe en 5 cycles, exactement la
  dégradation voulue, sans clé.
- Le coût est si bas (4 o, 5 cy) qu'on peut envisager de **livrer des
  sondes en release** — des tracepoints de production, à la DTrace. La
  compilation à vide par `PROBE_LEVEL` reste disponible, mais devient un
  choix, plus une nécessité.

**Ce qui reste au modèle bloc-RAM :** la classe **error**. Elle doit
capturer et se figer SANS superviseur (machine réelle) — c'est tout son
sens. Le bloc `$9EF0`, le halt à bordure clignotante et `probe.release`
restent son domaine. L'architecture se scinde proprement :

```
sondes de débogage (info/warn/break)  LBRN : annotation pure, zéro lib,
                                      observable sous émulateur seulement
contrôles fatals (error)              JSR probe.raise.error : bloc $9EF0,
                                      halt, bordure — autonome partout
```

**Vérifications faites :** LBRN n'est utilisé NULLE PART dans le dépôt —
le canal est vierge. `brn *` sert 4 fois de NOP de 3 cycles (attentes
YM2413) : le crochet émulateur ne doit donc surveiller QUE LBRN, jamais
BRN — sinon quatre faux positifs par attente, dans du code chaud. La
variante compacte `BRN nn` (2 octets, 3 cycles, 256 codes) reste possible
plus tard en excluant l'opérande $FE, mais rien ne la réclame.

**Le coût déplacé :** c'est TOJE qui porte le mécanisme — un crochet dans
le handler LBRN (gratuit pour toute autre instruction), une raison d'arrêt
« sonde » exposée au MCP avec l'opérande, un filtre par plage de codes, et
idéalement un **mode trace** : consigner les sondes dans un anneau
(code, PC, page, trame) SANS s'arrêter, à dépouiller après coup — le
chronogramme du séquencement du boss se lirait d'un coup. TOJE est à
nous : c'est le bon endroit pour payer, et ça ne coûte rien au 6809.

**La limite à documenter :** ces sondes n'existent que sous émulateur.
Si un canal de débogage matériel apparaît un jour (série, cartouche), les
classes débogage devront re-passer par un modèle à écriture RAM — la
façade `_probe.*` le permettra sans toucher les sites, comme pour SWI.

## LE MODÈLE RETENU — `log.`, deux niveaux, une routine (2026-08-07)

C'est CETTE section qui fait foi à l'implémentation. Décisions, dans
l'ordre où elles ont taillé le système :

1. **Deux niveaux : info et error.** Sous superviseur la politique fine se
   joue côté superviseur ; sans superviseur, seuls « continuer » et « se
   figer » existent.
2. **Pas de canal de données : les REGISTRES sont la donnée.** D, X, Y, U
   photographiés tels qu'à l'entrée du site. À l'auteur de placer la sonde
   là où les registres exposent l'intéressant, au registre des codes de
   documenter ce que chacun y signifie.
3. **Nommage `log.`** — universel ; l'émulateur peut bâtir une vraie log
   au travers de watchpoints intégrés.
4. **La classe est le bit 15 du code, l'origine le bit 14** (moteur /
   programme), et **le code s'écrit EN DERNIER** : son écriture est LE
   signal du watchpoint. Le `ldd` du code positionne N — le test de classe
   est un `bmi`, gratuit.
5. **Une seule routine**, le `bmi` aiguille.
6. **La page cartouche est capturée** (`_GetCartPageA` — la macro existante
   gère la variante machine) : le PC seul est ambigu pour un site paginé.
7. **Pas de signal visuel au halt : `bra *`.** Même geste que les treize
   `bra * ; error trap` existants, mais identifié — et la lib ne dépend
   plus de gfxlock ni du registre SYS2.

### L'espace des codes — 16 bits, deux bits de structure

```
bit 15     classe   0 = info, 1 = error   — posé par _log.error, jamais au registre
bit 14     origine  0 = moteur, 1 = programme
bits 13-8  domaine  (63 domaines par origine)
bits 7-0   cause    (256 par domaine)
```

Codes moteur `$0100-$3FFF`, codes PROGRAMME `$4000-$7FFF` — le moteur ne
touche jamais `$40+`. Un dump se décode à l'œil : `$8103` = error moteur
tlsf ; `$C001` = error programme. `$0000` = « rien », réservé.

### Le bloc — 13 octets, ancré sur la DP

```
* engine/log/log.const.asm — dérivé, pas codé en dur :
log.BLOCK       equ dp-16          ; $9EF0 : 16 octets verrouillés sous la DP
log.code        equ log.BLOCK+0    ; fdb — écrit EN DERNIER : LE signal du
                                   ;       watchpoint ; $0000 = rien
log.page        equ log.BLOCK+2    ; fcb — page:pc, l'ordre destination du
log.pc          equ log.BLOCK+3    ; fdb   loader ; pc = site+5
log.d           equ log.BLOCK+5    ; fdb — D,X,Y,U photographiés tels
log.x           equ log.BLOCK+7    ; fdb    qu'à l'entrée du site
log.y           equ log.BLOCK+9    ; fdb
log.u           equ log.BLOCK+11   ; fdb
                                   ; +13..+15 : réserve

* PAS d'init : le bloc n'est jamais lu qu'après un déclenchement de
* watchpoint, donc la poubelle du démarrage n'est jamais interprétée — et
* une mise à zéro au boot CLAQUERAIT le watchpoint avec un évènement
* fantôme (décision 2026-08-07, log.init retirée).

* engine/constants.asm — la pile plonge désormais SOUS le bloc :
glb_system_stack equ log.BLOCK     ; (était : equ dp)
```

### `engine/log/log.const.asm` — le registre moteur

```
* Un code n'existe que déclaré : ici pour le moteur ($01-$3F), dans le
* registre du PROGRAMME pour $40-$7F — le moteur n'y touche jamais.
* CHAQUE code documente ce que D/X/Y/U signifient au site : c'est le
* contrat de lecture du superviseur.

* --- domaines moteur ---
* $01 tlsf   $02 loader   $03 scene   $04 objects   $05 sound   $06 gfx

* tlsf — reprend les codes historiques de tlsf.err ($03 = out of memory)
log.tlsf.INIT_MIN_SIZE  equ $0101  ; D=taille de pool demandée
log.tlsf.INIT_MAX_SIZE  equ $0102  ; D=taille de pool demandée
log.tlsf.OUT_OF_MEMORY  equ $0103  ; D=taille demandée
log.tlsf.MALLOC_MAX     equ $0104  ; D=taille demandée
log.tlsf.FREE_NULL      equ $0105  ; X=pointeur fautif

log.scene.LOAD_OVERLAP  equ $0301  ; B:X=destination page:adresse, Y=entrée rép.
log.objects.POOL_FULL   equ $0401  ; U=OST du demandeur
log.objects.BAD_ID      equ $0402  ; A=identifiant fautif
```

Côté jeu, un fichier frère (ex. `src/common/engine/log.const.asm`) :

```
* registre des codes du PROGRAMME — plage $40-$7F
log.rtype.BOSS_EYES_DEAD  equ $4001  ; D=gameCount
log.rtype.WAVE_EXHAUSTED  equ $4002  ; X=pointeur wave
```

### `engine/log/log.macro.asm` — les sites, 5 octets, rien de détruit

```
_log.info MACRO
 IFDEF LOG_INFO              ; booléen — <define symbol="LOG_INFO"/> en dev
        jsr   log.write
        fdb   \1
 ENDC
 ENDM

_log.error MACRO             ; TOUJOURS compilé : le contrôle fatal embarque
        jsr   log.write
        fdb   (\1)|$8000     ; la classe est le bit de poids fort
 ENDM
```

Même point d'entrée : le code porte la classe. Le registre reste propre —
c'est la macro qui pose le bit, un même évènement peut être info sur un
chemin et error sur un autre sans doubler le registre.

### `engine/log/log.asm` — la routine (~55 octets), DEUX copies, UN bloc

`ram.set` et le tlsf vivent dans l'assemblée du LOADER, pas dans le
résident : la lib est donc incluse par les deux (moteur via engine.asm +
api ; loaders TO8 et MO6 via leurs includes). Deux copies du code, mais un
seul bloc à adresse absolue — le superviseur surveille le bloc, pas la
routine. La lecture de page est portable telle quelle :
`map.CF74021.CART` existe dans les deux cartes ($E7E6 TO8, $A7E6 MO6).

```
log.write
        pshs  cc              ; le CC du site — info le rendra intact
        orcc  #$50            ; une IRQ qui loguerait pendant l'écriture
                              ; mélangerait deux évènements
        std   log.d           ; LA PHOTOGRAPHIE D'ABORD : quatre stores
        stx   log.x           ; étendus, aucun registre modifié
        sty   log.y
        stu   log.u
        _GetCartPageA         ; A ← page montée (D déjà en lieu sûr)
        sta   log.page
        ldx   1,s             ; adresse de retour = le fdb du site
        ldd   ,x++            ; D = code… et N ← bit 15 : le ldd EST le test
        bmi   log.write.error ; IMMÉDIATEMENT — un stx détruirait N
        ; ----- info : publier, tout rendre -----
        stx   1,s             ; retour ajusté au-delà du fdb
        stx   log.pc
        std   log.code        ; <-- LE SIGNAL
        ldd   log.d           ; D et X rendus (Y, U jamais touchés)
        ldx   log.x
        puls  cc,pc           ; CC rendu — état IRQ du site compris

log.write.error
        stx   log.pc          ; même sémantique : site+5
        std   log.code        ; <-- LE SIGNAL
log.halt
        bra   log.halt        ; ne revient jamais — l'ancre émulateur

```

Info : ~90 cycles, transparence totale — D, X, Y, U et CC rendus, un site
est légal entre un `cmpa` et son branchement. Error : ne revient jamais,
IRQ coupées à jamais — bloc figé PAR CONSTRUCTION, pas de garde
« première erreur gagnante ».

### Le layout — la carte corrigée en même temps

```
<reserved name="dp"        page="$01" address="$9F00" size="$0100"/>
<reserved name="log.block" page="$01" address="$9EF0" size="$0010"/>
<reserved name="stack"     page="$01" address="$9ED0" size="$0020"/>
```

Le réservé `$9F00` mal nommé « stack » devient `dp` ; la pile est enfin
déclarée, fond de 32 octets que le témoin de crue vérifiera.

### Exemples d'appel

```
* L'écran noir d'une heure — tlsf à court de mémoire. Au point d'échec,
* D porte ENCORE la taille demandée :
        _log.error log.tlsf.OUT_OF_MEMORY

* Le tir silencieusement avalé — pool plein dans createFoeFire. Un INFO :
* le jeu continue, mais on veut le voir. U = l'OST du tireur.
createFoeFire
        jsr   LoadObject_x
        bne   @ok
        _log.info log.objects.POOL_FULL
        rts
@ok     ...

* La chronologie du boss — l'usage traceur. Placé APRÈS le ldd : la
* photo porte l'heure.
main.dobkeratops.allEyesDead
        ldd   gfxlock.frame.gameCount
        _log.info log.rtype.BOSS_EYES_DEAD

* CONTRE-EXEMPLE — les registres intéressants déjà consommés :
        ldd   #0
        std   fireCounter,u
        _log.info log.objects.POOL_FULL   ; photo de D=0 : du vide
```

### Migration et session

- tlsf : le loader arme `tlsf.err.callback` sur `log.tlsf.trap` juste
  après `tlsf.init` — le défaut de tlsf.asm reste `tlsf.err.loop`, pour ne
  pas toucher le banc tlsf.ut. A porte le code historique au moment du
  callback, la photographie le garde (`log.tlsf.ERROR : A=code 1..7`).
- Les `bra * ; error trap` de `ram.set` (TO8 et MO6) deviennent
  `_log.error log.ram.SET_RANGE` (B=page, U=adresse). Les onze du banc
  tlsf.ut restent : c'est un harnais autonome.
- Session superviseur : `load_symbols` ; `set_watchpoint` écriture sur
  `log.code` (une fois) ; `run_frames` ; à l'arrêt, lire le bloc, décoder
  via les registres de codes. Un breakpoint sur `log.halt` attrape les
  erreurs même sans watchpoint posé.
- Enrichissement TOJE possible (qui justifie le nom) : un watchpoint
  intégré de JOURNALISATION — à chaque claquement de `log.code`, copier le
  bloc dans un journal hôte avec le numéro de trame, et reprendre sans
  s'arrêter. Un journal réel à coût machine nul.

### VÉRIFIÉ SUR MACHINE (TOJE, 2026-08-07)

Test de bout en bout : routine copiée en RAM résidente ($6300) et appelée
par un site injecté, watchpoint en écriture sur `log.code` ($9EF0).

| Attendu | Mesuré |
|---|---|
| la surveillance claque sur le `std log.code` | oui, coupable `$6322` = la bonne instruction |
| info : `code=$0101` | `$0101` |
| info : `pc` = site+5 | `$6212` (site `jsr` en `$620D`) |
| info : photographie D,X,Y,U | `$1234 $5678 $9ABC $DEF0` — les quatre |
| info : appelant rendu intact | D,X,Y,U identiques au retour ; `CC=$58` porte le N que `ldu #$DEF0` avait posé — le CC du site, restitué |
| error : `code=$8101` (bit 15) | `$8101` |
| error : se fige sur `log.halt` | PC bloqué sur l'ancre, `F=1 I=1` |
| error : photographie | `d=$AA55`, X/Y/U conservés du site |

Deux enseignements du banc :

1. **Le secteur de boot ancrait sa pile en dur à `$9F00`** et poussait donc
   DANS le bloc (mesuré : `PSHS A` du moniteur écrivant `$9EF1`). Corrigé —
   `lds #log.BLOCK` — et vérifié : le bloc reste intact ($FF partout) sur
   tout le boot. C'est exactement le défaut « deux ancres pour une adresse »
   que la garde d'assemblage attrape désormais (garde testée : elle mord).
2. **Un banc de sondes mal placé casse son hôte.** Charger D/X/Y/U de
   valeurs témoins dans l'init du loader a détruit des registres vifs et
   fait partir la machine dans le décor. La discipline « placer la sonde là
   où les registres portent déjà l'intéressant » n'est pas un confort : une
   sonde ne doit RIEN préparer.

Non couvert : le chargement complet du jeu sous TOJE. Le `.fd` 640 Ko n'est
pas servi par le contrôleur émulé (la ROM interroge `$E7D0` sans réponse) et
le `.sap` n'expose qu'une face — le loader démarre, puis réclame « Insert
disk 0 ». La sonde d'exemple du stage 1 attend donc un test en jeu réel.

### Questions ouvertes restantes

- Budget cycles réel de `log.write` info (~90 estimés) — à mesurer à
  l'implémentation, et à documenter pour que personne n'en mette dans une
  boucle par pixel.
- Le témoin de crue de pile (zone peinte au boot, point bas relevé par
  l'émulateur) — au programme de la phase 1.
- L'emplacement des ~59 octets résidents pour r-type (pool une troisième
  fois, ou dégraissage) — contrainte d'application, hors design commun.

---

# Phase 2 — le déchargement déclaré par la scène — CONCEPTION

Acté : **le déchargement implicite du loader était une erreur** (commit
`6b7a9bac` du 2026-07-30 — sa propre limitation le condamne : il ne couvre
que la destination exacte, jamais le recouvrement partiel, c'est-à-dire
qu'il rate le cas réel). Le développeur maîtrise sa séquence.

## La découverte qui dicte la conception

En relevant le format avant de le modifier, il apparaît qu'il n'y a **rien
à modifier**. Une scène est appliquée en parcourant sa table **trois fois**,
avec un vecteur d'action différent à chaque passe (`loader.scene.load`) :

```
        ldx   #loader.file.load          \
        stx   loader.scene.routine        |  la MÊME table,
        jsr   loader.scene.apply          |  parcourue trois fois,
        ldx   #loader.file.decompress     |  avec trois actions
        stx   loader.scene.routine        |  différentes
        jsr   loader.scene.apply          |
        ldx   #loader.file.linkData.load  |
        stx   loader.scene.routine        |
        jsr   loader.scene.apply         /
```

`loader.scene.apply` est un **itérateur générique** : il décode les blocs
(%01, %10, %11), en extrait pour chaque fichier `B`=page, `U`=adresse,
`X`=identifiant, et appelle `jsr [loader.scene.routine]`. L'action est un
paramètre, pas une propriété du parcours.

**Donc : décharger une scène = une QUATRIÈME passe, avec la routine de
déchargement.** Pas de nouveau type de bloc, pas de seconde table, pas
d'évolution du format de scène. `loader.file.linkData.unload` existe déjà
et est dans la table de saut publique.

Et le corollaire est celui qu'on cherchait : **la table d'une scène EST la
liste de ce que cette scène a chargé.** Le stage sortant n'a rien à
déclarer — il rejoue sa propre table. La sémantique tombe juste sans qu'on
l'écrive : `scenes.boot` a chargé le commun, `scenes.stage1` ses tuiles,
cartes, collision et main ; déparcourir `scenes.stage1` retire exactement
ses cinq fichiers de l'index et laisse le commun tranquille.

## Ce que « décharger » veut dire, précisément

`loader.file.linkData.unload` **désindexe** : il libère le tampon de
données de lien et retire l'emplacement de l'index. Il n'efface pas la RAM,
et c'est la bonne sémantique — le danger n'a jamais été le contenu, c'est
qu'une relink globale aille patcher les décalages périmés d'un fichier
mort par-dessus le binaire vivant. « Occupé » veut dire « indexé », pas
« non nul ». C'est aussi la définition dont la phase 4 a besoin pour son
contrôle.

Un fichier non indexé rend `$FF` sans rien casser : **déparcourir deux fois
est sans effet**, et déparcourir une scène jamais appliquée aussi.

## Les trois points durs

### 1. La table de la scène sortante est LIBÉRÉE après usage

`loader.scene.load` finit par `jsr tlsf.free` : la table vit dans le pool
le temps des trois passes, puis disparaît. Pour en faire une quatrième plus
tard, il faut qu'elle soit encore là. Trois voies :

| Voie | Coût | Remarque |
|---|---|---|
| **a. Garder la table de la scène courante** | sa taille dans le pool en permanence (mesuré : 54-406 octets sur r-type) | la plus simple ; le pool est justement fait pour ça |
| b. Recharger le fichier de scène sortant avant de le déparcourir | un secteur lu, zéro RAM permanente | le déchargement devient une lecture disque |
| c. La scène entrante porte la liste | zéro | recrée le couplage entrant→sortant qu'on veut supprimer |

**Préférence : (a).** 406 octets au pire, et le loader sait déjà que la
scène courante est un objet vivant. (c) est à écarter explicitement : c'est
le raccourci qui redonnerait au nouveau stage la responsabilité de savoir
ce que l'ancien avait fait.

### 2. L'itérateur donne la page de DESTINATION, l'unload veut l'identifiant de DISQUE

Le parcours fournit `B`=page de destination ; `loader.file.linkData.unload`
attend `B`=identifiant de répertoire. Il faut donc une petite routine
d'adaptation — la quatrième « action » n'est pas `unload` directement mais
un adaptateur de quelques octets qui substitue `B` par le `diskId` courant
(le loader en tient déjà un, `>diskId`, posé par `loader.dir.load`) avant
d'appeler l'unload. C'est le seul code nouveau du côté loader.

### 3. Deux appels séparés, l'ordre appartient au développeur

**Pas de `switch`.** Un point d'entrée unique qui enchaînerait déchargement
et chargement serait le déchargement automatique sous un autre nom : la
séquence redeviendrait implicite, et c'est exactement ce qu'on retire. Le
jeu écrit les deux appels, dans l'ordre qu'il choisit :

```
        ldx   #scenes.stage1
        jsr   loader.scene.unload    ; ce que le stage sortant retire
        ldx   #scenes.stage2
        jsr   loader.scene.load      ; ce que le stage entrant apporte
```

Noms symétriques : `load` / `unload`. Pas d'`unapply`, terme sans emploi
ailleurs dans le loader.

**`unload` prend l'identifiant de scène en argument**, comme `load`. Aucun
état caché du genre « la scène courante » : le développeur nomme ce qu'il
décharge. C'est ce qui rend le mécanisme utilisable pour autre chose que
l'échange nominal — décharger une scène chargée deux échanges plus tôt,
par exemple.

La table gardée (voie a) devient donc un **cache**, pas un état de
protocole : `unload` regarde si l'identifiant demandé est celui de la table
en mémoire — cas nominal, puisque le déchargement précède immédiatement le
chargement suivant — et sinon relit le fichier de scène, exactement comme
`load` le fait. Le code du repli est celui de `load`, aux deux premières
lignes près.

### 4. Aucun garde-fou sur la scène de boot

On pourrait interdire de décharger la scène de boot, puisque son commun est
résident pour toute la partie. **On ne le fait pas.** Le développeur est
responsable de sa séquence, et ce cas a des usages légitimes : un test qui
vérifie qu'une scène se décharge proprement, ou un mode qui repart de zéro.
Un garde-fou ici serait une politique du loader imposée au jeu.

## Ce que le BUILDER a à faire : rien, ou presque

Aucun nouveau type de bloc, aucun attribut. Deux ajouts utiles seulement :

- **Une vérification statique.** Le builder connaît les `<load>` de chaque
  scène. Dès que l'enchaînement des scènes lui est déclaré — et le chaînage
  des stages est justement en train de l'introduire — il peut vérifier que
  tout ce qu'une scène charge est soit libre, soit déchargé par la scène
  qu'elle remplace. Le trap de la phase 4 devient le dernier filet, pas le
  premier.
- **Le rapport de pool.** `pool-map-fd.txt` doit compter la table de la
  scène courante, désormais résidente dans le pool (voie a).

## Ce qu'on n'aura pas, et qu'il faut assumer

Déparcourir la scène sortante retire ce que la scène **a chargé**, pas ce
qu'un objet a alloué en cours de route. Le déchargement reste au grain du
FICHIER — c'est le bon grain pour l'index de lien, et rien d'autre n'y est
indexé.

Et si un stage veut décharger autre chose que sa propre scène, il lui reste
`loader.file.linkData.unload` en direct, qui est déjà public. Le mécanisme
de scène est le cas général, pas une prison.

## Décisions prises (2026-08-07)

1. **Voie (a)** : la table de la scène chargée survit dans le pool, comme
   cache du déchargement à venir.
2. **`load` et `unload` séparés**, tous deux prenant l'identifiant de scène.
   Pas de `switch` : l'ordre appartient au jeu.
3. **Pas de garde-fou** sur la scène de boot : c'est au développeur de
   savoir ce qu'il décharge.

# Phase 3 — les scènes r-type déclarent leurs déchargements — FAIT

Implémenté le 2026-08-07.

**Trois sites d'échange**, tous par `game.stage.switch`, et aucun ne
déchargeait — l'éviction par destination faisait le travail en silence :

| Site | Sortant → entrant |
|---|---|
| `src/stages/01/main.asm` `stage.handOver` | stage 1 → `scenes.stage2` |
| `src/stages/02/main.asm` `stage.handOver` | stage 2 → `scenes.stage1` |
| `src/stages/stage-main.asm` `stage.gameOver` | stage courant → `scenes.stage1` |

Chacun nomme désormais **sa propre** scène avant de charger la suivante.
Chaque stage pose `STAGE_SCENE equ scenes.stageN` à côté de son
`STAGE_ID` : le corps partagé (`stage-main.asm`) ne sait pas dans quel
stage il tourne, mais le stage, lui, l'a dit.

`game.stage.unload` rejoint `game.stage.switch` dans le moteur résident,
et pour la même raison — l'appelant est le stage sortant, dont la région
est sur le point d'être écrasée. **Volontairement séparé** : une routine
qui recollerait déchargement et chargement retirerait au stage la
maîtrise de sa séquence. Le déchargement DÉSINDEXE et rend les données
de lien au pool ; il n'efface pas la RAM, donc le code appelant continue
de tourner jusqu'à ce que le chargement suivant l'écrase.

Le game over déchargeant sa propre scène pour recharger le stage 1 : quand
c'est le stage 1 qui meurt, l'index est rendu puis repris. C'est la
séquence honnête, pas un cas à excepter.

## L'héritage v1 : ce qu'on a trouvé, et ce qui reste

L'hypothèse se vérifie sur un point et un seul, mais il est net :
**un pageset doit émettre un membre par zone que la région déclare.**
`region tiles.odd` en déclare 5 parce que le stage 1 en remplit 5 ; le
stage 2 n'en remplit que 4, et le build le dit lui-même — *« pageset
stage2.tiles.odd fills 4 of the 5 zones region tiles.odd declares — the
other 1 could be given back »*. Le 5ᵉ membre existe donc uniquement parce
que la région a cette forme : l'adresse dicte encore l'existence d'un
fichier.

Depuis P5 ce membre ne coûte plus rien (fichier vide, aucun secteur), et
depuis P6 son codec ne fait plus avorter le build. Ce qui reste est une
**entrée de répertoire** et un identifiant réservés pour rien. Les faire
tomber demande qu'un pageset n'émette que les membres qu'il remplit — donc
que les identifiants ne soient plus réservés sur la déclaration, ce qui
touche l'arithmétique d'identifiants du type %11. À instruire à part ;
ce n'est pas un blocage.

Ce qui, en revanche, **n'est pas** un héritage v1 : le stage 2 sans
fichier de collision. Il pointe `ObjID_collision` sur `stage.placeholder`,
le stage 1 décharge sa collision en partant, et personne ne lit la région.
Le modèle marche exactement comme annoncé — le fichier absent n'est pas
chargé, son entrée d'index n'existe pas, et rien ne la consulte.

# Phase 4 — retrait de l'implicite, trap à sa place — FAIT

Implémenté le 2026-08-07.

`linkData.slot.findByDest` est parti avec son unique appelant. À sa place,
`linkData.slot.findOverlap` : même position dans `loader.file.linkData.load`,
mais il ne cherche plus une destination ÉGALE — il cherche une
**intersection**. L'égalité n'était déjà pas la bonne question : un fichier
chargé quelques octets plus loin recouvre tout autant.

Recouvrement détecté → `_log.error log.scene.LOAD_OVERLAP` ($0301), premier
vrai client du système de la phase 1. Le cliché porte les cinq valeurs :
`B` page de destination, `X` identifiant chargé, `Y` adresse de destination,
`U` identifiant occupant.

## Les deux décisions que le plan laissait ouvertes

**1. Stocker la taille dans l'index, ou la relire ? → LA RELIRE.** La
préférence écrite ici allait au stockage ; la mesure la renverse.
`loader.dir.getFile` est en **O(1)** — `base + id × 8`, une dizaine
d'instructions — parce que l'identifiant d'un fichier EST son index de bloc.
Relire coûte donc zéro RAM et presque zéro temps. Stocker aurait coûté 2
octets par slot **et** cassé le décalage : `linkData.entry` fait exactement
8 octets, et l'allocateur multiplie par 8 avec trois `_asld`. Passer à 10
imposait une vraie multiplication, ou 6 octets perdus par slot pour rester
sur une puissance de deux.

`loader.dir.fileSize` fait la lecture, et retient deux pièges : la taille
stockée est celle de l'**avant-compression**, qui est bien l'empreinte
finale (un fichier compressé se déplie sur sa propre destination) ; et un
fichier vide se reconnaît au marqueur `$ff00` de sa localisation disque, pas
à son champ de taille, qui lit $3fff (0-1 replié).

**2. Trap optionnel ou permanent ? → PERMANENT.** Il ne coûte que du temps
de chargement : O(n) sur les fichiers **porteurs de données de lien**, 14 sur
r-type, à côté d'une lecture disque. Et `_log.error` est déjà toujours
compilé par construction — un contrôle fatal qu'on peut éteindre n'en est
pas un.

## Portée réelle du trap, à savoir

Seuls les fichiers qui **portent des données de lien** sont indexés : un
fichier entièrement cuit n'a pas de slot, donc le trap ne le voit ni comme
chargeur ni comme occupant. Sur r-type, 14 fichiers sur 80 placements. Ça
suffit pour ce qui compte — l'échange de scènes, où `stage1` (page $01,
$8000-$849A) est indexé — mais ce n'est pas une garantie universelle, et il
ne faut pas la lire comme telle.

Le contrôle a lieu **après** l'écriture, à l'indexation. Détecter avant
demanderait de le déplacer dans la première passe de la scène, ce qui
perdrait les recouvrements internes à une même scène (les fichiers d'une
scène ne sont indexés qu'à la troisième passe). Comme le trap fige la
machine, « après corruption » ne coûte rien au diagnostic.

## Vérifications

- Rejeu du calcul du trap sur `scenes.boot` de r-type, à partir des
  destinations de la table de scène générée et des tailles du rapport
  d'occupation : **0 recouvrement** sur les 14 fichiers indexés. Le trap ne
  se déclenche pas à tort au démarrage.
- Coût : `findOverlap` 78 octets, `fileSize` ~18, moins les ~35 de
  `findByDest` — **~80 octets** de pool, site d'appel compris.
- Un `bra @fill` du chemin de déduplication a dû passer en `lbra` : le
  contrôle inséré a poussé sa cible au-delà de 127 octets.

## Le banc encodait l'ancien contrat

`examples/loader-ut` **testait le déchargement implicite** — c'est dire à
quel point il était installé :

- **T5/T8** : la scène « second » chargeait cc sur la destination de bb, et
  T8 vérifiait que bb avait été évincé. T5 décharge désormais bb **par son
  nom** avant de charger ; T8 garde ses assertions (bb absent, second
  déchargement « not found ») mais change de sens — ce qui a changé, c'est
  QUI a désindexé bb, et que ce soit écrit.
- **T11** : 128 cycles d'échange dd/ee sur la même destination, avec un
  déchargement explicite tous les 16 cycles seulement « pour exercer l'autre
  chemin ». Les deux variantes sont maintenant déchargées à chaque cycle —
  décharger celle qui n'est pas indexée est un no-op, T17 l'établit.
- **T18, nouveau** : le trap provoqué exprès. Il fige la machine, donc il
  vient **après** l'écriture du statut final : `+31` dit si T1..T17 sont
  passés, et T18 se lit dans le **bloc de log** ($9EF0), ce pour quoi ce
  bloc existe. Attendu `log.code = $8301`, `log.x = log.u = data.marker.cc`,
  `log.y = addr.marker.cc`. Une machine qui atteint `trap.missed` et écrit
  `$DE` en `+31` n'a PAS trappé : c'est la régression que T18 garde.

**Le banc n'a pas été exécuté sur machine** — les deux cibles construisent
proprement, mais T11 (128 cycles) et T18 demandent un passage réel.

# Phase 5 — le membre fantôme redevient vide — FAIT

Implémenté le 2026-08-07. `PageSetPlugin.writeMemberSource` n'écrit plus le
`fcb 0` : un membre que le rangement n'a pas rempli émet une section vide,
donc un fichier **vide, purement exportateur** que `cwrite` marque `$ff00`
sans écrire un seul secteur.

Le remplissage servait à faire **évincer par destination** le membre que
celui-ci remplaçait — le loader exempte les fichiers vides de cette
éviction, puisque tous les fichiers purement exportateurs partagent la
pseudo-destination (0,0) et s'évinceraient les uns les autres. C'était le
déchargement implicite qui travaillait, et ce n'est plus le modèle : la
scène qui **se termine** nomme ce qu'elle laisse tomber, donc un membre
entrant n'a plus rien à évincer. Un octet écrit pour épargner une
déclaration à l'auteur est exactement le confort que ce builder n'offre
pas.

Vérifié : r-type n'a qu'un seul membre non rempli
(`stage2.tiles.odd.4`), et `scenes.stage2` est **déclarée mais jamais
appelée** — le chaînage des stages reste à câbler. L'éviction que ce
`fcb 0` assurait ne servait donc encore personne ; quand le chaînage
arrivera, c'est P3 qui la remplace par une déclaration.

Gain médium : un octet. Le `cwrite` tasse les fins de fichiers dans des
secteurs partagés, un fichier d'un octet ne coûtait donc pas un secteur
entier. Ce qui disparaît vraiment, c'est **un fichier de données de
plus sur la disquette** et la ligne qui allait avec.


Sans déchargement implicite, le membre de remplissage d'un pageset n'a
plus de travail : il redevient un fichier **vide, purement exportateur**
(`sizea = $ff00`), que le loader indexe déjà sans empreinte RAM. Le
`fcb 0` disparaît de `PageSetPlugin.writeMemberSource`. Le cas « un octet
incompressible » disparaît à la racine.

# Phase 6 — compression : la réservation et l'émission disent pareil — FAIT

Implémenté le 2026-08-07.

La règle est **conservée** : une entrée trop petite, ou dont le delta ne
convient pas, n'est PAS compressée. Ce qui change est son issue — au lieu
d'avorter le build, elle est **stockée brute dans son enveloppe déclarée**.

Le défaut était une asymétrie : la réservation de blocs suivait la
DÉCLARATION (`blockCount(codec, linkSection)`), le descripteur suivait le
RÉSULTAT (`if (compress)`). Une entrée déclarée compressée mais
incompressible émettait donc un bloc de moins que le répertoire n'avait
réservé, et les identifiants dérivaient — mesuré : 267 blocs pour 268 ids.
Avorter était la seule sortie honnête tant que l'écart existait.

Le correctif est le geste déjà en place pour le bloc de lien, appliqué à la
compression : **le drapeau et les huit octets réservés reflètent la
déclaration**, et « stocké brut » se dit à l'intérieur du bloc, par un
décalage nul — aucune entrée réellement compressée ne peut en avoir un.

- `DirEntryPlugin` : l'avortement tombe (un `log.info` le remplace) ; le
  drapeau et le bloc suivent `codec != null` ; le décalage reste à zéro
  quand la compression ne paie pas.
- `loader.file.decompress` : après le drapeau, teste le décalage et sort
  s'il est nul.

**Ce que ça débloque.** `codec="zx0"` devient utilisable là où l'auteur ne
choisit pas ce qu'il compresse : un pageset applique le sien à chaque
membre, y compris celui que le rangement n'a pas rempli. Le codec revient
donc sur `stage2.tiles.odd`, et la disquette passe de 37,8 % à **32,8 %** —
le gain total de la passe zx0 atteint **311 564 octets** (526 726 → 215 162).

Le membre non rempli reste un fichier d'un octet, stocké brut, un secteur :
c'est la phase 5 qui le fera disparaître, pas celle-ci.

# Ordre et dépendances

```
P1 erreurs ──────────────┐
   (préalable : fix       ├──► P4 trap au chargement
    collision bench)      │
P2 format unload ────────┤
P3 scènes r-type ────────┘
P4 ──► P5 membre fantôme
P6 compression : indépendant, à tout moment
```

P1 est le premier sujet, conception complète avant code. P6 peut se
glisser n'importe où. P2 est la seule vraie décision de format — les
questions ouvertes ci-dessus sont à trancher ensemble avant.

# Règle gravée

> Le builder n'est pas spécifique à R-Type. Aucune solution de confort
> pour un cas d'usage particulier : si un cas particulier coince, c'est le
> modèle générique qu'on interroge, pas une exception qu'on ajoute.
> (2026-08-07, à la suite du remplissage compressible — annulé.)

> **Le développeur maîtrise sa séquence.** Aucune primitive ne doit
> enchaîner à sa place des étapes qu'il pourrait vouloir ordonner, espacer
> ou omettre — ni un déchargement déduit d'une adresse d'écriture, ni un
> `switch` qui recolle un `unload` et un `load`. Un mécanisme qui « rend
> service » en cachant la séquence est la même erreur sous deux noms.
> (2026-08-07, deux fois de suite : déchargement implicite, puis switch.)
