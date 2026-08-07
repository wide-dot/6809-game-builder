---
date: 2026-08-06
sujet: Carte d'occupation en HTML — implémentée (v1), design à itérer sur les données r-type
statut: implémentée dans le builder, produit dist/occupancy-<cible>.html
lié à: modele-zones-2026-08.md (étape 6 du plan)
---

# Rapport d'occupation

## Ce qui est implémenté

Le builder produit `dist/occupancy-<cible>.html` à la place de l'ancien
`ram-map-<cible>.txt`, qui a disparu (il affichait 100 % partout et ne savait
ni montrer une collision ni se filtrer). Le `pool-map` texte, lui, reste : il
mesure un autre budget.

Une page statique, sans dépendance, ouvrable hors ligne — données en JSON dans
la page, rendu en SVG par le script embarqué. Générateur :
`report/OccupancyReport.java` + gabarit `resources/report/occupancy.html`.

### Deux vues, un panneau latéral

**Vue RAM.** Les pages de la machine dessinées à leur capacité réelle —
`<layout pages="32">` (défaut) ou `pages="8"` pour un MO6 128K. **Rien n'est
coché par défaut** : on clique les éléments de l'arbre (scènes → fichiers,
plus le groupe `machine` pour les `reserved`) et ils se peignent au fil de
l'eau. Une **collision de destination entre éléments cochés** se peint en
rouge par-dessus, avec la liste détaillée (page, plage, les deux camps et
leur scène). Deux scènes qui chargent le **même fichier à la même adresse**
ne collisionnent pas : mêmes octets, c'est un rechargement. Les fichiers
**sans destination RAM** (tables de scènes, export-only) sont listés à part,
avec leur taille.

**Vue média.** Un sélecteur d'instance (la disquette, nommée par son fichier
image), puis la géométrie réelle : une grille de secteurs par face, pistes en
lignes. Chaque secteur écrit porte la couleur de sa section ; un clic dans
l'arbre (sections → contenus, triés par taille) surligne les secteurs de
l'élément et estompe le reste — l'alternance de faces du remplissage cylindre
devient visible. Pas de notion de collision : le média refuse les doubles
écritures au build.

### D'où viennent les données

- RAM : `ctx.ramMap` (ce que chaque scène charge où) + `ctx.regions`
  (réservations, nombre de pages). Corrigé au passage : la carte survivait aux
  passes du build sans être purgée — chaque fichier apparaissait une fois par
  passe (auto-collisions dans le rapport, doubles comptes silencieux dans le
  pool-map). `RamMap.forget(scene)` avant ré-enregistrement.
- Média : le **journal d'écritures** de `FdUtil` — le seul endroit qui sait où
  les octets atterrissent — croisé avec le **nom** de ce qu'on écrit, que seul
  l'appelant connaît : les écritures média prennent un paramètre nom
  (`MediaDataInterface.cwrite(location, data, name)`), et `FloppyDiskPlugin`
  verse le journal dans `ctx.occupancy` avec la géométrie de l'instance.
  Même purge inter-passes (`declareInstance` oublie les écritures de
  l'instance).

### `<window>` a disparu

Le rapport était son dernier lecteur ; le retrait a été fait avec cette
implémentation. Conséquence assumée : la **première région sans adresse d'une
page** doit désormais dire son adresse (l'erreur le dit) — c'est la doctrine
« une page ne dit pas où elle commence, ça appartient à la machine », sans
plus d'élément dédié pour le contourner. Les fenêtres qu'r-type et sound/mo6
déclaraient étaient décoratives ou remplacées par trois `address="$0000"`.

## À itérer (sur les données r-type)

La v1 est visible sur `games/r-type/dist/occupancy-fd.html`. Pistes déjà
identifiées, à trancher en regardant l'écran :

- un total « libre » par page ou global (la capacité moins les cochés est dans
  l'en-tête, pas la ventilation) ;
- la légende des couleurs de sections dans la vue média ;
- un lien croisé entre les deux vues (cliquer un fichier RAM → le voir sur le
  disque, et inversement) ;
- les chargements hors scène (SDDrive) restent invisibles — les déclarer comme
  scènes à un fichier suffirait, sans nouveau concept.
