# toje-bench — rejouer les bancs machine sans écran

Les bancs du dépôt (loader-ut, banc d'échange r-type) écrivent leurs
résultats en RAM précisément pour être lus par un outil. Ces scripts les
rejouent **headless** en pilotant l'émulateur toje par son serveur MCP
stdio (module `teo-mcp` du dépôt [wide-dot/toje]) : boot disquette (la
séquence de `/toje-boot`), `run_frames` + `read_memory` sur les témoins,
montage à chaud des disquettes quand le banc le demande, et au blocage un
dump complet (bloc de log moteur `$9EF0`, registres, désassemblage,
capture d'écran).

[wide-dot/toje]: https://github.com/wide-dot/toje

## Usage

```bash
# le lanceur est le plugin toje INSTALLE (derniere version, resolue par
# mcp.py dans le cache des plugins Claude Code) ; TOJE_MCP ne sert qu'a
# pointer un clone de dev : export TOJE_MCP=<clone de toje>/scripts/toje-mcp.sh

cd examples/loader-ut
python3 ../../ci/toje-bench/loader_ut.py dist/to8.fd dist/to8-disk1.fd

cd games/r-type
python3 ../../ci/toje-bench/rtype_bench.py dist/to8.fd
```

Codes de sortie : 0 = pass, 1 = fail/blocage, 2 = pas de verdict.
L'émulation tient ~250 trames/s : loader-ut se joue en ~1 min, le banc
r-type complet (vitesse de scroll réelle, ~25 000 trames) en ~2 min.

## Relevé de cadence — `fps_curve.py` + `fps_plot.py`

Deux scripts hors verdict : ils ne disent pas pass/fail, ils **mesurent**.
Servent à comparer deux modes de rendu sur le même niveau (chantier overlay,
08/2026).

```bash
cd games/r-type
python3 ../../ci/toje-bench/fps_curve.py dist/to8.fd releve.csv
python3 ../../ci/toje-bench/fps_plot.py courbes.svg \
    reference.csv="sauvegarde de fond" overlay.csv="overlay"
```

Le jeu ne porte aucune sonde ajoutée : `bench.frames` s'incrémente déjà une
fois par tour de `stage.loop`, et `read_memory` le lit **sans coûter un
cycle** au programme mesuré — une sonde écrite par le jeu fausserait
exactement ce qu'on compare. L'échantillonnage est à la trame machine
(50 Hz) : `run_frames(1)` coûte 4,1 ms, soit la vitesse d'émulation
elle-même, donc l'aller-retour MCP est gratuit et **toje n'a rien à
gagner d'un outil d'échantillonnage dédié**. Un niveau 1 complet (12 631
trames, 252 s émulées) se relève en une minute.

Conditions à tenir identiques des deux côtés d'une comparaison :
**l'invincibilité** (sans elle le vaisseau meurt faute d'entrée manette et le
relevé s'arrête — vécu à la trame 3835), aucune entrée manette,
`bench.SCROLL_VEL` inchangé.

Le traceur écarte de la moyenne **les deux queues qui ne sont pas du jeu** :

- la **queue muette**, le chargement de la scène suivante — sa durée dépend de
  la taille des fichiers, pas du rendu ;
- la **queue saturée**, la séquence de fin : il ne reste plus rien à dessiner
  et le jeu rend chaque trame machine. Sur le stage 4 c'était 541 trames à
  50 img/s, qui à elles seules faisaient passer la moyenne de 6,0 à 8,7 sans
  qu'une seule raconte le coût du rendu. Seuil réglable par `--saturated`
  (défaut 45 img/s ; `--saturated 51` ne coupe rien).

`--traversal` va plus loin et coupe **tout ce qui suit l'arrêt de la caméra** :
décompte de fin, dissolution — plus de bandes qui entrent, plus de vagues, ce
n'est plus la même scène. C'est la mesure de la **traversée**, et c'est celle
qu'on garde en référence pour le stage 4. Pas par défaut : sur un stage à
boss la caméra se fige aussi pendant le combat (la séquence de fin cale
`scroll_max` sur la salle du boss), et couper là jetterait le passage le plus
chargé du niveau.

Le `define invincible` a disparu : l'invincibilité vient du cheat du title.
`--cheat` l'arme au joypad (préfixe h,b,g,d puis bas), et c'est **aussi la
seule façon d'entrer ailleurs qu'au stage 1** — le même cheat sélectionne le
stage (préfixe puis N fois haut). Sans `--cheat`, le script presse start,
ce qui n'ouvre que le stage 1.

```bash
python3 ../../ci/toje-bench/fps_curve.py dist/to8.fd releve.csv --stage 4 --cheat
```

### Références mesurées

Elles vivent dans `ci/toje-bench/refs/`, CSV brut **et** SVG tracé, pour que
la comparaison d'après ne dépende pas d'un relevé à refaire.

| relevé | périmètre | moy. | creux |
|---|---|---|---|
| stage 1, 19/08/2026 @ 886fda9c | relevé entier | 12,0 | 3,9 (caméra 552) |
| [stage 4, 24/08/2026](refs/fps-stage4-2026-08-24.csv) @ dfcc4357 | traversée | 5,2 | 1,0 (caméra 711) |
| [stage 4, 24/08/2026](refs/fps-stage4-2026-08-24-opt.csv) @ bf51cc40 — **la référence** | **traversée** | **8,2** | **5,9** |

Le second relevé est le même stage après deux chantiers : `pscroll.grow` qui
ne divise plus par soustractions (`b33065da`) et la couche de gommes devenue
le plan arrière de la collision (`bf51cc40`). **+58 % de moyenne, creux ×6, et
la pente a disparu** — la cadence ne dépend plus de la position dans le
niveau. Le double test de collision que le stage 4 paie désormais partout ne
se voit pas : traversée identique à la trame près (5 327), profil à 0,3 img/s
près sur toutes les tranches.

Le chiffre du stage 1 est un relevé entier, queues comprises : il n'est **pas**
comparable tel quel à celui du stage 4, qui est une traversée. À rejouer avec
`--saturated` le jour où on voudra les mettre côte à côte (mais sans
`--traversal` : ce stage a un boss).

Ce que change le périmètre sur le même relevé de stage 4 — assez pour qu'on
dise toujours de laquelle on parle :

| périmètre | trames | moy. |
|---|---|---|
| relevé entier, jusqu'au stage 5 | 8 699 | 8,7 |
| jouable (queues muette et saturée retirées) | 8 158 | 6,0 |
| **traversée** (`--traversal`) — la référence | 7 418 | **5,2** |

(chiffres du relevé @ dfcc4357 ; les trois se décalent ensemble sur le suivant)

```bash
python3 ../../ci/toje-bench/fps_plot.py refs/fps-stage4-2026-08-24.svg \
    refs/fps-stage4-2026-08-24.csv="stage 4 — traversee, reference 24/08/2026" \
    --traversal --title "Cadence de rendu — R-Type stage 4, traversee"
```

Profil de la traversée par tranche de caméra (moyenne glissante 1 s) :

```
cam        0   100   200   300   400   500   600   700   800   900
dfcc4357 7,8   5,9   5,6   5,3   4,9   3,8   3,6   4,0   8,9   5,4
bf51cc40 9,0   7,0   7,7   8,2   8,3   7,7   7,1   8,7   8,7   9,6
```

La pente du premier relevé — de 7,8 à 3,6 au fil du niveau — était la division
par soustractions de `pscroll.grow`, dont le nombre de tours croissait avec la
coordonnée de carte. Le second est plat entre 7 et 9.

## RÉSOLU : examples/sound TO8 — la passerelle irq.off, pas f7d4474 (2026-08-10)

Le dossier ci-dessous s'est conclu le jour même, et la bissection était un
**leurre de phase**. Cause racine, prise sur le fait au désassemblage vivant
(breakpoint page-qualifié sur `ymm.frame.play`, lecture de `ymm.data.page`) :
la passerelle `irq.off equ IrqOff` du gm title tient la promesse du NOM sans
tenir celle du CONTRAT — le `IrqOff` v1 écrase A (il lit le STATUS moniteur
dedans), or `ymm.obj.play` appelle `irq.off` l'instruction d'avant
`sta ymm.data.page` : la page musicale stockée devenait $00, et chaque
`frame.play` remontait la fenêtre cartouche sur la page 0 **en s'exécutant
depuis la fenêtre** — le sol disparaît sous le PC, marche dans la ROM,
parcage en VRAM. Le crash n'arrivant qu'à la première IRQ musicale, le
verdict dépendait de la phase du chargement : tout changement de taille de
n'importe quel fichier déplaçait le vert/rouge — c'est ce qui a fait
bissecter vers l'innocent `f7d4474` (le tableau d'expériences ci-dessous
reste vrai ; son interprétation ne l'était pas — un filler mort de même
taille était rouge aussi, c'est ce qui a rouvert le dossier).

La preuve croisée : r-type mesuré sain (`data.page=$7A`) parce que SA
passerelle applique le contrat (`pshs a` — engine.asm, avec le war story en
commentaire). Correctif : mêmes wrappers dans le gm sound, placés APRÈS la
boucle principale (la scène saute sur le premier octet de l'unité — un
premier essai les avait mis en tête, plantant l'entrée). `irq-bridge.md`
amendé : l'equ nu qu'il recommandait est banni, deuxième morsure.
Validé : mainLoop en 4069 instructions, bascule title→level1 à chaud avec
les deux flux vérifiés en RAM, 1500 trames de vie libre. Seules les 4
images sound TO8 changent.

## Archive du dossier initial (diagnostic dépassé, méthode conservée)

Trouvée en préparant la migration 3b+4b de `sound` (le témoin d'exécution
n'a jamais pu passer au vert sur l'image de RÉFÉRENCE — la règle « un vert
est une revendication » appliquée à l'envers : un rouge de base n'est pas
un effet de la migration). **Le main loop du game mode title n'est jamais
atteint** ; le premier userIRQ qui streame la musique finit en sous-débord
de la pile d'IRQ privée (S remonte au-delà de `$6359`), les retours se
font sur des adresses fantômes (`$FF63`), la queue d'IRQ moniteur `PULS`
un PC=`$5C00` et la machine erre en VRAM, IRQ masquées. Déterministe.

Bissection outillée par cette lane (worktree + `git bisect run`, prédicat
= « mainLoop atteint sous toje ») : **bon à `7f9494d`, mauvais depuis
`f7d4474` (05/08)** — le commit qui ajoute `ymm.stop`/`ymm.restart` et le
bourrage d'anneau à `engine/sound/ymm.asm`. Expériences minimales, builder
de `4576b95` constant :

| variante de `ymm.asm` | verdict |
|---|---|
| ancienne (7f9494d) | VERT |
| ancienne + bourrage seul | VERT |
| nouvelle sans bourrage (stop/restart seuls) | ROUGE |
| nouvelle complète (celle de HEAD) | ROUGE |

Le **builder est disculpé** (même commit `4576b95`, seul `ymm.asm`
échangé, le verdict suit le fichier), le **bourrage est innocent** — le
bloc `ymm.stop`/`ymm.restart` est la condition nécessaire du rouge, alors
que rien dans `sound` ne les appelle. Le retaillage de régions de
`4576b95` (`ymm.player` \$0400→\$0480) ne faisait qu'absorber la
croissance ; il est innocent aussi (testé sur builder bon).

À qui la suite : c'est la même zone que le dossier « YMM restart
desync » (les routines incriminées SONT stop/restart) — à instruire avec
lui, au watchpoint sur la pile privée. r-type n'est PAS affecté (banc
5/5, son player à `$1C9B` ; `sound` place le sien à `$0000`, seul cas du
corpus). **La migration 3b+4b de `sound` est suspendue** jusqu'au vert de
base : sa validation d'exécution n'aurait rien prouvé.

Matériel de reproduction : le prédicat lit l'adresse de `mainLoop` dans
le listing du build et arme `run_until_pc` ; images bonne/mauvaise,
traces pas-à-pas jusqu'au crash et dumps du player chargé sont
regénérables par la méthode ci-dessus (breakpoint `$6100` posé AVANT le
boot, `write_memory` sur `$E7E6` entre deux trames pour lire la page 6,
registre restauré).

## 5/5 PASS (2026-08-10, seconde campagne)

**`rtype_bench.py` affiche « R-TYPE BENCH 5/5 PASS »** : stage1 → stage2 →
stage1 complet, checkpoint sans disque compris. Ce qui restait après la
première campagne s'est résolu en trois constats, tous établis au watchpoint
et au breakpoint page-qualifié de toje (voir les scripts d'instrumentation
dans l'historique de session ; la méthode : poser la surveillance sur la
DONNÉE qui ment, pas sur le code qu'on soupçonne) :

1. **« La marche $39CA » était un faux diagnostic.** `$6154-$6156` n'est pas
   un slot `rsv_prev_*` d'EraseSprites : c'est la boîte aux lettres soundFX
   (`curSound`/`newSound`, moteur+$53/$55, `$FF00` = NO_SOUND), et `$39CA`
   est le test d'entrée idle de `soundFX.playIRQ` (page 8, unité $398A).
   Une machine dont l'IRQ tourne s'échantillonne LÀ presque à chaque arrêt —
   ce n'est pas une boucle, c'est la signature d'un fil principal mort
   ailleurs. De même, S≈$62D1 sous IRQ n'est pas une pile corrompue :
   `Irq_sys_stack` vit à $62D6.
2. **La désync YMM à la relance n'existait plus** : les correctifs
   `clr @flip` + `ymm.buffer.reset` suffisaient. Vérifié contre un décodage
   ZX0 hors machine : à la relance du stage 2, le producteur suspend à
   buffer+47 (23 paires + wait), le consommateur suit la référence à
   l'octet (+47/+54/+61…, l'instrument à +110, les WAIT1 en rafale) — les
   « balayages » revus ensuite étaient des lectures mi-trame avec une autre
   page montée, et plus tard une VICTIME des corruptions ci-dessous.
3. **Deux corruptions résidentes, prises sur le fait :**
   - `stage.placeholder` (le bouchon d'index qui marque les témoins puis
     s'auto-supprime par `UnloadObject_u`) était mappé sur
     `ObjID_shellEraser`, que la boucle invoque À CRU chaque trame, sans
     OST : un slot fantôme par trame, la pile de slots (`stu ,--x`,
     culprit $672C) déborde sous $6628 et laboure object_list, les tables,
     puis le code de `terrainCollision.do` — gel caméra=16 à l'entrée du
     stage 2, fil principal finissant dans les octets de l'OST joueur
     ($9F08-$9F47, 98 % du profil). Le stage 1 était immunisé : vrai
     shellEraser, et ses spawns compensaient les fantômes. Corrigé par
     `stage.placeholder.raw` (rts) pour toute invocation sans OST.
   - La pile S de 28 octets ($9ED4-$9EF0) débordait sous le plancher dans
     la chaîne de mort d'un objet sous IRQ ; premier octet écrasé :
     `player_pos_ring_buffer_ptr`. La traînée désalignée ne rencontre plus
     jamais son wrap (égalité stricte) et laboure la page directe puis la
     fenêtre cartouche (le dispatcher du joueur !) — au 2e passage du
     stage 1, Init rejoué → AABB player auto-bouclé (`prev=next=self`,
     la signature du double-add) → `Collision_Do` infini au premier
     contact ennemi (cam=198). Corrigé : pool 45 → 44, ancres descendues
     de 117 ensemble, pile 145 octets.

Piège d'instrumentation consigné : `mount_disk` résout les chemins relatifs
depuis le cwd du serveur MCP — un chemin d'image relatif qui ne résout plus
donne un boot silencieusement raté (menu moniteur, witness muet). Chemins
absolus, et retenter l'appui « B » si le witness ne vient pas.

## État après la première campagne de correction (2026-08-10)

Les trois régressions ci-dessous sont **corrigées** :

1. T12/T14 : chaque export de lest est désormais consommé par une somme de
   contrôle dans le game mode ($3C15 pour les 6 iface, $B088 pour les 16
   pads) — les fichiers regagnent leur bloc de lien et leurs slots.
2. Le recouvrement fantôme : `findOverlap` ignore les slots d'un autre
   disque — leur étendue est illisible depuis le répertoire en cache (les
   ids de fichiers recommencent par disquette). Au passage, T18 était
   invalidable par construction (recharger le MÊME fichier prend la dédup,
   qui court-circuite le contrôle) : une scène `scenes.trap` charge bb sur
   cc, et le trap se déclenche. **loader-ut : 17/17, statut `$0D`, T18
   `$8301` — vérifié sous cette lane.**
3. r-type : témoins du banc relogés dans un bloc réservé à eux (`$8766`
   alors ; `$87DB` depuis le 19/08 — pool 44→43, le bloc remonte avec la
   base, voir bench.const.asm ;
   16 octets empruntés au 46e objet du pool — la page 1 n'a pas un octet
   libre par construction), `ymm.stop` posé dans les deux `stage.handOver`
   (la signature YM du gel a disparu), et le layout dit vrai sur
   globals/pile (le débordement missile de 4 octets est déclaré).

L'instrumentation étant enfin fiable, la suite s'est éclaircie :

- **« la wave n'exécute aucun objet » était un faux diagnostic** — la
  capture d'écran à la trame 3400 montre cinq patapata en formation et
  leurs tirs : la wave est parfaitement vivante. Le compteur
  `bench.spawns` ne compte que les BOUCHONS, et le cast du stage 1 est
  entièrement porté — plus un bouchon n'y tourne, donc t1 était
  invérifiable par construction depuis le portage. Le contrat de t1 est
  re-spécifié sur la progression de la wave (le pointeur de lecture a
  avancé) ; le chemin de spawn par l'index reste prouvé par t2, dont le
  bouchon du stage 2 est l'instrument. (Au passage : le t1=1 historique
  était un artefact — `handOver` testait un `bench.spawns` griffonné par
  la traînée du joueur, donc non nul par accident.)
- **Le spin YMM est éteint par construction** (décision auteur : une
  lecture fait table rase de ce qu'il lui faut) : `ymm.buffer.reset`
  remplit l'anneau de `$39` (fin de flux) à chaque `obj.play`/`restart`
  — le producteur n'écrit qu'une trame en avance, et un consommateur
  qui déborde dans le non-produit (les restes du morceau précédent, en
  phase quelconque — c'était le spin observé, pos à 400 octets du début
  quand seule la première trame était produite) s'arrête net au premier
  octet non produit et reboucle proprement. S'ajoute au `clr @flip` de
  l'init du décompresseur. La signature YM a disparu des blocages.
- **Le bloqueur restant du 5/5, que le player masquait : une marche de
  page en `$39CA` qui n'avance pas.** À l'entrée du stage 2 (caméra
  figée à 16, t=[1,0,0,0,0]), le CPU boucle sur : `LDD $6155 / CMPD
  #$FF00 / BEQ →` retour au même point — le slot lu (`$6154-$6156`,
  famille `rsv_prev_*` d'EraseSprites au lwmap moteur) contient `00 FF
  00` et les 16 octets autour sont IDENTIQUES à chaque échantillon : la
  boucle traite « entrée vide » sans jamais faire avancer son pointeur.
  Prochaine étape : désassembler la routine complète (`$3980-$3A40`)
  depuis la machine bloquée, identifier la page montée et le générateur
  de ce code (effacement de sprites généré ?), et confronter à la
  sémantique v1 des slots `rsv_prev`. t1 passe et survit à l'échange ;
  t2..t5 attendent cette marche.

## Ce que la première campagne a établi (2026-08-09)

La lane a été étalonnée en rejouant un état **connu-bon** : loader-ut à
`ff633bc` sort `$0D` 16/16 — le harnais reproduit la validation de
l'auteur. Sur cette base, trois régressions dormantes ont été trouvées et
bissectées, toutes antérieures à la campagne « modèle cible » (les images
de ses phases 0-1 sont byte-identiques, sa phase 2 gèle à l'identique de
son parent) :

1. **`4576b95` (05/08) casse T12/T14 de loader-ut** : « un bloc vide ne
   s'écrit plus » élague les exports que personne n'importe — or les
   fichiers `iface.b..e` et 20 des 22 `pad.*` du banc sont du lest
   d'index dont les équates ne sont consommées par personne. Leurs blocs
   passent de 12 à 0 octets (visible au link-report), ils ne sont plus
   indexés, le compte attendu ne colle plus ($F6/$FC). À arbitrer :
   donner à chaque fichier de lest un export consommé, ou re-spécifier
   les deux tests sur la sémantique d'élagage.
2. **`9c176a3` (07/08) : le trap de recouvrement gèle loader-ut après
   T15** — `log.code=$8301` (LOAD_OVERLAP), site `$AD11`, fichier id
   $45 chargé en page 6/`$1C00` sur « occupant » id 0. Le point
   d'avant ce commit passe T16/T17 : soit le banc migré devait déclarer
   un déchargement de plus, soit `findOverlap` produit un faux positif
   (occupant id 0 est suspect). Le statut final n'est jamais écrit.
3. **r-type : l'échange de stages gèle** (stage 1 se joue entièrement,
   art et HUD justes — la capture du blocage montre la fin du niveau).
   Pas de trap : le bloc de log est vierge. La CPU boucle dans du code
   paginé qui écrit `map.YM2413.D` (`$E7FD`) sans fin — le lecteur YMM
   streame au-delà de son marqueur de fin pendant la bascule, ses
   pointeurs visant des données remplacées. À regarder du côté de
   `ymm.stop`/ordre d'IrqOff dans `stage.handOver`. Antérieur au 09/08
   (l'image d'avant la campagne gèle pareil) ; le banc n'avait
   vraisemblablement pas été rejoué en entier depuis le passage à la
   vitesse de scroll réelle (`bfd1a52`, 02/08).

Moralité, déjà écrite dans CLAUDE.md : un filet vaut ce qu'on lui a vu
attraper. Deux commits ont annoncé leur validation sans rejouer le banc
qui les couvrait ; cette lane existe pour que le replay coûte une
commande.
