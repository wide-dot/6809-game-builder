# EN COURS — le gel du stage 7 (gestionnaire de chaînes du bug)

*22/08/2026. Diagnostic avancé, chantier en pause (réorganisation du workflow).
Deux sessions ont travaillé dessus ; ce fichier consolide ce que les deux ont
établi. Le détail de la bissection vit dans le transcript de la session
`1ac49dd6` ; les sondes sont `tools/bug_debug.py` et `tools/bug_autopsy.py`.*

## Le symptôme

Stage 7, très tôt (caméra 61-62, compteur de tours figé à 88), AVANT tout
spawn de bug (le premier arrive vers caméra 146). Reproduit 5 fois en tout,
états identiques. Amorce : cheat `tct.pstage=07,01` posé au point sûr
(`gfxlock.bufferSwap.wait`), voir l'en-tête de `tools/bug_debug.py`.

## Ce que la bissection (session 1ac49dd6) a établi

- Le gel PERSISTE avec : les chaînes courtes rebasculées sur le code v1, les
  tables du stage 7 à HEAD, les stages 1/4 à HEAD. La logique du gestionnaire
  (`mgr.asm`) est donc hors de cause sur ce gel.
- RÉFÉRENCE SAINE : un build mono-instance (shim type-3 seulement + anneau
  planaire 1024, jamais commité, contenu dans le transcript) a joué le stage 7
  ENTIER. La variable discriminante est donc le CONTENU/LA TAILLE de lib.bug
  (7 274 → 14 420 octets, page 13 pleine à 16 263/16 384, repack de l'arène
  enemies : 35 unités déplacées).

## Ce que l'autopsie instrumentée (cette session) a établi

- **Le gel n'existe que sous `run_frames` toje.** Quarante échantillons de PC
  pris entre des `run_frames(1)` tombent TOUS sur `$0EDA` =
  `soundFX.playIRQ+2` (unité `common.soundfx`, page 10), CC=$F1 — I et F
  masqués, on est SOUS IRQ. Le CPU y est prisonnier.
- **Sous `step`, le jeu REPART** : 200 000 pas → le compteur de tours passe de
  88 à 98, la caméra de 61 à 72, exécution normale (RunObjects, DrawTiles,
  moveByScript, pages qui tournent). Heisenbug pur.
- **Sensible au découpage des run_frames** : amorçage en tranches de 500 +
  surveillance en 25 (le rythme de bug_debug.py) → gel systématique ;
  surveillance en tranches de 5 → AUCUN gel en 2 000 trames, même build.
- Tout l'état de jeu inspecté est SAIN au moment du gel : variables du scroll
  (tile_pos/map_pos/camold/scroll_max), file tilemap (count/lost = 0), bloc de
  log engine `$9EF0` vierge, aucune référence liée à zéro, placements page 1
  propres (arènes stageN.res sans chevauchement).

## L'hypothèse de travail

Le « crash » est vraisemblablement un ARTEFACT de l'émulation toje en mode
TOJE_FAST (turbo sans rendu) : l'IRQ son (`soundFX.playIRQ`, pilote YM2413
sous IRQ 50 Hz) se retrouve dans un état que `run_frames` ne fait plus
avancer, alors que `step` le débloque. La corrélation avec la taille de
lib.bug serait alors du TIMING (le repack et la taille chargée déplacent
l'alignement trame du moment où l'IRQ son croise autre chose), pas de la
mémoire écrasée — cohérent avec une bissection qui n'a jamais trouvé de
coupable dans le code.

Précédent connu : toje n'émule pas les timers MPLUS (le factory test les voit
KO) ; et le gomander avait déjà produit la même signature de registres sous
IRQ son (jugée hareng rouge à l'époque — c'est peut-être le MÊME artefact).

## Par quoi reprendre

1. **Trancher artefact vs bug réel** : rejouer la repro SANS `TOJE_FAST`
   (retirer l'env var — les sondes marchent pareil, juste plus lentes), et/ou
   jouer le stage 7 à l'écran (toje UI ou DCMoto). Si ça ne gèle pas : c'est
   un artefact toje — le signaler côté toje (run_frames fast × IRQ son) et
   reprendre le chantier bug normalement.
2. Si ça gèle aussi en réel : instrumenter `soundFX.playIRQ` (compteur
   d'entrées/sorties en RAM fixe) pour voir si l'IRQ réentre ou ne sort pas,
   et regarder ce que `paged.call` du stage monte au moment du gel.
3. La revue de code du gestionnaire faite au passage n'a PAS trouvé de bug
   bloquant dans `mgr.asm` (idiomes outslay respectés, page callback OK,
   listes AABB nettoyées au checkpoint). Deux points d'hygiène restants :
   `objid.count` doit valoir 47 dans les trois stages (fait), et le renderer
   d'une instance jamais « vue » ne se libère qu'à l'extinction d'un slot.

## Les pièges payés (à ne pas repayer)

- `bug_debug.py` fuyait UNE JVM TOJE PAR RUN (la centaine de JVM du 22/08) :
  corrigé par `atexit` dans `ci/toje-bench/mcp.py`. Ne jamais sonder sans.
- Tout poke de `$E7E6` (cheat compris) passe par le point sûr, sinon la page
  montée est corrompue et le stage fige très tôt (vécu trois fois).
- Deux sessions sur le même clone local : plus jamais. Un clone par session.
