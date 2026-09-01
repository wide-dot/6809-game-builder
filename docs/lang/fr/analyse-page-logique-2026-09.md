# `page` : une valeur de registre qui se fait passer pour une identité

Statut : **analyse, rien n'est décidé**. Écrite le 01/09/2026 à la demande de
l'auteur, après qu'une ligne du rapport d'occupation a débordé de ses 16 Ko.
Elle établit ce que `page` nomme réellement, ce que cette ambiguïté coûte
aujourd'hui, et ce qu'une *page logique* changerait — en tenant compte des
deux machines cibles et d'une troisième qu'on se projette, le Tandy CoCo 3.

## 1. Ce que `page` nomme aujourd'hui

`ram.set` (`engine/system/to8/ram/ram.asm`) ne consulte jamais `page` pour
décider quoi faire : il **dispatche sur la plage d'adresse** de la
destination, puis écrit la valeur dans le registre qui gouverne *cette*
fenêtre.

| plage (TO8) | registre écrit | ce que la valeur désigne | unité |
|---|---|---|---|
| `$A000-$DFFF` | `$E7E5` | numéro de page RAM | 16 Ko |
| `$6000-$9FFF` | *aucun* | **rien** — la RAM y est fixe, la valeur est ignorée | — |
| `$4000-$5FFF` | bit 0 de `$E7C3` | index de **demi-page** | 8 Ko |
| `$0000-$3FFF` | `$E7E6` | numéro de page RAM + bit RAM-sur-cartouche | 16 Ko |

`page` est donc **la valeur d'un registre**, et l'unité qu'elle désigne change
avec la fenêtre : 16 Ko, 8 Ko, ou rien. C'est exact pour `ram.set`, qui est un
dispatcheur. Ça ne l'est pas pour le builder, qui s'en sert comme d'une
**identité de silicium** — et deux choses différentes y portent le même nom.

## 2. Ce que l'ambiguïté coûte, par gravité croissante

**Le rapport mélange des mémoires sans rapport.** Il groupe par `page` et
dessine une ligne de 16 Ko dont l'origine est la plus petite adresse déclarée.
Sur r-type, la « page 1 » réunit une demi-page vidéo (`$4000`) et la RAM
résidente non paginée (`$6100-$9FFF`) : l'origine tombe à `$4000`, et tout ce
qui est à `$8000` et au-delà sort du cadre. C'est le symptôme visible, et le
plus bénin.

**Deux déclarations décrivent les mêmes octets sans que rien ne le sache.** Le
config de r-type le dit lui-même, à propos du tampon vidéo du stage 4 : le
`<reserved pscroll.vid.half1 page="$00" address="$2000">` et le
`<region pscroll.vid page="$01" address="$4000">` « décrivent le même silicium
en référentiel de page ». Le builder, lui, voit deux couples `(page, adresse)`
étrangers l'un à l'autre.

**Et donc tous les contrôles ont le même angle mort.** Le chevauchement
intra-scène (`SceneChecks`), le contrôle de composition (`CompositionChecks`),
l'occupation du packer (`ArenaPacker.Placed`), le contrôle région ∩ réservé
(`LayoutPlugin`), la carte d'occupation : **tous comparent des couples
`(page, adresse)`**. Deux alias du même silicium ne se croisent jamais. Poser
un fichier en `page 0 / $2000` et un autre en `page 1 / $4000` les fait
s'écraser sans qu'aucun contrôle ne bronche.

C'est la même famille de défaut que celui qui a coûté la journée du 01/09 —
le packer croyait exclusifs deux fichiers que le jeu gardait ensemble — mais
d'une espèce plus vicieuse : là, c'était une hypothèse fausse sur le temps ;
ici, c'est une hypothèse fausse sur **l'identité**.

## 3. La seconde moitié du problème : deux machines, deux cartes

Le MO6 n'a pas les mêmes fenêtres aux mêmes adresses que le TO8 :

| fenêtre | TO8 | MO6 |
|---|---|---|
| vidéo | `$4000-$5FFF` | `$0000-$1FFF` |
| résidente | `$6000-$9FFF` | `$2000-$5FFF` |
| données (paginée) | `$A000-$DFFF` | `$6000-$9FFF` |
| moniteur | `$E000-…` | `$A000-$AFFF` |
| cartouche (paginée) | `$0000-$3FFF` | `$B000-$EFFF` |

Or un `<region>` déclare une **adresse CPU**. Une carte mémoire est donc liée
à une machine par construction, et le corpus en porte la trace : `examples/sound`
existe en deux configurations dont **73 lignes sur 148 diffèrent**, avec ce
commentaire — « the MO6 map differs from the TO8 one, so the layout is declared
per target and not shared ». Même jeu, même contenu, deux fichiers à maintenir
en parallèle.

Ce n'est pas un problème distinct du premier : c'est le même. `page` et
`address` disent ensemble *où*, en mêlant ce qui appartient à la machine (la
fenêtre, son registre, son unité) et ce qui appartient au jeu (quel bloc de
contenu, à quel décalage).

## 4. Le CoCo 3, pour se projeter

Le Tandy Color Computer 3 (GIME) organise sa mémoire d'une façon **régulière**,
là où le Thomson est irrégulier :

- **huit fenêtres de 8 Ko** couvrant la totalité des 64 Ko vus par le 6809 —
  `$0000-$1FFF`, `$2000-$3FFF`, … `$E000-$FFFF` ;
- **un registre par fenêtre**, `$FFA0` à `$FFA7`, chacun portant un numéro de
  bloc physique de 6 bits : **64 blocs de 8 Ko, soit 512 Ko** ;
- **deux jeux de registres** (`$FFA0-$FFA7` et `$FFA8-$FFAF`), commutables par
  le bit 0 de `$FF91` — deux cartes mémoire complètes entre lesquelles on
  bascule d'une écriture ;
- la mémoire vidéo se lit **par le même MMU** côté CPU ; c'est le *départ de
  l'affichage* qui a ses propres registres, pas l'accès.

Trois conséquences pour notre modèle. D'abord, **l'unité y est 8 Ko partout** —
la même que la demi-page vidéo du TO8, et la moitié de sa page. Ensuite, il n'y
a **aucune fenêtre spéciale** : pas de zone résidente non paginée, pas de bit
« RAM par-dessus la cartouche ». Enfin, les huit fenêtres sont
**interchangeables** : n'importe quel bloc peut apparaître à n'importe quelle
fenêtre, ce qui rend l'idée « la fenêtre décide du sens de `page` » caduque là-bas.

Autrement dit : le modèle actuel est taillé sur l'irrégularité Thomson, et la
machine suivante est régulière. Un modèle qui nommerait le silicium et
laisserait la machine dire comment l'atteindre marcherait sur les trois ; le
modèle actuel demandera un cas particulier de plus.

## 5. Ce qu'une page logique nommerait

Trois modèles possibles, du moins au plus engageant.

### (a) Statu quo, plus un correctif de rapport

Découper la ligne d'une page en grappes quand son contenu ne tient pas dans une
fenêtre. Une dizaine de lignes de JS, aucun risque. **Le symptôme disparaît,
l'angle mort reste**, et rien ne progresse sur le multi-machine.

### (b) `page` désigne un bloc physique, la machine dit comment l'atteindre

`page` cesse d'être une valeur de registre pour devenir un **numéro de bloc de
RAM**. L'adresse continue de dire la fenêtre (comme `ram.set` le fait déjà), et
`machine.xml` — qui existe et porte déjà le nombre de pages et l'expression de
l'octet de page — gagne la description des fenêtres : plage, registre, unité,
et comment un numéro de bloc se traduit en valeur de registre.

Les alias disparaissent par construction : la demi-page vidéo 1 du TO8 *est* un
bloc de 8 Ko, nommé une seule façon, et les contrôles comparent enfin des
identités. Le rapport groupe par silicium, la page 1 redevient une ligne
ordinaire.

Ce que ça ne règle pas : les adresses restent machine-spécifiques, donc les
deux configurations d'un même jeu restent deux fichiers.

### (c) La déclaration nomme la fenêtre, pas l'adresse

`<region name="music" window="cart" page="$06"/>` — l'adresse devient un
*décalage dans la fenêtre* quand elle compte, et la machine dit où cette fenêtre
se trouve. C'est (b) plus la portabilité : la même carte mémoire vaut pour le
TO8 et le MO6, et le CoCo 3 s'y coule sans cas particulier puisque ses huit
fenêtres sont exactement ce vocabulaire.

Le prix est le plus élevé : c'est le vocabulaire des configs qui change, donc
tout le corpus. Le gain est le plus grand : une carte au lieu de deux, et
l'angle mort fermé.

## 6. Ce qu'il faudrait toucher

Par ordre de profondeur, ce qui compare aujourd'hui des couples `(page, adresse)` :

| endroit | rôle |
|---|---|
| `SceneChecks` | chevauchement intra-scène, empiètement sur `<reserved>` |
| `CompositionChecks` | chevauchement dans un état de RAM |
| `ArenaPacker` | `Placed`, le calcul du début de zone (phase 5) |
| `LayoutPlugin` | région ∩ réservé |
| `Regions` / `RamMap` / `Cuts` | le stockage des placements |
| `OccupancyReport` | le groupement par page, l'origine d'une ligne |
| `SceneGenerator` | l'octet de page écrit dans la table de scène |
| `machine.xml` + `Machines` | le seul endroit qui devrait connaître les fenêtres |

Côté runtime, `ram.set` ne changerait **pas** : il continuerait de dispatcher
sur l'adresse. Ce qui changerait, c'est la valeur que le builder lui fait
écrire — et elle doit rester identique octet pour octet, ce que le harnais
`build-corpus.sh` sait prouver.

## 7. Ce qu'il faut trancher avant d'écrire une ligne

1. **L'unité logique.** 8 Ko (l'unité du CoCo 3, et la demi-page du TO8) ou
   « celle que la machine déclare » ? Le premier choix unifie ; le second évite
   de couper en deux des pages de 16 Ko qui n'ont jamais besoin de l'être.
2. **L'adresse : CPU ou décalage de fenêtre ?** C'est le choix entre (b) et (c),
   donc entre « fermer l'angle mort » et « fermer l'angle mort *et* n'avoir
   qu'une carte par jeu ».
3. **La RAM résidente**, qui n'a ni page ni registre : lui laisser une page de
   convention comme aujourd'hui, ou reconnaître qu'elle n'en a pas et que
   l'adresse suffit ?
4. **Le moment.** Rien ne casse aujourd'hui : l'angle mort est réel mais
   théorique tant qu'aucun fichier n'est posé des deux côtés d'un alias. À
   l'inverse, chaque carte mémoire écrite d'ici là sera à réécrire.

## 8. Ma recommandation

Le correctif du rapport, tout de suite et indépendamment : il traite le
symptôme que l'auteur a vu, sans engager le modèle.

Pour le reste, **(c)**, mais pas tout de suite — et pas sans une troisième
machine sur la table. La régularité du CoCo 3 est un argument fort pour un
vocabulaire de fenêtres, mais on ne conçoit bien un modèle générique qu'avec
deux exemples *différents* sous les yeux, et le MO6 ressemble trop au TO8 pour
faire contre-poids à lui seul. Le jour où un portage CoCo 3 devient un
objectif, cette analyse est le point de départ ; d'ici là, ce qu'elle laisse au
dépôt est la connaissance de l'angle mort, et la règle de prudence qui va
avec : **ne jamais déclarer deux fois le même silicium sous deux référentiels**
— ce que r-type fait aujourd'hui pour son tampon vidéo, en le sachant et en
l'écrivant.
