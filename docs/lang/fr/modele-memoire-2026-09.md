# Le modèle mémoire du builder — concepts et syntaxe définitive

*Septembre 2026. Fait suite à [`analyse-page-logique-2026-09.md`](analyse-page-logique-2026-09.md),
qui pose le problème. Le plan d'exécution est dans
[`plan-modele-memoire-2026-09.md`](plan-modele-memoire-2026-09.md).*

---

## 1. Trois besoins, trois attributs

Une ressource pose trois questions distinctes, et le format actuel n'en
exprime clairement aucune :

| besoin | comment il s'exprime | exemple |
|---|---|---|
| dans quelle RAM elle vit, absolument | `page`, écrit | `$17` |
| à quelle adresse elle s'exécute, pour cuire les adresses | `address`, écrit tel que le code l'utilise | `$6100` |
| dans quel espace le loader la copie | **déduit de l'adresse** | `$6100` → fenêtre résidente |

Le troisième ne s'écrit pas : les fenêtres de la machine occupent des plages
CPU disjointes, donc une adresse en désigne une et une seule. Le seul cas où
l'adresse ne suffit pas est une fenêtre **plus petite qu'une page** — la vidéo
montre 8 Ko d'une page de 16, et `$4000` ne dit pas laquelle des deux moitiés ;
d'où l'attribut `slice`, écrit dans l'ordre naturel de la page.

**Rien d'autre n'est écrit.** En particulier, la position de la ressource dans
la page — le référentiel absolu qui sert à détecter les collisions — n'est
jamais écrite par personne : le builder la calcule.

```
position dans la page = adresse CPU modulo la taille de page
adresse physique      = page × taille de page + position
```

Cette règle est vérifiée sur les trois fenêtres de 16 Ko du TO8 (cartouche,
résidente, données) contre la source de l'émulateur toje. Ce que sa
documentation appelle « ordre non linéaire » n'est que la conséquence d'un
fait simple : la fenêtre vidéo ne fait que 8 Ko, donc elle décale tout ce qui
la suit hors de la grille de 16 Ko, et `$6000` tombe au milieu d'une page.
Il n'y a aucun câblage tordu à modéliser — les 14 bits bas de l'adresse CPU
**sont** la position dans la page.

## 2. Ce qui était cassé

Ce n'était pas la notation, c'était que :

- `page` ne voulait pas toujours dire une page. Sur `<region name="pscroll.vid"
  page="$01" address="$4000"/>`, le `1` est un **bit de demi-page**, pas la
  page 1 ;
- `address` était tantôt une adresse CPU (`$6100`), tantôt une position dans
  la page (`$1D40` sur les `<reserved>` de la page 0) — et **rien dans le
  fichier ne permet de savoir laquelle** ;
- la fenêtre n'était jamais déclarée, donc le builder ne pouvait relier ni les
  deux nombres entre eux, ni deux places entre elles.

D'où : aucun contrôle de collision entre deux places atteintes par des
fenêtres différentes ; un rapport qui groupe par `page` des adresses de
provenances incompatibles (la fameuse « page 1 » qui commence à `$4000` et
déborde de 16 Ko) ; et des conversions faites de tête, jusque dans le code du
jeu — `bullet.Slots equ objects.bullets.address+$4000`.

## 3. Syntaxe : le fichier machine

`engine/config/machine.xml` existe déjà et porte `<ram pages>` et
`<pagebyte>`. Il gagne les fenêtres ; `<pagebyte>` disparaît, absorbé par le
sélecteur de la fenêtre cartouche — toujours **par son nom**, jamais par sa
valeur, pour que le nombre reste dans son foyer unique, l'en-tête asm.

```xml
<machine name="to8">

    <ram pages="32" pagesize="$4000"/>          <!-- 512 Ko, le referentiel -->

    <!-- Une fenetre : ou le processeur la voit, quelle taille, et d'ou vient
         la page qu'elle montre. La position dans la page se calcule. -->
    <window name="cart"     address="$0000" size="$4000"
            page="register:$E7E6" mask="%00011111"
            or="map.RAM_OVER_CART" include="engine/system/to8/map.const.asm"/>

    <window name="resident" address="$6000" size="$4000" page="1"/>

    <window name="data"     address="$A000" size="$4000"
            page="register:$E7E5" mask="%00011111"/>

    <!-- La fenetre video ne montre que 8 Ko d'une page de 16 : l'adresse CPU
         ne dit donc pas LAQUELLE des deux moities. C'est le seul endroit du
         systeme ou une table est necessaire — et elle porte l'inversion du
         bit materiel, pour que personne n'ait a la connaitre. -->
    <window name="video"    address="$4000" size="$2000" page="0"
            select="register:$E7C3" bit="0">
        <slice index="0" value="1"/>            <!-- 1re moitie <- bit a 1 -->
        <slice index="1" value="0"/>            <!-- 2e  moitie <- bit a 0 -->
    </window>

</machine>
```

Trois fenêtres sur quatre sont de l'arithmétique pure. La quatrième porte deux
lignes, parce que le matériel y numérote ses moitiés à l'envers.

Le CoCo 3 se projette sans effort — huit fenêtres de 8 Ko, chacune de la
taille d'une page, donc aucune tranche :

```xml
<machine name="coco3">
    <ram pages="64" pagesize="$2000"/>
    <window name="mmu0" address="$0000" size="$2000" page="register:$FFA0" mask="%00111111"/>
    <!-- … jusqu'a mmu7 en $E000 / $FFA7 -->
</machine>
```

## 4. Syntaxe : le fichier du jeu

`page` ne s'écrit que là où la fenêtre déduite ne le fixe pas déjà : la
résidente est la page 1, la vidéo la page 0.

```xml
<layout gensymbols="gen/layout.asm">

    <!-- Cartouche : page + adresse CPU, inchangees. -->
    <region name="collision" page="$17" address="$0000" size="$4000"/>

    <!-- Residente : la fenetre fixe la page 1, on ne l'ecrit pas. L'adresse
         est celle que le code utilise. -->
    <region   name="engine"     address="$6100"/>
    <reserved name="monitor.dp" address="$6000" size="$0100"/>

    <!-- Video : 8 Ko d'une page de 16, donc on dit laquelle des deux moities,
         numerotee dans l'ordre de la page. -->
    <region   name="pscroll.vid"   slice="0" address="$4000" size="$2000"/>
    <reserved name="objects.pool"  slice="1" address="$4000" size="$1B6C"/>

    <!-- Donnees : page + adresse CPU. -->
    <reserved name="framebuffer.2.form" page="$02" address="$C000" size="$1F40"/>

    <!-- Le loader, code ET tas : son pool TLSF est un `equ *` a la fin de son
         binaire, il court jusqu'a la fin de la fenetre. Sa place les couvre
         tous les deux, sinon le builder croirait la moitie de page libre. -->
    <reserved name="loader" page="$04" address="$C000" size="$2000"/>

    <arena name="objects">
        <zone page="$04" address="$2000" size="$2000"/>
    </arena>

</layout>
```

## 5. Ce que le builder en fait

**Il calcule** la position dans la page et l'adresse physique, pour lui seul.

**Il vérifie**, avant tout le reste :

1. la place tient dans sa fenêtre — une place cartouche de 8 Ko posée en
   `$3000` déborderait sur la fenêtre vidéo et écrirait dans l'écran ; c'est
   une erreur dure, et c'est un contrôle qui n'existe pas aujourd'hui ;
2. la fenêtre peut montrer cette page (`window="video" page="$01"` est refusé :
   la vidéo est une fenêtre sur la page 0) ;
3. **les places ne se recouvrent pas en physique, toutes fenêtres confondues** —
   le contrôle qui manquait, celui qui relie la page 1 vue en résident et la
   même page 1 montée en cartouche ;
4. la place ne mord pas sur ce que la machine se réserve.

La fenêtre étant déduite, chaque fenêtre exige ses propres attributs, ce qui
attrape presque toutes les fautes de frappe qui changent d'espace : la
résidente et la vidéo refusent un `page`, la cartouche et les données
l'exigent, la vidéo exige un `slice`. **Limite acceptée** (arbitrée) : entre
cartouche et données, les deux fenêtres qui prennent une page, une adresse
fautive reste acceptée — `page="$0B" address="$A000"` au lieu de `$2000`
désigne le même silicium mais cuit l'adresse et monte la page ailleurs.

Une place peut **enjamber la fin de la page** : les neuf écrans de r-type sont
chargés en `$7C00` et dépassent `$8000`, donc ils remplissent la fin de la
page 1 puis repartent sur son début. C'est de l'arithmétique modulo, le
processeur n'y voit rien, et le contrôle de recouvrement s'applique alors aux
deux morceaux. Le rapport le dit, il ne l'interdit pas.

**Il émet** ce qu'il émettait déjà : l'adresse CPU en équate `<name>.address`,
et en `<name>.page` l'octet que le loader écrira dans le registre — le numéro
de page plus le masque nommé pour les fenêtres à registre, la valeur de la
tranche pour la vidéo, n'importe quoi pour la résidente (le runtime l'ignore).

## 6. Ce que le modèle ne fait pas

- **Ce n'est pas une description du matériel.** Les bits d'activation (RAM over
  data, write enable), l'ordre d'écriture des registres, la synchronisation
  vidéo restent dans `ram.set` et les en-têtes asm.
- **Il ne rend pas un layout portable par magie.** Un jeu qui déclare la page
  `$18` ne tient pas sur un MO6 de 8 pages ; le modèle le dira, il ne le
  réparera pas.
- **Il ne touche pas au runtime.** Aucune ligne de `loader.asm` ne change, et
  les tables de scène portent les mêmes octets qu'avant.
