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

### 2.4 d7/t2 : le profil d'encodage est un défaut de target

La différence d7/t2 mesurée tient en un mot : le **profil** — `B0` en
disquette, `B0,B1` en cartouche (draw : `D0`/`D0,D1`). Proposition :

```xml
<target name="fd">
    <default name="images.profile" value="B0"/>      <!-- d7 : sans pré-décalé -->
    …
<target name="t2">
    <default name="images.profile" value="B0,B1"/>   <!-- t2 : avec -->
```

Une ligne `<images mirror="x"/>` compose sa variante complète :
`X` + chaque code du profil → `XB0` (fd) ou `XB0,XB1` (t2). **Les
déclarations d'objets deviennent identiques entre targets** — les mêmes
lignes, les mêmes fichiers ; la différence d7/t2 tient en UNE ligne de
défaut par target. Le vocabulaire est celui de la v1 (`NB0`, `XB1`…), déjà
parlé par les deux mondes et par check_variants. Une ligne peut toujours
donner son code complet (`encoders="ND0,ND1"`) quand elle échappe au profil
(les tuiles draw au milieu d'un projet bdraw).

## 3. Ce que ça change, chiffré

- scant : 18 lignes de config → 2 ; l'ennemi type tient en ~8 lignes
  (file + lwasm + unit + 2 images) ;
- les 340 blocs `<image>` → ~60 lignes `<images>` + les exceptions ;
- le portage d'un ennemi : copier les png en les numérotant (l'ordre est
  celui des properties d7), écrire 2 lignes — plus de bloc à coller depuis
  `gen_enemy_unit.py` ;
- le futur target t2 : dupliquer l'arbre du target (structure v2 normale)
  avec UNE ligne de profil différente — aucune liste d'images à réécrire.

## 4. Points ouverts (à trancher avec la validation)

1. **Étendue du renommage maintenant** : seulement les objets déjà portés
   (12 ennemis + explosion + armes, geste borné, prouvé par identité), les
   ~60 restants étant nommés AU portage ? Ou tout le stock v1 d'un coup ?
   Recommandation : les portés maintenant, la règle pour la suite.
2. **`names=` par défaut** : le nom du fichier hôte (`stage1.scant` →
   `set_stage1.scant_N` ?) ou un attribut toujours explicite ? Les noms
   actuels (`set_scant_0`) plaident pour `names=` déduit du répertoire
   d'images (`scant`) — à confirmer sur les 52 blocs réels.
3. **Le profil et les tuiles** : les tilesets (draw, `ND0/ND1`) suivent-ils
   le même défaut de target (`images.profile`) ou un profil séparé
   (`tiles.profile`) ? Les deux existent dans les mêmes targets.
