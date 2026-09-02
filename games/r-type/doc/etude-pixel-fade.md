# Le fondu pixel de fin de stage — étude (02/09/2026)

Question posée : le fondu pixel dissout l'écran **en place** ; il ne tient que
si rien n'est repeint et que la caméra est fixe. Le décor, on sait faire
(caméra à l'arrêt). Mais le vaisseau doit être arrivé à sa destination
d'autopilote, et tout ce qui bouge encore — faisceau chargé, force pod,
bits — laisse sa trace. Quels éléments masquer, et quelles séquences selon
les stages ?

## 1. Ce que le fondu exige, et pourquoi (l'état du code)

**L'algorithme** (v1, `engine/graphics/fade/pixel-fade.asm`, extrait du
« Accolade presents ») : un motif de 80 cellules sur un pavé de 8 px × 10
lignes ; chaque appel masque à zéro UNE cellule sur tout l'écran (400 px), dans
la page vidéo montée, dans le verrou graphique ; 160 appels couvrent les deux
pages du double tampon. Il ne repasse **jamais** sur une cellule traitée : la
dissolution est cumulative, tout ce qui est repeint après elle y reste gravé.

**Ce que la boucle fait déjà** (`stage-main.asm`, phase ≥ 3 =
`endstage.PHASE_FADE`) : dès que le fondu est armé, elle saute tout le bloc
« effacer et repeindre le champ » — `clearblast`/`clearWindow`, `DrawTiles`,
le blast `mscroll` du stage 3, la peinture `pscroll` du stage 4, le drain
`tilemap.flush`. Le HUD n'est pas peint en phase 3 (le bandeau se dissout
avec le reste), le relevé de score seul en phase 4. Ne tournent plus que
`stage.frameBlit` (c'est lui le fondu) et **`BuildSprites`**.

**Le point qui change tout depuis l'overlay** : `BuildSprites` en mode
overlay dessine chaque objet visible **à chaque trame, sans effacer**. Sous
le fondu, un sprite **immobile et figé** se contente de rester peint sur le
noir — c'est même voulu pour le vaisseau et le module (« ils flottent sur le
noir jusqu'au relevé »). Un sprite qui **bouge ou s'anime** laisse chaque
état précédent gravé : traînée ou fantôme, jusqu'au relevé de score.

Corollaire : `glb_force_sprite_refresh`, que les phases 3 et 4 posent pour
« garder vaisseau et module peints sur les deux pages », **n'est plus lu par
personne** — seul le `CheckSpritesRefresh` du mode bg-erase le lisait. En
overlay, tout est redessiné de toute façon. Ces écritures sont un reste.

## 2. La séquence aujourd'hui, et ses variantes par stage

Protocole du stage 1 (`obj_endstage.asm`), repris par l'objet générique
`obj_endlevel.asm` pour les stages 2 à 8 :

| Phase | Ce qui se passe | Caméra | Joueur |
|---|---|---|---|
| 0 | jeu ; le boss est vaincu ou le « hold » expire | stage 1 : plafonnée à la salle du boss | libre |
| 1 | décompte T−$10 : jingle, **autopilote** (`player1+subtype = −2`), boutons A et B coupés à la source | plafond en place | plus de contrôle |
| 2 | glissée : plafond levé, la caméra file au bout de la carte | stage 1 : défile ; 2–8 : déjà au bout | autopilote vers le point de ralliement |
| 3 | **fondu pixel**, 160 trames, puis 0,5 s de noir | à l'arrêt, les deux tampons au plafond | à l'arrêt (vitesses nulles exigées) |
| 4 | relevé de score, 3 s, palette au noir, coupure | idem | idem |

**Le fondu n'est armé que si** les deux tampons de scroll sont au plafond ET
les vitesses du vaisseau sont nulles — l'autopilote a convergé (0,375 px par
trame en x, 0,75 en y, zone morte). Ces deux gardes existent et sont justes.

Ce qui distingue les stages, d'après le code :

| Stage | Qui lève `bossDefeated` | Particularités de rendu à l'arrêt |
|---|---|---|
| 1 | le Dobkeratops (`monster.asm`) | fond de boss = champ d'étoiles (`plainBackdrop`) ; glissée réelle jusqu'au bout de la carte |
| 2 | le Gomander (`gomander/obj.asm`) | — |
| 3 | la **fin du script du pilote** (`warship/pilot.asm`) | couche mobile `mscroll` : le blast repeint la bande chaque trame, hors fondu ; la couche reste où le script l'a laissée |
| 4 | le Compiler (`compiler/obj.asm`) | champ de gommes `pscroll`, peint en tête de trame, hors fondu ; statique dès que la caméra l'est |
| 5 à 8 | le **hold** de substitution (timeout au bout de la carte) | — |

Tous passent par le même bloc gardé : à l'arrêt, **aucun décor ne se repeint
sous le fondu**, couche mobile et champ de gommes compris. Le décor est réglé.

## 3. L'inventaire : ce qui peut encore bouger pendant les phases 1 à 4

Statut = ce que le code fait aujourd'hui ; conséquence = sous le fondu, en
overlay.

| Élément | Comportement pendant la séquence | Statut | Sous le fondu |
|---|---|---|---|
| **Vaisseau** | autopilote, s'arrête au point de ralliement ; l'inclinaison suit `y_vel` (nulle à l'arrêt) | gardé (vitesses nulles exigées) | immobile, reste peint : **voulu** |
| **Flammes de réacteur** | s'animent à chaque trame (scintillement) | **pas gardé** | fantômes derrière le vaisseau |
| **Force pod attaché** | animation de rotation permanente (durée 4 ou 8 par image) | **pas gardé** (les boutons sont coupés, pas l'animation) | fantômes sur place |
| **Force pod détaché** | continue son mouvement propre ; le rappel est impossible (bouton B coupé) | **pas gardé** | traînée |
| **Bits** | orbitent autour du vaisseau en permanence | **pas gardé** | traînées circulaires |
| **Charge du faisceau** | l'objet `beamcharge` naît quand A est tenu ; le relâchement est traité dans le bloc de contrôle du joueur — **sauté** dès la phase 1. Bouton tenu au passage en phase 1 : la charge n'est jamais relâchée, l'objet s'anime jusqu'au bout, la jauge du HUD reste pleine | **pas gardé** — le cas cité | fantômes sur le vaisseau, jauge figée |
| **Missiles du joueur** | tirés avant la phase 1, ils continuent tout droit | pas gardé | traînée s'ils sont encore à l'écran (les stages 2–8 n'ont pas de glissée : 16 trames de décompte seulement) |
| **Tirs du pod** (simple, sol, contre-air, **rebond**) | en vol ; le rebond vit longtemps | pas gardé | traînées ; le rebond est le pire |
| **Tirs ennemis** (manager foefire) | continuent tant que le manager vit | pas gardé | traînées |
| **Ennemis encore vivants** | stage 1 : plus rien après le boss ; stages 5–8 (hold) : les derniers de la vague peuvent être là ; **chaîne de scies** lancée juste avant la mort du boss : jusqu'à 2,3 s de vol | pas gardé | traînées |
| **Explosions** | s'animent | pas gardé | fantômes si l'une finit sous le fondu |
| **Boîtes à option, bonus** | dérivent | pas gardé | traînées |
| **Managers du boss** (queue, yeux) | se figent ou s'effacent sur `bossDefeated` | gardés | — |
| **Champ d'étoiles** (stage 1) | peint chaque trame par `starfield.draw`, appelé **dans le bloc gardé** (`stage-main.asm:637`) | gardé | se fige en pixels puis se dissout : voulu |
| **HUD** | phase 3 : rien ; phase 4 : relevé | gardé | voulu |

Deux constats :

- **La seule protection qui existe est « à la source » sur les boutons**, et
  elle coupe le tir, pas le mouvement ni l'animation. Rien ne gèle rien.
- **Tout ce qui a une animation propre laisse un fantôme même sans bouger** :
  flammes, pod attaché, charge, explosions. L'immobilité ne suffit pas, il
  faut aussi **figer l'image**.

## 4. Les options

**A — Le gel global au fondu (recommandée).** Dès que le fondu est armé
(passage en phase 3), la boucle ne fait plus tourner ni `RunObjects`, ni le
joueur, ni les trois slots d'armement, ni les managers : **rien ne bouge, rien
ne s'anime**, `BuildSprites` redessine des sprites strictement identiques à
la même place — inoffensif par construction. Une seule règle, dans
`stage-main.asm`, à côté de la garde qui existe déjà pour le décor. Elle
couvre d'office tout consommateur futur, comme la coupure des boutons.
S'y ajoute un **tri à l'armement** : ce qui doit rester visible sur le noir
(vaisseau, pod, bits, flammes figées) et ce qui doit disparaître (missiles,
tirs, tirs ennemis, ennemis, explosions, bonus) — un `render_hide` posé une
fois sur tout le pool sauf les slots statiques du joueur.

**B — Garde par élément.** Chaque objet lit la phase et se fige. Douze
sites, et la leçon du force pod (cinq lectures de bouton oubliées) dit que ça
ne tient pas dans le temps.

**C — N'armer le fondu que si l'écran est calme** (plus de tir ni d'ennemi
en vol). Retarde la séquence de façon imprévisible ; la chaîne de scies seule
vaut 2,3 s. Non.

## 5. Ce qui reste à décider ensemble

1. **Le faisceau tenu** : au passage en phase 1, annuler la charge —
   supprimer l'objet `beamcharge`, vider la jauge — plutôt que la laisser
   filer. Ou la faire **partir** (le relâchement forcé) ? L'arcade coupe le
   contrôle ; je propose l'annulation, sans tir.
2. **Le pod détaché** au passage en phase 1 : le rappeler au vaisseau
   (autopilote) ou le figer là où il est au fondu ? L'arcade recolle le pod
   avant l'écran Stage Cleared, il me semble — à confirmer sur vidéo.
3. **Les bits** : ils orbitent pendant l'autopilote et se figent au fondu là
   où ils sont (naturel), ou on les recolle ?
4. **Ce qui reste visible sur le noir** : vaisseau + pod + bits + flammes
   (figées), le reste masqué — ou vaisseau seul, comme l'écran arcade ?
5. **La chaîne de scies en vol** à la mort du Dobkeratops : la laisser finir
   (elle sera masquée au fondu si elle vit encore) ou la couper à
   `bossDefeated` comme le monstre coupe ses tirs ? La glissée du stage 1
   dure probablement plus que son vol ; à mesurer avant de trancher.
6. **Nettoyage** : retirer les écritures mortes de `glb_force_sprite_refresh`
   dans les deux séquenceurs, pour que le code dise ce qu'il fait.

## 6. Validation prévue

Une sonde toje qui arme la séquence par le cheat (stage 1 et un stage à
hold), capture les deux pages vidéo au dernier pas du fondu et compte les
pixels non nuls hors du vaisseau et de sa suite — zéro attendu ; puis la
vidéo de la fin de stage 1 et de la fin de stage 3 (couche mobile) pour
l'œil.
