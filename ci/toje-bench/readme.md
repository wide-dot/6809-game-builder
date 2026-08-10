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

## État après la campagne de correction (2026-08-10)

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
- **Le lecteur YMM se désynchronise sur toute relance après
  interruption** — le dernier bloqueur du 5/5, et le dossier est prêt
  pour l'auteur. Au spin du stage 2 (caméra figée à 16, PC dans
  `@UpdateLoop`, X balayant l'anneau en boucle), l'inspection live
  donne : variables cohérentes (`ymm.data=$20BC`, `page=$7A`,
  `status=1`), et **l'anneau contient la musique VALIDE** (l'ouverture
  du morceau, octets identiques au premier lancement sain, waits
  présents : $D9, $59, $3A, $C2…) — le consommateur les traverse
  pourtant sans jamais s'arrêter : il lit le flux décalé d'un octet
  (les waits tombent en position valeur). `clr @flip` à l'init du
  décompresseur (corrigé, nécessaire — c'était l'évidence) ne suffit
  pas : la coroutine produit/consomme (`@stackContext`, `@flip` toggé
  par octet des deux côtés, suspend sur « wait et flip=0 ») garde un
  autre état de phase qui survit à l'interruption d'un morceau. Le
  premier lancement (état vierge) marche toujours ; toute relance
  après interruption part fausse. À reprendre avec l'auteur du player
  — la sonde `ymm_state_probe` rejoue le diagnostic en deux minutes.
  Piste secondaire écartée : les ClearAll de `checkpoint.load` sont
  sur le chemin d'entrée, et la marche EraseSprites vue dans certains
  échantillons (`$39C8`) est le travail normal de la boucle, échantillonné
  pendant que le player mange les trames.

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
