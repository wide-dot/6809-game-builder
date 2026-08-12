---
date: 2026-08-12
sujet: Organisation des ressources images pour la déclaration compacte (7b) —
  répertoires, noms de fichiers, et la gestion d7/t2 — mesurée sur la référence
  v1 (thomson-to8-game-engine, properties game-mode et d7/t2).
statut: proposition, rien d'implémenté
s'appuie sur: plan-migration-cible-2026-08.md (phase 7b),
  analyse-charge-manuelle-2026-08.md
---

# Les images en forme compacte : l'organisation qui rend le match possible

La forme compacte (`<images dir=… >`) suppose que **l'ordre des fichiers
soit l'ordre des index** et que **la distinction d7/t2 soit exprimable sans
dupliquer les listes**. Ni l'un ni l'autre n'est vrai des ressources
actuelles, copiées de la v1 avec leurs noms. D'où ce relevé de la référence,
puis la proposition.

## 1. Ce que la référence v1 dit vraiment (mesuré)

Source : `thomson-to8-game-engine/game-projects/r-type` — les
`main.<target>.properties` de game-mode (liste ordonnée des objets) et les
`obj.d7/t2.properties` par objet (liste ordonnée des images, avec variantes).

1. **L'ordre ne vient PAS des noms de fichiers.** Il vient des clés
   `sprite.Img_<nom>=<png>;<variantes>`, dans l'ordre du fichier properties.
   Preuve : player1 déclare `rship_4.png` en premier (Img_Player_up_1) et
   `rship_0.png` en dernier (Img_Player_down_1) — l'ordre des index est
   INVERSE du tri des noms. Un `match` trié sur les noms actuels produirait
   un index faux, silencieusement.
2. **d7 et t2 partagent les mêmes fichiers.** Sur tout le projet, les deux
   seules « divergences » de listes sont des lignes commentées (hud,
   counterairlaser). La vraie différence est le **jeu de variantes** : la
   disquette compile `NB0/XB0`, la cartouche ajoute les pré-décalées
   `NB1/XB1` (la place de la ROM achète la vitesse).
3. **Le vocabulaire des variantes est petit et déjà commun aux deux mondes** :
   `[N|X|Y|XY][B|D][0|1]` — miroir, encodeur bdraw/draw, décalage. 831×NB0,
   444×NB1, 340×ND0, 250×XB0… (`NDMAP0` n'existe que commenté). C'est
   exactement ce que les `<encoder>` v2 épellent en trois attributs.
4. **Les images d'un objet se groupent en SÉRIES homogènes** : une suite de
   fichiers qui partagent les mêmes variantes. player1 = la série vaisseau
   (5 png, NB0,NB1) puis la série explosion (8 png, NB0). Le miroir est une
   série qui RE-liste les fichiers d'une autre (scant : 0-2 en N, 3-5 = les
   mêmes png en X). Les cas vraiment hétérogènes (variante par image) sont
   rares — c'est l'exception, pas la forme.
5. Volumes : 65 images max pour un objet (dobkeratops), deux sous-répertoires
   d'images seulement dans toute la v1, 340 blocs `<image>` côté v2.

## 2. La proposition

### 2.1 Les répertoires : un répertoire = une série

```
src/enemies/scant/
    scant.unit.asm
    obj.asm
    images/                      ← série unique : directement ici
        00.png  01.png  02.png
src/common/player/
    images/
        ship/                    ← une série homogène par répertoire
            00-up2.png
            01-up1.png
            02-level.png
            03-down1.png
            04-down2.png
        explosion/
            00.png … 07.png
```

- **Un répertoire = une série** : tous ses fichiers partagent les mêmes
  variantes et se suivent dans l'index. Un objet à série unique les met
  directement dans `images/` ; un objet à plusieurs familles fait un
  sous-répertoire par famille (c'est la structure que la v2 a déjà donnée à
  dobkeratops : imgFace, imgNerves0-2).
- Le miroir n'est pas un répertoire : c'est une seconde déclaration du MÊME
  répertoire (§2.3).

### 2.2 Les noms : `NN[-label].png`

- **`NN` à deux chiffres, préfixe obligatoire, tri numérique** : l'ordre du
  répertoire EST la numérotation. 65 images max mesurées — deux chiffres
  suffisent.
- **`-label` libre et optionnel** : la sémantique humaine (`00-up2.png`)
  survit au renommage ; les ennemis n'en ont pas besoin (`scant/images/00.png`
  se lit par son chemin).
- **Le renommage absorbe les bizarreries d'ordre v1** : la numérotation est
  assignée depuis l'ordre des properties de la CIBLE d7 (la conf disquette
  fait foi, comme pour check_variants), pas depuis les noms actuels —
  l'inversion rship disparaît dans le renommage au lieu d'être portée par la
  déclaration.
- Une **table de renommage committée** (`ancien chemin → nouveau`) trace le
  geste : `v1-map.csv` est mis à jour (contenus identiques à l'octet, seule
  la colonne chemin bouge), et `check_variants.py` la lit pour continuer à
  rapprocher v2 et properties v1.

### 2.3 La déclaration : une ligne par série

```xml
<gfxcomp file="stage1.scant" …>
    <images dir="src/enemies/scant/images"/>                <!-- index 0-2 -->
    <images dir="src/enemies/scant/images" mirror="x"/>     <!-- index 3-5 -->
</gfxcomp>
```

- une ligne `<images>` = une série : les fichiers du répertoire, triés sur
  `NN`, aux index qui CONTINUENT la déclaration précédente du même gfxcomp ;
- `mirror=` re-liste le même répertoire dans l'autre sens de la symétrie —
  la forme du motif scant/dobkeratops ;
- `match=` optionnel (filtre) pour les cas résiduels ; l'`<image>` unitaire
  d'aujourd'hui reste valide au milieu, les index se suivent — c'est
  l'exception pour l'hétérogène ;
- les symboles se dérivent : `set_<base>_<index>`, `base` = attribut
  `names=` (défaut : le nom du fichier hôte). Pour les ennemis déjà portés,
  la dérivation redonne EXACTEMENT les noms actuels (`set_scant_0..5`) —
  l'identité binaire reste donc la preuve sur eux. Les rares bases multiples
  (explosion : expSmall/expFwk) posent `names=` par ligne.

### 2.4 d7/t2 : le défaut de target ne porte que les DÉCALAGES

Corrigé sur l'avertissement de l'auteur (12/08) — « le défaut d7 en B0 ne
veut pas dire qu'on n'aura pas des B1 aussi » — et la mesure lui donne
raison : **les d7 contiennent 39 NB1 et 13 ND1** (player1, tout
dobkeratops, foefire…). La comparaison objet par objet donne le motif
complet :

- 22 objets suivent « t2 = d7 + pré-décalées » (le gros des ennemis et
  projectiles) ;
- player1 et dobkeratops sont IDENTIQUES entre d7 et t2 — déjà décalés en
  disquette : le vaisseau et le boss bougent pixel par pixel, la d7 paie le
  surcoût pour eux seuls ;
- l'inverse existe aussi : l'explosion du player reste `NB0` même en t2.
- **Toutes les exceptions par image sont invariantes entre cibles** — aucun
  cas mesuré où une même image porte des jeux différents ET non déductibles
  du défaut dans les deux cibles.

Le défaut de target ne porte donc QUE la liste de décalages ; l'encodeur et
le miroir restent sur la ligne :

```xml
<target name="fd">
    <default name="images.shifts" value="0"/>      <!-- d7 : sans pré-décalé PAR DÉFAUT -->
    …
<target name="t2">
    <default name="images.shifts" value="0,1"/>    <!-- t2 : avec, par défaut -->
```

Une ligne compose sa variante : miroir de la ligne + encodeur de la ligne
(`bdraw` si absent, `encoder="draw"` pour les tuiles) + décalages du
target → `XB0` (fd) ou `XB0,XB1` (t2). Une ligne peut dire `shifts=` en
dur, dans les deux sens : `shifts="0,1"` (player1, dobkeratops — décalés
même en d7) ou `shifts="0"` (l'explosion du player — jamais décalée, même
en t2). Ces exceptions étant invariantes entre cibles, **les déclarations
d'objets restent identiques d'un target à l'autre** ; seule la ligne de
défaut change. Le même défaut sert les sprites (B) et les tuiles (D)
puisqu'il ne parle plus d'encodeur — la question « profil des tuiles » du
§4 se dissout.

## 3. Ce que ça change, chiffré

- scant : 18 lignes de config → 2 ; l'ennemi type tient en ~8 lignes
  (file + lwasm + unit + 2 images) ;
- les 340 blocs `<image>` → ~60 lignes `<images>` + les exceptions ;
- le portage d'un ennemi : copier les png en les numérotant (l'ordre est
  celui des properties d7), écrire 2 lignes — plus de bloc à coller depuis
  `gen_enemy_unit.py` ;
- le futur target t2 : dupliquer l'arbre du target (structure v2 normale)
  avec UNE ligne de profil différente — aucune liste d'images à réécrire.

## 4. Points ouverts et décisions

1. **Étendue du renommage : TOUT le stock v1 d'un coup** (décision auteur,
   12/08). La table de renommage couvre les ~60 objets non portés en plus
   des portés : leurs répertoires et noms v2 sont assignés dès maintenant
   depuis l'ordre des properties d7, pour que chaque portage à venir trouve
   ses fichiers déjà en place.
2. **`names=` par défaut** : d'où vient le « scant » de `set_scant_0` quand
   plus personne ne l'écrit par image ? Proposition : du RÉPERTOIRE de la
   série — `…/scant/images/` → `scant`, `…/player/images/ship/` → `ship` —
   ce qui redonne exactement les noms actuels des ennemis ; `names=`
   explicite quand le nom voulu ne s'en déduit pas (`names="expSmall"` sur
   la famille small de l'explosion). EN ATTENTE de validation.
3. ~~Le profil et les tuiles~~ — dissous par la correction du §2.4 : le
   défaut ne portant que les décalages, sprites (bdraw) et tuiles (draw)
   partagent la même ligne de défaut.
