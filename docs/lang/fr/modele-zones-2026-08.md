---
date: 2026-08-06
sujet: Modèle mémoire — zones, régions, arènes. Décision de conception et plan d'implémentation.
statut: les six étapes sont faites ; le rapport d'occupation a depuis été
  refondu (occupancy-<cible>.html, 03/08)
succède à: modele-regions-2026-07.md (doctrine des régions)
---

# Zones, régions, arènes

## Ce qui ne va plus

Le layout actuel décrit **un emplacement par nom**. Une `<region>` porte une page
et une adresse, et une scène y charge un fichier. Ce modèle a trois défauts qui
se sont révélés en portant le cast d'ennemis de r-type.

**Il oblige à déclarer chaque emplacement à la main.** Vingt-neuf régions pour
les objets communs, et il en faudrait des centaines pour un jeu complet. Chaque
déclaration est une décision que personne ne veut prendre : dans quelle page va
`cancer` ? À quelle adresse ? La réponse n'intéresse personne, elle doit être
calculée.

**Il gaspille.** Une région dimensionnée à la main porte une marge, et la somme
des marges faisait 105 060 octets sur r-type — six pages perdues, plus que le
cast qu'on disait ne pas pouvoir loger. La mesure automatique (`size="auto"`) a
supprimé les marges mais laissé les **queues de page** : 75 114 octets répartis
en douze bouts de 1 à 14 Ko, inutilisables parce qu'aucune ressource ne tombe
juste à la bonne taille.

**Il ne dit pas où finit une page.** Les queues étaient invisibles dans le
rapport d'occupation, qui affichait 100 % partout — il mesurait le remplissage
de la région, or une région mesurée se remplit toujours elle-même. Un élément
`<window>` a été ajouté pour combler ce trou, mais il n'est référencé nulle
part : c'est le symptôme d'un concept qui arrange le builder au lieu de décrire
le jeu.

## Le modèle

Quatre éléments, chacun avec un rôle qu'on peut énoncer en une phrase.

### `<zone>` — où il y a de la place

Une plage **continue** dans **une** page. `page`, `address` et `size` sont
obligatoires, toutes les trois. C'est le seul élément qui parle de mémoire
physique, et il ne parle que de ça.

Pas de zone multi-pages : c'est précisément pour décrire un espace discontinu
qu'on en déclare plusieurs.

### `<region>` — la cible d'un chargement

Un nom, et une liste de zones. Les fichiers qu'une scène y charge s'y placent
**dans l'ordre de déclaration des `<load>`**. C'est ce qui permet au moteur de
graver leurs adresses : l'emplacement du n-ième fichier ne dépend que de la
déclaration, donc il est le même pour toutes les alternatives.

Une région à zone unique se comporte exactement comme la région d'aujourd'hui.
Une région à n zones sert à ce qui est numéroté par construction — les cinq
membres d'un tileset, que le builder nomme lui-même `.0` à `.4`.

### `<arena>` — un espace de rangement

Un nom, et une liste de zones. Le builder y range ce qu'on lui confie, **du plus
gros au plus petit**, et publie l'emplacement de chaque fichier. Personne ne
grave d'adresse vers le contenu d'une arène depuis l'extérieur : on l'atteint par
une table.

Le mot est le terme consacré des allocateurs (*arena allocation* : on alloue
librement dedans, on récupère tout d'un bloc), ce qui est exactement la
sémantique — les niveaux se partagent l'arène, l'écran-titre la reprend entière.

### `<reserved>` — ce qu'on n'a pas le droit de prendre

Inchangé, et son usage s'élargit : il décrit aussi ce que **la machine** occupe
sans qu'aucun fichier n'y soit chargé — tampons vidéo, page directe du moniteur,
loader et son pool. Le rapport ment par omission tant que ces plages n'y
figurent pas.

```xml
<layout sparepages="$05-$1F">
    <reserved name="video.buffer.1" page="$02" address="$0000" size="$4000"/>

    <region name="common">
        <zone page="$01" address="$6100" size="$1EC0"/>
    </region>

    <region name="tiles.odd">                     <!-- membres numérotés -->
        <zone page="$09" address="$0000" size="$4000"/>
        <zone page="$0A" address="$0000" size="$4000"/>
        <zone page="$0B" address="$0000" size="$4000"/>
    </region>

    <arena name="objects">                        <!-- le builder range -->
        <zone page="$0E" address="$2E68" size="$1198"/>
        <zone page="$0F" address="$1EFE" size="$2102"/>
        <zone page="$05" address="$0000" size="$4000"/>
    </arena>
</layout>

<load name="stage1.tiles.odd.0" region="tiles.odd"/>
<load name="common.checkpoint"  arena="objects"/>
```

L'attribut du `<load>` dit lui-même le mode : `region=` pour une cible convenue,
`arena=` pour un rangement. Rien à retenir en plus.

## Les règles

**On déclare les contraintes, pas les décisions.** Ce qui est écrit contraint ;
ce qui est absent, le builder le trouve. Cette règle, posée le 2026-08-06 et déjà
implémentée pour les régions, s'étend : une zone est une contrainte d'espace, un
`size` de zone est un budget, jamais une mesure.

**Placement libre ou figé, selon la façon dont on atteint la cible.** Une adresse
peut être connue de deux façons : *gravée* dans les octets au moment du build, ou
*lue dans une table* à l'exécution. Ce qui est atteint par une table peut être
rangé n'importe où ; ce dont l'adresse est gravée ailleurs doit rester en place.
Nuance qui compte : une adresse gravée reste valide si le graveur et sa cible
sont rechargés ensemble — un niveau qui grave l'adresse de sa propre table de
vagues déménage avec elle sans dommage. Le danger n'existe que quand le moteur
résident grave l'adresse de quelque chose qui change avec le niveau.

**Le builder publie l'emplacement par fichier.** Dès qu'un contenant tient
plusieurs fichiers, `<region>.page` et `.address` n'ont plus de sens : il faut
`<file>.page` et `<file>.address`, comme un pageset publie déjà `<symbole>.page`.
C'est ce que lit l'index d'objets, donc c'est le vecteur réel du gain.

**Le rangement est stable.** À taille égale, l'ordre de déclaration. Le tri par
taille décroissante remplit mieux — sur les 29 régions communes de r-type il
atteint le minimum théorique de 8 pages au lieu de 12 — mais un fichier qui
grossit peut faire basculer le rangement. C'est acceptable (les tables sont
régénérées à chaque build) à condition que le rapport montre ce qui a bougé.

## Ce que le builder refuse, ce qu'il montre

Il refuse ce qui est faux **quel que soit l'enchaînement des écrans** :

1. deux fichiers d'une **même scène** qui s'écrasent ;
2. un contenu qui **dépasse** la capacité de son contenant ;
3. une zone qui mord sur un `reserved` ;
4. une adresse **gravée** vers une cible qui n'est pas rechargée avec le graveur
   — le garde-fou sans lequel l'erreur se reproduit en silence.

Le quatrième était **déjà tenu**, par un chemin qu'on n'avait pas vu : l'élection
de fournisseur. Mis à l'épreuve en rangeant les cartes des deux niveaux dans une
arène, le build refuse de lui-même — « `adr_tilesEven_1_ND0` est exporté par
[stage1.tiles.even.0, stage2.tiles.even.0], alternatives d'exécution dont
stage2.maps pourrait voir l'une ou l'autre ». Rien à ajouter, donc, sinon de
savoir que la protection existe et par où elle passe.

Il **montre**, sans refuser, tout le reste : les recouvrements entre contenants,
l'occupation réelle, ce qui dort. Deux contenants peuvent occuper la même RAM :
c'est ainsi qu'un écran-titre reprend la mémoire d'une famille de niveaux. Le
builder ne connaît pas l'ordre des écrans — il appartient au code du jeu — donc
il ne doit pas prétendre le vérifier. Un contrôle qui demanderait à la
configuration de déclarer ce qu'une scène « suppose déjà chargé » serait faux le
jour où quelqu'un ajoute un chemin de navigation, et faux en silence.

**Conséquence** : le contrôle de chevauchement, aujourd'hui global au layout,
descend au niveau de la scène. C'était déjà la doctrine écrite dans
`groups.md` (« les régions peuvent se recouvrir librement d'une scène à
l'autre ») ; l'implémentation était plus stricte que le modèle.

## Ce qui disparaît

| retiré | remplacé par |
|---|---|
| `<window>` | la zone porte ses bornes |
| `size="auto"` | une zone est un espace, le contenu se mesure toujours |
| `address="auto"` | le builder empile dans la zone, par définition |
| `pages="auto"` | autant de zones qu'on veut offrir |
| `stacked="true"` | c'est le cas normal d'une arène — et devient cuisable, ce que l'empilement par le runtime interdisait |
| l'enchaînement implicite | le rangement |

Cinq notions retirées pour une ajoutée.

## Ce qui ne bouge pas

**Le runtime.** Vérifié en lisant le chargeur : `loader.scene.load` charge,
décompresse, indexe — sans aucune phase de déchargement. Un fichier n'a pas
d'état, ce sont des octets écrits à une destination ; ce qui a un état (les
données de liaison dans le pool) est indexé par **identifiant de fichier**,
jamais par adresse. Donc un rangement quelconque ne perturbe rien, et deux
scènes qui se succèdent dans les mêmes zones ne se marchent pas dessus.

Le format `type01` (page + adresse par fichier) exprime n'importe quel
rangement, y compris discontinu. Le `type10` (une origine, une liste qui
s'empile) reste utile comme **format d'émission** : dès que des fichiers se
suivent, le builder les compresse en un bloc. Une région fragmentée coûte 5
octets de table par fichier — 231 octets pour les 44 fichiers de la scène de
boot, ~2,5 Ko si on montait à 500 ressources, dans le pool. Le choix du format
est une optimisation du builder, pas une contrainte du modèle.

**Les trois passes.** Le build mesure (passe 1), rejoue la découverte avec les
mesures (passe 2), puis construit (passe 3). Sans la passe 2, les exports
moissonnés portent les adresses provisoires de la mesure — c'est ce qui faisait
sauter le jeu dans de la RAM vide. Le rangement automatique en dépend
entièrement.

## Plan d'implémentation

Chaque étape a une preuve. La preuve de référence, quand elle s'applique, est
l'empreinte de la disquette : une évolution qui ne change pas le placement doit
produire un `to8.fd` au sha identique.

### 1. `<zone>` — la structure

Schéma : `<zone page address size>`, enfant de `<region>`. Le résolveur lit les
zones ; une `<region>` qui porte encore `page`/`address`/`size` sans enfant est
réécrite en une zone unique — **aucune migration forcée**.

*Preuve* : r-type inchangé, sha identique. Les 12 exemples passent.

### 2. `<arena>` — le rangement

Nouvel élément, même contenu qu'une région. Rangement par taille décroissante
sur la liste des zones, premier emplacement qui convient. Refus explicite quand
rien ne rentre, avec le manque en octets. `<load arena="…">`.

Publication de `<file>.page` et `<file>.address` dans `gen/layout.asm`.

*Preuve* : une ressource déplacée d'une région vers une arène, seule dans une
zone équivalente, donne un sha identique — comme l'a fait `page="auto"`.

### 3. Les contrôles

Descendre le contrôle de chevauchement au niveau de la scène. Ajouter le
garde-fou de l'adresse gravée : le builder sait qui grave quoi, il refuse si le
graveur n'est pas rechargé avec sa cible.

*Preuve* : un test qui met en arène une ressource dont le moteur grave
l'adresse, et vérifie que le build refuse. Un autre qui déclare deux contenants
sur la même RAM sans qu'aucune scène ne les charge ensemble, et vérifie que le
build passe.

### 4. Le retrait — partiel

**Fait** : les trois `auto` (`size`, `address`, `pages`) et tout le mécanisme de
placement automatique de RÉGION qui allait avec — la passe de rangement, la
plage `sparepages`, la recherche de trou. L'arène fait ce travail, mieux et à un
seul endroit. r-type au sha identique après le retrait.

**Fait aussi, le 2026-08-06 : `stacked`.** Le blocage (géométrie MO6 non
éprouvable) est tombé avec la validation du correctif `ldu #CART_START` sur
émulateur MO6. Les quatre configs (`mplus` ×2, `stacked-overflow` ×2) sont
migrées vers une arène à deux zones ; l'attribut est refusé avec le geste de
migration dans le message ; `Regions.Region.stacked`, le genre `BULK`, la
simulation de curseur des vérifications et la branche `Stacked` du générateur
de scène ont disparu. Ce que le retrait change de posture : **plus aucun octet
de donnée n'est placé par la marche à l'exécution du chargeur** — le builder
décide, publie, et émet du `%01` ; les blocs séquentiels `%10`/`%11` ne
servent plus qu'aux fichiers export-only, qui n'écrivent rien. Preuves :
r-type au sha identique, 12/12 exemples, mplus à l'écran identique
avant/après, stacked-overflow vert (les mêmes adresses, décidées cette fois
par l'arène).

**Fait enfin, le 2026-08-06 : `<window>`**, retiré avec l'implémentation du
rapport (étape 6), son dernier lecteur. La première région sans adresse d'une
page doit désormais dire son adresse — une page ne dit pas où elle commence,
et il n'y a plus d'élément pour prétendre le contraire. L'étape 4 est close :
les cinq notions retirées le sont toutes.

### 5. La migration de r-type

Les 29 régions d'objets communs deviennent une arène ; les régions
d'interface (tuiles, cartes, collision, stage) gardent leur forme, avec une zone
par membre. Les pages que la machine occupe (`$00`, `$02`, `$03`, `$04`)
deviennent des `reserved`, pour que la carte soit honnête.

*Preuve* : boot, niveau 1 joué jusqu'au corridor, `tlsf.err = 0`. Et la mesure
qui motive tout : combien de pages entières sont libérées (attendu ~4, soit
64 Ko, en plus des 32 Ko déjà libres et des 10 Ko de la page 4).

### 6. Le rapport — v1 implémentée

`dist/occupancy-<cible>.html`, deux vues (RAM / média), arbre cochable, rien
de coché par défaut, collisions en rouge parmi les cochés, fichiers sans
destination listés à part, sélecteur d'instance média sur la géométrie réelle.
L'ancien `ram-map-<cible>.txt` a disparu avec `<window>`. Détail et pistes
d'itération : [`rapport-occupation-2026-08.md`](rapport-occupation-2026-08.md).

## Points restés ouverts

- **Le nom `arena`** : retenu comme terme standard, à confirmer à l'usage.
- **Le total « non couvert »** du rapport additionne des choses de nature
  différente : les pages vierges, les queues récupérables, et ce qu'une autre
  combinaison de scènes occupe. Le chiffre est juste, sa lecture ne l'est pas —
  il faudra le scinder.
- **Les chargements hors scène** : le jeu peut charger un fichier isolé
  (`loader.file.load`), et le firmware SDDrive le fait déjà. Le builder ne les
  voit pas, donc la carte les ignore. Les déclarer comme des scènes à un fichier
  suffirait, sans introduire de concept.
- **Le tri par taille** : retenu, mais on mesurera son instabilité réelle avant
  d'en faire un défaut définitif.
