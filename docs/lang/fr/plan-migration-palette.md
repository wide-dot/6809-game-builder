# Migration palette — plan de travail et suivi

Le TODO de la campagne. L'étude qui le fonde :
[`analyse-palette-migration-2026-08.md`](analyse-palette-migration-2026-08.md) —
la nouvelle palette, la table de correspondance, les arbitrages et le protocole
y sont ; on ne les redit pas ici.

**Branche `new-color`, jamais fusionnée vers `master` avant la fin.** Chaque
ressource se termine par une planche PNG soumise à l'auteur ; rien n'est
committé sans sa validation.

## Les deux règles du protocole

**1. Conserver les niveaux de dégradé** (auteur, 16/08). Une ressource qui
montre N valeurs doit en montrer N après migration. Deux index employés qui
tombent sur le même sont une marche de rampe perdue, et l'outil **arrête**
plutôt que de la laisser passer : il nomme les coupables et liste les marches
encore libres dans la nouvelle palette. La méthode, quand la table par défaut
provoque une collision : classer les index *employés par cette ressource* par
luminance et les poser sur autant de marches de la nouvelle palette, dans le
même ordre — une bijection par rang, pas une fusion. Une fusion réellement
voulue et mesurée se déclare par le mot `fusion-ok` sur la ligne de la
ressource ; jamais par omission.

**2. Toute conversion est un script** (auteur, 16/08). Rien ne se fait à la
main. Deux fichiers portent la campagne, et rien d'autre :

| fichier | ce qu'il porte |
|---|---|
| `tools/palette-map.txt` | **les paramètres** — ce que devient chaque index, ressource par ressource, avec le pourquoi |
| `tools/palette-replay.sh` | **les commandes** — quelles ressources ont été validées, dans quel ordre |

Une ligne dans la table sans sa ressource dans le script est une *proposition* ;
elle devient une décision appliquée quand l'auteur valide et que le script la
nomme. L'ordre du script compte : une image déclarée par deux ressources est
décidée par la première nommée.

`sh tools/palette-replay.sh --verifier` est la preuve que ce couple **est** la
campagne et non son récit : il crée une copie fraîche de `origin/master`, y
rejoue tout, et compare `src/` à l'arbre courant. Un écart signifie qu'un geste
manuel s'est glissé quelque part. À rejouer avant chaque commit de migration.

Ordre général : l'outil d'abord, puis les ressources qui ne demandent aucune
décision (elles valident la chaîne), puis celles qui en demandent, **les tuiles
en dernier** (décision auteur).

## État

- [x] **0. L'outil** — `tools/palette_migrate.py`, qui **importe** le relevé de
      `palette_usage.py` (une seule source pour la liste des ressources et de
      leurs images) et y ajoute les deux pièces qui manquaient : une **table de
      correspondance en entrée** (`tools/palette-map.txt`) et l'**écriture des
      PNG migrés**. Outil séparé assumé : le relevé reste en lecture seule.
      Trois modes — `--liste` (le reste à faire), `--apercu` (la planche, rien
      d'écrit), `--ecrire` (applique, puis **relit chaque fichier** pour vérifier
      que la table et les index sont bien ceux prévus). Un index présent dans une
      image mais absent de la table **arrête** l'outil : aucune couleur ne peut
      être migrée par inadvertance.
      Une image déjà migrée par une autre ressource est **héritée**, pas refusée
      ni ré-appliquée (cas des deux impacts partagés `weapon`/`simplefire`) —
      y compris entre deux ressources d'une même commande, où la première
      nommée décide.
      Plusieurs ressources en une commande donnent **une seule planche**, une
      section par ressource : un tour de validation = un fichier à regarder.
      Les deux règles du protocole ci-dessus sont dans l'outil : la collision
      de rampe arrête, et `palette-replay.sh --verifier` prouve le rejeu.

### Groupe A — renumérotation pure, aucune décision (12 ressources, 75 images)

Ces ressources n'emploient que des couleurs conservées : la table de
correspondance suffit, la planche ne sert qu'à confirmer que l'outil ne ment
pas. À traiter d'un bloc, en un seul aller-retour de validation.

**Validé par l'auteur le 16/08/2026, appliqué** (73 fichiers distincts réécrits,
dont 2 hérités) :

- [x] `common.weapon` (3 img) · `common.beamcharge` (8) · `common.beamp` (12)
- [x] `common.reboundlaser` (17) · `common.counterairlaser` (8) · `common.simplefire` (7)
- [x] `common.emflash` (4) · `common.foefire` (4) · `common.missileflame` (4)
- [x] `common.engineflames` (2) · `common.explosion.imgFwk` (4) · `lib.scantfire` (2)

### Groupe B — l'orange, et la première application de la règle 1 (2 ress., 9 img)

Ces deux-là emploient **à la fois** l'ancien orange `F2AB00` et l'ancien saumon
`F99B68`, les deux barreaux que la nouvelle palette réduit à un. C'est le
premier cas où la table par défaut ferait perdre une marche, et c'est ce qui a
fait naître la règle 1. La rampe chaude compte cinq marches de chaque côté —
`610000` `AC0000` `CC5A3C` `F99B68` `FAF261`, plus le blanc au-dessus — donc
la place existe : il suffit de re-répartir.

- [ ] `common.explosion.imgBig` (5 img) — l'orange descend sur `CC5A3C`, le
      brun-rouge qui manquait : le saut 51→173 en luminance devient 51→121→177.
      Une seule ligne : `10>9`.
- [ ] `common.explosion.imgSmall` (4 img) — même rampe, mais cette ressource
      **emploie déjà** `CC5A3C` (39 px) : la place est prise. Tout le bas de la
      rampe glisse d'un cran (`8>7 9>8 10>9`) et prend appui sur le `610000` de
      la nouvelle palette, qu'elle n'utilisait pas.

*Vérifié avant de s'en inquiéter : les douze ressources du groupe A, déjà
écrites, n'emploient aucune paire en collision — la règle 1 ne les aurait pas
arrêtées. Rien à refaire derrière.*

### Groupe C — une décision de fusion à prendre (14 ressources, 98 images)

Ordre choisi : **les deux ancres d'abord** — ce qui est à l'écran en
permanence et contre quoi tout le reste sera jugé — puis les communs par poids
décroissant, puis les lots.

**Les ancres**

- [ ] `common.player` (13 img, 231 px sur 5) — le vaisseau. Le §3 de l'étude
      recommande d'y verser le beige foncé dans le gris `666` : 19 px perdus
      contre 91 par l'autre fusion.
- [ ] `common.hud` (12 img, 4 px) — quasi gratuit, mais c'est l'autre chose
      qu'on regarde à chaque trame. À faire avec le vaisseau pour juger les
      deux ensemble.

**Les communs, par poids**

- [ ] `common.forcepod` (16 img, 438 px)
- [ ] `common.pow` (6 img, 329 px)
- [ ] `common.optionbox` (5 img, 134 px)
- [ ] `common.bitdevice` (6 img, 101 px)
- [ ] `common.overlay` (1 img, 92 px) — le masque du champ de jeu
- [ ] `common.missile` (5 img, 25 px)

**Les lots** (chargés par combinaison de stage, mêmes règles)

- [ ] `lib.scant` (3 img, 592 px) — **le cas arbitré** : garde son olive sur
      l'index propre au stage, beige clair monté au blanc, 4 px perdus en tout.
- [ ] `lib.cancer` (3 img, 219 px)
- [ ] `lib.bink` (6 img, 173 px)
- [ ] `lib.pstaff` (6 img, 94 px)
- [ ] `lib.bug` (8 img, 91 px)
- [ ] `lib.patapata` (8 img, 57 px)

### Groupe D — le code de dessin écrit en dur (2 fichiers)

Ni un remap de PNG ni un remap global ne les traitent : ce sont des immédiats
`LDA #$xy` à réécrire nibble par nibble.

- [ ] `src/common/hud/hud.asm` — 796 px, renumérotation pure (indices 0, 1, 5,
      6, 13, tous conservés). Mécanisable comme la transformation F→0 du 15/08.
- [ ] `src/enemies/dobkeratops/tailmgr_blits.asm` — 102 px, dont 31 px d'ancien
      index 14 (renumérotation) et **2 px d'olive à décider**.

**À NE PAS TOUCHER** : `src/title/text/text.asm` (796 px dont 419 d'index 15).
Le title se dessine sur `Pal_title`, une palette distincte ; il ne participe pas
à la palette de jeu. `src/common/hud/mask/Img_mask_0_ND0.asm` est mort — aucun
INCLUDE ne l'atteint.

### Groupe E — la palette et le fond (bascule)

Quand A à D sont validés, on bascule pour de bon :

- [ ] `pal-next.png` devient la palette du stage 1 dans le config
- [ ] `checkpoint.unit.asm` : les deux `ldx #$FFFF` deviennent `#$0000`
- [ ] `starfield/obj.asm` : test du ciel sur le nibble 0, masques XOR = la
      couleur, deux `coma` en moins par étoile et par passe

### Groupe F — les tuiles, EN DERNIER (décision auteur)

- [ ] tuiles du stage 1 — **régénérées** depuis l'image du niveau (leanscroll →
      `<gfxcomp grid>` → `<tilemap>`), contraste repris à la main
- [ ] les stages 2-8 ensuite, en commençant par le **stage 2** (quinze index
      distincts dans ses tuiles : le pire cas, s'il passe les autres passent)

## Ce qu'il faut savoir avant de commencer

**Deux images sont déclarées par deux ressources** — `weapon/images/impact/00.png`
et `01.png`, partagées par `common.weapon` et `common.simplefire`. Aucune
décision n'y est attachée (elles n'emploient que des couleurs conservées), donc
le partage est sans danger ici ; mais la règle vaut d'être posée : **une image
partagée se décide une fois**, la seconde ressource hérite.

**Une ressource ≠ un fichier.** Une ligne `<images>` miroir redéclare le même
PNG : les comptes ci-dessus sont en fichiers distincts par ressource. Sur les
28 ressources, 180 fichiers distincts au total.

**La preuve, sur cette branche.** Le corpus ne sert plus à « rien n'a bougé » —
tout doit bouger. À chaque ressource : la planche validée par l'auteur,
`palette_usage.py` sans défaut, et la lane r-type 7/7 dès que l'image est
jouable. Le corpus reprend son rôle à la réunification, contre `master`.

**Conséquence de l'ordre choisi : le jeu est FAUX à l'écran entre A et E.**
La bascule de palette est en groupe E ; d'ici là les images migrées portent les
nouveaux index face à l'ancien `pal.png`, donc de mauvaises couleurs en jeu. Le
verdict visuel se lit sur les **planches** (rendu contre la palette cible), pas
sous toje, et la lane r-type ne juge sur cette période que la mécanique (7/7),
pas les couleurs. Alternative écartée : basculer la palette dès maintenant
rendrait chaque ressource validée immédiatement juste, mais rendrait fausses
toutes celles qui ne sont pas encore migrées — dont les tuiles, c'est-à-dire
tout l'écran. Mieux vaut un écran faux et des planches justes qu'un écran à
moitié faux tout du long.
