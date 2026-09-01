# Plan de migration : le modèle mémoire

*Concepts et syntaxe : [`modele-memoire-2026-09.md`](modele-memoire-2026-09.md).
Ce plan-ci ne décide rien, il exécute.*

## Principe directeur

Le modèle a une propriété qui rend la migration prouvable : **il recalcule les
octets qu'il émettait déjà**. L'adresse CPU cuite et l'octet de page d'une
table de scène sont, pour toute déclaration existante, identiques à ceux
d'aujourd'hui. Donc :

> **critère d'acceptation de chaque phase : le corpus froid (80 images,
> `ci/build-corpus.sh` après `rm -rf dist gen`) est identique octet pour octet,
> `loader-ut` passe 18/18 et `rtype_bench` 7/7.**

Toute divergence est un défaut du modèle, pas un effet de bord acceptable. La
seule phase autorisée à changer des octets est la 3, et seulement ceux du
loader — le jour où ses deux `<define>` manuscrits deviennent des équates
calculées, l'un d'eux pourrait s'avérer faux (c'est le but).

## Ampleur mesurée

| à migrer | combien |
|---|---|
| `<layout>` de configs | 8 (7 exemples + r-type) |
| places `<region>`/`<zone>`/`<reserved>` | 195, dont **173 dans r-type** |
| dont le **nombre change** (résident, données, vidéo) | **17**, toutes dans r-type |
| destinations brutes `page=`/`address=` sur `<file>`/`<data>` | 62 réparties sur 20 configs |
| machines à décrire | 2 (TO8 mesuré, MO6 par analogie) |

---

## Phase 0 — la machine décrit ses fenêtres

`engine/config/machine.xml` gagne `<ram pagesize>` et les `<window>` du
document de référence, pour TO8 et MO6. Côté Java : `Machines.Machine` porte
la liste des fenêtres, `MachineDefs` les décode (avec `fichier:ligne` comme le
reste), et une classe `WindowMap` répond aux trois questions du builder —
`cpuOf(window, page, offset)`, `physicalOf(window, cpuAddress)`,
`selectorByte(window, page, offset)`.

Aucun consommateur : rien ne change dans les images. `<pagebyte>` reste en
place, il sera retiré en phase 1.

**Validation** : tests unitaires portant la table TO8 mesurée — `resident $6000
↔ page 1 +$2000`, `data $C000 ↔ +$0000`, `video bit 1 ↔ +$0000`, cartouche
identité — plus les refus (`window="video" page="$01"`, place à cheval sur deux
vues non contiguës). Corpus inchangé par construction.

## Phase 1 — le builder calcule au lieu de croire

Les places acceptent `window` + `offset`. **L'ancienne forme reste acceptée**
et est traduite à l'entrée : `address` seul est une adresse CPU, la fenêtre
s'en déduit comme le fait `ram.set` aujourd'hui (`$0000`→cartouche,
`$4000`→vidéo, `$6000`→résident, `$A000`→données), et le couple `(page,
address)` devient un couple physique. En interne, **il n'existe plus qu'une
représentation** : `(page, offset, window)`.

Tout ce qui produisait une adresse CPU ou un octet de page passe par
`WindowMap` : `gensymbols`, les tables de scène, `<tilemap>`, `gensymbols` des
pagesets. `<pagebyte>` est retiré de `machine.xml`, son `expr`/`include`
devenant l'attribut `or` du sélecteur cartouche.

**Validation** : corpus froid identique. C'est ici que se prouve l'équivalence
du calcul ; si une image bouge d'un octet, le modèle est faux quelque part et
la phase ne passe pas.

## Phase 2 — les contrôles, en physique

Quatre contrôles, dans l'ordre où ils coûtent :

1. déclaration hors d'atteinte (fenêtre inconnue, page impossible, place à
   cheval sur deux vues) ;
2. place hors des bornes de la RAM déclarée (`pages × pagesize`) ;
3. **recouvrement en physique, toutes fenêtres confondues** — le contrôle qui
   n'existait pas ;
4. recouvrement avec une zone que la machine se réserve.

Le contrôle 3 va trouver des choses : au minimum `pscroll.vid` et
`pscroll.vid.half1`, qui décrivent le même silicium dans deux systèmes de
coordonnées. Chaque trouvaille est **consignée puis corrigée dans la
déclaration**, jamais contournée par une exception ; si une correction déplace
des octets, elle fait l'objet de son propre commit avec la mesure avant/après.

**Validation** : corpus froid identique après correction des déclarations,
`loader-ut` 18/18, `rtype_bench` 7/7.

## Phase 3 — le loader devient une place

```xml
<reserved name="loader" window="data" page="$04" offset="$0000" size="$10FE"/>
```

La taille n'a même pas à être écrite : le builder assemble le loader, il la
connaît — `size` y est donc facultatif, et une valeur écrite qui contredit le
binaire est une erreur.

`loader.PAGE` et `loader.ADDRESS` cessent d'être deux `<define>` manuscrits :
ce sont des équates générées depuis cette place. La liste des espaces de
chargement se déduit (les fenêtres moins celle du loader), et un cinquième
contrôle s'ajoute : **aucune destination de chargement dans la fenêtre d'où le
loader s'exécute**.

C'est la seule phase où des octets peuvent bouger : si les deux `<define>`
d'une config ne décrivaient pas exactement la place réelle du loader, l'écart
apparaît ici. On le mesure et on tranche avant de continuer.

**Validation** : `loader-ut` 18/18 (le banc exerce les trois espaces), corpus
froid, `rtype_bench` 7/7, et une lecture machine de la table de saut du loader
à l'adresse calculée.

## Phase 4 — le rapport dans le référentiel absolu

`occupancy-<cible>.html` passe à **une ligne par page physique** (32 sur TO8,
8 sur MO6), la fenêtre devenant une annotation portée par chaque bloc (« vu en
`$4000`, fenêtre vidéo »). La page 1 qui commençait à `$4000` et débordait des
16 Ko disparaît d'elle-même — c'était le symptôme, pas un défaut du rapport.

Le sélecteur de composition (phase 5 du chantier précédent) est conservé tel
quel ; il ne concerne pas les coordonnées.

**Validation** : lecture du rapport de r-type, page par page, contre le
`link-report` et le `pool-map` — les mêmes octets rangés autrement.

## Phase 5 — migration des configs, retrait de l'ancienne forme

Les 195 places et les 62 destinations brutes passent à la notation cible.
156 places cartouche gardent leur nombre ; les 17 places résidentes, données et
vidéo changent — c'est fait à la main, pas par script, chacune étant relue
contre la table des fenêtres. `address` sort des specs des places (le
`Validator` le refuse alors avec sa position et son candidat), et
`docs/schema/gamebuilder.xsd` est régénéré.

L'attribut `<layout pages="…">` devient redondant avec `<ram pages>` de la
machine : retiré.

**Validation** : corpus froid identique — c'est la propriété qui rend cette
phase sûre, puisque la même place physique produit les mêmes octets quelle que
soit la façon dont elle est écrite.

## Phase 6 — la documentation

- `docs/lang/en/memory.md` : la page de manuel du modèle (référentiel,
  fenêtres, places, espaces), en anglais comme le reste du manuel ;
- `docs/lang/en/scenes.md` et `groups.md` : les extraits qui écrivent encore
  `address=` sur une place ;
- un cas de migration n'est pas nécessaire : la v1 n'avait pas de fenêtres
  déclarées, il n'y a pas d'idiome v1 à traduire ;
- CLAUDE.md : la section « modèle mémoire », renvoyant aux deux documents.

---

## Points ouverts, à trancher en cours de route

1. **La non-linéarité des fenêtres MO6** n'est pas mesurée (pas d'émulateur MO6
   ici). Déclarée comme sur TO8 en phase 0 ; à confirmer le jour où une machine
   ou un émulateur MO6 est disponible. N'engage que les contrôles : les images
   MO6 ne changent pas, puisque le calcul part de l'adresse CPU déclarée.
2. **Quelle demi-page de la page 0 porte quoi** (`objects.pool` vs
   `pscroll.vid`) : les deux déclarations actuelles ne peuvent pas être vraies
   ensemble. À établir en phase 2 en lisant ce que l'engine monte réellement,
   pas en choisissant.
3. **Les noms `framebuffer.N.couleur` / `.forme`** désignent les moitiés dans
   l'ordre inverse de ce que la fenêtre vidéo montre (`bit 1` = forme = `+$0000`).
   Sans effet sur les octets — ce sont des réservations — mais le modèle rend la
   question posable, donc autant y répondre en phase 2.
4. **`<window>` dans le fichier machine ou dans le layout ?** Ici : dans la
   machine, parce qu'une fenêtre est un fait matériel. Si un jeu devait un jour
   déclarer une fenêtre à lui (bank switching applicatif), ce serait une
   extension du layout, pas une entorse à ce choix.
