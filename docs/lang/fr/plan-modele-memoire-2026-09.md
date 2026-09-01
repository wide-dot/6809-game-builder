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

### Ce qui a réellement été fait (01/09/2026), et les écarts

Faite en resserrant sur ce qui **porte des octets chargés** : `<region>`,
`<zone>` et les places brutes de `<file>` sont lues à travers la fenêtre —
laquelle montre cette adresse, cette page peut-elle y être montrée, les octets
restent-ils dedans. `slice` est déclarable. Quatre écarts, tous consignés :

1. **Le contrôle ne porte que sur la passe réelle.** La passe de découverte
   place ce qui n'a pas de taille mesurée sur une page entière, donc des
   régions empilées sur une page atterrissent en `$4000`, `$8000`… et dans des
   fenêtres qu'elles ne verront jamais. Deux configs l'ont montré tout de
   suite (`stageinit` de r-type, `ymm.data` de sound MO6). La passe réelle a
   les mesures et contrôle tout.
2. **La lecture héritée de la vidéo est traduite, pas refusée** :
   `page="$01" address="$4000"` voulait dire « demi-page 1 » et non « page 1 ».
   `WindowMap.resolve` le traduit, ce qui évite de migrer quoi que ce soit ce
   jour-là. La traduction part avec les déclarations, en phase 5.
3. **`<reserved>` garde sa coordonnée héritée** — une position dans la page,
   là où `<region>` écrit une adresse CPU. C'est la troisième coordonnée du
   fichier, et elle se règle en phase 5 avec la ligne d'assembleur des tirs.
4. **`<pagebyte>` n'a pas bougé** : le déplacer vers l'attribut `or` de la
   fenêtre cartouche est de la déduplication sans effet, à faire en phase 5
   avec le reste des déclarations.

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

### Ce qui a réellement été fait (01/09/2026), et les écarts

Les comparaisons passent dans le référentiel absolu là où elles portent :
recouvrement par composition, zone contre plage réservée, et chargement contre
plage réservée. Le cas qui n'existait pas est vérifié sur le jeu réel — une
région en `$0000` (cartouche) et une réservation en `$C000` (données) sont
désormais reconnues comme **le même silicium**, « both are page 23
+$0000-$00FF ».

**La migration des `<reserved>` de la page 0 est faite ici, pas en phase 5** :
sans elle les contrôles auraient comparé des coordonnées fausses. Les objets
passent en `slice="1"` avec leurs adresses CPU (`$4000`, `$5B6C`, `$5D40`),
`pscroll.vid.half1` disparaît — la région `pscroll.vid` occupe déjà cette
moitié, elle était son doublon dans l'autre système — et
`bullet.Slots equ objects.bullets.address+$4000` perd son `+$4000`. Les 80
images restent identiques : c'est la preuve que les deux écritures désignaient
bien le même endroit.

Trois écarts :

1. **Le recouvrement intra-scène de `SceneChecks` n'est pas converti.** Une
   scène appartient à une composition, donc chacune de ses paires est déjà
   comparée en physique par `CompositionChecks` ; convertir ne changerait que
   le libellé, au prix de quinze appels de test.
2. **Un fichier dont le contenu mesuré sort de sa fenêtre est un
   AVERTISSEMENT, pas une erreur.** Les samples de `mplus-pcm` couvrent
   24 Ko depuis `$0000` et traversent trois fenêtres délibérément — le config
   le dit en commentaire. Le builder ne peut pas dire quel silicium c'est : il
   le nomme et le laisse hors des comparaisons plutôt que de faire semblant.
   Une **région** déclarée qui déborde reste, elle, une erreur dure.
3. **Les contrôles se taisent sur une cible sans machine** : les cibles
   « assets » des exemples mplus ne décrivent aucune mémoire, et leur réclamer
   une machine arrêterait un build parfaitement formé.

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

### Ce qui a réellement été fait (01/09/2026), et les écarts

**Aucun octet n'a bougé** — donc les deux `<define>` décrivaient bien la place
réelle du loader. Les trois comportements sont vérifiés sur le jeu :

- une zone d'arène qui mord sur le loader est refusée, et le message relie les
  deux fenêtres : *region 'objects' [$0100-$3FFF] runs into the reserved range
  'loader' [$C000-$DFFF] — both are page 4 +$0000-$1FFF*. C'est exactement le
  scénario que j'avais pris pour « 3 840 octets libres » ;
- les deux descriptions ne peuvent plus diverger : *reserved range 'loader'
  starts at $C000 but loader.ADDRESS says $A000* ;
- un chargement dans la fenêtre du loader est refusé, en disant pourquoi :
  *loads at $A000, in the 'data' window — the loader runs from there, and
  mounting a page in it would unmap the loader mid-copy*.

Trois écarts :

1. **`loader.PAGE` et `loader.ADDRESS` restent des `<define>`**, contrairement
   à ce que cette phase annonçait. Le binaire du loader est assemblé contre eux
   bien avant qu'un layout existe, et son unité n'inclut pas `gen/layout.asm`.
   Mieux : lwasm ignore la casse, donc l'équate `loader.address` qu'une
   réservation émet **est** le symbole `loader.ADDRESS` — les émettre tous deux
   est une erreur d'assemblage, et c'est cette erreur qui a rendu la règle
   explicite : *le builder ne redéclare pas ce que le jeu déclare, il vérifie
   que les deux concordent*. La duplication devient une vérification, ce qui
   était le but.
2. **Les deux `<define>` remontent avant le `<layout>`** : ils décrivent la
   mémoire, et la vérification a besoin d'eux quand elle lit la réservation.
3. **La taille est déclarée, pas déduite.** L'étendue du pool vient d'une
   formule d'assembleur propre à la machine (`loader.ADDRESS -
   loader.memoryPool + $2000` sur TO8, `+$4000` sur MO6) : le builder ne peut
   pas l'inférer sans lire la carte de symboles du loader.

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
