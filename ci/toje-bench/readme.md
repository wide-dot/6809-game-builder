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
export TOJE_MCP=<clone de toje>/scripts/toje-mcp.sh   # construit son classpath au 1er run

cd examples/loader-ut
python3 ../../ci/toje-bench/loader_ut.py dist/to8.fd dist/to8-disk1.fd

cd games/r-type
python3 ../../ci/toje-bench/rtype_bench.py dist/to8.fd
```

Codes de sortie : 0 = pass, 1 = fail/blocage, 2 = pas de verdict.
L'émulation tient ~250 trames/s : loader-ut se joue en ~1 min, le banc
r-type complet (vitesse de scroll réelle, ~25 000 trames) en ~2 min.

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
3. r-type : témoins du banc relogés dans un bloc réservé à eux (`$8766`,
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
