# RÉSOLU — le gel du stage 7 : un artefact de sonde CACHAIT un vrai crash (22/08/2026)

*Diagnostic clos, en deux temps. Le « gel à caméra 61 » des deux sessions
précédentes était un artefact de sonde (§ cause 1) ; une fois les sondes
réparées, un VRAI crash à caméra ~174 est apparu — le premier rendu des
chaînes de bug — corrigé dans `mgr.asm` (§ cause 2). Banc CHAIN au vert :
chaîne courte pic 10 records (instance S), chaîne longue pic 34 (instance L),
extinction propre, captures `dist/stage7-chainS.png` et `dist/stage7-chain.png`.*

## Cause 2 — le vrai crash : X écrasé entre l'imageset et RecPublish

Au premier rendu d'une chaîne (caméra ~171-174), le jeu mourait : pile
détruite, CPU exécutant les restes du stage 2 en page 14. La chaîne causale,
remontée au watchpoint/breakpoint toje :

1. Site de publication (`bugmgr.wLoop`, mgr.asm) : X = entrée d'imageset
   (`ldx ,x` sur ImageIndex), puis `jsr bugmgr.WSlotPtr` — qui faisait
   `ldx bm.instp,u` : **X écrasé** par le bloc d'instance. L'outslay
   d'origine (mono-instance, base de slots immédiate) ne touchait pas X ;
   le passage à deux instances a introduit le clobber.
2. `RecPublish` lisait géométrie et routine compilée (+14/15) **dans le bloc
   d'instance** au lieu de l'entrée d'imageset → slot+3 = $00C9.
3. `DrawAll` : `jsr ,x` avec X=$00C9 = 3 octets au milieu du
   `ldy #Preset19260` de LiveCreator (obj_main) → décodage désaligné qui
   retombe dans la QUEUE du macro `_loadFirePresetBug` : `sta PSR_Page` avec
   A résiduel ($CE/$AE), puis le `jsr RunPgSubRoutine` d'origine.
4. RunPgSubRoutine monte la page fantôme ($AE → page 14, jamais chargée en
   stage 7) et saute — le CPU glisse dans les données jusqu'à se perdre.

Correctif : `bugmgr.WSlotPtr` préserve X (`pshs x … puls x,pc`) — commenté
dans le code. Les 16 entrées d'imageset et les 3 références load-time-linked
de lib.bug étaient saines ; la table Obj_Index_Page n'a jamais été écrite
(vérifié au watchpoint sur toute la fenêtre du crash).

## La cause

Les sondes (`tools/bug_debug.py`, `tools/bug_autopsy.py`) passaient
`timeout_ms: 900000` à `run_frames`. Le schéma du plugin toje 1.6.1 plafonne
`timeout_ms` à **600000** : chaque appel de la phase de surveillance était
**rejeté à la validation d'entrée** — zéro trame exécutée — et `mcp.py`
retournait l'erreur (`isError`) sans la lever ; les sondes ignorent la valeur
de retour de `run_frames`. La machine restait exactement où l'amorçage
(timeouts valides) l'avait laissée.

Tout le dossier s'explique :

- « gel à caméra 61-62, boucles 88 » = l'état où la phase d'amorçage
  (tranches de 500, timeout 600000, VALIDE) s'est arrêtée. Déterministe,
  donc « reproduit 5 fois, états identiques ».
- « 40/40 PC sur `$0EDA` = `soundFX.playIRQ+2`, CC=$F1, prisonnier sous
  IRQ » = le même état relu 40 fois. `runFrame` s'arrête à la frontière de
  trame (19968 cycles) ; l'IRQ 50 Hz du MC6846 partage cette phase, donc la
  machine se gare naturellement 2 instructions après l'entrée du handler son.
  Ce n'est PAS un état anormal.
- « sous `step` le jeu repart » = `step` était le seul appel qui exécutait
  quelque chose. Heisenbug parfait.
- « sensible au découpage des run_frames » = les variantes qui « guérissaient »
  utilisaient un timeout valide (ou le défaut).
- « corrélé à la taille de lib.bug » = coïncidence : la référence « saine »
  avait été jouée avec d'autres appels/timeouts.
- L'hypothèse TOJE_FAST est morte : le gel « persistait » sans l'env var
  (mêmes appels invalides), et la trace ring a prouvé zéro instruction ET
  zéro cycle sous `run_frames` — ce qu'aucun état CPU réel ne produit.

Preuve finale (sonde `bug_err.py`, transcript session du 22/08 après-midi) :

    run_frames(1) -> Tool (run_frames) input validation failed:
      [/timeout_ms: doit avoir une valeur maximale de 600000]

## Les correctifs (ce commit)

1. **`ci/toje-bench/mcp.py` : une erreur d'outil (`isError`) LÈVE désormais
   `RuntimeError`.** C'est le correctif systémique — l'erreur avalée a coûté
   deux sessions. Toute sonde qui ignorait le retour de `run_frames` est
   maintenant protégée.
2. `timeout_ms` ramené à 600000 dans `bug_debug.py`, `bug_autopsy.py`,
   `engulf_debug.py` (le plafond du schéma).

## État du chantier bug après validation

Voir le readme / les résultats du banc `TOJE_FAST=1 CHAIN=1 bug_debug.py` —
le gestionnaire de chaînes (2 instances) se valide désormais réellement.
Les deux points d'hygiène du gestionnaire relevés par la revue restent
ouverts (cf. `mgr.asm`) : `objid.count` = 47 dans les trois stages (fait),
et le renderer d'une instance jamais « vue » ne se libère qu'à l'extinction
d'un slot.

## Les pièges payés (à ne pas repayer)

- **Ne jamais ignorer la valeur de retour d'un appel toje** — et ne jamais
  sonder avec un `mcp.py` qui n'a pas le raise sur `isError`.
- `timeout_ms` max de `run_frames` : **600000**.
- `bug_debug.py` fuyait UNE JVM TOJE PAR RUN : corrigé par `atexit` dans
  `ci/toje-bench/mcp.py`. Ne jamais sonder sans.
- Tout poke de `$E7E6` (cheat compris) passe par le point sûr
  (`gfxlock.bufferSwap.wait`), sinon la page montée est corrompue.
- Deux sessions sur le même clone local : plus jamais. Un clone par session.
