# Plan de migration : le modèle mémoire

*Concepts et syntaxe : [`modele-memoire-2026-09.md`](modele-memoire-2026-09.md).
Ce plan-ci ne décide rien, il exécute.*

## Principe directeur

Le modèle recalcule les octets qu'il émettait déjà : l'adresse CPU cuite et
l'octet de page d'une table de scène sont, pour toute déclaration existante,
identiques à ceux d'aujourd'hui. D'où le critère d'acceptation de **chaque**
phase :

> le corpus froid (80 images, `ci/build-corpus.sh` après `rm -rf dist gen`) est
> identique octet pour octet, `loader-ut` passe 18/18 et `rtype_bench` 7/7.

Toute divergence est un défaut du modèle, pas un effet de bord acceptable.
Seule la phase 3 est autorisée à déplacer des octets, et seulement ceux du
loader.

## Ampleur réelle

Les quatre fenêtres du TO8 occupent des plages CPU disjointes, donc **la
fenêtre se déduit de l'adresse** et ne s'écrit nulle part (décision auteur,
option A). Conséquence : la très grande majorité des déclarations ne change
pas d'un caractère.

| ce qui change | combien |
|---|---|
| places cartouche, résidentes et données déjà écrites en adresse CPU | **0** (inchangées) |
| `<region name="pscroll.vid">` : `page="$01"` (un bit de demi-page) → `slice="0"` | 1 |
| `<reserved>` de la page 0 : positions dans la page → adresses CPU + `slice="1"` | 3 |
| `<reserved name="pscroll.vid.half1">` : redondant avec la région, supprimé | 1 |
| `<reserved>` framebuffers : positions → adresses CPU, noms remis à l'endroit et mis en anglais (`form`/`color`) | 4 |
| le loader : deux `<define>` manuscrits → une place déclarée | 1 |
| code assembleur | **1 ligne**, et c'est une simplification |

---

## Phase 0 — la machine décrit ses fenêtres

`engine/config/machine.xml` gagne `<ram pagesize>` et les `<window>` du
document de référence, pour TO8 et MO6. Côté Java : `Machines.Machine` porte
les fenêtres, `MachineDefs` les décode (avec `fichier:ligne` comme le reste),
et une classe `WindowMap` répond aux quatre questions du builder — quelle
fenêtre pour cette adresse, quelle position dans la page, quelle adresse CPU
pour cette position, quel octet de sélecteur.

Aucun consommateur : rien ne change dans les images. `<pagebyte>` reste en
place, il sera retiré en phase 1.

**Validation** : tests unitaires portant la table mesurée — la règle du modulo
sur les trois fenêtres de 16 Ko, l'inversion du bit vidéo (tranche 0 ↔ bit 1),
et les refus (une adresse hors de toute fenêtre, une place qui déborde sa
fenêtre, `window="video" page="$01"`).

## Phase 1 — le builder cuit par la fenêtre

Les places acceptent `window` (facultatif, vérifié) et `slice` (obligatoire
pour une fenêtre plus petite qu'une page). En interne, une place devient
`(page, position dans la page)`, et tout ce qui produisait une adresse CPU ou
un octet de page passe par `WindowMap` : `gensymbols`, les tables de scène,
`<tilemap>`, les pagesets. `<pagebyte>` est retiré de `machine.xml`, son
`expr`/`include` devenant l'attribut `or` du sélecteur cartouche.

**Validation** : corpus froid identique. C'est ici que se prouve l'équivalence
du calcul ; si une image bouge d'un octet, la phase ne passe pas.

## Phase 2 — les contrôles

Quatre, dans l'ordre où ils coûtent : débordement de fenêtre (erreur dure),
page inatteignable par la fenêtre, **recouvrement en physique toutes fenêtres
confondues**, et empiètement sur ce que la machine se réserve. Une place qui
enjambe la fin de la page est **légale** ; son empreinte est alors deux
plages, et les contrôles s'appliquent aux deux.

Le troisième contrôle va trouver des choses — au minimum le doublon
`pscroll.vid` / `pscroll.vid.half1`. Chaque trouvaille est consignée puis
corrigée dans la déclaration, jamais contournée par une exception.

**Validation** : corpus froid identique après correction, `loader-ut` 18/18,
`rtype_bench` 7/7.

## Phase 3 — le loader devient une place

```xml
<reserved name="loader" window="data" page="$04" address="$C000" size="$2000"/>
```

`loader.PAGE` et `loader.ADDRESS` cessent d'être deux `<define>` manuscrits :
ce sont des équates générées depuis cette place.

**La taille couvre le code ET le tas.** Le pool TLSF du loader est un
`equ *` à la fin de son binaire (`loader.memoryPool`), dimensionné par
`loader.ADDRESS - loader.memoryPool + $2000` : il court jusqu'à la fin de la
fenêtre. Sur r-type, code `$C000-$D0FD` puis pool `$D0FF-$E000`, soit la
**première moitié entière de la page 4** en physique (`+$0000-$1FFF`). Ce pool
est aujourd'hui totalement invisible au builder — rien n'empêcherait d'y
déclarer une place. Le contrôle qui vient avec : la somme du binaire et du
pool doit tenir dans la taille déclarée, et le pool ne doit pas déborder la
fenêtre.

Deux choses en découlent sans règle en dur : les octets du loader entrent dans
le contrôle de recouvrement (rien ne les protégeait, et l'arène des objets
partage sa page), et **la liste des espaces de chargement se déduit** — les
fenêtres de la machine moins celle d'où le loader s'exécute, ce qui redonne
exactement cartouche, vidéo et résident.

C'est la seule phase où des octets peuvent bouger : si les deux `<define>` ne
décrivaient pas exactement la place réelle du loader, l'écart apparaît ici.

**Validation** : `loader-ut` 18/18 (le banc exerce les trois espaces), corpus
froid, `rtype_bench` 7/7, et une lecture machine de la table de saut du loader
à l'adresse calculée.

## Phase 4 — le rapport dans le référentiel absolu

`occupancy-<cible>.html` passe à **une ligne par page physique** (32 sur TO8),
la fenêtre devenant une annotation portée par chaque bloc (« vu en `$4000`,
fenêtre vidéo »). Un fichier qui enjambe la fin de la page est dessiné en deux
morceaux, avec la mention qui l'explique. La « page 1 » qui commençait à
`$4000` et débordait de 16 Ko disparaît d'elle-même : son contenu vidéo
retourne sur la ligne de la page 0.

Le sélecteur de composition est conservé tel quel.

## Phase 5 — migration des déclarations

Les onze déclarations du tableau d'ampleur, à la main, chacune relue contre la
table des fenêtres. Puis la vieille forme sort des specs : une `<reserved>`
dont l'adresse n'est pas une adresse CPU valide de sa fenêtre est refusée par
le `Validator`, avec sa position et son candidat. `docs/schema/gamebuilder.xsd`
est régénéré, et `<layout pages="…">` — redondant avec `<ram pages>` — retiré.

L'unique ligne d'assembleur :

```asm
bullet.Slots    equ objects.bullets.address+$4000     ; avant
bullet.Slots    equ objects.bullets.address           ; apres
```

**Validation** : corpus froid identique — la même place physique produit les
mêmes octets quelle que soit la façon dont elle est écrite.

## Phase 6 — la documentation

`docs/lang/en/memory.md` (la page de manuel du modèle), les extraits de
`scenes.md` et `groups.md` qui écrivent encore une position dans la page, et la
section de CLAUDE.md renvoyant aux deux documents. Pas de cas de migration : la
v1 n'avait pas de fenêtres déclarées, il n'y a pas d'idiome v1 à traduire.

---

## Points ouverts

1. *(tranché — la fenêtre est déduite, jamais écrite ; la limite acceptée est
   qu'une confusion cartouche/données reste indétectable, les deux étant les
   seules fenêtres à prendre un `page`.)*
2. **L'enjambement de fin de page : le rapport l'explique, sans rien exiger.**
   Le vrai danger — une place qui déborde sa **fenêtre** — est un contrôle
   séparé et une erreur dure.
3. **Le MO6** est mis de côté (décision auteur) : ses fenêtres seront décrites
   le jour où on s'y intéresse. Les images MO6 ne dépendent pas de
   l'hypothèse, puisque la traduction adresse CPU → position → adresse CPU est
   un aller-retour.
4. **Le packer d'arènes** range en `(page, adresse)` ; à relire pour vérifier
   qu'il ne peut pas déborder une fin de fenêtre. Le contrôle de la phase 2 le
   couvre, mais la lecture reste à faire.
5. **Qui pose les bits `RAM_OVER_CART`** : `ram.set` les ajoute au runtime et
   les tables générées les écrivent déjà. Inoffensif (idempotent), mais le
   modèle doit désigner un responsable.
