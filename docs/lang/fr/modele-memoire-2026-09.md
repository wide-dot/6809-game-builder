# Le modèle mémoire du builder — concepts et syntaxe définitive

*Septembre 2026. Fait suite à [`analyse-page-logique-2026-09.md`](analyse-page-logique-2026-09.md),
qui pose le problème ; ce document-ci fixe les concepts et la syntaxe. Le
plan d'exécution est dans [`plan-modele-memoire-2026-09.md`](plan-modele-memoire-2026-09.md).*

---

## 1. Le problème, établi par la mesure

Aujourd'hui, un `<region>`, un `<zone>` ou un `<reserved>` se déclare avec
`page` et `address`. Ni l'un ni l'autre ne désigne quelque chose de stable :

| ce qui est écrit | ce que ça veut dire | où |
|---|---|---|
| `page="$06" address="$0400"` | page RAM 6, adresse CPU dans la fenêtre cartouche | `<region>` cartouche |
| `page="$01" address="$4000"` | **demi-page 1**, adresse CPU dans la fenêtre vidéo | `<region name="pscroll.vid">` |
| `page="$01" address="$6100"` | page RAM 1, adresse CPU dans la fenêtre résidente | `<region name="engine">` |
| `page="$00" address="$2000"` | page RAM 0, **décalage dans la page** | `<reserved>` de la page 0 |

Quatre sens pour deux attributs. Le builder ne peut donc rien vérifier entre
deux places qui ne passent pas par la même fenêtre : il compare des nombres
qui ne parlent pas de la même chose.

### Ce que le matériel fait réellement

Le gate array du TO8 ne présente pas les pages de la même façon dans toutes
les fenêtres. Vérifié sur machine (trois relevés sous toje, pages 0, 1 et 4)
puis confirmé dans la source de l'émulateur (`MemoryPager.update*()`) et sa
documentation technique, qui parle d'« ordre NON LINÉAIRE » et d'« effet
direct du câblage non-linéaire du gate array TO8 » :

| fenêtre | plage CPU | page montée | décalage dans la page |
|---|---|---|---|
| cartouche | `$0000-$3FFF` | registre `$E7E6` (bits 0-4, + overlay bit 5) | **linéaire** : `$0000`→`+$0000` |
| vidéo | `$4000-$5FFF` | page 0, fixe | demi-page par `$E7C3` bit 0 : **1**→`+$0000`, **0**→`+$2000` |
| résidente | `$6000-$9FFF` | page 1, fixe | **non linéaire** : `$6000`→`+$2000`, `$8000`→`+$0000` |
| données | `$A000-$DFFF` | registre `$E7E5` | **non linéaire** : `$A000`→`+$2000`, `$C000`→`+$0000` |

La conséquence tient en un exemple, tiré du jeu tel qu'il est aujourd'hui :

- le loader est déclaré `PAGE=4, ADDRESS=$C000` — donc page 4, **décalage `$0000`** ;
- l'arène des objets offre `<zone page="$04" address="$2000" size="$2000"/>` —
  donc page 4, **décalage `$2000`**.

Les deux ne se recouvrent pas, et c'est heureux : `common.anim` y est rangé.
Mais leur non-recouvrement n'est écrit nulle part et n'est vérifié par rien —
il tient à ce que l'auteur ait fait la conversion de tête, entre deux systèmes
de coordonnées qui ne se parlent pas. Une zone élargie à `size="$4000"`
poserait une animation sur la table de saut du loader, sans un mot du build.

Deux autres symptômes de la même cause :

- le rapport d'occupation dessine une « page 1 » qui commence à `$4000` et
  déborde des 16 Ko : il regroupe par numéro de page des adresses CPU issues
  de fenêtres différentes ;
- `<region name="pscroll.vid" page="$01" address="$4000">` et
  `<reserved name="pscroll.vid.half1" page="$00" address="$2000">` décrivent
  le même silicium — le config le dit en commentaire — dans deux systèmes de
  coordonnées, et rien ne relie les deux déclarations.

---

## 2. Les quatre concepts

### 2.1 Le référentiel absolu

Un octet de RAM a une identité et une seule : **son adresse physique**.

```
physique = page × pagesize + offset
```

La machine déclare `pages` et `pagesize` (TO8 : 32 × 16 Ko ; MO6 : 8 × 16 Ko ;
CoCo 3 : 64 × 8 Ko). Toute place du jeu se déclare dans ce référentiel, et
**tous les contrôles s'y font**. Deux places se recouvrent si leurs intervalles
physiques se croisent — quelle que soit la fenêtre par laquelle on les atteint.

C'est le point qui règle le cas du résident : la fenêtre résidente est une
fenêtre sur la page 1, et cette même page 1 montée en cartouche est le même
intervalle physique. Le modèle le sait ; le builder actuel ne peut pas le savoir.

### 2.2 La fenêtre

Une fenêtre est **ce que le processeur voit**, et comment se choisit ce qu'il
voit. Elle est faite de :

- un **sélecteur de page** : soit une valeur fixe (vidéo → page 0, résident →
  page 1), soit un champ de registre (cartouche → `$E7E6`, données → `$E7E5`) ;
- une ou plusieurs **vues** : chaque vue relie une plage d'adresses CPU à une
  plage de décalages dans la page. C'est là que se déclare la non-linéarité,
  et c'est le seul endroit du système où elle apparaît.

Une vue peut être conditionnée par un **sous-sélecteur** (la demi-page vidéo) :
la vue porte alors la valeur qui l'active.

Rien d'autre. La fenêtre ne décrit pas le matériel — elle décrit exactement ce
dont le builder a besoin : traduire `(page, offset)` en adresse CPU, et en
l'octet que le runtime écrira dans le registre.

### 2.3 La place

Une place — `<region>`, `<zone>`, `<reserved>` — dit **où** dans le référentiel
absolu (`page`, `offset`, `size`) et **par quelle fenêtre** on l'atteint
(`window`). Les deux besoins que tu as séparés y sont, distincts et explicites :

- `page`/`offset` répondent à *où vont les ressources, dans le référentiel
  absolu de la RAM, peu importe la fenêtre* ;
- `window` répond à *par quelle fenêtre on l'exécute, pour cuire les adresses*.

### 2.4 L'espace de chargement

Au runtime, le loader doit savoir dans quel espace copier et décompresser.
Cet espace **ne se déclare pas** : il se déduit.

Le loader est une place comme une autre — il vit quelque part
(`page 4, offset $0000, window="data"` sur le TO8). Monter une autre page dans
la fenêtre d'où il s'exécute le démonterait en plein travail. Donc :

> **les espaces de chargement = les fenêtres de la machine, moins celle d'où le
> loader s'exécute.**

Sur TO8 et MO6, le loader vit dans la fenêtre données : il reste cartouche,
vidéo et résident — exactement les trois espaces que `ram.set` sait servir
aujourd'hui. Sur une machine où le loader vivrait ailleurs, la liste change
sans qu'une ligne du modèle bouge.

---

## 3. Syntaxe : le fichier machine

`engine/config/machine.xml` existe déjà et porte `<ram pages>` et `<pagebyte>`.
Il gagne les fenêtres ; `<pagebyte>` disparaît, absorbé par le sélecteur de la
fenêtre cartouche — au même endroit que le reste, et toujours **par son nom**,
jamais par sa valeur.

```xml
<machine name="to8">

    <ram pages="32" pagesize="$4000"/>          <!-- 512 Ko, le referentiel -->

    <!-- Fenetre cartouche : la page vient d'un registre, la vue est lineaire.
         'or' est un NOM defini par l'en-tete asm de la machine : le nombre
         reste dans son foyer unique. -->
    <window name="cart" address="$0000" size="$4000">
        <select register="$E7E6" mask="%00011111"
                or="map.RAM_OVER_CART" include="engine/system/to8/map.const.asm"/>
        <view offset="$0000"/>
    </window>

    <!-- Fenetre video : page 0 fixe, la demi-page vient d'un bit.
         Chaque vue dit ce que vaut la valeur du selecteur. -->
    <window name="video" address="$4000" size="$2000">
        <page value="0"/>
        <select register="$E7C3" bit="0"/>
        <view value="1" offset="$0000"/>
        <view value="0" offset="$2000"/>
    </window>

    <!-- Fenetre residente : page 1 fixe, vues NON LINEAIRES (gate array). -->
    <window name="resident" address="$6000" size="$4000">
        <page value="1"/>
        <view address="$6000" size="$2000" offset="$2000"/>
        <view address="$8000" size="$2000" offset="$0000"/>
    </window>

    <!-- Fenetre donnees : page par registre, memes vues non lineaires. -->
    <window name="data" address="$A000" size="$4000">
        <select register="$E7E5" mask="%00011111"/>
        <view address="$A000" size="$2000" offset="$2000"/>
        <view address="$C000" size="$2000" offset="$0000"/>
    </window>

</machine>
```

Règles de lecture, sans exception :

- pas de `<page>` **et** pas de `<select register>` de page → la fenêtre ne
  montre qu'une page, fixe ;
- une `<view>` sans `address` couvre toute la fenêtre ; sans `offset`, elle est
  l'identité ;
- une `<view value>` n'existe que si la fenêtre a un sélecteur de sous-page.

Le MO6 est le même fichier avec d'autres nombres (`pages="8"`, vidéo en
`$0000`, résident en `$2000` sur la page 1, données en `$6000`, cartouche en
`$B000`, demi-page par `$A7C0` bit 0). **La non-linéarité de ses fenêtres
résidente et données reste à confirmer** — il n'y a pas d'émulateur MO6 ici ;
d'ici là elles sont déclarées comme sur TO8, ce qui est l'hypothèse la plus
probable (même gate array) et n'engage que les contrôles, pas les images.

Le CoCo 3 se projette sans effort — huit fenêtres de 8 Ko, toutes identiques,
toutes linéaires :

```xml
<machine name="coco3">
    <ram pages="64" pagesize="$2000"/>          <!-- 512 Ko en blocs de 8 Ko -->
    <window name="mmu0" address="$0000" size="$2000">
        <select register="$FFA0" mask="%00111111"/><view offset="$0000"/>
    </window>
    <!-- … mmu1 $2000/$FFA1 … jusqu'a mmu7 $E000/$FFA7 -->
</machine>
```

---

## 4. Syntaxe : le fichier du jeu

Une place se déclare dans le référentiel absolu, et nomme sa fenêtre. Le
`<layout>` porte la fenêtre par défaut — la plupart des places d'un jeu sont
dans la même.

```xml
<layout window="cart" gensymbols="gen/layout.asm" gencompositions="gen/compositions.asm">

    <!-- Cartouche : page + decalage dans la page. -->
    <region name="collision"   page="$17" offset="$0000" size="$4000"/>
    <region name="music"       page="$06" offset="$0400" size="$3C00"/>

    <!-- Resident : la fenetre fixe la page, on ne l'ecrit pas. -->
    <region   name="engine"     window="resident" offset="$2100" size="$1B00"/>
    <region   name="stage"      window="resident" offset="$3C00" size="$0400"/>
    <reserved name="monitor.dp" window="resident" offset="$2000" size="$0100"/>

    <!-- Video : page 0 fixe, les deux moities de la page 0. -->
    <reserved name="objects.pool"  window="video" offset="$0000" size="$1B6C"/>
    <region   name="pscroll.vid"   window="video" offset="$2000" size="$2000"/>

    <!-- Le loader est une place comme une autre : d'ou son adresse CPU, son
         octet de page, ET la liste des espaces de chargement. -->
    <reserved name="loader" window="data" page="$04" offset="$0000" size="$10FE"/>

    <!-- Une arene : ses zones sont dans le referentiel, sa fenetre est celle
         par laquelle le contenu sera atteint. -->
    <arena name="objects" window="cart">
        <zone page="$04" offset="$2000" size="$2000"/>
        <zone page="$18" offset="$0000" size="$4000"/>
    </arena>

</layout>
```

`address` disparaît des places. Ce n'est pas un renommage : pour une place
résidente ou données, **le nombre change** (`$6100` devient `$2100`), et un
renommage mécanique aurait gardé silencieusement de faux nombres. Pour les
places cartouche — 156 des 173 de r-type — le nombre est inchangé, la fenêtre
cartouche étant linéaire.

---

## 5. Ce que le builder en fait

**Il vérifie**, avant tout le reste :

1. la fenêtre existe ; elle peut montrer cette page (`window="video" page="$01"`
   est refusé : la vidéo n'a pas de sélecteur de page) ;
2. la place tient dans une vue (une place à cheval sur deux vues non contiguës
   est refusée — sur TO8, une place résidente de 16 Ko est légale, une place de
   12 Ko à partir de `$1000` ne l'est pas) ;
3. les places ne se recouvrent pas **en physique**, toutes fenêtres confondues,
   et ne mordent pas sur une zone que la machine se réserve ;
4. aucune destination de chargement n'est dans la fenêtre d'où le loader
   s'exécute.

**Il calcule**, au lieu de faire confiance :

- l'adresse CPU = `vue.address + (offset − vue.offset)`, publiée en équate
  (`engine.address`, `loader.ADDRESS`…) ;
- l'octet de page que la table de scène porte = la valeur du sélecteur de page
  (plus le masque `or` nommé), ou la valeur de la vue quand le sélecteur est un
  sous-sélecteur. **Ce calcul reproduit exactement les octets émis aujourd'hui**
  — c'est la propriété qui rend la migration prouvable image par image.

**Il dessine** le rapport dans le référentiel : une ligne par page physique
(32 × 16 Ko sur TO8), la fenêtre devenant une annotation — « atteint par la
fenêtre vidéo, vu en `$4000` ». La page 1 qui commençait à `$4000` et débordait
disparaît d'elle-même.

---

## 6. Ce que le modèle ne fait pas

- **Ce n'est pas une description du matériel.** Les bits d'activation (RAM over
  data, write enable), l'ordre d'écriture des registres, la synchronisation
  vidéo restent dans `ram.set` et les en-têtes asm. Le fichier machine ne porte
  que ce dont le builder a besoin pour calculer une adresse et un octet.
- **Il ne rend pas un layout portable par magie.** Un jeu qui déclare la page
  `$18` ne tient pas sur un MO6 de 8 pages ; le modèle le dira, il ne le
  réparera pas.
- **Il ne décide pas des demi-pages vidéo à la place de l'auteur.** Il rend
  seulement impossible de décrire la même demi-page de deux façons
  contradictoires — ce que `pscroll.vid` et `pscroll.vid.half1` font aujourd'hui.
- **Il ne touche pas au runtime.** Aucune ligne de `loader.asm` ne change ; les
  tables de scène portent les mêmes octets qu'avant.
