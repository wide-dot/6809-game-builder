# Le modèle des régions — doctrine d'organisation mémoire

Statut : **doctrine validée et implémentée** (31/07/2026) — campagne close :
vérifications par scène, régions `bulk`, encodage `%11` automatique, equates
de layout. Seul le §7 (adresses calculées) reste en veille jusqu'au portage
R-Type. Référence utilisateur : [`docs/lang/en/scenes.md`](../en/scenes.md).

Ce document explique **comment décider du découpage mémoire d'un jeu** dans le
builder v2, et pourquoi les règles sont ce qu'elles sont. Il complète
[`groups.md`](../en/groups.md) (le modèle couches/régions) et
[`scenes-declaratives-2026-07.md`](scenes-declaratives-2026-07.md) (le plan
d'implémentation).

---

## 1. L'invariant

Tout découle d'un seul fait technique. Le loader identifie « cette mémoire
appartient maintenant à quelqu'un d'autre » par la **destination exacte**
(page + adresse) : quand un fichier s'enregistre en (p, a), l'unload implicite
retire de l'index le fichier qui y était. C'est le seul mécanisme d'éviction
automatique, et il compare des adresses, pas des plages.

> **Deux ressources ne peuvent se relayer que si elles partagent une adresse
> fixe, connue au build et stable d'une variante à l'autre.**

Une région, c'est exactement ça : une adresse fixe partagée. D'où la règle qui
gouverne tout le reste :

> ## La région est l'unité de remplacement. Pas le fichier.

Une région n'est pas « un endroit où ranger des choses », c'est **un point
d'échange**. La question à se poser en déclarant un layout n'est donc pas
« comment je découpe ma mémoire ? » mais :

> **Combien de choses ai-je besoin de remplacer indépendamment les unes des
> autres ?**

Autant de réponses, autant de régions.

### Ce que le builder vérifie — et ce qu'il ne vérifie pas (décision 31/07)

On compose des briques **réutilisables** et de tailles **hétérogènes** — c'est
le but même du link dynamique. Chaque composition a donc sa propre carte
mémoire, et le code du jeu enchaîne les compositions dans un ordre que le
builder ne voit pas.

La ligne de partage est donc :

- **le builder vérifie une composition** (une scène) : pas d'écritures qui se
  chevauchent en son sein, budgets respectés, cohérence des fichiers vides ;
- **les enchaînements appartiennent au code** : deux régions peuvent se
  chevaucher, deux scènes peuvent utiliser la même page différemment — c'est à
  l'auteur de décharger ce qu'il faut avant de charger par-dessus (`unload`,
  `isLoaded`). Aucun contrôle global de chevauchement n'est imposé au build :
  ce serait exiger une carte mémoire unique pour tout le jeu, le placement
  statique de la v1 qu'on cherche justement à quitter.

« Même adresse = éviction automatique » n'est pas une loi imposée : c'est **le
motif qui ne coûte rien**. Deux ressources qui se relaient à la même adresse
n'ont besoin d'aucun unload ; à des adresses différentes, l'unload explicite
est le prix de la liberté.

### Pourquoi « unload » ne suffit pas

Le mot induit en erreur. `loader.file.linkData.unload` (indexé par
`[disk id][file id]`) fait deux choses : `tlsf.free` sur le **buffer de link
data**, et retrait du slot d'index. Les données du fichier ne sont pas
touchées — et il n'y a rien à toucher : elles sont chargées à une destination
fixe dans une page, jamais allouées depuis le pool. Seule la petite table de
relocations vit dans le TLSF.

`unload` signifie donc : **« arrête de suivre ce fichier au relink »**. Pas
« rends-moi la RAM ». Il n'existe aucun moyen de « libérer » une zone pour y
mettre autre chose : on écrit par-dessus, et c'est l'écriture à la **même
adresse** qui déclenche l'éviction propre. D'où l'invariant.

---

## 2. Vocabulaire

| Terme | Ce que c'est | Dans la config |
|---|---|---|
| **direntry** (= *group*) | l'unité de chargement : un fichier du répertoire, éventuellement composé de plusieurs membres (asm, bin, converti) concaténés | `<direntry name="...">` |
| **région** | une destination fixe (page + adresse) qui accueille une ressource à la fois | `<region name="..." page="..." address="..."/>` |
| **scène** | la liste de ce qu'on charge en une fois, et où | `<scene name="...">` |
| **load** | une ligne de scène : quel direntry, dans quelle région | `<load name="..." region="..."/>` |

Rappel de `groups.md` : **un group est un direntry multi-membres**. Plusieurs
fichiers qui vivent et meurent ensemble ne forment pas une région à plusieurs
entrées — ils forment **un seul direntry** dont lwasm concatène les membres.

---

## 3. Cas d'usage

### UC1 — Un point d'échange (le cas nominal)

*« La musique change entre l'écran-titre et le niveau 1. »*

C'est `examples/sound`, et c'est le cas qui ne coûte rien : même région, donc
même destination, donc éviction implicite propre et garantie.

```xml
<layout>
  <region name="gamemode" page="$01" address="$6100" size="$1F00"/>
  <region name="ymm.data" page="$06" address="$0400" size="$3C00"/>
  <region name="vgc.data" page="$07" address="$0A80" size="$3580"/>
</layout>
...
<scene name="scenes.title" section="SCENE">
  <load name="assets.gm.title"         region="gamemode"/>
  <load name="assets.sounds.title.ymm" region="ymm.data"/>
  <load name="assets.sounds.title.vgc" region="vgc.data"/>
</scene>

<scene name="scenes.level1" section="SCENE">
  <load name="assets.sounds.level1.ymm" region="ymm.data"/>
  <load name="assets.sounds.level1.vgc" region="vgc.data"/>
</scene>
```

**Le « différentiel » est ici, et il est écrit à la main** : `scenes.level1` ne
liste que ce qui change. Rien ne le calcule au runtime, et c'est voulu — c'est
la décision qui a fait abandonner `loadDelta`.

`size` est le budget du point d'échange : il doit contenir **la plus grosse des
variantes** (ici `level1.ymm`, 4032 octets), pas la première déclarée.

### UC2 — Chargé une fois, jamais remplacé

*« Le player YMM est chargé au boot et ne bouge plus. »*

Pas de mécanisme dédié : c'est une région comme les autres, que seule la scène
de boot référence.

```xml
<region name="ymm.player" page="$06" address="$0000" size="$0400"/>
<region name="vgc.player" page="$07" address="$0000" size="$0A80"/>
```

(Un attribut `permanent` avait été envisagé pour verrouiller ce cas au build ;
retiré le 31/07 : même logique que pour le chevauchement — le builder ne
connaît pas les séquences, il n'a pas à figer des intentions de durée de vie.
La convention de nommage et la revue de la config suffisent.)

### UC3 — Plusieurs fichiers à une même destination

*« Mon niveau, c'est une tilemap + des tuiles compilées + une table
d'ennemis. »*

**Ce n'est pas une région à trois `<load>`.** Trois contenus qui vivent et
meurent ensemble = **un direntry multi-membres** (un group) :

```xml
<direntry name="group.level1" codec="zx0" loadtimelink="LINK">
  <bin filename="src/levels/1/tilemap.bin"/>
  <lwasm gensource="gen/levels/1/tiles.asm">
    <asm filename="src/levels/1/tiles.asm"/>
  </lwasm>
  <lwasm gensource="gen/levels/1/waves.asm">
    <asm filename="src/levels/1/waves.asm"/>
  </lwasm>
</direntry>
...
<scene name="scenes.level1">
  <load name="group.level1" region="level"/>
</scene>
```

Avantages : un seul id, une seule compression (meilleur ratio), un seul slot
d'index, et le loader n'a jamais à connaître les membres. Les offsets de link
data des membres sont décalés automatiquement (c'est ce que la phase 2 de la
revue Java a débloqué, épinglé par T16 de `loader-ut`).

Un group doit tenir dans **une page de 16 Ko** (`direntry.maxsize`) ; au-delà,
on déclare plusieurs groups et donc plusieurs régions.

### UC4 — Fichiers d'interface (link data seule)

*« Ces constantes ne portent aucune donnée, elles exportent juste des
symboles. »*

Un `<load>` **sans destination** : le fichier est vide (drapeau `$ff00`), il
n'occupe aucune mémoire, seule sa link data est enregistrée.

```xml
<scene name="scenes.title" section="SCENE">
  <load name="assets.gm.title" region="gamemode"/>
  <!-- link data seule : ni région, ni page/adresse -->
  <load name="engine.system.to8.sound.ym.const"/>
  <load name="engine.system.to8.sound.sn.const"/>
</scene>
```

Ces fichiers partagent la pseudo-destination (0, 0) et sont **exemptés** de
l'éviction par destination — sans quoi ils s'évinceraient les uns les autres
(bug attrapé le 30/07 par `loader-ut`).

### UC5 — Un lot de données remplacé en bloc

*« 9 blocs de données son à charger à la suite dans la page 5 ; je ne veux pas
maintenir 9 adresses qui changent à chaque ré-encodage d'un VGM. »*

C'est `examples/mplus` (`to8-mplus-test`, `mo6-mplus-test`), migré le
31/07/2026 — une région `bulk` accueille une liste :

```xml
<region name="sound.data" page="$05" address="$0000" size="$6000" bulk="true"/>
...
<scene name="scenes.title" section="SCENE">
  <load name="assets.gm.title" region="gamemode"/>

  <!-- région bulk : n loads, placés à la suite dans l'ordre déclaré.  -->
  <!-- Le builder calcule chaque destination à partir des tailles.     -->
  <load name="assets.sounds.samples"  region="sound.data"/>
  <load name="assets.sounds.sn"       region="sound.data"/>
  <load name="assets.sounds.sn.noise" region="sound.data"/>
  <load name="assets.sounds.ym"       region="sound.data"/>
  <load name="assets.sounds.ym.rythm" region="sound.data"/>
  <load name="assets.sounds.mea8000"  region="sound.data"/>
  <load name="assets.sounds.sn.music" region="sound.data"/>
  <load name="assets.sounds.ym.music" region="sound.data"/>
</scene>
```

**Le prix à payer, et c'est le cœur du sujet** : les membres d'une région
`bulk` n'ont **pas d'adresse fixe propre** — seule la base l'est. Ils ne sont
donc **pas remplaçables individuellement**. La région entière est l'unité de
remplacement.

Concrètement :

- unloader un membre seul *fonctionne* (l'unload est indexé par file id), mais
  ne rend aucune mémoire réutilisable : le trou n'est adressable par personne,
  puisque la disposition est recalculée depuis la liste entière ;
- recharger **toute la liste** est sûr, même si une taille a changé : la dédup
  par file id met à jour la destination de chaque membre ;
- ce qui est dangereux, c'est de charger une **liste différente** dans la même
  région : les membres survivants peuvent voir leur mémoire recouverte alors
  que leur slot les déclare toujours là → le relink global écrit dedans.

La vérification est locale à la scène : la somme des tailles tient dans le
budget de la région. Deux scènes peuvent mettre des listes différentes dans la
même région `bulk` — c'est une composition différente, et l'enchaînement
appartient au code (décharger l'ancienne liste avant si nécessaire).

**Si tu veux remplacer une ressource individuellement, elle doit avoir sa
propre région.** Il n'y a pas de contournement.

### UC6 — Destination brute (échappatoire)

*« Ce fichier n'est pas une ressource de jeu, c'est une astuce de
chargement. »*

`examples/mplus/to8-mplus-pcm` charge un `dummyfile` à une demi-page
uniquement pour forcer le loader à changer de page avant les samples :

```xml
<scene name="scenes.title" section="SCENE">
  <load name="assets.gm.title" region="gamemode"/>
  <!-- destination brute : pas un point d'échange, une astuce de placement -->
  <load name="dummyfile" page="$00" address="$4000"/>
  <load name="assets.samples" region="samples"/>
</scene>
```

`page`/`address` restent autorisés, sans les garanties d'une région. À réserver
à ce qui n'est **pas** une ressource remplaçable — sinon on perd exactement ce
que le modèle apporte.

### UC7 — Multi-disquette

Le `<layout>` est déclaré au niveau du **target**, donc partagé par toutes les
disquettes ; une scène vit sur sa disquette et charge ses fichiers.

```xml
<layout>
  ...
  <region name="disk1.marker" page="$06" address="$1800" size="$0400"/>
</layout>

<floppydisk model="fd640">          <!-- disquette 1 -->
  <directory id="1" ...>
    <direntry name="d1.marker" codec="zx0" loadtimelink="LINK">...</direntry>
    <scene name="d1.scenes.main" section="SCENE">
      <load name="d1.marker" region="disk1.marker"/>
    </scene>
  </directory>
</floppydisk>
```

Les file ids étant globaux au target, un fichier est identifié sans ambiguïté
entre disquettes, et les symboles se résolvent dans les deux sens (validé par
T15/T16 de `loader-ut`).

### UC8 — Cible R-Type (illustratif, à confirmer au portage)

Application des couches de `groups.md` au jeu visé — avec les libertés du
modèle : deux découpages **différents de la même page** (le title voit la
page $04 comme un logo plein écran, le jeu la voit comme map + ennemis), et un
lot `bulk` pour les effets sonores.

```xml
<layout>
  <!-- chargés au boot, plus jamais touchés : des régions ordinaires,
       que seule la scène de boot référence -->
  <region name="engine"       page="$01" address="$6100" size="$1F00"/>
  <region name="sound.player" page="$06" address="$0000" size="$0400"/>

  <!-- commun à toute une partie : rechargé au changement de famille d'état -->
  <region name="player.sprites" page="$02" address="$0000" size="$2000"/>
  <region name="hud"            page="$02" address="$2000" size="$0800"/>

  <!-- points d'échange par niveau : level1, level2... s'y relaient -->
  <region name="level.tiles"   page="$03" address="$0000" size="$4000"/>
  <region name="level.map"     page="$04" address="$0000" size="$2800"/>
  <region name="level.enemies" page="$04" address="$2800" size="$1800"/>
  <region name="level.music"   page="$06" address="$0400" size="$3C00"/>

  <!-- la MÊME page $04, vue autrement par l'écran-titre : les régions
       peuvent se chevaucher, ce sont deux compositions différentes.
       Le code décharge l'une avant de charger l'autre. -->
  <region name="title.logo"    page="$04" address="$0000" size="$4000"/>

  <!-- lot bulk : liste placée à la suite, remplacée en bloc (proposé) -->
  <region name="sfx"           page="$05" address="$0000" size="$2000" bulk="true"/>
</layout>

<scene name="scenes.title" section="SCENE">
  <load name="group.gm.title"    region="engine"/>
  <load name="group.title.logo"  region="title.logo"/>
  <load name="group.title.music" region="level.music"/>
</scene>

<scene name="scenes.level1" section="SCENE">
  <load name="group.gm.level1"      region="engine"/>
  <load name="group.level1.tiles"   region="level.tiles"/>
  <load name="group.level1.map"     region="level.map"/>
  <load name="group.level1.enemies" region="level.enemies"/>
  <load name="group.level1.music"   region="level.music"/>
  <!-- bulk : n loads, adresses calculées par le builder, budget vérifié -->
  <load name="sfx.shot"    region="sfx"/>
  <load name="sfx.boom"    region="sfx"/>
  <load name="sfx.powerup" region="sfx"/>
  <!-- interfaces : link data seule -->
  <load name="engine.system.to8.sound.ym.const"/>
</scene>
```

Côté code, la transition title → level1 s'écrit :

```
        _loader.file.linkData.unload #0,#group.title.logo  ; la page $04 change de découpage
        ldx   #scenes.level1
        jsr   loader.scene.load
```

`level.music` n'a pas besoin d'unload : title et level1 s'y relaient à la même
adresse — c'est le motif qui ne coûte rien. `title.logo` en a besoin : la même
mémoire est recomposée autrement.

Ce qu'on lit tout de suite dans cette déclaration, et qu'aucune table
manuscrite ne montrait : **ce qui est stable, ce qui est commun, ce qui
s'échange, et où deux compositions se partagent la même mémoire** — plus le
budget de chaque point d'échange, qui devient une contrainte de production
(« le niveau 3 dépasse `level.tiles` de 300 octets » au build, pas à
l'exécution).

---

## 4. Table de décision

| Besoin | Déclaration |
|---|---|
| une ressource que je remplace par une autre | **une région dédiée**, une variante par scène |
| plusieurs ressources qui vivent et meurent ensemble | **un direntry multi-membres** (group), une région |
| une ressource chargée une fois pour toutes | une région ordinaire, référencée par la seule scène de boot |
| des constantes / interfaces sans données | un `<load>` **sans destination** |
| un lot de données jamais remplacé individuellement | une région `bulk` |
| une astuce de placement, pas une ressource | `page`/`address` bruts |
| du contenu > 16 Ko | plusieurs groups, donc plusieurs régions |

---

## 5. Ce qui est vérifié au build

Déjà actif (phase A) :

1. un `<load>` référence un direntry ou une scène qui existe ;
2. région inconnue (avec la liste des régions déclarées) ;
3. une même région chargée deux fois dans une scène (avec le conseil : en faire
   un direntry multi-membres) ;
4. `region` **et** `page`/`address` sur le même `<load>` ;
5. attributs inconnus ou mal typés, via le contrat d'attributs général.

Proposé (phase B) — **tout est local à une scène** :

6. taille **décompressée** de chaque fichier ≤ `size` de sa région ;
7. dans une même scène, deux chargements ne s'écrivent pas l'un sur l'autre
   (destinations explicites, régions, et destinations calculées d'un lot
   `bulk` comprises) ;
8. cohérence export-only : `<load>` sans destination ⇔ fichier vide, dans les
   deux sens ;
9. `bulk` : somme des tailles de la liste ≤ `size` ;
10. avertissement : scène mélangeant des fichiers de plusieurs disquettes.

**Pas de contrôle de chevauchement entre régions ni entre scènes** (décision
31/07, cf. §1) : les compositions sont hétérogènes par nature, l'ordre des
chargements appartient au code.

---

## 6. L'encodage est automatique et invisible

Les trois types de blocs du loader existent pour une raison : **la compacité de
la table de scène**, qui est `malloc`ée dans le pool TLSF au chargement (3,5 Ko
seulement dans `loader-ut`). Coûts relevés dans `loader.asm` :

| n fichiers | `%01` | `%10` | `%11` |
|---|---|---|---|
| 2 | 12 | 9 | **7** |
| 6 | 32 | 17 | **7** |
| 9 | 47 | 23 | **7** |
| 16 | 82 | 37 | **7** |

`%01` = 5 octets/fichier ; `%10` = 3 octets de base + 2/fichier ; `%11` =
**7 octets fixes**, quel que soit *n*.

Aucun type n'est écrit par l'auteur. Le builder connaît toutes les
destinations et toutes les tailles : il détecte les suites exactement
contiguës et émet le codage le moins cher. Pour `%11`, il vérifie en plus que
les ids se suivent selon la règle de parcours du loader
(`id += 1 + compressé + linké`, soit exactement le `blockCount()` du builder).

Conséquence pratique : cette optimisation **change les octets des tables**, donc
elle ne peut pas se valider par identité binaire. Elle se validera par
exécution (`loader-ut` sous toje, qui exerce précisément les lots export-only et
les échanges), dans un commit séparé.

---

## 7. Extension proposée : adresses calculées (modèle overlay)

Aujourd'hui l'auteur écrit **les adresses et les budgets** à la main. Le
builder pourrait calculer les deux, comme le font les linkers avec les
overlays :

> adresse du slot *k* = base + Σ **max**(tailles de toutes les variantes des
> slots précédents)

Chaque slot reçoit la place de sa plus grosse variante. On obtient des adresses
**calculées** (plus rien à maintenir), **fixes** (donc chaque slot reste un
point d'échange, contrairement à `bulk`), et un budget **exact** déduit du
contenu réel. Le prix : de la mémoire perdue quand les variantes sont très
inégales — le compromis classique.

Avant :

```xml
<region name="ymm.player" page="$06" address="$0000" size="$0400" permanent="true"/>
<region name="ymm.data"   page="$06" address="$0400" size="$3C00"/>
```

Après (opt-in, une région à adresse explicite reste inchangée) :

```xml
<autolayout page="$06">
  <region name="ymm.player" permanent="true"/>
  <region name="ymm.data"/>
</autolayout>
```

Ce serait une étape **distincte et postérieure** à la phase B : elle change les
adresses, donc les images.

## 8. Extension : exporter les régions en equates — FAIT (31/07/2026, attribut `gensymbols` sur `<layout>`)

Le game mode d'`examples/sound` contient :

```
page.ymm equ map.RAM_OVER_CART+6  ; ram page that contains ymm player and sound data (as defined in scene file)
```

Le commentaire avoue la duplication. Le load-time linker règle déjà la moitié
du problème — les *adresses* arrivent par symboles exportés (`sounds.title.ymm`)
— mais la **page** reste recopiée à la main.

Si le builder exportait les régions dans le fichier de symboles généré, comme il
le fait déjà pour les file ids :

```
ymm.data.page    equ 6
ymm.data.address equ $0400
```

…le code jeu écrirait `_ram.cart.set #ymm.data.page` et la duplication
disparaîtrait. C'est le prérequis naturel du §7 : dès que les adresses sont
calculées, le code jeu **doit** les recevoir du builder.

---

## 9. Ce qui reste interdit, et pourquoi

- **Deux `<load>` avec région dans la même région d'une scène** (hors `bulk`) :
  c'est un group, pas deux entrées.
- **L'empilage runtime authorable hors `bulk`** : les destinations dériveraient
  avec les tailles, et une région dont l'adresse bouge n'est plus un point
  d'échange.
- **Le recouvrement partiel d'un fichier encore lié** reste LE danger runtime :
  les tailles ne sont pas suivies dans l'index, l'éviction ne se déclenche que
  sur adresse exacte, et le relink écrirait dans les données du nouveau. Ce
  n'est pas au build de l'empêcher (il ne connaît pas les séquences) : c'est la
  discipline `unload` avant de charger par-dessus à une autre adresse. Le filet
  automatique, si un jeu en a besoin un jour, est le suivi des tailles dans
  l'index côté loader (éviction par plage — différé).
- **`loadDelta`** (calcul runtime du différentiel) : abandonné, cf.
  `groups.md`. Le différentiel est de l'authoring.

---

## 10. Points à valider

1. La ligne de partage « le builder vérifie une composition, pas les
   enchaînements » — actée le 31/07, `permanent` retiré dans la foulée
   (même logique : le builder ne fige pas des intentions de durée de vie).
2. `bulk` — le nom (vs `pack`, `sequence`).
3. Le périmètre de la phase B : les vérifications 6 à 10 du §5.
4. Les extensions §7 (adresses calculées) et §8 (equates de région) : à
   planifier, ou à laisser en veille jusqu'au portage R-Type ?
