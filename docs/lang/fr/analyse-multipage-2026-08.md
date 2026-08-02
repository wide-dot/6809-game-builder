# Données multi-pages : répartir ce qui ne tient pas dans 16 Ko

Conception du dernier verrou du pipeline. Le banc d'échange de stages a buté
dessus de façon mesurable : les tuiles compilées d'un niveau entier de R-Type
pèsent bien plus qu'une page — 245 tuiles pour le plan pair du niveau 1, 304
pour l'impair, 191 et 230 pour le niveau 2 — alors qu'un direntry est plafonné
à 16 Ko (champ de taille sur 14 bits) et qu'une page RAM en fait autant. Le
banc a donc dû se contenter d'une tranche de 24 colonnes. Les ~149 objets de
jeu poseront le même problème, en plus gros.

## Ce que faisait la v1

`BuildDisk.generateObjects` compilait **chaque objet séparément**, obtenait sa
taille, puis un allocateur (`RamImage`, premier ajustement sur une liste de
pages) lui attribuait une page et une adresse. Les tables générées ensuite —
index d'objets, buffer de tuiles — lisaient ce placement et écrivaient
`page + adresse` en dur, valeur par valeur. D'où le constat déjà noté : la v1
ne payait aucune donnée de lien pour ses cartes, parce qu'elle générait après
placement.

Deux propriétés à retenir : **on compile avant de placer** (sinon on ne connaît
pas les tailles), et **le placement est une donnée que les générateurs
relisent**.

## Ce que la v2 a déjà, et qui change la difficulté

Trois acquis rendent le portage bien plus simple qu'un portage littéral :

1. **Un direntry peut contenir plusieurs objets lwasm.** Le rebasage des
   offsets multi-objet a été fait pendant la campagne Java (phase 2), et il est
   exercé. Un direntry est donc déjà « un sac d'objets assemblés séparément » —
   exactement l'unité que l'allocateur v1 manipulait.
2. **Les régions sont déclarées par l'auteur**, et `PlacementScan` les connaît
   *avant* que la cible ne tourne. Le builder sait donc où chaque direntry
   atterrit au moment où il le construit.
3. **Les sections `.static` cuisent les références contre ce placement.** Une
   table qui pointe des tuiles n'a besoin que d'une chose : que le builder
   sache, pour chaque symbole, la page et l'adresse. C'est déjà le contrat de
   `StaticLink`.

Le multi-pages ne demande donc pas un nouveau mécanisme de liaison. Il demande
que **le placement d'un symbole cesse d'être « celui de son direntry » pour
devenir « celui de son objet dans son direntry »**.

## La forme retenue : la région à plusieurs pages, et `<pageset>`

Deux ajouts, et rien d'autre ne bouge côté auteur.

### 1. Une région peut couvrir plusieurs pages

```xml
<region name="tiles" page="$06" pages="4" address="$0000" size="$4000"/>
```

« Quatre pages consécutives à partir de $06, toutes vues à $0000, $4000
chacune. » C'est la déclaration du budget mémoire, et elle reste à l'auteur —
la doctrine v2 (« la région, pas le fichier, est l'unité de remplacement »)
est respectée : l'auteur dit *où*, le builder dit *comment ça rentre*.

### 2. Un `<pageset>` remplit cette région

```xml
<pageset name="stage1.tiles" region="tiles" section="DATA" loadtimelink="LINK">
    <gfxcomp gendir="gen/tiles" gensource="gen/tiles/includes.asm">
        <image name="tiles" filename="src/.../tiles.png" grid="12x12">
            <encoder name="draw" shift="0"/>
        </image>
    </gfxcomp>
</pageset>
```

Ce que le builder en fait :

1. il compile le contenu **objet par objet** (une tuile = un objet lwasm), donc
   il connaît la taille de chacun ;
2. il les range dans les pages de la région, premier ajustement en ordre de
   déclaration — comme la v1 ;
3. il émet **un direntry par page**, `stage1.tiles.0` … `stage1.tiles.3`, chacun
   un sac d'objets, ce que le format sait déjà porter ;
4. il enregistre pour chaque symbole exporté la page et l'adresse réelles ;
5. si le contenu déborde du nombre de pages déclaré, c'est une **erreur de
   build** qui dit combien de pages il faudrait — jamais un débordement
   silencieux.

Côté scène, rien de nouveau : `<load name="stage1.tiles" region="tiles"/>` se
développe en les membres du pageset.

La facilité de configuration tient en une phrase : **l'auteur déclare un budget
de pages et un contenu ; il n'assigne jamais un élément à une page.**

## Ce que ça change pour les consommateurs

`<tilemap>` cesse d'avoir un attribut `file` unique. Chaque entrée résout
**son** symbole, donc **sa** page. **Fait (02/08)** — et plus simple que prévu :
aucun attribut de remplacement n'est nécessaire, le symbole se suffit. Le
générateur demande `StaticLink.pageOf(symbole)` et écrit un **littéral**
`fcb map.RAM_OVER_CART+6`, là où il émettait une référence `<file>$PAGE`. Une
référence de moins par table, et la réponse devient juste par construction
quand les tuiles sont réparties.

Même bénéfice, gratuit, pour l'index d'imageset des sprites et pour le futur
index d'objets : le jour où les 149 objets de R-Type dépassent une page, ils
entrent dans un pageset sans que leur table change de forme.

## Ce qui est vérifié au build

- débordement du budget de pages : erreur, avec le nombre de pages nécessaire ;
- un objet plus gros qu'une page : erreur nommant l'objet (aucun découpage
  d'objet, jamais — un objet est atomique) ;
- l'unicité des exports et le contrôle d'interface s'appliquent aux membres du
  pageset comme à n'importe quel direntry ;
- les membres d'un pageset partagent le sort de leur région : chargés ensemble,
  évincés ensemble.

## Ordre d'implémentation

1. ~~`pages="N"` sur `<region>`~~ **FAIT (02/08)** : attribut déclaré et
   contrôlé (bulk et multi-pages s'excluent), `gensymbols` émet
   `<région>.pages` et `<région>.page.last`.
2. ~~`StaticLink` par-symbole~~ **FAIT (02/08)** : `pageOf(symbole)` ajouté et
   branché sur `<tilemap>`. Les 8 configs de référence restent identiques à
   l'octet près, tilescroll revalidé sous toje.
3. **La capacité, elle, est déjà là (02/08)** : `range="<premier>-<dernier>"`
   sur une `<image grid=…>` fait qu'une unité ne prend qu'une tranche de la
   feuille, les identifiants restant ceux de la feuille. Un tileset trop gros
   se déclare donc en plusieurs direntries, chacun dans sa région, et la carte
   résout la page de chaque tuile toute seule. **Prouvé sur machine** : le
   tileset pair du stage 1 coupé en 0-10 (page $06) et 11-19 (page $09), la
   carte porte bien deux pages différentes, l'art est intact et le banc
   d'échange repasse 5/5. Ce qui manque à `<pageset>` n'est donc plus la
   capacité mais l'ergonomie : choisir les coupes à la place de l'auteur.
4. ~~`<pageset>`~~ **FAIT (02/08)** : mesure par une seule assemblée de
   l'ensemble (les tailles se lisent entre symboles exportés consécutifs, et
   lire des offsets n'enregistre aucun export — sinon il entrerait en
   collision avec les membres réels), premier ajustement en ordre de
   déclaration, un direntry par page émis en réutilisant tout le pipeline
   direntry (codec, link data, cuisson `.static`, contrôles de taille). Le
   nombre de membres est le **budget déclaré**, pas le résultat du rangement :
   les ids de fichiers sont distribués avant toute construction, donc il doit
   se déduire de la seule configuration. Un budget non rempli laisse des
   membres vides et le build le dit. La scène développe un `<load>` de pageset
   en ses membres.
5. L'index d'imageset branché sur la même résolution par-symbole.
5b. Vérifié sur les vraies données : l'ouverture du niveau 2, qui échouait à
   « data size 18396 is over maxsize: 16384 », se range en 92 + 9 tuiles sur
   les pages $06/$07 (plan pair) et 76 + 40 sur $08/$09 (impair), la première
   page remplie à 16 347 octets sur 16 384. Les cartes portent 168 entrées
   page 6 et 9 page 7, 137 page 8 et 44 page 9. Banc d'échange 5/5.

6. Banc : le niveau 1 **entier** (245 + 304 tuiles) à la place de la tranche de
   24 colonnes, et la carte complète qui défile — la preuve étant que les
   tuiles d'une même carte viennent de pages différentes.

Le point 5 est le critère d'acceptation : il n'est atteint que si le placement
par-symbole est juste jusqu'au dernier octet, et il se vérifie à l'œil (une
tuile lue sur la mauvaise page est du bruit à l'écran) autant qu'aux témoins.

## Ce qui reste hors périmètre

Le découpage d'un objet trop gros (une image plein écran compressée qui
dépasse une page) : la v1 ne le faisait pas non plus, elle exigeait que l'objet
tienne. Et la répartition sur des pages **non consécutives** : la région dit
`page` + `pages`, donc un intervalle. Si un jour un jeu a besoin de pages
éparses, l'attribut deviendra une liste sans que le reste bouge.
