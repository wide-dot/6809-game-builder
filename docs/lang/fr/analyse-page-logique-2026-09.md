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

---

# 9. Le modèle recommandé, en détail

Ajouté le 01/09/2026 à la demande de l'auteur : à quoi ressemblerait
précisément le modèle (c), avant toute décision.

## 9.1 Le principe, en une phrase

**Le builder raisonne en adresses PHYSIQUES ; l'adresse CPU est une vue.**

Un octet de RAM a une identité et une seule : son rang dans la mémoire de la
machine. La fenêtre par laquelle le processeur le voit, et la valeur qu'il faut
écrire dans un registre pour l'y voir, sont des *conséquences* — calculées, pas
déclarées.

## 9.2 La formule, et la preuve qu'elle marche

    physique = page × unité(fenêtre) + décalage

L'unité est celle de la fenêtre, pas de la machine : 16 Ko pour une fenêtre
paginée du Thomson, 8 Ko pour sa fenêtre vidéo, 8 Ko pour les huit fenêtres du
CoCo 3.

La preuve tient dans le cas que r-type documente à la main. Son tampon vidéo
est déclaré deux fois :

| déclaration | fenêtre | calcul | physique |
|---|---|---|---|
| `page="$01" address="$4000"` | vidéo, unité 8 Ko | 1 × $2000 + 0 | **$2000-$3FFF** |
| `page="$00" address="$2000"` | cartouche, unité 16 Ko | 0 × $4000 + $2000 | **$2000-$3FFF** |

Le commentaire du config — « décrivent le même silicium en référentiel de
page » — devient une **égalité calculée**. C'est tout le modèle : ce que
l'auteur sait et écrit en français, le builder le sait et le vérifie.

## 9.3 Ce que déclare la machine

`machine.xml` existe déjà et porte le nombre de pages et l'expression de
l'octet de page. Il gagnerait la description des fenêtres — la seule
connaissance qui soit vraiment celle de la machine :

```xml
<machine name="to8">
    <ram blocks="64" blocksize="$2000"/>      <!-- 512 Ko en blocs de 8 Ko -->
    <window name="cart"     address="$0000" size="$4000" unit="$4000"
            register="$E7E6" or="%01100000"/>
    <window name="video"    address="$4000" size="$2000" unit="$2000"
            register="$E7C3" bit="0"/>
    <window name="resident" address="$6000" size="$4000" physical="…"/>
    <window name="data"     address="$A000" size="$4000" unit="$4000"
            register="$E7E5"/>
    <reserved name="monitor.dp" window="resident" offset="$0000" size="$0100"/>
</machine>
```

Le MO6 est **le même fichier avec d'autres nombres** — c'est ce qui rend le
modèle crédible : vidéo `$0000-$1FFF` en demi-pages (registre `MC6821.PRA`,
bit 0), résidente `$2000-$5FFF` sans registre, données `$6000-$9FFF` et
cartouche `$B000-$EFFF` en pages de 16 Ko. Même structure, autres adresses.

Le CoCo 3 s'y coule sans cas particulier : huit fenêtres de 8 Ko, une par
registre de `$FFA0` à `$FFA7`, unité 8 Ko, 64 blocs. Ses deux jeux de
registres (`$FFA8-$FFAF`) sont une affaire d'exécution — deux cartes
commutables — pas de déclaration.

Deux gains discrets mais réels : l'`or="%01100000"` (RAM par-dessus la
cartouche) trouve enfin son foyer, au lieu d'être une expression que
`machine.xml` transporte sans la comprendre ; et les zones réservées de la
machine — page directe du moniteur, pile, registres — se déclarent **une fois
là**, au lieu d'être réécrites par chaque jeu (r-type ne l'avait d'ailleurs
jamais fait pour la page directe du moniteur : c'est du 01/09/2026).

## 9.4 Ce que déclare le jeu

L'adresse CPU disparaît de la déclaration au profit du couple
*fenêtre + décalage*, machine-indépendant :

```xml
<!-- aujourd'hui, lié au TO8 -->
<region name="music"  page="$06" address="$0400" size="$3C00"/>
<region name="engine" page="$01" address="$6100"/>

<!-- modèle (c) -->
<region name="music"  window="cart" page="$06" offset="$0400" size="$3C00"/>
<region name="engine" window="resident" offset="$0100"/>
```

Une fenêtre non paginée n'a pas de `page` — la RAM résidente cesse d'en porter
une par convention, ce qui était le troisième sens du mot. Et le même layout
vaut pour le TO8 et le MO6 : `window="resident" offset="$0100"` donne `$6100`
sur l'un, `$2100` sur l'autre.

## 9.5 Ce que le builder stocke, et ce que les contrôles deviennent

Un placement porte quatre choses au lieu de deux :

    Placement { physique, taille, fenêtre, adresseCPU }

`physique` est l'identité : **tous les contrôles comparent des intervalles
physiques**, et l'angle mort se ferme par construction. `adresseCPU` reste ce
que le code voit — c'est elle qui va dans les tables générées et dans les
équates du jeu.

Les huit endroits qui comparent aujourd'hui `(page, adresse)` — `SceneChecks`,
`CompositionChecks`, l'occupation du packer, région ∩ réservé, `Regions`,
`RamMap`, `Cuts`, le rapport — changent mécaniquement : même code, autre
grandeur. Le rapport, lui, groupe par bloc physique : une ligne par bloc,
quelle que soit la fenêtre, et la « page 1 » de r-type cesse d'exister en tant
que ligne fourre-tout.

## 9.6 Ce que le runtime ne change pas

`ram.set` continue de dispatcher sur la plage d'adresse : rien à toucher côté
engine. Ce qui change est la valeur que le builder lui fait écrire — désormais
**calculée** depuis le bloc physique et l'unité de la fenêtre, au lieu d'être
recopiée depuis la déclaration. Elle doit rester identique à l'octet près, et
c'est exactement ce que `build-corpus.sh` sait prouver.

## 9.7 La migration, en quatre temps prouvés

**A — l'identité, sans changer la syntaxe.** Le builder calcule le physique
depuis `(page, adresse)` et la table des fenêtres de la machine ; tous les
contrôles y passent. Aucune image ne bouge. *Conséquence à anticiper : l'alias
du tampon vidéo de r-type devient un vrai chevauchement, et le build le
refusera.* C'est le but — mais c'est le premier geste à faire, avant tout le
reste : exprimer ce tampon une seule fois.

**B — le vocabulaire.** `window` + `offset` acceptés, l'ancienne forme aussi,
les deux résolvant au même physique. Corpus identique à l'octet.

**C — la migration des configs.** Les layouts TO8 et MO6 d'un même exemple
fusionnent là où le contenu tient dans les deux machines. La mesure de départ :
73 lignes sur 148 dans `examples/sound`.

**D — une machine de plus.** Le fichier CoCo 3, le jour où c'est un objectif.

## 9.8 Ce que le modèle ne résout pas

- **Les tailles de RAM diffèrent** (MO6 128 Ko contre TO8 512 Ko) : un layout
  portable ne l'est que si le contenu tient dans la plus petite. La fusion des
  cartes est possible là où elle est vraie, pas partout.
- **Le code du jeu garde ses adresses machine** (`map.const.asm`, les équates
  `glb_*`) : la portabilité gagnée est celle de la *carte mémoire*, pas de
  l'assembleur.
- **Le départ de l'affichage** — quelle moitié est visible à l'écran, les
  registres vidéo du GIME — reste affaire d'engine. Le modèle parle de ce que
  le processeur *atteint*, pas de ce que l'écran *montre*.
- **Un fait à vérifier avant d'écrire la table** : le rang physique de la
  fenêtre résidente sur chaque Thomson. Le modèle en a besoin (c'est le
  `physical="…"` laissé en points de suspension ci-dessus) et la réponse est
  dans la documentation matérielle, pas dans ce dépôt.
