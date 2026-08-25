# Laser rebond — plan d'implémentation

*Troisième volet, 25/08/2026. Décisions validées avec l'auteur.
Voir [l'état des lieux v2](rebound-laser-v2.md) et [le relevé arcade](rebound-laser-arcade.md).*

---

## Ce que le relevé de la table de routage a tranché

La borne route chaque slot d'arme par une table `[palier][type]`
(`weapon_object_routines_table`, ES:0x1B80, deux blocs de 12 mots par slot :
détaché puis accroché, indexés `(niveau−1)·4 + type`). Décodée pour le type 0
(rebond), elle donne :

| slot | palier 2 | palier 3 |
|---|---|---|
| 1 | diag-UR seg 1 | diag-UR seg 1 |
| 2 | diag-UR seg 2 | diag-UR seg 2 |
| 3..8 | **no-op** | diag-UR seg 3..8 |
| 9 | diag-DR seg 1 | diag-DR seg 1 |

**Deux segments au palier faible, huit au palier fort.** Le commentaire de notre
code — *« laser length (2 or 8) based on forcepod power »* — disait donc vrai,
et **notre palier faible est déjà juste**. Seul le palier fort est amputé : 4 au
lieu de 8.

Corollaire sur les boîtes : au palier faible seuls les segments 1 et 2 existent,
et le 2 est désarmé. **La boîte unique du palier faible est donc correcte
aussi.** Tout ce qui manque ne concerne que le palier fort.

## Les choix validés

- **Manager partiel.** Les passagers (segments désarmés) deviennent des
  *records* sans OST, dessinés par un renderer groupé. Les segments **porteurs
  de boîte** restent de vrais objets : ils gardent le chemin de collision
  existant, leur explosion et leur mort.
- **Retrait du split.** La promotion du 3ᵉ segment en nouvelle tête disparaît :
  restaurer les porteurs de milieu de chaîne la rend redondante, et la borne ne
  promeut personne.

## Le budget en slots, avant et après

| | aujourd'hui | après |
|---|---|---|
| segments visibles (palier 3) | 12 | **24** |
| OST consommés | 12 | **9** — 8 porteurs + 1 renderer |
| objets graphiques | 12 | **9** |

Huit porteurs : horizontal 1 et 5 ; diagonale haut-droite 1, 4 et 7 ; diagonale
bas-droite 1, 4 et 7. Un seul renderer pour les trois lasers — ils sont toujours
tirés ensemble (la volée exige les trois slots libres), et il balaie les trois
anneaux.

---

## Les étapes

### Étape 0 — l'anneau (préalable, invisible)

L'anneau ne tient que 16 entrées ; un enfant lit à `bufferIndex − (childId·4 + 6)`
et le septième demanderait 34 octets, ramenés à 2 par le masque `#%00011111` :
il lirait une position **plus récente** que la tête.

- `glb.horizontalBuffer` 32 → 64 octets ;
- `glb.diagonalUpBuffer` / `DownBuffer` 96 → 192 (trois plans de 64) ;
- masque `#%00011111` → `#%00111111` partout, et les offsets de plan 32/64 → 64/128 ;
- `ALIGN 32` → `ALIGN 64`.

Coût : 224 → 448 octets dans la page de l'unité.
**Test** : aucun changement visible à 4 segments ; la chaîne doit être identique.

### Étape 1 — le renderer groupé

La pièce neuve, et la seule risquée. Modèle : `bugmgr.FakeImg*` / `DrawAll*`
(`src/enemies/bug/mgr.asm`), y compris son piège documenté — poser le slot
**avant** que `BuildSprites` n'y saute.

- un OST renderer, coordonnées écran, boîte parquée au centre, priorité 7 ;
- un faux imageset dont l'entrée compilée pointe sur `reboundmgr.DrawAll` ;
- `DrawAll` parcourt les trois anneaux et, pour chaque passager vivant, calcule
  sa position et appelle le dessin. La liste des passagers vivants se déduit de
  la tête de chaque chaîne (qui vit, quel `childId` maximum).

**Test** : à 4 segments, l'image doit être **identique** à avant — c'est le banc
différentiel (même scène, VRAM comparée), comme pour les optimisations de
`BuildSprites`.

### Étape 2 — la longueur au palier fort

Décommenter les quatre appels de chaque voie… mais ils ne créent plus d'objets :
les passagers deviennent des entrées du renderer. Concrètement, la tête n'alloue
plus que les **porteurs**, et déclare le nombre total de segments.

**Test** : 8 segments visibles au palier 3, 2 au palier 2 ; slots libres relevés
sous toje, à comparer aux 35 minimum d'aujourd'hui.

### Étape 3 — les boîtes de milieu de chaîne

- horizontal : segment **5**, potentiel 1 ;
- diagonales : segments **4** et **7**, potentiel 1 ;
- le segment 1 garde son potentiel 2.

Chacun est un OST porteur, armé après son `pre_delay` équivalent (son retard
dans l'anneau), avec la boîte `5,9` déjà en place.

**Test** : un ennemi encaisse bien trois touches successives d'une même chaîne
diagonale ; le porteur touché explose et la chaîne raccourcit devant lui.

### Étape 4 — le retrait du split

`InitExplosion` perd la promotion du 3ᵉ segment : plus de nouvelle tête, plus de
recul d'index. Les passagers derrière un porteur mort se suppriment en cascade
jusqu'au porteur suivant, qui continue — c'est le comportement de la borne.

**Test** : tuer le segment 1 en vol ; la chaîne doit repartir du segment 5
(horizontal) ou 4 (diagonale) sans discontinuité de position.

### Étape 5 — validation d'ensemble

- banc r-type sous toje, et relevé de cadence stage 4 comparé à la référence ;
- slots libres au pire, en vague dense ;
- comparaison visuelle à MAME sur la longueur et le rythme de déploiement
  (un segment toutes les deux trames).

## Ce qu'on ne fait pas

- palette par objet (0x3D) et SFX 0x3B : hors de portée du moteur ;
- `isInCollisionRange` : conservé, il est justifié dans le code ;
- l'anneau reste notre implémentation du `pre_delay` arcade — les segments de la
  borne volent seuls mais tracent la même trajectoire, c'est établi au volet 2.
