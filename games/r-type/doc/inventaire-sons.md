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

> **Depuis le 03/09/2026 (soir)** : dix-neuf sons en données, tous joués,
> une trentaine de sites — voir « Le câblage » en §6. Ce qui suit est l'état
> du matin, gardé comme point de départ.

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

Inventaire complet, identifiant par identifiant, avec les routines
appelantes : [`arcade-sound-reference.md`](arcade-sound-reference.md). Ce qui
suit n'en est que le résumé.

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

Source Master System **confirmée à l'oreille le 03/09/2026** (§5) pour tout
ce qui a un identifiant en gras.

| Borne | Événement | Chez nous | Source SMS |
|---|---|---|---|
| 0x31 | relâchement du beam chargé | appel **commenté**, à décommenter | 33-fire-blast |
| 0x32 | début de charge du beam | manque | 34 ou 35 (non confirmé) |
| 0x33 | arrêt de la charge | manque | 34 ou 35 (non confirmé) |
| 0x34 | lancement du missile | on joue FireBlastSound à la place | **35** |
| 0x36 | éjection du force pod | manque | **37** |
| 0x37 | accrochage du force pod | **données présentes, jamais jouées** | 38-pod-attach |
| 0x38 | vie supplémentaire au score | manque | **39** |
| 0x3B | tir et rebond du laser reflex | manque, arme portée | **41** |
| 0x3C | tir du laser de sol | manque, arme portée | **42** |
| 0x3D | tir du counter-air laser | manque, arme portée | **43** |
| 0x3F | tir simple du pod, celui des reflets | manque, porté aujourd'hui | **44** |

### Combat

| Borne | Événement | Chez nous | Source SMS |
|---|---|---|---|
| 0x50 | petite explosion | on en a une, générique | **45** |
| 0x51 | explosion moyenne | manque | **46** |
| 0x52 | **explosion de tourelle — 24 sites, la 2ᵉ plus fréquente** | manque | **47** |
| 0x53 | grosse explosion | manque | **48** |
| 0x54 | explosion du Wick | manque, ennemi porté | **49** |
| 0x56 | **coup encaissé par un ennemi — 39 sites, la plus fréquente du jeu** | manque | **50** |
| 0x57 | coup encaissé par un boss | manque, 23 sites | **51** |
| 0x59 | tir laser ennemi | manque | non confirmé |
| 0x5D | salve d'ennemi lourd, émergence du Zoid | manque | non confirmé |
| 0x5F | traînée du Gouger, billes de l'orbe Gomander | manque | non confirmé |
| 0x61 | décollage du Tabrok | manque | non confirmé |
| 0x62 | destruction d'un nerf optique | manque, implémenté aujourd'hui | non confirmé |
| 0x64 | entrée en scène du Mikun, tir de Dobkeratops | manque | non confirmé |

### Interface

| Borne | Événement | Chez nous |
|---|---|---|
| 0x22 | jingle de game over | manque |
| 0x55 | bascule du score | manque |
| 0x72-0x79 | décompte de continue | sans objet, pas de continue |

Sans objet également : la famille borne, attract, saisie de nom et pièce.
Restent hors portée les sons des boss non portés, le Bronco et le Bydo.

## 5. La correspondance entre les deux catalogues

### Ce qui est établi

Six paires, par les noms de fichiers que l'auteur avait posés en portant les
six premiers sons — une s'est révélée décalée d'un cran, corrigée plus bas, dans « Confirmé à l'oreille » :

| Master System | Borne | Événement |
|---|---|---|
| 18-fire | 0x30 | tir de base |
| 33-fire-blast | 0x31 | relâchement du beam |
| 36-player-hit | 0x35 | explosion du joueur |
| 38-pod-attach | 0x37 | accrochage du pod |
| 40-bonus | 0x3A | ramassage d'un bonus |
| 46-explosion-0 | ~~0x50~~ **0x51** | explosion moyenne, pas la petite (voir « Confirmé à l'oreille » plus bas) |

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

### Confirmé à l'oreille (03/09/2026, relevé de l'auteur)

Relevé complet, au test sonore, des identifiants Master System 35 à 51.
Résultat : la quasi-totalité de la zone que le test d'intervalle laissait
en candidats se règle d'un coup, sans exception ni ambiguïté.

| Master System | Borne | Événement |
|---|---|---|
| 35 | 0x34 | lancement du missile |
| 36 | 0x35 | explosion du joueur *(déjà l'ancre `36-player-hit`)* |
| 37 | **0x36** | éjection du force pod *(confirme la paire forcée plus bas, dans « Le test d'intervalle »)* |
| 38 | 0x37 | accrochage du pod *(déjà l'ancre `38-pod-attach`)* |
| 39 | **0x38** | vie supplémentaire au score *(confirme la paire forcée plus bas, dans « Le test d'intervalle »)* |
| 40 | 0x3A | ramassage d'un bonus *(déjà l'ancre `40-bonus`)* |
| 41 | **0x3B** | tir et rebond du laser reflex |
| 42 | **0x3C** | tir du laser de sol |
| 43 | **0x3D** | tir du counter-air laser |
| 44 | **0x3F** | tir simple du pod (celui des reflets) |
| 45 | **0x50** | petite explosion |
| 46 | **0x51** | explosion moyenne |
| 47 | **0x52** | explosion de tourelle — la 2ᵉ plus fréquente du jeu |
| 48 | **0x53** | grosse explosion |
| 49 | **0x54** | explosion du Wick |
| 50 | **0x56** | coup encaissé par un ennemi — **la plus fréquente du jeu** |
| 51 | **0x57** | coup encaissé par un boss |

**L'ancre `46-explosion-0` était décalée d'un cran** : ce fichier est
l'explosion *moyenne* (0x51), pas la petite (0x50, qui est en fait le 45).
L'erreur venait d'un nom posé une fois, à l'oreille, sur un son générique —
les cinq autres ancres (tir, beam, joueur, pod, bonus) sont des sons
distinctifs qui ne prêtent pas à confusion ; une explosion en prête.

**Les quatre écarts que ce relevé traverse sont maintenant tous expliqués**,
et chacun confirme une pièce du dossier déjà réunie ailleurs dans ce
document :

- **35 → 39** ne saute rien côté Master System, mais la borne va de 0x34 à
  0x38 en passant par 0x35, 0x36, 0x37 sans creux — sauf que la borne a
  aussi un 0x39 que **personne n'appelle jamais** (§3, table des
  identifiants jamais référencés). La Master System n'en a donc logiquement
  pas d'équivalent : ce n'est pas un trou du relevé, c'est un identifiant
  mort des deux côtés ;
- entre 44 (0x3F) et 45 (0x50), la borne compte 0x40 et 0x41 en plus — les
  deux sons de curseur de saisie de nom (§4, table borne). Une cartouche de
  salon n'a pas d'écran de high-score à remplir : logique qu'elle n'ait
  aucun son pour ça. Confirme l'hypothèse posée plus bas, dans « Le test d'intervalle » (« le son absent est
  une saisie de nom ») ;
- entre 44 et 45 encore, la borne a aussi 0x3E, également listé « jamais
  référencé » en §3 — un second identifiant mort, dans le même intervalle ;
- entre 51 (0x57) et la suite, la borne a 0x55 (bascule du score) sans
  équivalent Master System relevé ici — cohérent avec un affichage de score
  probablement traité différemment sur console, à vérifier si la zone au-delà
  de 0x57 est un jour couverte.

Deux ids restent choisis par défaut plutôt que confirmés : 34 et 35 pour
« début de charge » (0x32) et « arrêt de charge » (0x33) du beam — mais 35
est désormais identifié comme le lancement du missile (0x34), ce qui
retire une option et laisse 34 seul candidat pour l'un des deux réglages de
charge. Le relevé ne dit pas lequel.

### Le test d'intervalle, décompte exclu (03/09/2026) — la méthode qui a mené ici

Le décompte sort de la comparaison : chez nous il est porté par une musique
dédiée, pas par des effets. Restent **42 effets distincts** côté Master
System et **46 identifiants déclenchés** côté borne.

On compte alors, entre deux ancres consécutives, combien de sons chaque
catalogue place. Si les deux listes suivent le même ordre, les comptes
doivent coïncider.

| Entre les ancres | Master System | Borne | Verdict |
|---|---|---|---|
| 18 → 33 / $30 → $31 | aucun | aucun | **exact** |
| 33 → 36 / $31 → $35 | 34, 35 | $32, $33, $34 | borne +1 |
| 36 → 38 / $35 → $37 | 37 | $36 | **exact, paire forcée** |
| 38 → 40 / $37 → $3A | 39 | $38 | **exact, paire forcée** |
| 40 → 46 / $3A → $50 | 41 à 45 | $3B, $3C, $3D, $3F, $40, $41 | borne +1 |

Quatre intervalles sur cinq concordaient déjà, et le premier était le plus
parlant : **aucun son de part et d'autre entre le tir de base et le beam**.
Avant la déduplication ce même intervalle affichait quatorze sons côté
Master System contre zéro — c'est la table de la ROM qui a rendu la
comparaison possible.

**Deux paires étaient déjà certaines**, chacune seule dans son intervalle,
et le relevé à l'oreille (la section « Confirmé à l'oreille ») les confirme mot pour mot :

| Master System | Borne | Événement |
|---|---|---|
| 37 | 0x36 | éjection du force pod |
| 39 | 0x38 | vie supplémentaire au score |

Le dernier intervalle listé ci-dessus porte encore la table AVANT
correction de l'ancre (40→46 au lieu de 40→45) : c'est la lecture qui avait
mené à l'hypothèse **41 = laser reflex, 42 = laser de sol, 43 = counter-air,
44 = tir simple du pod**, une fois posé que le son en trop était une saisie
de nom. Le relevé à l'oreille confirme les quatre sans exception.

### Là où le test s'arrête désormais

Le relevé à l'oreille pousse la correspondance confirmée jusqu'au coup
encaissé par un boss (Master System 51 = borne 0x57) — bien au-delà de la
« petite explosion » où le test d'intervalle seul s'arrêtait. Au-delà de
0x57, la méthode par comptage ne s'applique plus : la liste de la borne
n'est que celle des identifiants **que le code déclenche**, avec 26 trous
jamais cités ($42 à $4F, $58, $5C, $60, $69 à $71) dont une partie porte
sans doute de vrais sons ; la liste Master System est celle des sons
**présents**. Prolonger encore demanderait soit le catalogue complet du
processeur son de la borne, soit — plus simple maintenant que `$C149`
(« Les 24 index non capturés ») permet de déclencher n'importe quel
identifiant sans repasser par le test sonore — un nouveau relevé à
l'oreille sur la Master System au-delà de l'identifiant 51.

### Ce qui reste ouvert

| Borne | Master System | Statut |
|---|---|---|
| 0x32 début de charge | 34 (probable) | un seul candidat restant, non confirmé |
| 0x33 arrêt de charge | inconnu | aucun candidat Master System identifié |
| 0x59 et au-delà | — | hors de la zone couverte par le relevé |

### Comment confirmer le reste

`$C149` en RAM (« Les 24 index non capturés ») déclenche n'importe quel
identifiant Master System sous émulateur sans repasser par le test sonore —
c'est ainsi que ce relevé a été fait. Les 54 blocs de
`reference/sms/sfx/soundfx/` sont au format du pilote et s'assemblent tels
quels côté portage.

## 6. Le câblage (03/09/2026)

Les treize sons confirmés qui manquaient sont en données et branchés, plus
l'accrochage du pod, qui dormait en données depuis la v1. Le corpus est
inclus **tel que l'outil le génère** (`reference/sms/sfx/soundfx/`, treize
`INCLUDE` en queue de `soundFX.asm`) : rien n'est retouché à la main, une
reconversion suffit.

### Deux gestes de plus dans l'outil

- **l'instrument personnalisé** — cinq sons (35, 48, 49, 50, 51) jouent sur
  l'instrument 0, celui que les registres $00-$07 définissent, et cette
  définition vivait dans le préambule que l'outil coupe. Il la retient et la
  remet en tête du bloc, en huit commandes ordinaires. La commande `$FF` du
  pilote, prévue pour ça, n'est pas employée : après `leax 3,x` le pilote
  relit son délai en `-1,x`, c'est-à-dire l'octet bas de l'adresse de la
  table — un délai au hasard. La remise à plat finale de la voie (instrument
  0, volume 15) n'est pas un usage : elle passait pour tel, et faussait la
  calibration ;
- **cette remise à plat part** — les blocs à la main ne la gardaient pas. La
  calibration remonte à 95-97 % sur les cinq sons mono-voie.

Le lecteur de musique partage l'instrument personnalisé ; la Master System
faisait exactement de même, son pilote le réécrivait avant chaque bruitage.
À écouter sur un stage dont la musique s'en sert.

### Le son d'une explosion : cinq paliers et deux cascades

La borne ne tire pas le son du sprite mais de l'ennemi qui meurt. Chez nous
l'objet explosion joue le son ; le palier voyage donc dans les **bits 4-6 du
subtype**, à côté de l'animation (bits 0-3), posé sur le site qui crée
l'explosion (`explosion.sfx.*`, `explosion.const.asm`). Sans palier, le son
est celui d'avant, l'explosion moyenne ($51). Quarante sites classés d'après
`arcade-sound-reference.md` :

| Palier | Borne | Sites |
|---|---|---|
| small | $50 | pata-pata, bug (deux), canon du tabrok, missile commun, POW, boule du warship |
| medium | $51 | bink, cytron, p-staff, slither (trois), cancer, geld — inchangés |
| turret | $52 | shell, blaster, brood, zoid, nerfs, outslay, warship (huit) |
| big | $53 | tabrok, gouger, scant, capsule du warship |
| wick | $54 | wick |
| cascade | $51/$52/$53 au sort, un quart de silence | gomander, dobkeratops (cinq sites) |
| cascade2 | $52/$53 au sort | pièces du compiler |
| none | — | l'explosion du missile du joueur, muette sur la borne |

Les cascades sont celles de la borne (`AND AL,3 / JZ / ADD CL,AL` depuis
$50 ; un bit depuis $52 pour le compiler), tirées par `RandomNumber`.
L'outslay et le gomander demandaient le son à part en plus de l'explosion :
ces demandes sont retirées, l'explosion porte le son.

### Le coup encaissé : un crochet dans le noyau

Le son le plus fréquent du jeu n'avait aucun point d'accroche : la passe de
collision décrémente le potentiel de l'ennemi et lui seul s'en aperçoit,
quand il s'en aperçoit. Le point commun est `Collision_Do` (engine, importé
1:1) : sa branche `@loose` est exactement « l'arme meurt, la cible garde du
potentiel », c'est-à-dire un coup non fatal, pour toutes les paires de listes
— le joueur, boîte faible, n'y passe jamais. Un `IFDEF COLLISION_ON_LOOSE`
y appelle un macro que l'includeur définit ; le noyau ne sait rien du son
(V2-DEVIATION, tracée au manifeste). R-Type le définit dans `engine.asm` :
un `jsr Collision_OnLoose` — une expansion en ligne faisait déborder les
branchements courts du noyau — vers une routine résidente qui applique la
règle de `_soundFX.play` avec l'id et la priorité en pile :

- **$56** (`HitSound`, priorité 0) par défaut ;
- **$57** (`BossHitSound`, priorité 1) quand la seconde liste est
  `AABB_list_target`, les points faibles de boss — `Collision_Do_2` porte la
  tête de la liste, il suffit de la comparer. Aujourd'hui c'est l'œil du
  gomander, un $57 chez la borne ;
- les ennemis de la liste ordinaire qui sonnent $57 sur la borne et
  détectent déjà leurs coups (dobkeratops, gouger, slither) le demandent
  eux-mêmes, priorité 1 : la passe précède `RunObjects` dans la trame, leur
  demande gagne la boîte aux lettres avant l'IRQ ;
- le contact du pod et des bits (`WeaponContactTick`) joue $56 quand son
  `dec` laisse du potentiel.

Restent $56 au lieu de $57 : le brood et le parasite du zoid, sans
détection de coup propre. Une trame de frame-drop peut aussi glisser une IRQ
entre la passe et le tick du boss, et faire entendre $56 une trame avant
$57.

### Les autres sites

| Son | Où |
|---|---|
| missile (35) | `player_missile.asm`, à la place du son du beam |
| éjection du pod (37) | `forcepod.asm`, passage à `RunEjected` |
| accrochage (38) | `forcepod.asm`, `@rear` — jamais joué jusqu'ici |
| vie supplémentaire (39) | `hud.asm`, `@grant` |
| laser reflex (41) | `obj_reboundlaser.asm` : la volée après `reboundmgr.reset`, puis chaque rebond (entrées `.rebound`) |
| laser de sol (42) | `obj_groundlaser.asm`, la volée armée après `groundmgr.reset` |
| counter-air (43) | `obj_counterairlaser.asm`, `GenChilds` |
| tir simple du pod (44) | `obj_counterairreflect.asm`, `Init` — c'est le reflet qui le joue sur la borne |

Priorités : tirs et coups 0, explosions et lasers 1, pod 2, vie 4 — la
même échelle que les six d'avant.

### La place

Le fichier de sons passe de 1 003 à 2 492 octets et ne tient plus en page
$08 : l'arène commune manquait de 152 octets, mais en premier ajustement les
miettes ne s'additionnent pas. La frontière de la page $0C avec l'arène des
lots — que le config disait pouvoir bouger — recule de $0A80 à $0E80 ;
le lot pstaff, seul occupant, tient entier derrière. Après build : 2 420
octets contigus en queue de $17, le reste en miettes.

### Ce qui reste

- le début et l'arrêt de charge du beam ($32, $33) : le 34 est le seul
  candidat, non confirmé ; et le relâchement du beam (33, en données) a
  toujours son appel commenté ;
- au-delà de $57 : rien de relevé.
