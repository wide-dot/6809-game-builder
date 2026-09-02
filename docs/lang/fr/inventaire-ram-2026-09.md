# Inventaire RAM de r-type — où va la place, et ce qu'on peut encore y mettre

*Septembre 2026. Mesuré sur le build du 02/09, à partir des empreintes
physiques du rapport d'occupation (une place y est désormais dessinée là où
elle est, cf. [`modele-memoire-2026-09.md`](modele-memoire-2026-09.md)).*

## Ce que chaque état de RAM occupe

Les dix compositions déclarées, sur les 512 Ko de la machine :

| état | occupé | libre |
|---|---|---|
| boot | 166 Ko | 346 Ko |
| title | 192 Ko | 320 Ko |
| **stage 1** | **421 Ko** | **91 Ko** |
| stage 2 | 393 Ko | 119 Ko |
| stage 7 | 304 Ko | 208 Ko |
| stage 3 | 331 Ko | 182 Ko |
| stage 4 | 294 Ko | 218 Ko |
| stage 5 | 250 Ko | 262 Ko |
| stage 8 | 218 Ko | 294 Ko |
| stage 6 | 220 Ko | 292 Ko |

**Le stage 1 est l'état contraignant** : 91 Ko libres, deux fois moins que le
stage 3. Le stage 2 le suit. Tout budget « pour tous les stages » se mesure
donc contre le stage 1.

Attention à la lecture : ces 91 Ko sont la somme de ce qui reste **dans les
32 pages**, y compris des pages entières qu'un autre stage utilise. C'est de
la place réelle pour le stage 1, mais elle n'est pas contiguë.

## La carte des 32 pages

Les 32 pages sont toutes utilisées. Voici où la place se trouve vraiment, en
prenant pour chaque page l'état qui la remplit le plus :

| page | remplissage max | libre | chargée dans |
|---|---|---|---|
| 15 | 12 % | **14,0 Ko** | s1, s3, s4, s7 (arène `enemies`) |
| 11 | 32 % | **10,8 Ko** | stage 4 seul (`pscroll.edit`) |
| 23 | 48 % | **8,2 Ko** | **tous** (`objects`, `collision`, `stageinit`) |
| 22 | 76 % | 3,7 Ko | s1, s2 |
| 1 | 81 % | 2,9 Ko | **tous** (résident : moteur, écrans, lots) |
| 13 | 88 % | 1,9 Ko | s1, s4, s7 |
| 14 | 89 % | 1,7 Ko | s1, s4, s5, s7 |
| 0, 2-10, 12, 16-21, 24-31 | 94-99 % | 0,0-0,7 Ko chacune | — |

Autrement dit : **48 Ko libres au total, mais 33 Ko dans trois pages
seulement** (15, 11, 23), et le reste en miettes de quelques centaines
d'octets.

## Les conteneurs, capacité déclarée contre occupation

| conteneur | pages | capacité | occupé | libre | chargé dans |
|---|---|---|---|---|---|
| `stage5.gfx` | 24-25 | 120 Ko | 20 Ko | **100 Ko** | s5 |
| `stage6.gfx` | 24,25,27 | 120 Ko | 40 Ko | **80 Ko** | s6 |
| `stage8.gfx` | 24-27 | 119 Ko | 48 Ko | **71 Ko** | s8 |
| `stage5.foes` | 16-19 | 112 Ko | 50 Ko | **62 Ko** | s5 |
| `stage3.foes` | 16-20 | 112 Ko | 62 Ko | **50 Ko** | s3 |
| `stage7.gfx` | 24-29 | 120 Ko | 86 Ko | 34 Ko | s7 |
| `stage3.gfx` | 24,25,27 | 70 Ko | 37 Ko | 33 Ko | s3 |
| `stage4.gfx` | 24-28,30 | 103 Ko | 72 Ko | 32 Ko | s4 |
| `title` | 24-25 | 48 Ko | 23 Ko | 25 Ko | title |
| `enemies` | 12-15 | 61 Ko | 44 Ko | **18 Ko** | s1,s3,s4,s5,s6,s7 |
| `stage1.gfx` | 24-30 | 120 Ko | 103 Ko | 17 Ko | s1 |
| `stage1.foes` | 16-22 | 112 Ko | 97 Ko | **15 Ko** | s1 |
| `pscroll.edit` | 11 | 16 Ko | 5 Ko | 11 Ko | s4 |
| `objects` | 4-10,12,23 | 118 Ko | 107 Ko | **11 Ko** | **tous** |
| `stage2.foes` | 16-22 | 112 Ko | 105 Ko | **7,3 Ko** | s2 |
| `stage2.gfx` | 24-31 | 120 Ko | 113 Ko | **6,8 Ko** | s2 |
| `stageN.res` | 1 | 2,7 Ko | 0,1-2,6 Ko | 0,1-2,7 Ko | sN |

Les régions à destination fixe (`engine` 5,3 Ko, `stage` 16,3 Ko pour neuf
écrans alternatifs, `collision` 27 Ko, `pscroll.vid` 7,4 Ko) n'ont pas de
budget déclaré : elles valent ce que leur contenu mesure.

## Ce que coûte une variante `offset 1`

Mesuré sur les 1 158 poses compilées du jeu : **une variante pré-décalée pèse
1,06 fois la variante droite**. Ajouter `shift="1"` à une image **double donc
son code**, à 6 % près.

Aujourd'hui **1 070 images sur 1 158 n'ont que la parité droite**, pour
1 007 Ko de code. Les doter toutes coûterait 1 068 Ko — sans objet. La
question est donc toujours « lesquelles », jamais « toutes ».

## Où il y a de la place, et pour qui

**Pour du commun** (chargé dans tous les états), la marge est de **11 Ko dans
l'arène `objects`**, plus 8,2 Ko de page 23 et 2,9 Ko de page 1 hors arène.
C'est peu : le commun est ce qui pèse le plus lourd, puisqu'il est là dans les
dix états. Un doublement de parité y est possible sur des images totalisant
**au plus 11 Ko en ND0**.

**Pour du spécifique**, tout dépend du stage :

- **stages 5, 6, 8** : 60 à 100 Ko libres dans leurs arènes. On peut y doubler
  la parité de presque n'importe quoi ;
- **stages 3, 4, 7** : 30 à 50 Ko. Confortable ;
- **stage 1** : 15 Ko côté ennemis, 17 Ko côté décor — le budget le plus
  serré, et c'est le stage qui porte le boss ;
- **stage 2** : 7,3 Ko côté ennemis, 6,8 Ko côté décor. **C'est le plus
  contraint des dix**, alors que son état de RAM global (119 Ko libres) le
  laisserait croire à l'aise : sa place manque là où ses ressources vont.

## Ce que l'inventaire dit du rangement

Trois observations, sans jugement sur ce qu'il faut en faire :

1. **Les arènes des stages 5, 6 et 8 sont surdimensionnées** — 120 Ko déclarés
   pour 20 à 48 Ko utilisés. Elles ne coûtent rien tant que personne d'autre ne
   veut leurs pages, mais ces pages (24-27) sont justement celles que tous les
   stages se disputent : chaque stage y range son décor, en alternance.
2. **La page 15 est vide à 88 %** (14 Ko), à l'intérieur de l'arène `enemies`
   qui est déjà commune à six stages. C'est la plus grosse réserve utilisable
   sans toucher à la carte.
3. **La page 11 (10,8 Ko) n'existe que pour le stage 4** (`pscroll.edit`).
   Pour les neuf autres états, c'est une page entière inutilisée.

## Comment reproduire ces chiffres

Tout vient du rapport d'occupation, `dist/occupancy-fd.html`, dont les données
JSON portent maintenant les empreintes physiques de chaque place. Les tailles
de poses viennent des listings d'assemblage (`OPT C,CT` y met aussi les
cycles). Aucun chiffre de ce document n'est estimé.
