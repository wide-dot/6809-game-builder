---
date: 2026-08-06
sujet: Carte d'occupation mémoire en HTML — maquette validée, implémentation à faire
statut: maquette faite, non implémentée dans le builder
lié à: modele-zones-2026-08.md (étape 6 du plan)
---

# Carte d'occupation mémoire

## Pourquoi

Le rapport texte (`dist/ram-map-<cible>.txt`) affichait **100 % partout** : il
mesure le remplissage de la *région*, et depuis que les tailles se mesurent, une
région épouse son contenu. Il ne pouvait pas mieux dire — le layout ne déclarait
nulle part où une page commence ni où elle finit. 75 114 octets dormaient
au-dessus des dernières régions, invisibles.

Et depuis qu'on a levé l'interdiction de recouvrement entre contenants (le
builder ignore l'ordre des écrans, donc il ne doit pas prétendre le vérifier),
il faut **montrer** ce qu'on ne refuse plus. C'est le rôle de ce rapport.

## Maquette

Construite avec les vraies données de r-type, publiée le 2026-08-06 :
<https://claude.ai/code/artifact/426c327f-5062-4e93-89b0-5a7de59d6a6b>

Ce qu'elle établit, et qui est validé :

- **Les 32 pages de la machine**, pas seulement celles que le layout déclare.
  Les tampons vidéo, la page directe du moniteur, le loader et son pool y
  figurent en hachuré : ils occupent la RAM même si aucun fichier ne s'y charge.
  Sans eux la carte ment par omission. C'est un usage supplémentaire de
  `<reserved>` : documenter le matériel, pas seulement protéger le pool.
- **Les scènes se cochent**, plusieurs à la fois. Décocher `stage2` montre la
  machine après le seul niveau 1 ; tout cocher fait apparaître les relais.
- **Les couches se cochent** aussi (résident, commun, niveau, images, audio,
  ennemis, machine).
- **Les superpositions s'empilent sur des couloirs** au lieu de se cacher : la
  page grandit d'une ligne et on voit qui partage quoi.
- **Le vide est un objet à part entière** — des blocs mesurés et étiquetés, pas
  un fond hachuré. Trois totaux séparés : en régions, réservé, non couvert.

## Les trois granularités de chargement

Le rapport coche des scènes parce que c'est ce que la configuration déclare.
Mais il y en a trois, et la distinction compte :

| granularité | ce que c'est | le builder la connaît ? |
|---|---|---|
| scène | ce qu'une transition charge en bloc | oui, déclarée |
| contenant | l'unité de remplacement : ce qui se substitue à quoi | oui |
| fichier | l'unité élémentaire (`loader.file.load`) | **non**, c'est le code qui décide |

Le firmware SDDrive charge déjà un fichier isolé, hors de toute scène : le
rapport l'ignore et la carte ment sur ce point. Les déclarer comme des scènes à
un seul fichier suffirait, sans introduire de concept.

## À trancher avant d'implémenter

- **Le total « non couvert » additionne des choses de nature différente** : les
  pages vierges, les queues récupérables, et ce qu'une autre combinaison de
  scènes occupe. Le chiffre est juste, sa lecture ne l'est pas. À scinder en
  « jamais utilisé par personne » et « libre dans cette combinaison ».
- **`<window>` doit disparaître avec cette refonte.** Plus rien ne s'en sert
  pour placer ; le rapport est son dernier usage, pour dire ce qui reste en haut
  d'une page. Le modèle veut qu'il parle par zone à la place — de l'espace que
  personne n'a déclaré n'est offert à personne.

## Comment l'implémenter

Un fichier statique produit par le builder à côté de `ram-map-<cible>.txt`,
qu'on **garde** : le texte se lit en CI et se compare dans un diff git, le HTML
sert à explorer. Données injectées en JSON dans la page, aucune dépendance
externe, ouvrable hors ligne. Le générateur est le pendant de `RamMapReport`.
