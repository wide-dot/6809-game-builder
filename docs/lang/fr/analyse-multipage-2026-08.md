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
**son** symbole, donc **sa** page :

```xml
<tilemap map="..." label="map.even" tiles="tilesEven" variant="ND0"
         from="stage1.tiles" gensource="..."/>
```

`from` nomme le pageset ; la page vient du placement du symbole, pas d'un
`<file>$PAGE` commun. Le mécanisme `.static` est inchangé — c'est seulement la
réponse de `StaticLink.resolvePage` qui devient par-symbole.

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

1. `pages="N"` sur `<region>` : parsing, `Regions`, `PlacementScan`, et
   `gensymbols` qui émet `<région>.pages`.
2. `StaticLink` : le placement d'un symbole porte sa page propre ;
   `resolvePage(symbole)` remplace `resolvePage(direntry)`.
3. `<pageset>` : compilation par objet, mesure, premier ajustement, émission
   des direntries membres, enregistrement des placements.
4. `<tilemap from=…>` et l'index d'imageset branchés sur la résolution
   par-symbole.
5. Banc : le niveau 1 **entier** (245 + 304 tuiles) à la place de la tranche de
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
