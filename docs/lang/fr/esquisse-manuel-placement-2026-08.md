---
date: 2026-08-08
sujet: Esquisse du manuel utilisateur du placement, écrite pour éprouver le
  modèle cible (région / arène / découpage / table d'accès / références).
statut: brouillon d'étude — la syntaxe montrée est celle du modèle EN DISCUSSION,
  pas celle du builder d'aujourd'hui. Les failles relevées en l'écrivant sont
  consignées dans analyse-placement-2026-08.md §11.
---

# Placer et charger — esquisse de manuel

## La machine, en trois phrases

La mémoire d'un TO8 est faite de pages de 16 Ko. Le programme n'en voit
qu'une poignée à la fois : une zone fixe où vit le code résident, et une
fenêtre dans laquelle une page de données vient se monter quand on la demande.
Un jeu complet ne tient pas en mémoire : on charge des morceaux depuis la
disquette pendant que le jeu tourne, et on écrase ce qui ne sert plus.

Votre travail : dire ce qui existe (les fichiers), où ça peut aller (les
emplacements), et ce que chaque écran du jeu charge (les listes de
chargement). Le builder mesure, découpe, range, écrit les tables — et refuse
au build ce qui ne peut pas marcher.

## Les idées, une phrase chacune

- **Un emplacement** (`<zone>`) : de la place — une page, une adresse, une
  taille. C'est la seule chose qui parle de mémoire physique.
- **Un rendez-vous** (`<region>`) : un nom posé sur des emplacements. Tout ce
  qui s'y charge, quel que soit l'écran, atterrit au même endroit — c'est ce
  qui permet au niveau 2 de remplacer le niveau 1, à l'octet près.
- **Un rangement** (`<arena>`) : un nom posé sur des emplacements. Vous y
  confiez des fichiers, le builder trouve la place et publie où chaque chose
  est tombée. Personne n'a besoin de savoir où — on y accède par une table.
- **Une liste de chargement** (`<scene>`) : ce qu'un écran du jeu charge, et
  où. Le jeu la demande par son nom ; en la quittant, il nomme ce qu'il lâche.
- **Le découpage** : un contenu trop gros pour une page (les tuiles d'un
  niveau, une troupe d'ennemis) se déclare découpable. Le builder le coupe en
  morceaux qui tiennent, les range, et génère la **table d'accès** — numéro →
  page + adresse. Votre code n'atteint ce contenu QUE par cette table ; c'est
  le marché qui autorise le builder à ranger librement.
- **Les références entre fichiers** : quand un fichier en pointe un autre, le
  builder écrit l'adresse de deux façons. *Gravée* au build : gratuit à
  l'exécution, mais la cible doit toujours se trouver là où c'était gravé.
  *Résolue au chargement* : la cible peut être n'importe où, mais chaque
  référence coûte de la mémoire et du temps à chaque chargement. Le builder
  choisit bien tout seul ; vous n'y touchez que si le rapport de fin de build
  vous montre un coût qui dépasse.

## Cas 1 — une démo d'un seul tenant

Un programme, une page, un écran. Un rendez-vous, une liste, c'est tout :

```xml
<layout>
    <region name="main">
        <zone page="$01" address="$6100" size="$1F00"/>
    </region>
</layout>
...
<scene name="boot">
    <load name="demo" region="main"/>
</scene>
```

Le budget (`size`) est une promesse que le builder tient pour vous : le jour
où `demo` grossit au-delà, le build refuse et donne le dépassement en octets.

## Cas 2 — un écran-titre et des niveaux qui se remplacent

Le titre et les niveaux ne coexistent jamais : ils peuvent occuper la même
mémoire. Déclarez les rendez-vous une fois, et une liste par écran :

```xml
<region name="stage" page="$01" address="$8000" size="$0761"/>

<scene name="scenes.title">  <load name="title"  region="stage"/> </scene>
<scene name="scenes.stage1"> <load name="stage1" region="stage"/> </scene>
<scene name="scenes.stage2"> <load name="stage2" region="stage"/> </scene>
```

Dans le code, trois gestes : charger une liste, la décharger, enchaîner.
Quitter le stage 1 pour le 2, c'est `unload(scenes.stage1)` puis
`load(scenes.stage2)`. **Charger n'a jamais déchargé personne** : si vous
oubliez le premier geste, le jeu s'arrête au chargement suivant avec un
message précis (qui recouvrait qui, où) — au moment de l'erreur, pas trois
écrans plus tard sur une corruption.

Deux écrans peuvent viser la même mémoire par des déclarations différentes :
le builder vous le *montre* (rapport d'occupation) mais ne l'interdit pas —
c'est ainsi qu'un titre reprend la place d'un niveau. Il n'interdit que ce
qui est faux à coup sûr : deux fichiers d'une même liste qui s'écrasent.

## Cas 3 — un niveau plus gros qu'une page

Les tuiles du niveau 1 pèsent trois pages. Vous ne choisissez ni les coupes
ni les pages de chaque tuile — vous donnez un budget et un contenu :

```xml
<region name="tiles">
    <zone page="$18" address="$0000" size="$4000"/>
    <zone page="$19" address="$0000" size="$4000"/>
    <zone page="$1A" address="$0000" size="$4000"/>
</region>

<load name="stage1.tiles" region="tiles"/>   <!-- contenu déclaré découpable -->
```

Le builder compile tuile par tuile, mesure, coupe au plus juste, et la carte
du niveau — générée aussi — sait pour chaque tuile sa page et son adresse.
Si le contenu déborde du budget, le build refuse en disant combien de pages
il faudrait. Si une seule tuile dépasse une page, elle est nommée : un
morceau ne se coupe jamais en deux, il faut le faire maigrir.

Le niveau 2 déclare son propre contenu vers le même rendez-vous : mêmes
numéros de tuiles, autres dessins, autre découpe — votre code ne voit pas la
différence, il passe par la table.

## Cas 4 — la troupe commune, chargée une fois

Le joueur, ses armes, les explosions : chargés au boot, jamais remplacés,
et personne ne se soucie de leur adresse. C'est un rangement :

```xml
<arena name="objects">
    <zone page="$04" address="$2000" size="$2000"/>
    <zone page="$05" address="$0000" size="$4000"/>
</arena>

<load name="common.player"    arena="objects"/>
<load name="common.explosion" arena="objects"/>
```

Le builder range (les gros d'abord), publie l'endroit de chacun, et la table
des objets — générée — donne au moteur le numéro → page + adresse de chaque
habitant. Ajoutez un ennemi : une ligne de `<load>`, zéro adresse à choisir.

## Cas 5 — remplir les queues

La dernière page d'un contenu découpé finit rarement pleine. Plutôt que de
perdre le reste, déposez-y ce que le niveau porte de petit — sa vague
d'ennemis, ses textes : un fichier de plus vers le même rendez-vous, déclaré
après le contenu découpé, tombe dans ce qui reste, et sa page vous est
publiée en équate.

## Ce que le builder garantit, montre, ou laisse au runtime

**Refusé au build** : un budget dépassé (avec le manque en octets) ; deux
fichiers d'une même liste qui s'écrasent ; un emplacement qui mord sur du
réservé ; une adresse gravée vers une cible qui peut bouger sans son graveur.

**Montré, jamais interdit** : l'occupation réelle page par page, écran par
écran ; les recouvrements entre écrans ; ce qui dort ; ce que chaque liste
coûte en mémoire de liaison.

**Au runtime, en clair** : charger sur de l'occupé non déchargé s'arrête net
avec le qui-quoi-où. Le builder ne connaît pas l'ordre de vos écrans, il ne
prétend pas le vérifier — c'est votre enchaînement, c'est votre code.
