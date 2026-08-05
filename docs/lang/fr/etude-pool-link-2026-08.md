---
date: 2026-08-05
sujet: Optimiser les données de load et de link pour limiter l'usage du pool —
  taxonomie des cas R-Type, limites du mécanisme .static, propositions
statut: IMPLÉMENTÉE le 2026-08-05 — P3, P2, P1b et P4 réalisés dans la foulée ;
  résultat mesuré sur R-Type : 9 104 → 264 octets de lien (6 direntries au lieu
  de 30), pool à 1 %, jeu validé sous toje. Le mécanisme `.static` par section
  est retiré, remplacé par `bake="none|auto|all"` sur la direntry. P2 n'a PAS
  demandé la restructuration du pipeline média envisagée : la passe de
  découverte existante moissonne exports, placements et exclusivités, et la
  passe réelle résout dessus — l'élection par consommateur remplace le
  last-one-wins. Doctrine à jour dans symbols.md.
---

# Économiser le pool : jusqu'où le bake au build peut-il aller ?

## 1. Objet

Le pool du loader vient de déborder deux fois en deux jours sur R-Type — 9 296
octets servis pour un plafond physique de 12 415 — et chaque unité câblée
ajoute la sienne. Le mécanisme `.static` existe et fonctionne (4 537 références
cuites au dernier build), mais 9 036 octets de données de lien restent, et la
question posée est : **lesquels sont réductibles, par quel mécanisme, et
lesquels sont le prix structurel de l'échange de stages ?**

L'étude passe la chaîne en revue de bout en bout (générateur Java, format
disque, loader/linker runtime), classe les cas d'usage réels de R-Type, mesure
ce que le mécanisme actuel ne couvre pas, et propose. **Rien n'est implémenté
ici.**

Références : [symbols.md](../en/symbols.md) (la doctrine actuelle),
[static-link-bake.md](../en/migration/static-link-bake.md) (les deux pannes),
`dist/link-report-fd.csv` et `dist/pool-map-fd.txt` (les chiffres).

## 2. La chaîne, mesurée de bout en bout

### 2.1 Côté build

`lwasm --obj` produit un LWOBJ16 par unité : sections, avec pour chacune ses
symboles **exportés** (nom, offset) et ses références **incomplètes** (offset
du trou, expression). `LwObject` lit ce format ; `bakeStatic()` patche dans le
binaire les références des sections `*.static` ; `LinkData` sérialise le reste
en six listes :

| type | octets/entrée | contenu |
|---|---|---|
| exportAbs | 4 | id de symbole, valeur (constantes — `SECTION constant`) |
| exportRel | 4 | id de symbole, offset dans l'unité |
| intern | 4 | offset du trou, opérande (relogement local) |
| extern8 | 6 | offset, opérande, id de symbole |
| extern16 | 6 | offset, opérande, id de symbole |
| externPage | 6 | offset, opérande, id de fichier (custom : page d'un fichier) |

Plus **12 octets d'en-tête** (six compteurs) par bloc, même vide. Les noms ne
quittent jamais le build : `LinkSymbols` assigne les ids, stables par tri
alphabétique. Le pruning retire les exports que rien n'importe (comparé
post-`.static` : une consommation cuite ne compte pas comme import).

### 2.2 Sur le disque et dans le pool

Le binaire et son bloc de lien sont deux objets séparés. Au chargement, le
loader indexe le fichier (`linkData.entry` : 11 octets par fichier, table
allouée par paquets de 8 slots, `realloc` au-delà) et garde le bloc de lien
**dans le pool tant que le fichier est indexé**. Le pool (TLSF, en-tête 4 o par
bloc, arrondi à la classe de taille — 2 266 octets en occupent 2 304) porte
aussi le répertoire, le fichier de scène et la table de slots. D'où la règle
établie le 05/08 : la ligne « link data » du build est un indicateur, l'octet
`tlsf.err` (`$A138`) est la mesure.

### 2.3 Côté runtime

`loader.file.link` re-linke **tous les fichiers indexés à chaque
`scene.load`** — c'est ce re-link total qui fait fonctionner l'échange de
stages : quand stage2 remplace stage1, les `EXTERNAL` du moteur se résolvent
sur les exports du nouveau venu. La résolution est une recherche linéaire
(`linkData.symbol.search`) : pour **chaque** référence, tous les fichiers
indexés, tous leurs exports, comparaison d'ids. Coût mesuré ~113
instructions/référence. Un symbole introuvable vaut **zéro** sans erreur (sauf
`loader.CHECK_UNRESOLVED_SYMBOLS`) — c'est à la fois le mécanisme des
références « en avant » (le son qui pointe une musique pas encore chargée) et
un piège documenté.

Trois conséquences structurent tout le reste :

1. **Chaque référence évitée économise deux fois** : des octets de pool, et du
   temps de chargement quadratique.
2. **Un bloc vide coûte quand même** : 12 octets + un slot d'index + une
   allocation TLSF. Le gain final passe par la disparition du `loadtimelink`,
   pas seulement par sa réduction.
3. **Le re-link total est l'invariant à préserver** : toute optimisation qui
   figerait une référence vers du contenu échangeable casse l'échange de
   stages.

## 3. EXPORT / EXTERNAL de lwasm : ce qui nous sert

Réponse directe à la question posée : **oui, c'est la colonne vertébrale, et il
n'y a rien à y changer.** `EXPORT` alimente la liste d'exports du LWOBJ16,
`EXTERNAL` produit les références incomplètes — le générateur de données de
lien ET le bake `.static` consomment exactement ces deux listes. La totalité de
la chaîne v2 (ids de symboles, pruning, uniqueness par ensemble co-chargeable,
régions `interface`) est construite dessus.

Ce qui ne nous sert pas, et pourquoi c'est déjà écrit dans
[symbols.md](../en/symbols.md) :

- **`EXTDEP`** (dépendance forcée sans référence) : aucun usage.
- **`--pragma=undefextern`** : proscrit. La v1 s'en servait ; en v2 un symbole
  inconnu est une erreur d'assemblage, pas un external silencieux qui se
  résoudra à zéro.
- **La liste des symboles locaux** du format : jamais émise.

Une subtilité qui SERT : lwasm écrit des **zéros** aux sites de relogement, pas
la valeur relative à la section. On ne peut donc jamais « laisser les interns
tels quels » pour une unité chargée en `$0000` — c'est mesuré, et c'est
pourquoi le bake des interns est un vrai patch, pas une omission.

## 4. Taxonomie des cas — ce que R-Type contient réellement

La doctrine actuelle dit : *le critère est la destination fixe, pas le contenu
partagé*. L'inventaire complet du jeu montre qu'il faut la raffiner, parce que
le critère se juge **par référence**, pas par unité. Quatre natures de
fournisseur, deux natures de consommateur :

**Fournisseurs :**
- **F1 — fixe** : une seule destination dans toutes les scènes du target
  (le moteur résident, chaque unité montée d'objet, les tuiles, l'anim).
- **F2 — interface** : région à alternatives (`interface="true"`), le contenu
  change à chaque échange mais la destination et la liste d'exports sont
  contractuelles (`stage`, `collision`, `maps`, `tiles.*`).
- **F3 — mobile** : chargé à des destinations différentes selon la scène.
  *Aucun cas aujourd'hui dans R-Type* — mais c'est le cas annoncé (« d'autres
  sont réutilisés dans d'autres stages et seront mobiles »).
- **F4 — runtime** : chargé à une adresse calculée à l'exécution par l'API du
  loader. Aucun cas dans R-Type ; le mécanisme existe.

**Consommateurs :** C-fixe (l'unité qui référence est elle-même en F1) et
C-mobile (F2/F3 — le stage échangeable, l'objet mobile).

La matrice des références, avec le verdict :

| référence | interne | vers F1 | vers F2 | vers F3 | vers F4 |
|---|---|---|---|---|---|
| **depuis C-fixe** | ✅ cuisable | ✅ cuisable | ❌ doit rester liée | ❌ doit rester liée | ❌ |
| **depuis C-mobile (F2)** | ✅ cuisable* | ✅ cuisable | ❌ | ❌ | ❌ |
| **depuis C-mobile (F3)** | ❌ (destination inconnue) | ✅ cuisable | ❌ | ❌ | ❌ |

\* les alternatives d'une région interface ont chacune une destination unique
et connue — c'est déjà exploité : `stage1` et `stage2` sont `code.static`.

Et les cas concrets du jeu, chiffres du rapport du 05/08 :

| cas | direntries | lien aujourd'hui | nature des références |
|---|---|---|---|
| **A. moteur résident** | `common.engine` | 2 266 o | 455 interns (F1→soi) + 15 extern16, **tous** vers l'interface du stage (comptés dans l'objet : `Obj_Index_*` ×10, `Ani_*_Index` ×4, `mainloop.state`, `Img_Page_Index`) + 86 exports importés par les unités montées. Les externals d'api.asm côté moteur (`checkpoint.load`, `ymm.stop`…) ne pèsent rien : c'est le stage qui les référence, pas lui |
| **B. objet monté, un seul usage, fixe** | `hud`, `messages`, `checkpoint`, `soundfx`, `collisionpass`, `stage1.init`, `stage1.collision` | ~1 550 o | interns + extern16 vers moteur (→F1). **Tout cuisable** |
| **C. objet monté, réutilisé entre stages, destination fixe** | `player`, `weapon`, `beam*`, `emflash`, `pow`, `optionbox`, `bitdevice`, `explosion`, `foefire`, `firechain`, `engineflames`, `fade`, `enemies`, `overlay`, `ymm`, … | ~4 900 o | idem B : la « réutilisation » ne change rien, la destination est unique. **Tout cuisable** |
| **D. stage échangeable (F2)** | `stage1`, `stage2` | 48 o chacun | déjà cuits (`code.static`, 235 réf.) ; il reste 12 + 9 exports d'interface — **le prix structurel de l'échange** |
| **E. données déjà cuites** | anim, maps, tilesets | 0 | la politique a atteint sa cible |

La leçon de l'inventaire : **il n'y a plus une seule « grosse table » à
marquer `.static` — le corpus restant est fait de CODE, dont les références
sont cuisables une à une mais dont les unités sont *mixtes*.** Le cas A en est
l'archétype : 97 % du bloc du moteur est cuisable (interns + refs vers unités
montées + exports que le bake des consommateurs ferait élaguer), mais les ~5
sites qui lisent les tables du stage doivent impérativement rester liés. Le
mécanisme actuel ne sait pas exprimer cela.

## 5. Ce que `.static` couvre, et les quatre trous

Le mécanisme actuel (`LwObject.bakeStatic`) : une section nommée `*.static`
promet que TOUTES ses références se résolvent au build — interns contre le
placement de l'unité elle-même, extern16 contre le placement du fournisseur,
extern8 uniquement pour `*$PAGE`. Échec = erreur de build nommée. C'est le bon
outil pour les tables générées, et il doit le rester (la promesse stricte est
une qualité : pas de repli silencieux).

Les trous, constatés sur le corpus réel :

**T1 — l'unité mixte est inexprimable.** `common.engine` ne peut pas passer
`code.static` : ses 5 sites vers `Obj_Index_*` feraient échouer le build (et
c'est voulu — les cuire casserait l'échange). Il faudrait éclater le source en
deux sections selon la destination de chaque référence — c'est-à-dire faire
transpirer dans le SOURCE du moteur une connaissance qui appartient à la
CONFIGURATION du jeu. Contraire à l'exigence de neutralité (§6.1), et
inapplicable : une même routine mêle les deux natures à quelques instructions
d'écart.

**T2 — l'unité mobile (F3) est inexprimable.** `.static` cuit interns ET
externs d'un même geste. Une unité F3 devra cuire ses externs-vers-F1 mais
garder ses interns liés (sa destination varie). Aucun moyen de le dire.

**T3 — l'ordre de déclaration est une contrainte d'auteur.** Le fournisseur
doit être déclaré avant le consommateur (son offset n'existe qu'assemblé), et
`registerExport` est last-one-wins — un consommateur déclaré après deux
alternatives cuirait silencieusement contre la seconde. Tolérable pour dix
tables ; ingérable si le bake devient la règle sur trente direntries.

**T4 — extern8 hors `$PAGE` et exportAbs.** Un extern8 vers une constante
absolue (`ymm.NO_LOOP`, exportée par `SECTION constant`) est refusé par le bake
actuel alors que sa valeur est connue au build sans même un placement.
`engine.sound.ymm` garde 2 extern8 pour cette seule raison.

## 6. Propositions

### 6.1 Le contrat de neutralité du moteur, d'abord

L'exigence énoncée : *le code commun engine ne doit pas dépendre de syntaxe ou
d'éléments dans le source qui empêcheraient un comportement différent dans un
autre contexte.* Formulée en règle de conception :

> **Le source déclare CE QUE l'unité référence (`EXPORT`/`EXTERNAL`, du lwasm
> nu). La configuration déclare OÙ chaque chose vit (régions, scènes,
> `interface`). Le builder DÉDUIT ce qui se cuit.** Aucune unité du moteur ne
> porte de marqueur de placement ; le même `engine.asm` doit pouvoir être
> entièrement lié dans un jeu-outil, partiellement cuit dans R-Type, et
> entièrement cuit dans une démo mono-scène — sans changer d'une ligne.

Le suffixe `.static` respecte déjà ce contrat pour les tables **propres au
jeu** (la carte d'un stage est à lui, marquer sa section est légitime). Il le
violerait s'il fallait l'introduire dans `engine/` — c'est le trou T1, et
c'est pourquoi la proposition principale est portée par la configuration.

### 6.2 P1 — le bake par référence, piloté par la direntry (`bake="auto"`)

Un attribut de direntry, dans le XML du jeu :

```xml
<direntry name="common.engine" loadtimelink="LINK" bake="auto">
```

Sémantique : pour chaque référence de chaque section (plus seulement les
`*.static`), le builder applique la matrice du §4 :

- **intern** : cuit si la direntry a une destination unique déclarée ; lié
  sinon.
- **extern16 / extern8 / externPage** : cuit si le fournisseur est F1 (une
  destination, pas de conflit, pas d'alternative d'interface) ; lié si le
  fournisseur est F2/F3/F4 ou inconnu.
- **exports** : inchangés — c'est le pruning existant qui les fera tomber,
  puisque chaque référence cuite chez un consommateur est un import de moins.

Différences avec `.static`, voulues : `auto` **replie** vers le lien au lieu
d'échouer (c'est un optimiseur, pas une promesse), et il est **hors du
source** (contrat 6.1). `.static` reste tel quel pour les tables générées où
l'échec doit être bruyant. Les deux compostent : une unité peut avoir ses
tables en `.static` (erreur si ça casse) et son code en `auto`.

L'infrastructure existe presque entièrement : `PlacementScan` collecte déjà
tous les placements avant le target, `StaticLink` connaît conflits et régions
d'interface, `bakeStatic` sait patcher, le pruning sait compter les
consommations cuites. Le travail est la boucle de classification et l'attribut.

**Garde-fou indispensable** : une référence vers un export d'une région
`interface` ou d'une direntry à destinations multiples n'est JAMAIS cuite par
`auto` — c'est la règle directionnelle de symbols.md (« un consommateur d'une
région interface ne cuit pas »), appliquée mécaniquement au lieu de
manuellement.

### 6.2bis P1b — retirer `.static` : tout par la configuration, zéro marqueur source

La question mérite d'être posée frontalement : une fois P1 acquis, **le
mécanisme par section a-t-il encore une raison d'exister ?** Réponse courte :
non. Le suffixe était le véhicule d'implémentation disponible — un endroit où
accrocher l'intention sans toucher au builder profond — pas une nécessité
sémantique. La preuve par les usages : le nom de section sert aujourd'hui à
deux choses, et les deux tombent.

1. **L'opt-in du bake.** Remplacé par la classification par référence de P1 :
   le builder n'a besoin d'aucune assertion d'auteur pour savoir qu'un intern
   d'une unité fixe se cuit — il connaît les placements mieux que le source.
2. **La convention du point d'entrée.** `leads()` a dû apprendre que
   `code.static` mène l'unité comme `code` — une complication née du
   mécanisme lui-même (le renommage déplaçait le point d'entrée en silence,
   panne vécue). Sans suffixe, `code` mène, point.

Et deux irritants disparaissent avec lui : les générateurs
(`TilemapPlugin`, gfxcomp, png2pal) n'ont plus besoin de leur attribut
`section` ni du contrôle « section must end with .static » — tout le monde
émet `SECTION code` ; et la promesse stricte cesse d'être écrite à un endroit
(le source, parfois généré) et vérifiée à un autre (la config, qui place).

**Ce qui remplace chaque usage, en XML :**

| aujourd'hui (source) | demain (config) | sémantique |
|---|---|---|
| pas de marqueur | `bake="none"` (défaut initial) | tout passe par le lien — comportement actuel hors `.static` |
| — | `bake="auto"` | classification par référence, repli vers le lien (P1) |
| `SECTION xxx.static` | `bake="all"` | **la promesse stricte** : toute référence de la direntry doit cuire, sinon erreur de build nommant symbole et cause — l'équivalent exact du contrat `.static`, porté par la déclaration qui place au lieu du source |

Trois formes possibles pour le porter, cumulables :

- **S1 — l'attribut de direntry** (`<direntry name="…" bake="all">`) :
  minimal, local, recommandé pour commencer.
- **S2 — le défaut de target avec surcharge**
  (`<target bake="auto">` + `bake="none"` sur les cas F4/runtime) : la
  politique du §« policy » de symbols.md devient un défaut mécanique. À
  activer une fois P1 éprouvé.
- **S3 — un bloc de politique centralisé** (un élément `<bake>` listant
  direntries et modes, à côté des scènes) : même pouvoir que S1, mais la
  décision de placement et la décision de bake se lisent au même endroit.
  Question de goût ; S1 suffit.

**Ce que le retrait coûte — la surface est petite :**

| à toucher | quoi |
|---|---|
| 5 fichiers asm (stage1, stage2, fade, anim, tilescroll) | renommer `*.static` → nom nu ; `code.static` → `code` |
| `TilemapPlugin`, imageset, gfxcomp | défaut `section="map.static"` → `code`, contrôles de suffixe supprimés, attribut `section` retiré |
| `LwObject` | `STATIC_SUFFIX` et la double forme de `leads()` supprimés ; `bakeStatic` devient piloté par le mode de la direntry, plus par le nom |
| `DirEntryPlugin` | lire l'attribut `bake`, le passer |
| symbols.md, migration docs, tests | réécrire la doctrine ; les tests de bake changent de déclencheur, pas d'assertions |

**La seule perte réelle : la granularité par section.** `bake="all"` promet
pour la direntry entière là où `.static` promettait pour une section. Sur le
corpus réel, aucune direntry n'en a besoin — les porteurs de tables générées
(cartes, anim, imagesets) sont des direntries de données pures, et les stages
cuisent en entier. Le cas hypothétique (une unité mêlant une table à promesse
et du code à repli) a deux issues propres : la scinder en deux direntries —
un geste de configuration, cohérent avec le principe — ou l'assumer en `auto`
et surveiller le résiduel au `pool-map`. Aucune ne justifie de garder deux
mécanismes en parallèle.

Verdict : **P1 devrait être implémenté directement sous cette forme** —
`bake="none|auto|all"` par direntry, retrait complet du mécanisme par
section dans le même chantier. Le corpus `.static` n'a que quelques semaines
et cinq fichiers ; c'est maintenant que le retour arrière est bon marché. Le
contrat de neutralité (§6.1) en sort renforcé : plus AUCUN marqueur de
placement dans AUCUN source, moteur ou jeu.

### 6.3 P2 — cuire en fin de target, pas au fil des déclarations

Pour lever T3 : déplacer l'application du bake dans une passe **après
l'assemblage de toutes les direntries**, quand tous les offsets d'exports sont
connus — les binaires ne sont patchés et écrits qu'ensuite. L'ordre de
déclaration cesse d'être une règle d'auteur ; last-one-wins devient une
détection de collision franche (deux fournisseurs candidats = erreur, sauf
alternatives d'une même destination). C'est aussi le préalable pratique de P1 :
`auto` sur trente direntries ne peut pas exiger un tri topologique manuel du
XML.

Coût : restructuration du pipeline direntry (aujourd'hui chaque direntry est
finalisée — compressée, écrite — au fil de l'eau). À évaluer ; c'est le gros
morceau du chantier.

### 6.4 P3 — étendre le vocabulaire cuisable (T4)

- extern8 vers **exportAbs** : valeur connue, aucune contrainte de placement.
- extern16 vers exportAbs : idem (le cas existe — `Irq_one_frame` a dû être
  sorti du lien à la main précisément parce que le lien le rebasait ; une
  constante absolue cuite est immunisée contre ce bug par construction).
- externPage : déjà couvert par `.static`, à inclure dans `auto`.

### 6.5 P4 — faire tomber le bloc, pas seulement le remplir de zéros

Quand `auto` a tout cuit et que le pruning a vidé les exports, la direntry doit
**perdre son `loadtimelink` d'elle-même** : plus de bloc de 12 octets, plus de
slot d'index, plus d'allocation. La garde existe déjà dans l'autre sens (le
build refuse de retirer l'attribut si un import subsiste) ; il s'agit de
l'inverser en automatisme, avec le même contrôle. Gain secondaire : moins de
fichiers indexés = table de slots plus petite = recherche runtime plus courte.

### 6.6 P5 — le cas mobile (F3), quand il arrivera

Trois voies, par coût croissant :

1. **Bake partiel** : P1 le donne gratuitement — externs-vers-F1 cuits,
   interns liés. Le bloc restant est proportionnel aux interns seuls.
2. **Copies pré-relogées** : si une unité est chargée à N destinations
   connues, le builder peut émettre N binaires patchés (un par destination) et
   zéro donnée de lien. Le disque paie (640 Ko, large), le pool ne paie rien.
   La scène choisit la copie par sa destination. À réserver aux unités où les
   interns dominent.
3. **Code indépendant de la position** (PCR) : possible sur 6809
   (`leax ,pcr`, `lbra`), mais +1 cycle et +1..2 octets par accès, et c'est une
   contrainte de SOURCE — acceptable pour un objet de jeu qui la choisit,
   contraire au contrat 6.1 pour le moteur. À documenter comme option d'objet,
   pas comme politique.

À noter : l'architecture R-Type actuelle **contourne déjà** le besoin de F3.
Le moteur n'atteint les objets montés que par l'index d'objets (tables
page+adresse exportées par le stage, région interface) — pas par référence
directe. Un objet « réutilisé dans d'autres stages » peut donc rester F1 (même
destination partout, chargé par la scène qui en a besoin) tant que les pages ne
manquent pas. F3 n'est justifié que le jour où deux stages veulent la même
page pour des objets différents — et ce jour-là, la voie 2 est probablement la
bonne.

### 6.7 P6 — le reste du pool (données de load)

Hors données de lien, le pool porte : le répertoire (`nsector × 256` octets),
le fichier de scène, la table de slots (12 + 8×11 octets par paquet,
`realloc`). Pistes mineures, à ne prendre que si le besoin revient après
P1-P4 : dimensionner le premier paquet de slots sur le nombre réel de fichiers
à lien du target (le builder le connaît — P4 le réduit déjà) ; libérer le
répertoire entre deux `dir.load` du même disque. Aucune de ces pistes ne vaut
le dixième de P1 ; elles sont notées pour que le périmètre soit complet.

## 7. Gains estimés sur R-Type

Méthode : pour chaque direntry, reste = 12 (en-tête, si le bloc survit) +
6 o par référence vers F2 + 4 o par export encore importé après pruning.
Estimations au rapport du 05/08 :

| direntry | aujourd'hui | après P1+P3+P4 | reste pourquoi |
|---|---|---|---|
| `common.engine` | 2 266 | **102** | 12 + 15 sites extern16 vers les tables du stage (F2), comptés dans l'objet |
| cas B+C (24 unités montées fixes) | ≈ 6 450 | **0** | tout cuit, blocs tombés (P4), exports élagués |
| `stage1` / `stage2` | 48 + 48 | 48 + 48 | le contrat d'interface : 9 exports re-liés à chaque échange |
| `engine.sound.ym.const` | 20 | 0 | ses 2 exportAbs consommés cuits (P3) |
| divers (images spread, musiques) | ≈ 60 | 0 | blocs vides tombés (P4) |
| **total scenes.boot (servi TLSF)** | **9 296** | **≈ 210** | |

Soit un pool ramené de 75 % à ~2 % de `$3000` — le plafond cesse d'être un
sujet, et le `DEFAULT_DYNAMIC_MEMORY_SIZE` peut même revenir à sa valeur
d'origine. Gain de chargement du même ordre : ~4 100 références × ~113
instructions ≈ 460 000 instructions de moins au boot (cohérent avec la mesure
tilescroll : 883 k → 548 k pour 768 références).

L'échange de stages, lui, garde exactement son coût actuel : ~15 références du
moteur re-résolues contre 9 exports — quelques milliers d'instructions,
invisibles.

## 8. Invariants à préserver (la liste des choses qu'on ne casse pas)

1. **Le re-link total à chaque `scene.load`** et les références du moteur vers
   les régions `interface` : jamais cuits. C'est LE mécanisme de l'échange.
2. **Les références « en avant » volontaires** (le lecteur son pointant une
   musique chargée plus tard, résolue à zéro puis au prochain load) : `auto`
   les laisse liées d'office — leur fournisseur est une alternative parmi
   d'autres, donc jamais F1. Vérifier ce cas dans les tests de P1.
3. **La promesse `.static`** : l'échec bruyant sur les tables générées reste ;
   `auto` ne remplace pas, il complète.
4. **Le refus du retrait prématuré de `loadtimelink`** (imports restants
   nommés) : P4 doit passer par la même vérification, dans les deux sens.
5. **L'uniqueness par ensemble co-chargeable** et le contrat des régions
   `interface` (même liste d'exports post-prune) : inchangés — `auto` s'appuie
   dessus, il ne les modifie pas.
6. **`tlsf.err` comme mesure de vérité** : chaque étape du chantier se valide
   sur machine, pas sur la ligne « link data » (leçon du 05/08).

## 9. Ordre recommandé

1. **P3** (extern8/exportAbs) — petit, isolé, gains immédiats sur `ymm`, et le
   vocabulaire complet est un préalable de P1.
2. **P2** (passe de bake en fin de target) — le morceau structurel ; tout le
   reste s'y adosse. À faire tant que le corpus est petit.
3. **P1 sous la forme P1b** (`bake="none|auto|all"`, retrait du mécanisme par
   section — §6.2bis) : la récolte, appliquée aux 24 unités B+C puis au
   moteur, en mesurant `pool-map` et `tlsf.err` à chaque lot. Faire le retour
   arrière `.static` DANS ce chantier, pas après : cinq fichiers source, trois
   plugins, et deux mécanismes de moins à documenter.
4. **P4** (chute automatique du bloc) — transforme les 12 o résiduels et les
   slots en zéro.
5. **P5/P6** — dossiers ouverts, à ne rouvrir que sur besoin constaté (arrivée
   d'un vrai F3 ; pool encore contraint après le reste, ce que les chiffres du
   §7 rendent improbable).

Le point d'arrivée doctrinal, si tout est fait : *symbols.md* se réécrit en une
phrase — **le lien au chargement ne porte plus que les frontières d'échange ;
tout le reste est cuit, automatiquement, parce que le builder sait déjà où tout
vit.** Le `.static` d'aujourd'hui aura été l'étape manuelle qui a permis de
vérifier, cas par cas, que cette phrase est vraie — et qui disparaît dans le
mouvement : la promesse qu'il portait déménage dans la configuration
(`bake="all"`), au seul endroit qui sait déjà où tout vit.
