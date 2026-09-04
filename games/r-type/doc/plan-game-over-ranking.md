# Game over, STAGE SCORE, saisie des initiales, RANKING — plan d'implémentation

*04/09/2026. Décisions validées avec l'auteur, voir
[les questions](portage-game-over-ranking-questions.md), [le relevé arcade](arcade-game-over-ranking-reference.md)
et [la maquette](portage-game-over-ranking-maquette.md) (variante 12 px).*

---

## Ce qui est tranché

| Sujet | Décision |
|---|---|
| Déclenchement | après le GAME OVER final (le continue reste avant), **seulement si le score entre dans le top 10** |
| Hôte | la scène de stage reste montée ; le code s'exécute depuis la **demi-page de l'OST** ($4000–$5FFF, page 0 tranche 1, RAM stable), la police reste dans `common.hud` (page 7) |
| État | tout dans la demi-page : table des dix, scores par stage, état de saisie |
| RANKING | un seul rendu, partagé avec le title ; sprites de rang du title si la place le permet |
| Saisie | manette seule : croix gauche/droite, A valide, alphabet arcade avec RUB et END |
| Mise en page | STAGE SCORE : pas 12 px, ancres = y arcade × 0,75 + 10 ; RANKING : voir le point à trancher |
| Palettes | deux palettes dédiées dérivées du stage 1 (`Pal_ranking.stage`, `Pal_ranking.table`), 64 o dans `common.ranking` ; le title lit la seconde |
| Nouvelle entrée | recolorée par table de quartets (dégradé 8–11), ~80 o |
| Pata-Pata | oui, l'objet du jeu, émetteur porté de l'arcade |
| Musique | `rtype-name-entry` (3 588 o ymm, 38,7 s en boucle), **chargée depuis la disquette** dans le créneau de musique de stage ($2C09) |
| GAME OVER | inchangé |

## La place

**En page $1A.** Le créneau de musique de stage va de $2C09 à $3BFF, soit
4 087 o, identique pour les huit stages et le title (la plus grosse piste,
stage 1, en prend 4 032). La piste de saisie en fait 3 588 : elle tient
partout. Le créneau commun ($20BC–$2C08) est plein à l'octet, on n'y touche
pas.

**Sur la disquette.** La dernière piste écrite est la 63 sur 80 : 17 pistes
libres, largement plus que les 15 secteurs de la piste.

**Dans la demi-page.** Sous `OverlayMode` l'objet fait 63 o et non 117 : le
pool réel finit en $4EC4, les quatre OST statiques en $4FC0. En remontant
`objects.bullets` juste derrière, **$51C0–$5FFF = 3 648 o** sont libres.
Budget :

| Contenu | Estimation |
|---|---|
| table des dix : 10 × (3 o score/100 + 7 caractères) | 100 o |
| scores par stage : 16 × 3 o | 48 o |
| état (rang, curseur, index, minuterie, répétition, drapeau « classé ») | 8 o |
| code des trois écrans + émetteur + insertion + 6 glyphes | ~1 500 o |
| deux palettes + recoloration de la nouvelle entrée | ~145 o |
| sprites de rang, **découpés** (voir ci-dessous) : « NO. » 162 o + dix chiffres 1 007 o + index ~185 o | ~1 355 o |
| **total** | **~3 165 o** |

Il reste ~480 o de marge : tout tient, sprites compris.

**Les images de rang du title sont d'un seul tenant** (`src/title/scores/images/00..09.png`,
18 × 9) : chacune porte « NO. » sur ses colonnes 0 à 11 — identique sur les
dix — puis le chiffre sur les colonnes 12 à 17. Compilées telles quelles
elles coûtent 1 987 o (172 à 206 o chacune, listing du title) + 170 o
d'index. Mesuré avec gfxcomp en ligne de commande (même encodeur `draw`,
même mémoire 40 × 2 plans) sur les morceaux recadrés :

| Variante | Images | Octets |
|---|---|---|
| entière (aujourd'hui) | 10 × 18 × 9 | 1 987 |
| « NO. » seul (colonnes 0–11) | 1 × 12 × 9 | 162 |
| chiffres seuls (colonnes 12–17) | 10 × 6 × 9 | 1 007 |
| **découpée** | 11 images | **1 169** (−818) |

Le rendu dessine « NO. » puis le chiffre, deux sprites par rang au lieu
d'un — le coût est nul, c'est une position de plus. Les onze PNG se
produisent par recadrage des dix existants (colonnes 0–11 de `00.png`,
colonnes 12–17 de chacun) ; le title cesse d'embarquer `title.scores`
(2 224 o rendus à son arène, page 25) puisque les images vivent dans la
demi-page, toujours montée.

**Dans l'arène `objects` (page 7, `common.hud`)** : le seul ajout est
l'export des routines de police (`hud.drawStr`, `letter_addr`,
`numbers_addr`, `DRAW_text_space`) et quelques dizaines d'octets de relais.
La police est déjà là.

## Le mécanisme de chargement au game over

Le corps de stage partagé ne sait pas dans quel stage il tourne ; il connaît
`STAGE_SCENE` par le lien. La séquence :

```
GAME OVER affiché (hud.gameOverWait, comme aujourd'hui)
  → ranking.check : score > table[9] ?      (demi-page, toujours montée)
      non → stage.gameOver (title), comme aujourd'hui
      oui → IrqOff, _ram.data.set #loader.PAGE,
            composition.load(STAGE_RANKING_COMPOSITION)   ← converge la RAM :
                décharge la musique du stage ($2C09) et les lots absents,
                charge nameentry.music et lib.patapata s'ils manquent
            → ranking.run : STAGE SCORE + saisie + RANKING (boucle objets)
            → stage.gameOver (title)
```

`composition.load` est l'API qu'utilise déjà `game.stage.switch`
(`loader.composition.load.IDX`) ; elle respecte la règle LOAD_OVERLAP en
déchargeant elle-même ce qui n'est plus dans l'état cible. Côté config :

- la musique de chaque stage sort de `scenes.stageN` pour vivre dans sa
  scène `scenes.stageN.music` (idem `scenes.title.music`), listée dans la
  composition du stage — l'état de RAM ne change pas, seule la granularité
  de déchargement ;
- une composition `stageN.ranking` par stage = `scenes.boot` +
  `scenes.stageN` + ses lots **+ `scenes.lot.patapata` + `scenes.nameentry.music`** ;
  chaque `main.asm` de stage exporte `STAGE_RANKING_COMPOSITION` à côté de
  `STAGE_SCENE` ;
- `scenes.lot.patapata` n'existe aujourd'hui que dans les compositions des
  stages 1, 3, 4 et 7 : la composition de ranking l'ajoute aux autres ; son
  emplacement ($0E:$2792) y est libre (voir la section Pata-Pata).

## Les Pata-Pata : deux options, à choisir

### Les faits

- `lib.patapata` : **3 897 o** (code + images décalages 0 et 1), lot de
  l'arène `enemies`, placé en page $0E à $2792 derrière `lib.scant`, sur la
  piste 16 de la disquette (16 secteurs).
- Il est dans les compositions des stages **1, 3, 4 et 7** seulement. Dans
  les stages 2, 5, 6 et 8 son emplacement ($0E:$2792) est libre : seul
  `lib.scant` partage la page $0E, et les deux cohabitent déjà en 1 et 7.
- **Les identifiants d'objet ne sont pas alignés** : le bloc commun va de 0
  à 31 ; au-dessus chaque stage numérote à sa main. `ObjID_patapata` vaut
  32 au stage 1, 35 aux stages 3, 4 et 7, et n'existe pas ailleurs (les onze
  unités communes incluent `src/stages/01/objid.const.asm`, mais aucune
  n'emploie d'identifiant ≥ 32 — le décalage est sans effet aujourd'hui).
  Les waves citent les identifiants par symbole : renuméroter est mécanique.
- Un symbole cité par une table d'index et non chargé se résout à 0 en
  silence (le piège `loader.CHECK_UNRESOLVED_SYMBOLS` n'est pas posé dans ce
  config) et le re-link global le corrige au chargement suivant.
- L'arène commune `objects` est pleine à quelques centaines d'octets près ;
  le levier connu est la frontière de la page $0C ($0B00), qui prend sur
  l'arène `enemies`.

### Ce que les deux options ont en commun

Le code de classement est commun et fait naître le Pata-Pata par
`LoadObject` + identifiant : il faut **une ligne `ObjID_patapata` dans les
huit tables d'index, au même numéro**. Soit un identifiant commun de plus
(32, ce qui décale d'un cran les numéros locaux des huit stages — un script,
les waves sont symboliques), soit chaque `main.asm` exporte un octet
`stage.patapata.id`. Le plan retient l'identifiant commun : c'est la
convention que les unités communes supposent déjà.

### Option A — chargement dynamique au moment de la saisie

La composition `stageN.ranking` liste `scenes.lot.patapata` (et la musique)
; `composition.load` charge le lot s'il manque, décharge les autres lots.

| | |
|---|---|
| RAM | 0 o en jeu ; le lot occupe sa place habituelle le temps de l'écran |
| Disque | 16 secteurs, piste 16, plus les 15 de la musique : **moins d'une seconde** estimée, dans le noir que l'arcade a de toute façon ; les deux direntries déclarés côte à côte pour un seul déplacement de tête |
| Config | rien de plus que ce que la musique impose déjà (les compositions de ranking) |
| Index | dans les stages 2, 5, 6, 8 la ligne pointe un symbole non chargé jusqu'au game over : résolu à 0 puis corrigé par le re-link de la composition — mécanisme documenté, jamais un saut avant le chargement |
| Placement des lots | inchangé, aucune image de stage ne bouge |
| Risque | la convergence au game over (déjà à valider pour la musique, phase 0.2) |

### Option B — Pata-Pata résident permanent

`lib.patapata` passe dans l'arène `objects` ; il sort des lots.

| | |
|---|---|
| RAM | **3 897 o permanents** dans une arène pleine : frontière $0C de $0B00 à $1A80 (+3 968), la zone ennemis de $0C tombe à 9 600 o |
| Repaquetage | `lib.pstaff` (12 206 o) ne tient plus en $0C ; un rangement global existe (bink $0B, bug $0D, pstaff + scantfire $0E, scant $0F, cancer + mid $0C — le départ du Pata-Pata libère $0E) mais **toutes les adresses de lots changent** : les huit images de stage à revalider |
| Disque | 0 au game over (mais 16 secteurs de plus au boot) |
| Config | frontière + arène du fichier + retrait des quatre `scenes.lot.patapata` + huit index |
| Bénéfice de jeu | aucun : les stages 2, 5, 6 et 8 n'ont pas de Pata-Pata, et les lots des quatre autres avaient la place |
| Risque | la mémoire commune, dont chaque octet est disputé (les miettes ne s'additionnent pas) |

### Décision (auteur, 04/09/2026) : option A, chargement dynamique

B dépensait 3,9 Ko du résident le plus disputé du jeu pour un décor de dix
secondes, et faisait bouger toutes les pages ennemis.

### Les identifiants : le 31 n'est plus libre

`src/common/objid-common.const.asm` dit encore « le 31 reste libre », mais
`ObjID_forcepod_counterairreflect equ 31` l'occupe depuis le 03/09/2026
(commit a16971d15, les reflets du counter-air), et les huit index ont la
ligne. Le préfixe commun 0..31 est donc **plein**, et ce chantier a besoin
de **trois** identifiants communs, pas d'un :

| Objet | Rôle |
|---|---|
| `ObjID_patapata` | le Pata-Pata, à naître depuis le code commun |
| `ObjID_ranking` | le contrôleur des écrans (STAGE SCORE, saisie, RANKING) |
| `ObjID_patapataEmitter` | l'émetteur (ou une routine du contrôleur — alors deux identifiants suffisent) |

Proposition : **la base du spécifique passe de 32 à 40** (bornes rondes,
huit places communes dont cinq de réserve), les identifiants locaux des
huit stages et du title glissent de 8 — l'auteur l'a déjà fait une fois
(« glissé de deux » le 26/08), les waves citent par symbole, un script fait
le décalage des `objid.const.asm` et des `objid.index.asm`. Le garde
`IFGE objid.common.count-32` devient 40, et le commentaire du 31 est
corrigé au passage. Aucun stage n'approche le plafond de 127 (stage 2 monte
à 56).

Dans les quatre stages sans lot Pata-Pata, la ligne `ObjID_patapata` de
l'index pointe `patapata.Object`, non chargé : 0 en silence jusqu'à la
convergence du game over, puis corrigé par le re-link. Aucun chemin
n'atteint cet identifiant avant.

## Les phases

### Phase 0 — les deux pointes de risque — FAITE le 04/09/2026

**0.1 — charger un direntry dans la fenêtre vidéo : déjà éprouvé, pas de
sonde à écrire.** Le stage 4 le fait en production : `stage4.pscroll.vid`
est un vrai fichier, avec link data, déclaré `region="pscroll.vid"` =
`page="$00" slice="0" address="$4000"`, chargé par `scenes.stage4`. Sa
ligne de scène porte le page-octet `$01` — la *valeur* du sélecteur, pas un
numéro de page. Le chemin complet existe :

- côté builder, `WindowMap.selectorOf` rend la valeur de la tranche pour une
  fenêtre à page fixe (tranche 0 → 1, tranche 1 → 0) ;
- côté runtime, `ram.set` (`engine/system/to8/ram/ram.asm`) reconnaît
  l'espace vidéo et **remplace le bit 0 de `$E7C3` par le bit 0 du
  page-octet**, sans toucher aux sept autres (de l'I/O vivante) ;
- l'IRQ sauve et restaure exactement cette demi-page sous `OverlayMode`
  (`engine/irq/Irq.asm`), parce que le mainline peut tourner sur l'autre.

Notre tranche 1 ne diffère de la tranche 0 que par ce bit. Le seul point
propre à la tranche 1 n'est pas *si* on peut y charger, mais *quand* : elle
porte le pool d'objets vivant, donc le chargement se fait au boot (unité
jamais échangée), pas en cours de jeu.

**0.2 — `composition.load` depuis un stage en cours : construit, à
éprouver sur machine.** Ce qui a été fait :

| Où | Quoi |
|---|---|
| `src/common/music/adnz/ymm/rtype-name-entry.ymm` | la piste convertie par `vgm2ymm` (3 588 o) |
| `src/common/music/nameentry.unit.asm` | l'unité de données, export `sounds.nameentry.ymm` |
| `to8.config.xml` | direntry `common.nameentry.ymm` en `$1A:$2C09` ; scène `scenes.nameentry.music` ; la piste de chaque stage sort de `scenes.stageN` vers `scenes.stageN.music` ; huit compositions `stageN.ranking` = celle du stage, sa musique remplacée par celle de la saisie |
| `src/common/engine/engine.asm` | `game.ranking.run` (56 o) + `game.ranking.states` (16 o) : IRQ coupée, page du loader montée, convergence vers `compositions.stageN.ranking`, puis `game.music.play` sur la piste de saisie et cinq secondes d'attente |
| `src/common/engine/api.asm` | `_api game.ranking.run` |
| `src/stages/stage-main.asm` | `jsr game.ranking.run` juste avant `jmp stage.gameOver` — trois octets par stage |

Build vert en 46 s, disquette à 63 pistes sur 80 (inchangé).

**Ce que l'auteur doit entendre** : à la fin d'une partie, après le message
GAME OVER et son morceau, l'écran passe au noir et **la musique de saisie
joue cinq secondes** avant le retour au title. Depuis n'importe quel stage.

**Ce qu'un échec dirait** :

| Symptôme | Cause probable |
|---|---|
| silence, puis title | la convergence n'a pas chargé la piste, ou `game.music.play` n'a pas trouvé sa page |
| gel | recouvrement refusé par le loader (`log.scene.LOAD_OVERLAP`) — deux fichiers à `$2C09` dans le même état |
| bruit, notes fausses | la piste est là mais le lecteur lit à côté : page du lecteur mal remontée |
| le title revient sans musique | la convergence vers `compositions.title` n'a pas relâché la piste de saisie |

La sonde est **jetable** : les cinq secondes d'attente et l'appel direct
disparaissent quand les trois écrans prendront leur place.

### Le cheat de test (04/09/2026, hors phases)

Le classement ne s'ouvre qu'au-dessus du dixième score par défaut, 75 000 :
l'éprouver demandait de les gagner. Le cheat du title gagne donc une entrée,
et en perd une :

| Séquence | Effet |
|---|---|
| h,b,g,d puis N × haut | départ au stage N (inchangé) |
| h,b,g,d puis bas | invincible (inchangé) |
| h,b,g,d puis **gauche** | **continue infini** — remplace le comptage de vies |
| h,b,g,d puis **droite** | **départ à 100 000 points** |

Trois changements de fond :

- **un seul bruitage** pour les quatre (BonusSound) : c'est un accusé de
  réception, pas une signature ;
- **deux secondes sans presser effacent tout**, préfixe et cheats acceptés.
  C'est le remplaçant de l'abandon par `droite` : casser la séquence ne
  remettait que l'étape à zéro, les cheats acceptés survivaient sans moyen de
  les retirer ;
- **le comptage de vies disparaît** avec `cheat.extraLives` : sans plafond, il
  débordait son octet à la 254ᵉ pression, et le continue infini rend mieux le
  même service. Deux octets résidents le remplacent (`cheat.freeContinue`,
  `cheat.startScore`) ; le banc n'arme que `cheat.invincible`, rien ne bouge.

Le continue infini fait sauter le quota de `hud.continueScreen` (le define
`game.continue.MAX` reste la règle de build) ; le score de départ est semé au
même endroit que les vies, à l'entrée d'une partie fraîche.

### Phase 1 — la demi-page redécoupée — FAITE le 04/09/2026

Les trois `<reserved>` comptaient 117 octets par objet ; l'overlay en met 63.
Corrigés, et la queue devient une arène :

| Bloc | Avant | Après |
|---|---|---|
| `objects.pool` (60 slots) | $4000, $1B6C | $4000, **$0EC4** |
| `objects.static` (4 OST) | $5B6C, $01D4 | **$4EC4**, **$00FC** |
| `objects.bullets` | $5D40, $0200 | **$4FC0**, $0200 |
| arène `ranking` | — | **$51C0, $0E40** (3 648 o) |

Rien à changer dans l'assembleur : `palettefade` et ses trois voisins dérivent
de `Dynamic_Object_RAM_End`, et `bullet.Slots` vaut `objects.bullets.address`,
une équate que le layout génère. Le récit de `ram.const.asm`, lui, parlait
encore de 117 : corrigé. La garde de la v1 sur les OST statiques
(« ne pas retailler, le fondu écrit `o_fade_curwait` au-delà ») ne s'applique
pas : ce champ est à `ext_variables+9` = 47, sous les 63 octets du pas.

Validation : **banc rtype 7/7**, chaîne complète des stages 1 à 4 avec morts,
checkpoints, game over et rejouées — c'est exactement ce que couvre la table
de tirs déménagée.

### Phase 2 — l'état résident et les scores par stage — FAITE le 04/09/2026

`src/common/ranking/ranking.unit.asm`, direntry `common.ranking` dans l'arène
`ranking`, chargé par `scenes.boot` : 288 octets placés en $5D89.

| Symbole | Rôle |
|---|---|
| `ranking.table` | 10 × (3 octets de score par centaines + 7 caractères), les dix défauts de la borne en dur dans le binaire |
| `ranking.stage` | 16 × 3 octets, le score de chaque stage de la partie |
| `ranking.rank` | le rang décroché, 0 si non classé |
| `ranking.insert` | classe `globals.score`, décale, rend le rang en B |
| `ranking.reset` | remet les seize cases à zéro |
| `ranking.stageAdd` | cumule une récompense dans la case du stage courant |

**Pas de mot magique** : l'unité est chargée une seule fois par `scenes.boot`,
présente dans toutes les compositions, donc la déduplication du loader garantit
qu'aucune convergence ne la relit. Le contenu initial est celui du binaire.

Câblage, trois points seulement :

- `game.stage.switch` appelle `ranking.reset` quand `game.fresh` est posé —
  une seule place résidente, plutôt qu'une déclaration dans les huit mains ;
- `AwardScore` cumule chaque récompense dans la case du stage courant, en
  plus du score de la partie. **Corrigé le 04/09/2026 après relecture de
  l'auteur** : le premier jet rangeait le score à la CLÔTURE d'un stage, ce qui
  laissait à zéro celui où le joueur meurt — précisément celui que le
  récapitulatif montre, d'où un « 1 STAGE 0 » sous un total non nul. C'est
  d'ailleurs le geste de la borne (`update_current_stage_score`, 0xE8BD) : la
  même récompense va au score courant et à la case du stage ;
- `game.ranking.run` classe **d'abord** : un score hors des dix rend la main
  aussitôt, sans rien charger ni jouer. Le comportement final est donc en
  place, seuls les écrans manquent.

Vérifié sous toje, en trois sondes :

| Ce qui est éprouvé | Résultat |
|---|---|
| les dix défauts au boot | 174 500 ABIKO.. à 75 000 IREM . |
| le classement d'une partie à 100 000 points | **rang 6**, entre MISAKO! et MASATO, les suivants poussés, IREM perdu, nom à sept espaces |
| la remise à zéro d'une partie fraîche | les seize cases à zéro |
| le cumul par stage | suivi trame par trame pendant tout le stage 1 : `ranking.stage[1]` égale `globals.score` à chaque relevé, de 0 à 6 200, et garde 6 200 au passage au stage 2 |
| le chemin « non classé » | **banc rtype 7/7** inchangé |

### Phase 3 — l'écran STAGE SCORE — PREMIÈRE MOITIÉ FAITE le 04/09/2026

**Ce qui existe** : `ranking.screen`, dans la même unité que l'état. Titre
« S T A G E   S C O R E » espacé comme ceux du title, une ligne par stage
joué, la ligne TOTAL à l'emplacement qui suit, « ENTER YOUR INITIALS. », et la
ligne « NO.n » suivie des sept cases de saisie en tirets. Vérifié à l'écran
sous toje : partie perdue au stage 1 avec le cheat de score, TOTAL SC 100000,
NO. 6 — le rang que l'insertion venait de calculer.

**Architecture, et pourquoi elle diffère du plan.** Pas d'objet contrôleur ni
d'état de boucle : une routine BLOQUANTE, comme l'écran de continue déjà porté.
Elle peint les DEUX tampons à l'identique — rien n'arme d'échange ici, donc on
ne sait pas lequel est affiché, et on n'a pas à le savoir. Son code vit dans la
demi-page vidéo, toujours montée ; elle monte la page du HUD le temps de
peindre, puisque la police y est. Six exports de plus côté HUD (`hud.drawStr`,
`letter_addr`, `numbers_addr`, `DRAW_text_space`, `ScoreToDigits`,
`hud.scoreWork`) et rien de dupliqué.

Les six glyphes manquants (`? > < , - :`) sont générés par
`tools/gen_font_glyphs.py` et commités dans l'unité de classement, pas dans la
police : seuls cette ligne et l'alphabet de la saisie s'en servent, et l'arène
des objets n'a pas 500 octets à donner.

**Un défaut de l'outil trouvé au passage.** L'arène refusait de placer l'unité :
« 720 octets d'un tenant, la zone la plus large en a 631 ». Le packer d'arène
comparait page + adresse sans regarder la TRANCHE : il voyait la part fixe du
pscroll du stage 4 (page 0 tranche 0, $4000-$5D88) comme occupant les octets de
notre zone (page 0 tranche **1**, $51C0-$5FFF), alors que les deux moitiés d'une
page ne partagent aucun octet. Corrigé dans `ArenaPacker` : `Placed` porte
désormais la tranche, et deux tranches différentes ne se gênent plus. Le
correctif est **prouvé neutre** pour le reste — aucun autre config du corpus ne
déclare de tranche, donc le test ajouté n'y est jamais vrai ; corpus rebâti
malgré tout, 84 images, zéro échec.

**LA SAISIE — FAITE le 04/09/2026.** `ranking.input`, dans la même unité.
L'alphabet est celui de la borne (ROM 0x1000:0B5C) : vingt-six lettres, six
signes, RUB puis END — trente-quatre entrées que gauche et droite font défiler
en bouclant aux deux bouts, avec répétition après douze trames tenues. Le
bouton valide, RUB efface et recule, END termine, la limite de temps est celle
de la borne (2 048 trames) et la case courante clignote.

Deux écarts assumés. La borne fait clignoter la lettre en alternant deux
palettes ; notre police écrit des index fixes, donc on alterne la lettre et le
tiret de la case vide — le clignotement dit la même chose. Et les bruitages
sont ceux du jeu (tir pour le pas de curseur, bonus pour la validation, vie
supplémentaire pour la fin), pas ceux de la borne : les convertir est un
chantier à part.

Vérifié sous toje en pilotant la manette : la suite « valider, droite valider,
droite valider, deux droites valider, gauche valider » écrit `ABBC` puis prend
END, et l'entrée du rang 6 porte le nom `ABBC   ` — l'alphabet repart bien de
`A` après chaque validation, et gauche depuis `A` tombe sur END. Banc 7/7.

**Ce qui reste à la phase 3** : les Pata-Pata — dont le coût réel est
apparu ici : sur un écran peint en absolu, les sprites de l'overlay effacent
en restaurant un décor qui n'existe pas, et laisseraient des trous dans le
texte. Aucun écran du portage ne mêle sprites et texte absolu aujourd'hui. À
arbitrer avec l'auteur avant de s'y engager.

### Phase 4 — le RANKING du title, vivant — PREMIÈRE MOITIÉ FAITE le 04/09/2026

Le tableau d'attract lit désormais la table **résidente**, celle qu'une fin de
partie écrit, et non plus sa copie en dur. `allscores` a disparu de
`text.asm` (273 lignes de source rendues) ; les dix entrées par défaut vivent
dans l'unité de classement, d'où le title les lit comme les autres.

**Sept chiffres au lieu de six.** Le title ne savait afficher que quatre
chiffres significatifs plus « 00 », faute d'un `DisplayDigit` 16 bits qui
plafonnait à 6 553 500 points quand notre score en autorise 9 999 900. La
conversion 24 bits est maintenant **résidente et partagée** (`ranking.digits5`)
— l'écran de fin de partie et le title ont chacun leur police, dans leur page,
mais convertissent au même endroit. Le nom recule d'une cellule.

Vérifié sous toje, boucle complète : partie avec le cheat de score, mort,
classement au rang 6, saisie de `ABBC`, retour au title, et l'attract affiche
les dix rangs dont **`No. 6  100000  ABBC`**, IREM à 75 000 poussé dehors.
Banc 7/7.

**LE TABLEAU DE FIN DE PARTIE — FAIT le 04/09/2026.** `ranking.tableScreen`
montre les dix rangs juste après la saisie, tenus 256 trames ou jusqu'à un
bouton, dans la mise en page du title (titre ligne 6 colonne 14, rangs tous les
14 px depuis la ligne 36, score colonne 17, nom colonne 27) : les deux écrans
se suivent à quelques secondes, ils devaient se ressembler.

**Deux rendus, et c'est la forme du jeu qui l'impose.** Le title dessine le
sien avec des objets et sa propre police, dans sa page ; celui-ci vit dans
l'unité résidente et emprunte la police du HUD, parce que la page du title
n'est pas chargée quand un stage tourne. Ce qu'ils partagent — la table, la
conversion des chiffres, la mise en page — est écrit une fois.

**L'entrée nouvelle est recoloriée**, comme la borne la peint dans une autre
palette. La ligne est dessinée normalement, puis relue et chaque quartet non
nul décalé de quatre : la police écrivant les index 3 à 6, la ligne passe sur
7 à 10, les rouges et orangés COMMUNS aux huit palettes de stage. Pas une
entrée de palette de plus, pas un glyphe de plus, une trentaine d'octets de
code.

**Deux corrections de finition** le même jour : « NO.n » recule d'une cellule
pour laisser deux cases vides avant la première lettre (relevé de l'auteur), et
le blanchiment des zéros de tête couvre les SEPT chiffres et non les cinq
significatifs — sans quoi un score nul s'affichait « 000 ».

**Deux régressions relevées par l'auteur le 04/09, instruites sous toje.**

- *Le continue avait disparu.* Le semis de partie fraîche remettait le quota
  à zéro par `sta game.continueUsed`, en comptant sur A resté à zéro depuis le
  `ldd #0` du score six instructions plus haut ; le cheat de score y glisse
  un `ldd #1000`, A vaut 3, le quota part consommé. Corrigé par un `clr`
  explicite (`stage-main.asm`).
- *Pas de musique à la saisie, seulement les bruitages.* Le lecteur YMM est
  entièrement sous IRQ et **décompresse toujours** ; la piste avait été
  convertie sans `-c zx0` (codec par défaut `none`), donc livrée brute :
  le lecteur lisait son troisième octet `$EF` comme une attente de 182
  trames puis bouclait sur du silence — les bruitages, purement IRQ,
  passaient. Piège aggravant : `vgm2ymm` saute en silence toute conversion
  dont la sortie est plus récente que l'entrée, il faut effacer la sortie
  brute avant de reconvertir. Reconvertie en ZX0 : 1 218 octets au lieu de
  3 588. Diagnostic par journal de l'anneau du lecteur à chaque IRQ
  (statut, attente, page, position) comparé entre le stage et l'écran.
  L'IRQ, le timer 6846 et l'init de la puce ont été mis hors de cause par
  la mesure : période de 19 968 cycles dans l'écran de saisie, avec ou
  sans resynchronisation après le chargement disque (un patch `IrqSync`
  essayé puis retiré, inutile).

Vérifié : capture continue de 44 s depuis la mort — continue (12 s), game
over, chargement, puis l'écran de saisie de 24 à 44 s dont l'audio varie
comme une mélodie (passages par zéro de 4 600 à 700 par seconde) là où la
piste brute donnait un bourdon fixe. Banc 7/7.

**Ce qui reste, et qui est de la finition** : les sprites de rang du title
découpés en « NO. » plus chiffre (818 octets à rendre, mesurés), et la palette
réordonnée pour que les lettres du tableau d'attract aient le même rendu que
sur les autres écrans — aujourd'hui son index 5 est noir, donc les lignes 2 à 4
de ses lettres sont invisibles.

### Phase 5 — config et compositions

- `scenes.stageN.music` × 8 + `scenes.title.music`, `scenes.nameentry.music`
  (direntry `common.nameentry.ymm`, page $1A, $2C09, données
  `src/common/music/adnz/ymm/rtype-name-entry.ymm` produites par `vgm2ymm`,
  à committer avec ses sources vgm/dmf déjà déposées), compositions
  `stageN.ranking` × 8.
- Chaque `main.asm` de stage : `STAGE_RANKING_COMPOSITION equ compositions.stageN.ranking`.

### Phase 6 — validation

- Corpus : images hors r-type identiques ; r-type rebuild propre
  (`rm -rf gen` avant toute conclusion).
- `rtype_bench` 7/7 inchangé.
- Sonde dédiée sous toje (à la demande de l'auteur) : partie forcée en game
  over avec un score au-dessus de 75 000 (cheat), vérifier la table en RAM
  ($51C0…), l'écran STAGE SCORE contre la maquette, la saisie de trois
  lettres + END, le tableau, le retour au title avec la table vivante ;
  même parcours sur un stage sans lot Pata-Pata résident (stage 2) pour
  exercer la convergence.
- Mesure de trames : la séquence doit tenir avec frame-drop (les compteurs
  se compensent comme le relevé de fin de stage).

## Cas limites déjà réglés par le plan

- **Score nul ou sous le dixième** (75 000 par défaut) : pas classé, retour
  au title comme aujourd'hui. Ex æquo : n'entre pas.
- **Le stage en cours au game over** : sa ligne est calculée à ce moment
  (`score − stageScoreBase`), comme le relevé de fin de stage ; les stages
  finis ont écrit la leur à leur relevé.
- **Après un continue** : le score n'est pas remis à zéro (choix antérieur),
  donc les lignes vont du stage 1 au stage courant, scores compris — pas de
  remise à zéro de la table par stage au continue, contrairement à l'arcade.
- **Saisie vide ou incomplète** (délai, END avant la 7e lettre) : les cases
  restantes sont des espaces ; RUB en première case ne fait rien.
- **Bouton A encore tenu** au sortir du GAME OVER : la saisie s'ouvre après
  36 trames et sur un front (même discipline que `hud.cont.keydown`).
- **Compensation de frame-drop** : les compteurs (révélation, délai,
  clignotement, répétition) se décrémentent de `gfxlock.frameDrop.count`
  comme le relevé.
- **Mise sous tension** : la demi-page n'est pas mise à zéro ; l'unité
  vérifie un mot magique en tête de sa table et la ré-amorce avec les dix
  entrées par défaut si le mot manque (title comme game over passent par ce
  point d'entrée, pas de crochet de boot à ajouter).
- **Retour au title** : la composition du title décharge la musique de
  saisie et le lot Pata-Pata, recharge la musique du title ; le pool
  d'objets est ré-amorcé par le title comme après tout game over.
- **Disque** : `common.nameentry.ymm` est déclaré juste après `lib.patapata`
  dans l'ordre du média, un seul déplacement de tête au game over.
- **Second tour** : 16 emplacements par stage réservés (24 o de plus que
  huit) ; seuls 1..8 sont écrits aujourd'hui.

## Les palettes : harmoniser STAGE SCORE, RANKING et le title

### Les faits (index MATÉRIELS — l'entrée 0 des PNG est la transparence, `pal.png` fait 17 entrées)

| Palette | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12–15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `Pal_stage` (les huit, 0–11 identiques) | noir | 616161 | ababab | fafaf2 | 00618f | 009ecc | 00d4eb | 610000 | ab0000 | cc6100 | fa9e61 | faf261 | propres au stage |
| `Pal_scores` (title, phase tableau) | noir | 31ffff | noir | ffffff | a5ffff | noir | 00006b | noir | 0021de | 1084ff | noir | noir | noir |
| `Pal_title` (logo, machine à écrire) | noir | 04dedc | dcdeda | cc96cc | c0fefc | dcdefc | 009ecc | dc02cc | 047274 | 04a0a4 | 9396fc | bcbefc | clairs |

Qui utilise quoi :

- **la police** (title, relevé, continue, et nos trois écrans) écrit les
  index **3, 6, 5, 4** : lignes 0–1 = 3 pour le premier pixel allumé puis
  6, lignes 2–4 = 5, lignes 5–6 = 4 (`gen_font_glyphs.py`). Sous
  `Pal_stage` : blanc / cyan / bleu / bleu sombre. Sous `Pal_title` :
  mauve / bleu / clair / cyan clair. Sous `Pal_scores` : blanc / bleu nuit /
  **noir** / cyan clair — les lignes 2 à 4 des lettres du tableau du title
  sont aujourd'hui invisibles ;
- **les sprites de rang** (« NO. » + chiffre) écrivent 1, 3, 4, 6, 8, 9 :
  cyan, blanc, cyan clair, bleu nuit, bleu, bleu moyen — `Pal_scores` a été
  générée depuis leur PNG ;
- **le Pata-Pata** écrit 3, 6, 7, 8, 9, 10, 11 (communs) **et 14, 15**
  (propres au stage : deux verts au stage 1, bruns/vert au stage 2). Sous la
  palette d'un stage sans Pata-Pata il garde des couleurs plausibles, pas
  les siennes ;
- le **logo** du title écrit 1, 3, 4, 5, 8–15 de `Pal_title` : les entrées
  3–6 de cette palette ne sont pas libres, le title garde sa palette.

### Ce que le Pata-Pata fait des index 14 et 15

Ses huit poses (9 × 18) posent 2 à 6 pixels d'index 14 et 2 à 4 d'index 15
par pose : les deux verts du stage 1 (617a00, 9ecc00), des reflets sur le
corps — image `patapata-index-14-15.png` fournie le 04/09. Sous la palette
du stage 2 ils deviennent 886838 et 308840 : plausible, pas fidèle.

### Décision (auteur, 04/09/2026) : deux palettes dédiées dérivées du stage 1

`Pal_stage` varie d'un stage à l'autre sur 12–15, dont le Pata-Pata a
besoin : l'écran de saisie prend donc une palette **dédiée, copie de celle
du stage 1** — le Pata-Pata y est natif, les lettres y ont le rendu du
relevé. Le RANKING n'a pas de Pata-Pata mais six couleurs de sprites à
loger ; sur la copie du stage 1 les entrées libres de cet écran sont 1, 2,
12, 13, 14, 15 (les gris 1–2 ne servent qu'au décor de jeu, 12–15 au stage).

| hw | `Pal_ranking.stage` (STAGE SCORE, saisie) | `Pal_ranking.table` (RANKING, attract du title) |
|---|---|---|
| 0 | noir | noir |
| 1, 2 | 616161, ababab (inutilisés) | **31ffff, a5ffff** (sprites) |
| 3, 4, 5, 6 | fafaf2, 00618f, 009ecc, 00d4eb — la police | idem — **mêmes lettres sur les deux écrans** |
| 7–11 | rouges/orangés communs (Pata-Pata, et la mise en valeur ci-dessous) | idem |
| 12, 13 | 9e8f7a, ccc2ab (stage 1, inutilisés ici) | **00006b, 0021de** (sprites) |
| 14, 15 | 617a00, 9ecc00 (Pata-Pata) | **1084ff**, libre (sprite) |

Deux fois 16 mots = **64 o** dans `common.ranking`, toujours montée : le
title y lit `Pal_ranking.table` à la place de sa `Pal_scores` générée. Les
onze PNG de rang sont écrits avec les index 1, 2, 3, 12, 13, 14 ; le blanc
des sprites (ffffff) devient le 3 de la police (fafaf2). Variante à une
seule palette (32 o) : il manque une entrée, il faudrait approcher le bleu
nuit 00006b par le 4 (00618f) — pas recommandé pour 32 o.

Transition entre les deux écrans : tampons au noir, palette posée, comme le
title entre ses phases.

### La nouvelle entrée du RANKING : en couleur, pas en clignotement (décision auteur, 04/09/2026)

L'arcade la peint en palette 7. Un marqueur `>` n'existe pas en arcade,
c'était une proposition, retirée. Mesuré dans `hud.lst` : un glyphe de la
police coûte **70 à 90 o** (lettres 87 en moyenne, 2 176 o pour A–Z, 854 o
pour les chiffres) — un second jeu de glyphes dans une autre couleur
pèserait ~3,6 Ko, exclu.

La voie économique : **recolorer après coup**. La ligne est dessinée avec
les glyphes normaux, puis une passe relit ses 17 cellules × 8 lignes × 2
plans (272 o d'écran) et remplace chaque quartet par une table de 16
entrées : 3 → 11, 6 → 10, 5 → 9, 4 → 8, le reste identique — un dégradé
jaune / saumon / orange / rouge pris dans les entrées communes 8–11, **sans
entrée de palette nouvelle**. Coût : ~60 o de code + 16 o de table ≈ **80 o**,
deux tampons à traiter, une fois par révélation de la ligne. C'est moins
que le clignotement (qui redessine 17 cellules toutes les 8 trames dans les
deux tampons) et c'est l'arcade.

## La mise en page du RANKING : le title aujourd'hui, et ce qui doit changer

Ce que fait le title (`text.asm` mode 2, `title.mountScore`) :

| Élément | Position | Détail |
|---|---|---|
| `R A N K I N G` | ligne 6, colonne 14 (x 56) | ancre au milieu du glyphe, lignes 3..10 |
| sprite de rang r | x 45, y 35 + 14 r | 18 × 9, un objet par rang |
| score | ligne 36 + 14 r, colonnes 17..22 (x 68..91) | **6 chiffres** : 4 significatifs + « 00 » (`DisplayDigit`, `ldb #4`) |
| nom | colonnes 27..33 (x 108..135) | 7 lettres |
| révélation | une ligne de plus par trame, toutes redessinées chaque trame | |

Ce qui doit changer quoi qu'on décide :

1. **7 chiffres** : notre score plafonne à 9 999 900 ; avec 4 chiffres
   significatifs le title ne sait pas afficher au-delà de 999 900 (ni le
   174 500 par défaut au-delà de six cellules). Le nom recule d'une cellule
   (x 112..139, tient dans les 160 px).
2. **La table lue en RAM** (`common.ranking`) au lieu de `allscores`.
3. **Sprites découpés** (« NO. » puis chiffre) au lieu d'une image par rang.
4. Le clignotement de la nouvelle entrée, inutile au title (rang 0).
5. La palette réordonnée ci-dessus.

Ce qui est un choix :

| | Garder la mise en page du title (pas 14, ancres actuelles) | Prendre celle de la maquette (pas 12, arcade × 0,75 + 10) |
|---|---|---|
| titre | y 6 | y 34 |
| rangs | y 35..161 | y 58..166 |
| rang r | x 45 | x 36 |
| score | x 68 | x 60 |
| nom | x 112 | x 100 |
| pour | l'attract ne change pas d'aspect ; un seul code déjà écrit à adapter | même échelle que STAGE SCORE, qui le précède de deux secondes |
| contre | le pas 14 n'est ni l'arcade (16 × 0,75 = 12) ni celui de STAGE SCORE | l'attract change |

Recommandation : **garder la mise en page du title** et ne faire que les
cinq changements obligatoires — le pas 12 vaut pour STAGE SCORE parce que
c'est l'arcade à l'échelle, mais le tableau du title est validé et vu à
chaque attract ; deux pas différents sur deux écrans qui n'ont pas la même
structure ne se remarquent pas. La révélation reste celle du title.

## Points tranchés en fin d'étude

Aucun : les quatre derniers sont tranchés (auteur, 04/09/2026).

| # | Sujet | Décision |
|---|---|---|
| 1 | Base des identifiants spécifiques | **40** — le commun gagne 32..39, dont cinq de réserve ; les ids locaux des huit stages et du title glissent de 8 (script), le garde `IFGE objid.common.count-32` devient 40, le commentaire « le 31 reste libre » est corrigé |
| 2 | Tir des Pata-Pata sur l'écran | **coupé** par un bit de sous-type |
| 3 | Émetteur de Pata-Pata | **routine du contrôleur**, pas d'identifiant de plus (le chantier en prend donc deux : `ObjID_patapata`, `ObjID_ranking`) |
| 4 | Mise en page du RANKING | **celle du title**, plus les cinq changements obligatoires (7 chiffres, table en RAM, sprites découpés, recoloration, palette) |

## Ordre et dépendances

Phase 0 conditionne tout (si la demi-page ne se charge pas, l'hôte
change). Phases 1 → 2 → 3 → 4 se suivent ; la phase 5 se fait avec la 3
(la musique) et la 4 (rien) ; la 6 clôt. Chaque phase livre un build qui
tourne et un commit.

## Risques identifiés

| Risque | Parade |
|---|---|
| chargement par la fenêtre vidéo en tranche 1 jamais exercé | phase 0.1 |
| `composition.load` au milieu d'un stage (page DATA, IRQ, ymm) | phase 0.2 |
| identifiant du Pata-Pata absent ou différent selon le stage | identifiant commun dans les huit index (section Pata-Pata) |
| code de la demi-page appelant la police de la page 7 | le corps de stage tient la page 7 montée pendant l'écran, comme pour le continue |
| budget de la demi-page dépassé (marge mesurée ~630 o avant le code réel) | les chiffres de rang peuvent repasser en police (−1 007 o) sans toucher au reste |
| `ram.const.asm` et le layout qui se croient (117 vs 63) | les trois valeurs changent dans le même commit, garde `<reserved>` du builder |
