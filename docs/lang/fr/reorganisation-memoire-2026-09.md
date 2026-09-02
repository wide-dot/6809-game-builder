# Réorganisation de la carte mémoire de r-type — proposition (02/09/2026)

Point de départ : la configuration actuelle (`games/r-type/to8.config.xml`,
commit `a430ad75a`), mesurée par le rapport d'occupation. Objectif : des
étages propres par durée de vie, et la place libre regroupée là où elle sert.
Rien ici n'est décidé ; chaque point marqué **À TRANCHER** attend l'auteur.

## 1. Ce que la carte est aujourd'hui

Trois étages existent déjà, rangés à la main page par page, avec le
raisonnement consigné en commentaire dans le layout :

| Étage | Pages | Contenu | Durée de vie |
|---|---|---|---|
| Système | $00–$04 | pool d'objets, résident, deux framebuffers, loader | permanent |
| Commun | $04 (queue), $05–$0A, tête de $0C, queue de $17, bloc son de $1A | arène `objects` | permanent (boot) |
| Lots d'ennemis | $0C (après le commun), $0D–$0F | arène `enemies` | par stage, partagés |
| Stage | $10–$16 (`stageN.foes`), $17 (collision, init), $18–$1F (`stageN.gfx`) | arènes par stage | échangés |
| Travail stage 4 | $0B (édition, page entière), $10–$12 et $1D (tampons), $00 tranche 0 | régions sans fichier | stage 4 seul |

Totaux mesurés, chaque fichier compté une fois :

| | Octets | Pages |
|---|---|---|
| Système réservé | 49 022 | 3,0 |
| Commun (arène + résident + son) | 125 251 | 7,6 |
| Lots d'ennemis (stage 4 compris) | 91 090 | 5,6 |
| Stage 1 | 217 192 | 13,3 |
| Stage 2 | 230 146 | 14,0 |
| Stage 3 | 156 669 | 9,6 |
| Stages 4 à 8 | 45 503 à 94 006 | 2,8 à 5,7 |

**Le stage 1 est l'état contraignant** : 30 pages entamées sur 32, 4,6 pages
libres en tout. Le stage 2 en a 7,2, le stage 3 10,9, les autres plus de 12.

## 2. Deux pièges de lecture

**Le rapport ne montre que les fichiers chargés.** Les quatre tampons du
ruban de gommes ($10, $11, $12, $1D) sont des régions de travail : aucun
fichier n'y est chargé, le rapport les dessine vides. Un bilan fait sur le
rapport seul les donne libres en stage 4. Ils ne le sont pas.

**Une note du layout est périmée.** Le commentaire de l'arène `objects` dit
que la frontière $0A80 de la page $0C « ne PEUT pas monter » parce que le
visage du Dobkeratops (13 443 o) tient dans la zone ennemis de cette page à
3 octets près. Depuis la partition des arènes (24/08), le visage est en **$11**
dans `stage1.foes`. La page $0C ne porte plus que le commun (2 563 o) et le
P-Staff. La frontière peut bouger.

## 3. Où sont les pertes

Libre **dans tous les états à la fois** : 14 471 o, soit 0,9 page. La carte
est saturée transversalement ; la place d'un stage est dans les pages que les
autres n'utilisent pas. Les pertes sont donc des pages **mal affectées**, pas
des miettes :

1. **$0B, une page entière pour le stage 4.** L'édition du ruban y vit en
   demi-ordre échangé, la page est réservée en entier ; le fichier fait
   5 286 o. Vide dans les huit autres états : 16 Ko que les stages 1, 2 et 3
   ne peuvent pas prendre, alors que le stage 4 a quatre pages vides ailleurs
   ($13, $14, $15, $16).
2. **Le commun déborde sur deux pages** pour 7,6 Ko : 2 563 o en tête de
   $0C, 5 092 o en queue de $17. Deux pages entamées par du permanent, ce qui
   bride les lots (qui commencent à $0A80) et les stages (dont la collision
   et l'init vivent en $17).
3. **L'arène des ennemis** a 6 747 o libres en quatre morceaux ; le plus grand
   fait 2 626 o. Aucun lot ne peut y grossir, et $16 juste à côté est vide
   dans six états — le stage 1 n'y met que la mâchoire et la scie du
   Dobkeratops (4 994 o), qui tiendraient ailleurs.
4. **$1F est vide en stage 1** et dans les stages 4 à 8 ; seuls les stages
   2 et 3 s'en servent.

## 4. Principes proposés

- **P1 — un étage = des pages contiguës, une page = un étage.** Système,
  commun, lots, stage. Une page ne se partage qu'entre alternatives (deux
  stages), jamais entre un permanent et un échangé.
- **P2 — les régions de travail d'un stage vivent dans SES pages**, groupées,
  sur des pages qui ne portent rien de permanent. C'est déjà la règle ; on la
  rend visible en regroupant.
- **P3 — la place libre se regroupe en fin d'étage**, pas en queue de pages
  dispersées : c'est là que les variantes offset 1 et les prochains ennemis
  iront.

## 5. Carte cible

Chaque étage est un **bloc de pages voisines**, dans l'ordre des durées de
vie : le rapport d'occupation se lit alors de haut en bas comme la carte.

| Pages | Étage | Changement |
|---|---|---|
| $00–$04 | système | aucun |
| $04 (queue) + $05–**$0B** | commun | **$0B rejoint le commun** ; $0C et $17 lui sont retirés |
| **$0C–$10** | lots | $0C entier (dès $0000) ; **$10 devient la cinquième page des lots** |
| $11–$16 | stage : ennemis (`stageN.foes`) | perd $10, gagne la queue de $17 |
| $17 | stage : collision, init, et ce qui déborde des foes | plus de commun |
| $18–$1F | stage : décor (`stageN.gfx`) | aucun |
| $11–$15 | travail stage 4 | **tampons $10–$12 → $11–$13, édition $0B → $14, tampon 3 $1D → $15** : cinq pages contiguës, dans l'étage des stages |

Ce que ça donne, mesuré sur les tailles actuelles :

| Étage | Capacité | Occupé | Libre après |
|---|---|---|---|
| Commun (arène `objects`) | 122 880 | 113 230 | **9 650**, d'un seul tenant possible |
| Lots (5 pages) | 81 920 | 56 101 | **25 819** |
| Ennemis de stage, 6 pages + queue de $17 | 109 527 (stage 1) | 102 099 | 7 428 |
| | 110 723 (stage 2) | 107 212 | **3 511 — le plus serré de la carte** |

Prendre $10 plutôt que $16 pour les lots ne change **rien à la capacité** des
ennemis de stage : six pages plus la queue de $17 dans les deux cas, et le
packer re-range tout du plus gros au plus petit quelle que soit la page
retirée. Seule la numérotation change — et avec $10, la mâchoire et la scie
du stage 1 n'ont même plus à bouger, ni les images de Gouger du stage 2.

Avec les lots à cinq pages, le Scant (+5 236), le Bink (+6 113) et quatre
poses du Bug (+1 636) tiennent ensemble, et il reste ~12,8 Ko. Le Bug entier
reste exclu : 20 972 o dépassent le plafond d'un fichier (16 384), quelle que
soit la carte.

## 6. Ce qui doit être vérifié au build, et pourquoi c'est sûr

- **$0B au commun** : le commun est permanent, la page doit être vide dans
  tous les états. Elle l'est dès que l'édition du stage 4 a déménagé
  (matrice §3). Le builder refuse le build si ce n'est pas le cas.
- **$11–$15 pour le travail du stage 4** : vides en stage 4, ne portent rien
  de permanent (stages 1, 2, 3, 5 seulement, tous alternatifs au 4). Même
  logique que $10–$12 aujourd'hui. Le code d'édition est « une page ordinaire
  montée par paged.call » : n'importe quelle page convient.
- **$10 aux lots — l'ordre des étapes est OBLIGATOIRE** : le stage 4 charge
  des lots, et son tampon 0 vit en $10 aujourd'hui. Les tampons doivent avoir
  déménagé **avant** que les lots ne prennent $10, sinon le ruban écrase un
  lot en stage 4 — exactement le déraillement du 25/08 sur $0E/$0F. Le
  contrôle de composition ne le verrait pas : les tampons sont invisibles
  au rapport (§2). C'est l'étape 1 avant la 3, sans exception.
- **$1D rendu à `stage4.gfx`** une fois le tampon 3 parti : le commentaire du
  28/08 (compiler écrasant le tampon) n'a plus d'objet.

## 7. Étapes, chacune validée seule

Chaque étape = un commit, `rtype_bench` 7/7, et pour celles qui touchent le
stage 4, la sonde `tools/shot_stage4.py` sur son ouverture.

1. **Stage 4 regroupé** : tampons $10–$12 → $11–$13, `pscroll.edit`
   $0B → $14, `pscroll.buf3` $1D → $15, $1D rendu à `stage4.gfx`. Ne change
   rien aux autres stages. **Obligatoirement avant l'étape 3.**
2. **Commun** : `objects` gagne $0B, perd $0C et la queue de $17. Le commun
   se re-range ; tout est lié au chargement, aucune adresse n'est gravée.
3. **Lots** : `enemies` prend $0C dès $0000 et gagne $10 ; `stageN.foes`
   perdent $10 et gagnent la queue de $17 (le packer démarre après la
   collision et l'init du stage). Le stage 2 est le plus serré : 3 511 o de
   marge, à confirmer au build.
4. **Offset 1** : Scant, Bink 01–05, quatre poses du Bug. Vidéo du stage 1.
5. **Notes du layout** : réécrire les commentaires périmés ($0C/imgFace,
   $1D/buf3, $0B/pscroll).

## 8. À TRANCHER

- **A. À qui vont les 16 Ko de $0B ?** Personne n'en a besoin aujourd'hui :
  tout est placé. $0B se libère parce que l'édition du stage 4 déménage, et
  la question est seulement **où mettre la marge de croissance**.

  | | Option 1 : $0B aux lots | Option 2 : $0B au commun (carte du §5) |
  |---|---|---|
  | Carte | commun $05–$0A, lots $0B–$0F, stages $10–$1F | commun $05–$0B, lots $0C–$10, stages $11–$1F |
  | Ce qui bouge | l'édition du stage 4 seulement | édition, trois tampons, commun, lots, foes des 8 stages |
  | Piège d'ordre | aucun, les tampons restent en $10–$12 | tampons avant lots, obligatoire |
  | Lots | 79 232 o : Scant + Bink + 4 poses du Bug passent | 81 920 o, idem |
  | Stage 2, le plus serré | garde 7 pages, marge 19,9 Ko | 6 pages, marge 3,5 Ko |
  | Commun | inchangé : 7 Ko dont 6,2 en queue de $17, déborde encore en tête de $0C | 9,6 Ko d'un tenant, aucun débordement |

  **Recommandation : option 1.** Elle réalise l'objectif du chantier (offset
  1 des ennemis du stage 1) en déplaçant une seule région, sans piège
  d'ordre. Le débordement du commun sur $0C et $17 est cosmétique tant
  qu'il ne grossit pas de plus de 6 Ko. L'option 2 reste la carte « parfaite »
  si un jour le commun doit grossir ; ses étapes 1 à 3 sont écrites ci-dessus.

  **Et les stages ?** Aucun n'a besoin de $0B, contrairement à ce que la
  marge de 3,5 Ko du stage 2 en option 2 laissait croire — elle n'existe
  que dans cette option. Aujourd'hui :
  - le **stage 1** n'occupe pas $1F, que son arène de décor déclare : 16 Ko de
    marge déjà là ; ses ennemis laissent 11 Ko sur $16 ;
  - le **stage 2** ne charge aucun lot : $0D–$0F sont vides dans son état,
    48 Ko qu'il suffit de déclarer dans `stage2.foes` et `stage2.gfx`. Les
    compositions disent au builder qu'un fichier du stage 2 et un lot ne
    sont jamais co-résidents ; le packer les superpose et le contrôle de
    composition le vérifie. Sa saturation est dans la liste de pages de ses
    arènes — la même pour les huit stages, copiée-collée — pas sur la machine.
  Le seul étage court est celui des **lots** : 6,7 Ko en quatre miettes. C'est
  là que vivent Scant, Bink et Bug, et c'est là que va $0B.
- **B.** La cinquième page des lots est $10, la première de l'étage des
  stages : les étages restent des blocs voisins et personne ne bouge dans
  les stages 1 et 2. $16 ferait la même capacité mais un trou dans l'étage ;
  $1F est pris par les stages 2 et 3, dont le 3 charge des lots — exclu.
- **C.** Regrouper les cinq pages de travail du stage 4 en $11–$15 : les
  trois tampons doivent bouger de toute façon (ils sont sur $10, future page
  de lots) ; déplacer aussi l'édition et le tampon 3 est du confort qui rend
  $0B au commun et $1D au décor du stage 4. Tout dans l'étape 1.
- **D.** Deux améliorations du builder, hors de ce chantier : que le rapport
  dessine les régions de travail (elles sont invisibles aujourd'hui), et que
  le packer calcule le départ d'une zone **par fichier** et non par arène —
  sans quoi une zone partagée ne rend que sa queue au-dessus du plus haut
  gêneur de l'arène entière.

## 9. Réalisé (02/09/2026) — option 1, trois commits

| Étape | Commit | Vérification |
|---|---|---|
| 1. `pscroll.edit` $0B → $13 | `d28d34d1d` | stage 4 ouvert par le cheat, caméra 3 → 547 sur 3 000 trames, capture ; banc 7/7 |
| 2. $0B en tête de l'arène `enemies` | `841cce3cb` | banc 7/7 ; le Bug et le mid vont en $0B, $0F reste vide |
| 3. Scant, Bink 01–05, Bug ×4 en offset 1 | commit suivant | banc 7/7, stage 1 complet capturé |

État final des lots : 68 999 / 79 232 o, **10 233 o de marge** ; le Bug à
15 972 o sur un plafond de 16 384. Les quatre poses du Bug ont été choisies
en comptant les pas de mouvement affichés par pose dans ses huit scripts de
vol (bug_8, bug_7, bug_9, bug_6 : 47 % du temps d'affichage).

L'option 2 (commun sur $0B, lots sur $0C–$10, travail du stage 4 regroupé
en $11–$15) reste écrite aux §5–7 pour le jour où le commun devra grossir.
Les améliorations du builder (§8 D) ne sont pas engagées.
