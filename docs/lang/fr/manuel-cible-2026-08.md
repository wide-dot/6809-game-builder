---
date: 2026-08-09
sujet: Manuel utilisateur complet du modèle cible « file maître » — la disquette
  ET la mémoire, tous les cas d'usage.
statut: brouillon d'étude, écrit pour éprouver le modèle du §12 de
  analyse-placement-2026-08.md. La syntaxe montrée est CELLE DU MODÈLE EN
  DISCUSSION, pas celle du builder d'aujourd'hui. Ce que l'écriture a révélé
  est consigné au §13 de l'analyse.
supersède: esquisse-manuel-placement-2026-08.md (modèle intermédiaire)
---

# Construire un jeu qui charge — le manuel

## 1. La machine et le problème

La mémoire d'un TO8 est découpée en pages de 16 Ko. Le programme en voit une
partie fixe — où vivent votre moteur et vos variables — et une fenêtre, dans
laquelle une page de données vient se monter quand on la demande. Un jeu
complet ne tient pas en mémoire : on charge des morceaux depuis la disquette
pendant que le jeu tourne, et on écrase ce qui ne sert plus.

Vous déclarez trois choses : **ce qui existe** (les fichiers et ce qui les
produit), **où il y a de la place** (les emplacements mémoire), **ce que
chaque écran du jeu charge** (les listes de chargement). Le builder fait le
reste : il mesure, compresse, place, écrit les tables, produit la disquette —
et refuse au build ce qui ne peut pas marcher.

## 2. La disquette

### 2.1 Ce que c'est physiquement

Une disquette 640 Ko a deux faces, 80 pistes par face, 16 secteurs par piste,
256 octets par secteur. La tête de lecture lit un secteur à la fois, pendant
que le disque tourne. Deux choses coûtent du temps : **déplacer la tête**
d'une piste à l'autre (un « seek »), et **attendre** qu'un secteur repasse
dessous. Tout ce que le builder fait côté disquette vise à éviter ces deux
attentes.

### 2.2 Le fichier : d'un seul tenant

Un `<file>` est l'unité de base : un contenu nommé, produit par les modules
que vous lui donnez (assembleur, convertisseur d'image, de musique, générateur
de données…), et écrit **d'un seul tenant** sur la disquette. Il se charge
d'une seule traite, sans seek interne, et se compresse d'un bloc — plus le
bloc est gros, mieux il se compresse.

```xml
<file name="stage1.music">
    <vgm2ymm filename="src/stages/01/music.vgm"/>
</file>
```

Un fichier est **indivisible** : le builder ne coupe jamais dedans. C'est vous
qui maîtrisez la taille de vos fichiers en choisissant ce que vous groupez
dedans. Limite haute : un fichier doit tenir de son adresse de chargement à
la fin d'une page — en pratique, 16 Ko au plus.

Sur la disquette, les fichiers sont collés bout à bout, à l'octet près : un
fichier peut commencer au milieu du dernier secteur du précédent. Rien n'est
perdu entre deux.

### 2.3 La compression

Chaque fichier est compressé, sauf quand ça ne paie pas — un fichier minuscule
ou déjà dense est alors stocké tel quel, et le chargeur le sait tout seul.
Vous n'avez rien à déclarer. Ce que la compression achète : moins de secteurs
lus (chargement plus rapide) et plus de contenu par disquette. La
décompression se fait après la lecture, en mémoire, pas pendant — la tête ne
l'attend jamais.

### 2.4 Les quartiers de la disquette

La disquette est divisée en quartiers nommés (les *sections*) : quelques-uns
appartiennent au système — l'amorce, le chargeur, le répertoire, les données
de liaison — et le reste est à vous. Vous dites dans quel quartier va chaque
fichier ; les fichiers d'un quartier se suivent sur les pistes.

Le builder range les fichiers d'un quartier **dans l'ordre où les listes de
chargement les demandent** : quand un écran se charge, la tête balaie les
pistes vers l'avant, sans revenir en arrière. Un fichier demandé par
plusieurs écrans est rangé pour le premier ; le rapport de chargement vous
montre, écran par écran, les retours de tête restants et ce qu'ils coûtent.

### 2.5 Le répertoire et les numéros

Le builder tient un répertoire sur la disquette : pour chaque fichier, où il
commence, combien de secteurs, s'il est compressé. Chaque fichier reçoit un
**numéro**, et c'est par ce numéro que le chargeur — et parfois votre code —
le désigne. Les numéros sont attribués par le builder ; dans votre code, vous
utilisez toujours le **nom** (une équate générée vaut le numéro), jamais un
nombre en dur : les numéros changent d'un build à l'autre.

Une entrée de répertoire coûte 8 à 24 octets. C'est le seul prix fixe d'un
fichier : beaucoup de petits fichiers = un répertoire plus long à charger.

### 2.6 La rotation, réglée pour vous

Pendant que le processeur range un secteur en mémoire, le disque tourne.
Si le secteur suivant était juste derrière, il serait déjà passé — il
faudrait attendre un tour complet. Le builder écrit donc les secteurs **un
sur deux**, et décale chaque piste pour que le premier secteur de la piste
suivante arrive sous la tête juste après le déplacement. Le chargeur connaît
ce motif. Résultat : la lecture avance au rythme du disque, sans tour perdu.
Il n'y a rien à déclarer ni à régler ; c'est décrit une fois par format de
disquette.

### 2.7 Les sorties

Le même build produit, au choix : une image `.fd` (émulateurs), `.sap`
(émulateurs, format de préservation), `.hfe` (matériel réel via lecteur
Gotek), `.sd` (lecteur SDDrive). Même contenu, mêmes numéros, mêmes
performances relatives.

### 2.8 Le démarrage

Une disquette produite démarre seule : la machine lit l'amorce, l'amorce
charge le chargeur, le chargeur charge votre première liste et saute dans
votre code. Vous ne configurez que la première liste.

## 3. La mémoire

### 3.1 Où il y a de la place

Trois déclarations, dans le `<layout>` :

- une `<zone>` : de la place — une page, une adresse, une taille ;
- un **rangement** (`<arena>`) : un nom posé sur des zones. Le builder y
  place vos fichiers et publie où chaque chose est tombée ;
- du **réservé** (`<reserved>`) : ce que la machine ou votre code occupe sans
  jamais rien y charger — tampons vidéo, variables, pile. Le déclarer rend la
  carte honnête ; rien ne peut être placé dessus.

```xml
<layout>
    <reserved name="video" page="$02" address="$0000" size="$4000"/>
    <arena name="main">
        <zone page="$04" address="$2000" size="$2000"/>
        <zone page="$05" address="$0000" size="$4000"/>
    </arena>
</layout>
```

Plusieurs rangements servent à séparer des **durées de vie** : ce qui est
chargé au début et reste (`common`), ce qui change à chaque niveau
(`stage`). On décharge un rangement d'un coup, on ne mélange pas les durées.

### 3.2 Où va un fichier : la place attitrée

Chaque fichier reçoit du builder une **place attitrée** — une page et une
adresse — choisie pour que toutes les listes qui le chargent tiennent
ensemble, et gardée d'un chargement à l'autre. Vous ne déclarez rien ; le
rapport d'occupation vous montre où tout est tombé.

Quand une place précise compte — une table que le matériel lit, un tampon à
adresse fixe — le fichier la déclare lui-même :

```xml
<file name="hud.tiles" page="$1A" address="$3000"> ... </file>
```

Deux fichiers peuvent déclarer **la même place** : cela dit au builder qu'ils
ne sont jamais en mémoire en même temps — l'un remplace l'autre. C'est ainsi
qu'on déclare des contenus interchangeables (le décor du niveau 1, celui du
niveau 2) quand quelque chose d'extérieur a besoin qu'ils soient au même
endroit. La plupart du temps, même ça est inutile — voir 3.3.

### 3.3 Les références entre fichiers

Quand un fichier en pointe un autre — le moteur appelle une routine du
niveau, une carte pointe ses tuiles — le builder écrit l'adresse **à
l'avance**, dans les octets mêmes du fichier sur la disquette. C'est gratuit
à l'exécution : rien à résoudre, rien à retenir. C'est possible parce que
chaque fichier a une place attitrée.

Un seul cas fait exception, et le builder le détecte seul : quand **plusieurs
fichiers proposent le même nom** — le niveau 1 et le niveau 2 exportent
chacun leur table `stage.wave` — l'adresse dépend de qui est chargé. La
référence est alors **résolue au chargement** : à chaque fois qu'une liste se
charge, le chargeur la fait pointer sur la version présente en mémoire. Ça
coûte un peu de mémoire et de temps par référence ; le rapport de fin de
build liste ce qui est résolu au chargement et pourquoi — cette liste doit
rester courte, et chaque ligne doit vous sembler normale. Une ligne
surprenante est en général un nom exporté deux fois par erreur.

En une phrase : **tout est écrit à l'avance, sauf ce qui désigne du contenu
interchangeable — et ça se voit dans le rapport.**

### 3.4 Les listes de chargement

Une `<scene>` est la liste de ce qu'un écran charge. Rien d'autre : les
places sont attitrées, il n'y a que des noms.

```xml
<scene name="scenes.stage1">
    <load name="stage1.code"/>
    <load name="stage1.tiles"/>
    <load name="stage1.map"/>
    <load name="stage1.music"/>
</scene>
```

Dans le code, trois gestes : charger une liste, la décharger, enchaîner.
**Charger n'a jamais déchargé personne** : quitter le niveau 1 pour le 2,
c'est décharger `scenes.stage1` puis charger `scenes.stage2`. Si vous oubliez
de décharger, le jeu s'arrête net au chargement suivant, avec le
qui-quoi-où — au moment de la faute, pas trois écrans plus tard sur une
corruption.

Le builder vérifie chaque liste en elle-même (rien ne s'y écrase, tout
rentre). Il ne connaît pas l'ordre de vos écrans et ne prétend pas le
vérifier : l'enchaînement est votre code.

### 3.5 Les collections et leur table d'accès

Certains contenus sont des **collections** : des tuiles, des images, des
ennemis — des dizaines d'éléments du même genre, que le code désigne par un
numéro et n'appelle jamais directement. Une collection trop grosse pour un
fichier se déclare comme un **ensemble** (`<set>`) :

```xml
<set name="stage1.tiles" blocks="~4k">
    <gfxcomp ...les tuiles du niveau.../>
</set>
```

Le builder compile chaque élément, les groupe en fichiers de la taille
demandée (`blocks`), les place, et génère la **table d'accès** : numéro →
page + adresse. Votre code n'atteint la collection QUE par cette table —
c'est le marché qui autorise le builder à ranger librement. La table
elle-même est un fichier ordinaire, chargé et déchargé avec sa collection.

La taille des blocs est un réglage, avec un compromis que le rapport vous
montre : des blocs plus petits remplissent mieux la mémoire (moins de place
perdue en fin de zone), des blocs plus gros se compressent mieux et coûtent
moins d'entrées de répertoire.

Attention aux numéros : ils suivent l'ordre de déclaration des éléments. Tout
est régénéré ensemble à chaque build, donc rien ne se décale — mais ne
stockez jamais un numéro dans une sauvegarde ou un mot de passe qui doit
survivre à une nouvelle version du jeu.

## 4. Les cas d'usage

### 4.1 Le plus petit programme

Un fichier, une liste. Pas de layout : une zone par défaut suffit au builder
pour attribuer une place.

```xml
<file name="demo"><lwasm><asm filename="src/main.asm"/></lwasm></file>
<scene name="boot"><load name="demo"/></scene>
```

### 4.2 Une démo : code, image, musique

Trois fichiers, une liste, un rangement. Le builder place, compresse, ordonne
sur la disquette dans l'ordre de la liste — la démo charge d'une seule passe
de tête.

### 4.3 Un écran-titre et des niveaux qui se remplacent

Deux durées de vie : le moteur (chargé une fois) et l'écran courant. Deux
rangements, une liste par écran :

```xml
<arena name="common"><zone .../></arena>
<arena name="screen"><zone .../><zone .../></arena>

<scene name="boot">          <load name="engine"/> ... </scene>
<scene name="scenes.title">  <load name="title"/>  ... </scene>
<scene name="scenes.stage1"> <load name="stage1.code"/> ... </scene>
```

Le titre et les niveaux déclarent leurs fichiers dans le rangement `screen` :
le builder peut leur attribuer les mêmes pages, puisqu'aucune liste ne les
charge ensemble. Le rapport d'occupation le montre ; rien à déclarer.

### 4.4 Un niveau plus gros qu'une page

Le cas 3.5 en vrai : les tuiles en `<set>`, la carte générée qui connaît la
page et l'adresse de chaque tuile, la table d'accès chargée avec le niveau.
Le niveau 2 déclare son propre ensemble : mêmes numéros de tuiles, autres
dessins, autre découpe — le code ne voit pas la différence.

Si l'ensemble déborde des zones du rangement, le build refuse en donnant le
manque. Si un seul élément dépasse un fichier, il est nommé : un élément ne
se coupe jamais, il faut le faire maigrir.

### 4.5 La troupe commune, chargée une fois

Le joueur, ses armes, les explosions : un ensemble dans le rangement
`common`, chargé au boot, jamais remplacé. Sa table — l'index des objets —
donne au moteur numéro → page + adresse de chaque habitant. Ajouter un
ennemi : une déclaration dans l'ensemble, zéro adresse à choisir.

### 4.6 La frontière entre ce qui reste et ce qui change

Le moteur résident lit les tables du niveau courant — la vague d'ennemis, la
carte. Ces tables existent en version niveau 1 et niveau 2 : deux fichiers,
même nom exporté. C'est LE cas de la référence résolue au chargement (3.3),
et il se déclenche tout seul : vous n'avez rien déclaré, le rapport montre
quelques lignes « résolu au chargement : stage.wave — deux fournisseurs », et
c'est exactement ce que vous attendez. Tout le reste du moteur est écrit à
l'avance.

### 4.7 Remplir les queues

La dernière page d'un ensemble finit rarement pleine. Les petites données du
niveau — sa vague, ses textes — se déclarent comme fichiers du même
rangement : le builder les glisse dans les creux. Leur page vous est publiée
en équate quand votre code doit la monter.

### 4.8 Recommencer sans disquette

Recharger une liste déjà en mémoire ne relit pas la disquette pour rien : le
checkpoint recharge la liste du niveau, l'état repart, le disque ne tourne
que si quelque chose a réellement été écrasé.

### 4.9 Deux disquettes

Déclarez un répertoire par disquette et répartissez les fichiers. Les noms
restent uniques sur tout le jeu ; une référence d'une disquette vers l'autre
marche dans les deux sens. Quand le jeu demande un fichier de l'autre
disquette, le chargeur affiche « Insérez la disquette n » et attend. À vous
de grouper par disquette ce qui se joue ensemble — le rapport de chargement
signale une liste qui demanderait un échange au milieu d'un niveau.

### 4.10 Les données en flux

Musique, échantillons, paroles : des octets consommés en séquence par un
lecteur. Un flux vit dans UN fichier (donc une page au plus) et le lecteur le
lit dans la page montée. Pour un flux plus long, découpez-le en plusieurs
fichiers et enchaînez-les par leur table — le lecteur change de morceau, pas
de page au milieu d'un octet. Aucun contenu du moteur ne lit à cheval sur
deux pages ; ne concevez pas de données qui l'exigent.

## 5. Un exemple suivi de bout en bout

Comment s'articulent l'ensemble, ses fichiers, le rangement et la liste —
sur le cas réel du niveau 1. (Les tailles sont illustratives.)

### Ce que vous écrivez

```xml
<layout>
    <!-- durée de vie : tout le jeu -->
    <arena name="common">
        <zone page="$04" address="$2000" size="$2000"/>
        <zone page="$05" address="$0000" size="$4000"/>
    </arena>
    <!-- durée de vie : le niveau courant -->
    <arena name="stage">
        <zone page="$18" address="$0000" size="$4000"/>
        <zone page="$19" address="$0000" size="$4000"/>
        <zone page="$1A" address="$0000" size="$4000"/>
    </arena>
</layout>

<!-- une collection : 244 tuiles, ~17,8 Ko compilés — trop pour un fichier -->
<set name="stage1.tiles" arena="stage" blocks="~4k">
    <gfxcomp>
        <image name="tiles" filename="src/stages/01/tiles.png" grid="12x12"/>
    </gfxcomp>
</set>

<!-- des fichiers ordinaires, même durée de vie -->
<file name="stage1.map"  arena="stage"> <tilemap .../> </file>
<file name="stage1.wave" arena="stage"> <lwasm .../>   </file>

<scene name="scenes.stage1">
    <load name="stage1.tiles"/>     <!-- l'ensemble, par son nom -->
    <load name="stage1.map"/>
    <load name="stage1.wave"/>
</scene>
```

Trois lignes de `<load>`. Aucune adresse, aucune page, aucun mode.

### Ce que le builder en fait

1. **Il mesure.** Chaque tuile est compilée seule : 244 morceaux de 30 à
   120 octets, 17 810 octets en tout.
2. **Il coupe.** L'ensemble devient des fichiers d'environ 4 Ko, dans
   l'ordre des tuiles : `stage1.tiles.0` (tuiles 0–58, 3 980 o),
   `.1` (59–121, 4 010 o), `.2`, `.3`, `.4` (le reste, 1 828 o) — plus la
   **table** `stage1.tiles.idx` : 244 entrées de 3 octets, 732 o. À partir
   d'ici, l'ensemble n'existe plus : il n'y a que des fichiers.
3. **Il place.** L'optimiseur du rangement `stage` attribue les places
   attitrées — les fichiers à adresse déclarée d'abord (aucun ici), puis du
   plus gros au plus petit :

   | fichier | page | adresse |
   |---|---|---|
   | stage1.tiles.3 (4 102 o) | $18 | $0000 |
   | stage1.tiles.1 (4 010 o) | $18 | $1006 |
   | stage1.tiles.0 (3 980 o) | $18 | $2AB0 |
   | stage1.map (5 940 o)     | $19 | $0000 |
   | stage1.tiles.2 (3 890 o) | $19 | $1734 |
   | stage1.tiles.4 (1 828 o) | $19 | $2666 |
   | stage1.tiles.idx (732 o) | $19 | $2D8A |
   | stage1.wave (610 o)      | $19 | $3066 |

4. **Il génère, maintenant que tout est placé.** La table `.idx` est
   remplie : l'entrée 137 dit « page $19, adresse $1B12 » — la place du
   fichier qui porte la tuile 137, plus son décalage dedans. La carte
   `stage1.map` écrit ses pointeurs de tuiles de la même façon. Tout est
   écrit à l'avance : zéro donnée de liaison pour tout ça.
5. **Il écrit la disquette.** Huit entrées de répertoire, les huit fichiers
   compressés collés bout à bout dans l'ordre de la liste, et la liste
   elle-même devient une petite table sur disque : huit fois
   (page, adresse, numéro).

### Ce qui se passe en jeu

- `charge(scenes.stage1)` : le chargeur lit la liste, charge les huit
  fichiers en un seul balayage de tête, décompresse, et résout les quelques
  références « au chargement » — ici, celle du moteur vers
  `stage.tiles.idx`, car le niveau 2 exporte le même nom (le cas 4.6, la
  frontière).
- Le code veut la tuile 137 : il lit l'entrée 137 de la table → page $19,
  $1B12 → monte la page, y va. Il ne sait pas — et n'a pas à savoir — dans
  quel fichier la coupe l'a mise.
- Fin du niveau : `décharge(scenes.stage1)`, `charge(scenes.stage2)`. Le
  niveau 2 a son propre ensemble, ses propres fichiers, sa propre table qui
  exporte le même nom — la référence du moteur pointe maintenant sur elle.
  Mêmes numéros de tuiles, autres dessins, autre découpe : le code ne voit
  pas la différence.

### L'articulation en quatre phrases

L'**ensemble** est une déclaration : il n'existe qu'au build, où il PRODUIT
des fichiers — les morceaux, et la table qui est la porte d'entrée. Les
**fichiers** sont la seule chose que connaissent la disquette, le répertoire,
la liste et le chargeur. Le **rangement** est l'endroit où ces fichiers
reçoivent leur place attitrée — et la durée de vie qu'ils partagent. La
**liste** ne manipule que des noms : charger le nom d'un ensemble, c'est
charger les fichiers qu'il a produits ; la décharger, c'est les lâcher tous.

## 6. Quand le build refuse

Trois familles, toujours avec le fichier, la ligne et le geste à faire :

1. **Ça ne rentre pas** : un budget dépassé (le manque en octets), un élément
   plus gros qu'un fichier (son nom), un ensemble plus large que son
   rangement (le nombre de zones qu'il faudrait).
2. **C'est ambigu** : deux fichiers d'une même liste à la même place ; une
   adresse écrite à l'avance vers un nom que deux fichiers proposent à des
   places différentes ET que rien ne désigne comme interchangeable — le
   message propose les deux sorties : résoudre au chargement, ou attitrer la
   même place aux deux.
3. **Ça s'est écrasé en jeu** : pas un refus du build — l'arrêt net au
   runtime, avec qui recouvrait quoi, où. La cause la plus courante : un
   déchargement oublié.

## 7. La performance : ce qui coûte, où le voir

- **Le chargement** : secteurs lus (la compression les réduit), retours de
  tête (l'ordre disquette suit vos listes ; le rapport montre ce qui reste),
  références résolues au chargement (le rapport en donne la liste et le
  coût). La rotation est réglée d'avance, vous n'y pouvez ni bien ni mal.
- **La mémoire** : le rapport d'occupation, page par page, écran par écran —
  les creux, les queues d'ensembles, ce qui dort. Le réglage `blocks` des
  ensembles arbitre creux contre compression.
- **La mémoire de liaison** : chaque référence résolue au chargement occupe
  le pool du chargeur tant que son fichier est en mémoire. La liste doit
  rester courte ; si elle enfle, un nom est exporté en double quelque part.
