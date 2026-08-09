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
