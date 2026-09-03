# Les sons : d'où ils viennent, ce que la borne joue, ce qui nous manque (03/09/2026)

Trois questions, dans cet ordre : quelle est la source de nos données YM2413,
quels sons la borne déclenche et quand, et lesquels manquent à notre portage.
La correspondance entre les deux catalogues n'est pas donnée : elle est
établie en fin de document, avec son niveau de preuve.

## 1. La chaîne de données

```
R-Type Master System, version FM japonaise (YM2413)
  -> capture VGM      reference/sms/sfx/<n>.vgm            54 sons + 2 musiques
  -> vgm2sfx          reference/sms/sfx/asm/<n>.asm        toolbox/audio/vgm2sfx
  -> réduction        reference/sms/sfx/soundfx/<n>.asm    tools/sms_sfx_to_soundfx.py
  -> à la main        src/common/fx/soundfx/soundFX.asm    6 sons, les seuls buildés
```

`vgm2sfx` ne garde du flux VGM que les écritures YM2413, saute celles qui
réécrivent un registre inchangé et convertit les attentes en trames 50 Hz.
Il n'est appelé par **aucun `config.xml`** : la conversion est faite hors
build, ses sorties sont committées, et une reconversion des 54 fichiers les
reproduit à l'octet près.

La réduction vers notre format rejoue cinq gestes lus dans les six blocs
écrits à la main : préambule d'init coupé, une seule voie gardée, numéro de
voie sorti du registre vers l'en-tête, coupure de note supprimée, volume
poussé à fond avec l'original noté en commentaire. `--calibrer` la mesure
contre ces six blocs : 92 à 95 % de commandes identiques sur les cinq sons
mono-voie, 49 % sur le sixième, qui occupe trois voies et que l'auteur a
retouché davantage.

Le corpus complet pèse **6,4 Ko**, dont 786 octets déjà portés. Il
s'assemble tel quel.

## 2. Ce que notre portage joue aujourd'hui

Six sons en données, **cinq** joués, huit sites d'appel.

| Son | Priorité | Site |
|---|---|---|
| FireSound | 0 | tir de base du joueur |
| ExplosionSound | 1, 1, 2 | explosion générique, outslay, gomander |
| FireBlastSound | 1 | lancement des missiles |
| BonusSound | 4 | ramassage d'un bonus, deux sites |
| PlayerHitSound | $85 | mort du joueur |
| **PodAttachSound** | — | **aucun site d'appel** |

Deux défauts, tous deux hérités de la v1 :

- **le beam est muet** — l'appel existe mais il est commenté
  (`src/common/weapons/beam/beam.asm:47`) ;
- **le force pod est muet** — `PodAttachSound` est en données depuis le
  début et n'a jamais été joué, ni à l'accrochage ni à l'éjection.

## 3. Ce que la borne joue

La routine d'émission est `enqueue_audio_cmd` (0x400303), une file de 32
slots. Son argument couvre **deux espaces** : sous 0x22 ce sont des
commandes d'orchestration musicale, à partir de 0x22 des effets sonores.

**245 sites d'appel**, dont 232 avec une valeur immédiate. **54 identifiants
d'effets** distincts, plus 24 codes musique lus dans trois tables par stage
et 8 bips de décompte lus dans une table.

### Les effets, par famille

| Identifiants | Famille | Sites |
|---|---|---|
| 0x22, 0x25-0x2B, 0x40, 0x41, 0x63 | borne : game over, attract, titre, saisie du nom, pièce | 12 |
| 0x30-0x38, 0x3A-0x3D, 0x3F | armement du joueur et ramassages | 21 |
| 0x50-0x54 | explosions, quatre niveaux de lourdeur | 33 |
| 0x55 | bascule du score | 1 |
| 0x56, 0x57 | coup encaissé, ennemi ordinaire puis boss | 62 |
| 0x59-0x5B, 0x5D, 0x5F, 0x61, 0x62, 0x64-0x68 | tirs et manœuvres d'ennemis nommés | 40 |
| 0x72-0x79 | bips du décompte de continue, un par chiffre | 1 site indexé |

Les deux identifiants les plus sollicités de tout le jeu sont **0x56**, le
coup encaissé non fatal, à 39 sites, et **0x52**, l'explosion de tourelle, à
24 sites. Ce sont eux qui donnent au jeu son grain sonore, et ce sont
précisément ceux que nous n'avons pas.

Treize sites calculent leur identifiant au lieu de le poser en dur. Douze
sont des cascades d'explosion qui tirent au sort dans 0x51 à 0x53 avec une
chance sur quatre de silence ; le treizième est le décompte de continue.

## 4. Les sons qui nous manquent

Classés par ce qui est **déjà porté chez nous**, donc immédiatement
utilisable. La colonne de droite dit où le brancher.

### Armement du joueur

| Borne | Événement | Chez nous |
|---|---|---|
| 0x31 | relâchement du beam chargé | appel **commenté**, à décommenter |
| 0x32 | début de charge du beam | manque |
| 0x33 | arrêt de la charge | manque |
| 0x34 | lancement du missile | on joue FireBlastSound à la place |
| 0x36 | éjection du force pod | manque |
| 0x37 | accrochage du force pod | **données présentes, jamais jouées** |
| 0x3B | tir et rebond du laser reflex | manque, arme portée |
| 0x3C | tir du laser de sol | manque, arme portée |
| 0x3D | tir du counter-air laser | manque, arme portée |
| 0x3F | tir simple du pod, celui des reflets | manque, porté aujourd'hui |

### Combat

| Borne | Événement | Chez nous |
|---|---|---|
| 0x51, 0x52, 0x53 | explosions moyenne, tourelle, grosse | un seul son d'explosion pour tout |
| 0x54 | explosion du Wick | manque, ennemi porté |
| 0x56 | coup encaissé par un ennemi | **manque, 39 sites côté borne** |
| 0x57 | coup encaissé par un boss | manque, 23 sites |
| 0x59 | tir laser ennemi | manque |
| 0x5D | salve d'ennemi lourd, émergence du Zoid | manque |
| 0x5F | traînée du Gouger, billes de l'orbe Gomander | manque |
| 0x61 | décollage du Tabrok | manque |
| 0x62 | destruction d'un nerf optique | manque, implémenté aujourd'hui |
| 0x64 | entrée en scène du Mikun, tir de Dobkeratops | manque |

### Interface

| Borne | Événement | Chez nous |
|---|---|---|
| 0x22 | jingle de game over | manque |
| 0x38 | vie supplémentaire au score | manque |
| 0x55 | bascule du score | manque |
| 0x72-0x79 | décompte de continue | sans objet, pas de continue |

Sans objet également : la famille borne, attract, saisie de nom et pièce.
Restent hors portée les sons des boss non portés, le Bronco et le Bydo.

## 5. La correspondance entre les deux catalogues

### Ce qui est établi

Six paires, par les noms de fichiers que l'auteur avait posés en portant les
six sons :

| Master System | Borne | Événement |
|---|---|---|
| 18-fire | 0x30 | tir de base |
| 33-fire-blast | 0x31 | relâchement du beam |
| 36-player-hit | 0x35 | explosion du joueur |
| 38-pod-attach | 0x37 | accrochage du pod |
| 40-bonus | 0x3A | ramassage d'un bonus |
| 46-explosion-0 | 0x50 | petite explosion |

### Ce que dit la documentation publique (recherché le 03/09/2026)

**Nos numéros ne sont pas arbitraires : ce sont les index du test sonore de
la Master System**, et cette numérotation est documentée. Le test sonore
s'ouvre sur l'écran de décompte après un game over ; il expose **les
musiques de 00 à 17 et les effets de 18 à 95**, ces derniers accessibles en
maintenant le bouton 2. Le découpage se recoupe avec la rip publique de
SMS Power, qui contient exactement **17 musiques** et aucun effet.

Ce que la recherche N'A PAS trouvé, malgré plusieurs angles (SMS Power,
The Cutting Room Floor, vgmrips, Zophar, forums, sources japonaises) :
**aucune liste ne nomme les effets un par un**. SMS Power donne bien une
liste de déclencheurs mémoire par jeu pour l'extraction, mais R-Type y est
marqué « unknown » — d'où, très probablement, l'extraction par le test
sonore plutôt que par déclencheur, et les six noms posés à l'oreille.

### Les 24 index non capturés : réponse tranchée par la ROM (03/09/2026)

Le test sonore compte **78 emplacements d'effets** (18 à 95) et notre corpus
n'en a que 54 : les index 19 à 32 et 77 à 86 n'avaient jamais été capturés.
La question « portent-ils un son ? » est tranchée, et la réponse est **non,
ce sont des doublons** — le corpus est complet.

La preuve est dans la ROM, pas à l'oreille. Le chemin, reproductible :

1. les écritures aux ports du YM2413 (`OUT ($F0)`, `OUT ($F1)`) situent le
   pilote de son entre `$6F00` et `$7900` ;
2. dans cette zone, une lecture de table de pointeurs à `$7883` :
   `LD C,A / ADD A,A / LD E,A / LD D,0 / LD HL,$829B / ADD HL,DE /
   LD E,(HL) / INC HL / LD D,(HL)`. L'identifiant est donc doublé **sans
   décalage** et indexe une table à l'adresse d'exécution `$829B` ;
3. la banque 3 de la ROM est mappée en `$8000` (le pilote lit son instrument
   personnalisé à `LD HL,$8000`), donc la table vit à l'offset ROM
   **`$C29B`** ;
4. elle compte **96 entrées de 16 bits** — exactement la plage 00 à 95 du
   test sonore, ce qui la confirme.

Ce que dit la table :

| Identifiants | Pointeur | Sons distincts |
|---|---|---|
| 00 à 17 | 18 pointeurs distincts | les 18 entrées musique |
| **18 à 32** | **`$A8AA` pour les quinze** | **un seul son** |
| 33 à 73 | 41 pointeurs distincts | 41 sons |
| **74 à 86** | **`$B255` pour les treize** | **un seul son** |
| 87 à 95 | 9 pointeurs distincts | 9 sons |

96 identifiants, **70 sons distincts**, dont **52 effets distincts**. Notre
corpus de 54 fichiers couvre ces 52 effets : les fichiers 74 et 75 sont des
captures redondantes de 76, ce que vérifie la comparaison de leurs corps
réduits, identiques à la ligne près. **Aucun son ne manque.**

Un gain de côté, et il vaut plus que la réponse : la variable de demande de
son du pilote est **`$C149`** en RAM. Trouvée en écrivant un octet témoin
dans les douze variables que le pilote lit et en regardant laquelle il
consomme, sous MAME piloté en Lua. C'est le déclencheur mémoire que SMS
Power donne comme « unknown » pour R-Type. Y écrire un identifiant joue le
son correspondant : l'audition d'un son ne demande plus de traverser le test
sonore.

Une limite de la réduction, révélée au passage : les sons du décompte (74 à
95) jouent sur les voies 0 à 3, et leurs corps réduits à la voie 0 sont
identiques alors que la table les donne distincts. Ce qui les sépare vit sur
les autres voies. Pour cette famille, garder une seule voie ne suffit pas.

### La structure, et ce qu'elle apprend

Les deux catalogues sont de taille voisine sans être égaux : **52 effets
distincts** côté Master System, **54 identifiants d'effets** côté borne.
L'égalité que j'avais crue frappante n'existe pas — elle venait de compter
les 54 fichiers du corpus au lieu des 52 sons qu'ils portent.

Aucune relation numérique ne relie les identifiants — ni offset constant, ni
lecture hexadécimale : les écarts des six ancres valent 30, 16, 17, 17, 18
et 34.

En revanche, **les deux listes triées avancent du même pas**. En rang, les
six ancres donnent un décalage de 8, 8, 9, 9, 9 puis 10 :

```
Master System, rang    0    1    4    6    8   14
borne,          rang    8    9   13   15   17   24
```

C'est une observation **locale**, valable autour des ancres : les deux
catalogues n'ayant pas le même nombre d'effets, elle ne peut pas se
prolonger en bijection. Deux choses s'en déduisent tout de même :

- **les huit premiers effets de la borne n'ont pas d'équivalent Master
  System** — ce sont précisément le jingle de game over, l'attract, la pose
  des lettres du titre et la saisie du nom de score, c'est-à-dire tout ce
  qui n'existe que sur une borne à pièces ;
- **le décalage grandit de deux rangs** entre le début et le rang 14, donc
  la borne a deux effets de plus que la Master System dans cet intervalle,
  parmi le début de charge, l'arrêt de charge, le lancement de missile et
  les deux sons de curseur de saisie.

La conséquence pratique : la correspondance est un **alignement de deux
listes ordonnées**, pas une formule. Elle se lit de proche en proche à
partir des six ancres, et elle demande l'oreille pour confirmer chaque pas.

### Candidats immédiats

Les deux sons dont notre portage a le plus besoin tombent juste à côté
d'une ancre, ce qui les rend raisonnablement sûrs :

| Borne | Candidat Master System | Ce qui l'appuie |
|---|---|---|
| 0x36 éjection du pod | **37** | rang immédiatement avant l'ancre de l'accrochage, seul candidat |
| 0x32 début de charge | **35** | 9 commandes étalées sur 54 trames, la seule tenue longue du corpus, exactement ce qu'est une charge |
| 0x34 lancement du missile | **34** | 72 commandes sur 33 trames, un son dense et bref |

Au-delà, les candidats se multiplient et l'écoute devient indispensable :
c'est le cas des trois explosions 0x51 à 0x53 et surtout du coup encaissé
0x56, le son le plus fréquent du jeu, pour lequel je ne peux proposer qu'une
zone, les rangs voisins de l'explosion de base.

### Comment confirmer

À l'oreille, et c'est désormais rapide : écrire l'identifiant voulu dans
`$C149` sous un émulateur joue le son de la Master System sans passer par le
test sonore. Côté portage, les 54 blocs de `reference/sms/sfx/soundfx/` sont
au format du pilote et s'assemblent tels quels. Le protocole le plus court est d'en charger une
poignée dans la table des sons d'un build de test et de les déclencher au
clavier, en partant des candidats ci-dessus. Chaque paire confirmée
s'inscrit ici, et le nom de fichier Master System se complète comme l'ont
été les six premiers.
