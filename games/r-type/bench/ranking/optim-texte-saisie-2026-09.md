# Le rendu des caractères de l'écran de saisie : où passent les 30 000 cycles (06/09/2026)

Chiffres lus dans le code (cycles 6809) et recoupés avec le profil p3/p4 :
`ranking.in.paint` coûte ~30 000 cycles par boucle pour ~86 cases.

## Ce que coûte une case aujourd'hui : ~245 cycles, dont 140 de dessin

| étape | cycles | où |
|---|---:|---|
| le glyphe compilé lui-même (`DRAW_text_x` : `pshs u`, `leau`, ~8 `lda`, 16 `sta n,u`, `puls u,pc`) | ~140 | police du HUD |
| le dispatch `ranking.in.glyph` : six `cmpa/beq` pour les signes hors police, puis `suba/asla/ldx/jmp [a,x]` | ~45 | unité ranking |
| la boucle de cases (`emitN` : index et compte en mémoire, `ldx src`, `lda a,x`, `ldu dst`, `leau b,u`, `jsr`) | ~60 | unité ranking |
| pour les lignes de score seulement : `slotU` (un `mul` et trois décalages 16 bits) et `rowChar` par case | ~90 | unité ranking |

Et par trame, hors cases : deux conversions de score (`ranking.digits7`,
~1 100 chacune), la recopie du libellé de ligne, la logique « dû jusqu'à la
trame f » des trois peintres, le curseur recolorié (~1 300).

**Une espace coûte autant qu'une lettre** : `DRAW_text_space` fait seize
`sta` de zéro sur un champ que le blast vient de noircir. Il y en a une
vingtaine par trame (dix dans « S T A G E   S C O R E », les zéros de tête
des scores, les séparateurs).

## Les leviers, dans le modèle « tout effacer, tout repeindre »

| # | levier | gain/boucle | prix |
|---|---|---:|---|
| 1 | **Sauter les espaces** — l'appelant n'appelle pas le glyphe pour `' '` | −5 000 | trois instructions |
| 2 | **Convertir les scores une fois**, à l'entrée de l'écran (ils ne changent plus) : 14 chiffres en RAM | −2 200 | 14 octets |
| 3 | **Ancres par ligne** — `slotU` et `rowChar` sortis de la boucle de cases : U de la ligne calculé une fois, puis `leau 1,u` | −3 000 | réécriture de `stepRows` |
| 4 | **Boucle de cases à plat** — `lda ,x+` / `jsr` / `leau 1,u` / `decb`, sans index en mémoire | −2 300 | réécriture d'`emitN`/`botCell` |
| 5 | **Dispatch par table** — les six signes ont des codes ASCII entre 32 et 63 : une table de 32 mots dans l'unité (64 octets), plus de `cmpa` en cascade | −2 000 | 64 octets |
| 6 | Convention « U conservé par l'appelant » dans les glyphes : plus de `pshs u`/`puls u` | −1 000 | touche la police du HUD, partagée : non |
| | **total 1 à 5** | **−14 500** | local à l'unité, aucune perte de fidélité |

La boucle de saisie est à ~93 500 cycles (blast 25 500, texte 30 000,
Pata-Pata 17 000, divers 10 000, attente 10 000). Avec −14 500 : **79 000,
sous la marche des 4 trames (80 000) : 12,5 fps** au lieu de 10, à
densité égale de Pata-Pata. La marge est mince (1 000 cycles) : avec la
réduction des Pata-Pata (−8 500) elle devient confortable.

## Hors modèle : deux idées, et pourquoi pas maintenant

- **Le texte fixe compilé en un seul sprite** (« S T A G E   S C O R E »,
  « N STAGE », « TOTAL SC », « ENTER YOUR INITIALS. » : 57 cases, 912
  `sta`, ~5 000 cycles ; les 23 cases variables restent en glyphes) : le
  texte tomberait à ~10 000 (−20 000, la saisie à 4 trames large). Mais 912
  `sta` compilés pèsent **~3,5 Ko**, et l'arène du classement en a 1 : il
  faudrait une page — pas dans le périmètre du jeu. Et le nombre de lignes
  de score varie d'un crédit à l'autre (1 à 16).
- **Ne pas effacer les lignes de texte** (blast en bandes entre les lignes,
  texte peint une fois) : les Pata-Pata les traversent, il faudrait
  repeindre les cases qu'ils touchent — une liste de cases sales par
  Pata-Pata, et le retour à plusieurs fenêtres de blast. C'est l'axe C du
  profil précédent : la seule voie vers 3 trames (16,7 fps), au prix d'un
  changement de modèle sur cet écran.

Rappel : la borne ne repeint rien — son texte est une couche de tuiles
matérielle. Notre texte EST cette couche, en logiciel, 30 000 cycles par
trame.

## FAIT le même jour : les cinq leviers, mesurés

Implémentés dans `ranking.unit.asm` (unité partagée, aucun define) :
`ranking.scr.prepare` construit une fois par séquence le texte de chaque
ligne de score (libellé, espace, sept chiffres) et son ancre ;
`ranking.scr.emitN` est une boucle à plat qui saute les espaces ; le bas est
trois chaînes (invite, « NO.n », tirets) ; `ranking.in.glyph` dispatche par
`ranking.glyphs`, copie locale des 59 entrées de `letter_addr` avec les six
signes à leur place. L'unité passe de 2 659 à 3 079 octets (les tables :
118 + 272 + 34).

| phase | avant | après |
|---|---:|---:|
| révélation | 21,4 fps | **24,5 fps** (le plafond est 25) |
| saisie, Pata-Pata compris | 10,1-10,6 fps | **11,5 fps** (8 à 24 selon la densité) |
| tableau (peintre inchangé) | 8,5 | 8,3 |

Vérifié : rythme de révélation identique à la référence (928 → 1 352 →
2 464 → 3 152 → 3 264 → 4 968 → 5 456 aux mêmes trames), tableau à
14 824 px, séquence in situ du jeu intacte (tableau, continue, READY,
reprise). La saisie moyenne reste sous la marche des 4 trames parce que la
densité de Pata-Pata la fait osciller de 8 à 24 : la réduction des
Pata-Pata est le levier suivant.
