# Un manager de tirs pour tout le jeu — analyse

*29/08/2026. Question de l'auteur : les tirs ennemis remplissent l'écran ; un
manager unique, portant les collisions et les directions, avec une animation
synchronisée par un compteur partagé et ses images dans sa propre page,
libérerait-il des ressources objet et gagnerait-il des trames ?*

**Réponse courte : oui, et c'est le troisième cas d'un patron que le dépôt a
déjà validé deux fois. Mais le plus gros gain immédiat n'est pas le manager —
c'est une boucle de compensation de trame qu'on peut remplacer aujourd'hui,
sans rien réarchitecturer.**

## 1. Ce qu'une balle coûte réellement, poste par poste

Relevé sur `src/enemies/_shared/foefire.asm`, le tir ennemi partagé.

### Le dispatch (`RunObjects`, par objet et par trame)

```
        ldb   id,u
        ldx   #Obj_Index_Page
        abx
        lda   ,x
        _SetCartPageA          ← MONTAGE DE PAGE
        aslb
        ldx   #Obj_Index_Address
        abx
        ldd   run_object_next,u
        std   object_list_next
        jsr   [,x]             ← indirection double
```

### Le tick (`foefire.live`)

| Poste | Ce que ça coûte |
|---|---|
| animation | `imgIdx` incrémenté, masqué, table, `std image_set` |
| **déplacement** | **deux boucles `addd` répétées `frameDrop.count` fois**, puis `moveXPos8.8` / `moveYPos8.8` |
| terrain | 1 sonde, **2 si `backgroundSolid`** (le stage 3 l'arme) |
| fenêtre | 6 comparaisons 16 bits |
| boîte | mise à jour `AABB.cx/cy` |

### Le rendu (`BuildSprites`, par sprite et par trame)

```
        ldx   #Img_Page_Index
        ldb   id,u
        abx
        lda   ,x
        _SetCartPageA          ← MONTAGE DE PAGE
        ldx   image_set,u
        ... décodage de l'imageset : x_size, y_size, center_offset, x1, y1 ...
        lda   _page_draw_routine
        _SetCartPageA          ← MONTAGE DE PAGE
        jsr   [_draw_routine]
```

**Bilan : deux à trois montages de page par balle et par trame**, un dispatch
d'objet complet, un décodage d'imageset complet, et une boucle de
compensation de trame.

## 2. Le gain gratuit, à prendre avant toute chose

`foefire` applique sa vitesse ainsi :

```
        lda   gfxlock.frameDrop.count
        sta   glb_d0_b
        ldd   #0
!       addd  x_vel,u
        dec   glb_d0_b
        bne   <
        jsr   moveXPos8.8
```

C'est une **multiplication faite par additions répétées**, deux fois par balle
et par trame. À la cadence mesurée du stage 3 (9,59 fps), `frameDrop.count`
vaut 5 à 6 : une douzaine d'`addd` plus la boucle, par balle.

Les pièces du vaisseau font le même calcul avec **deux `mul`**
(`layer.AddPos`, `warship-elements/layer.asm`). Porter cet idiome dans
`foefire` et `scantfire` est un changement local, sans risque architectural, et
c'est proportionnellement le poste le plus lourd du tick d'une balle.

**À faire d'abord, et à mesurer.** Si le gain suffit, le manager devient un
choix de confort plutôt qu'une nécessité.

## 3. Ce que le manager retire — et ce qu'il ne retire pas

### Il retire

| Poste | Aujourd'hui | Avec manager |
|---|---|---|
| dispatch d'objet | N | **1** |
| montages de page | 2N à 3N | **1** (la page du manager, montée par le moteur avant sa routine de dessin) |
| préambule `BuildSprites` | N décodages d'imageset + N insertions dans la liste de priorité | **1** |
| état par balle | **117 octets** (un slot d'OST entier) | **~12 octets** : vivant, x 16.8, y 16.8, vx 8.8, vy 8.8 |
| phase d'animation | 1 octet + inc/masque/table par balle | **un compteur partagé** |

Le rapport d'occupation est de **10 pour 1**. Vingt balles cessent d'occuper
vingt slots sur soixante — c'est exactement la marge qui manque au stage 3,
où le vaisseau seul culmine à 44 pièces vivantes.

### Il ne retire pas

- **l'arithmétique de déplacement** par balle (mais voir §2) ;
- **la sonde terrain** par balle — chaque balle doit tester le décor où elle
  est ;
- **la confrontation AABB**, *sauf si* le manager fait le test lui-même :
  une balle contre le joueur, c'est une boîte contre une boîte. Le manager
  peut boucler sur ses balles et sortir complètement de
  `AABB_list_foefire` — ce qui retire aussi N inscriptions/retraits de liste.

## 4. Sur l'animation synchronisée

L'auteur a raison et l'argument est plus fort qu'il n'y paraît. Aujourd'hui
chaque balle porte **sa** phase (`imgIdx`, incrémentée à chaque tick, masquée
sur 4). Mais les balles sont **le même sprite** : deux balles en phases
différentes ne se distinguent pas à l'œil, et personne ne peut dire, en
regardant l'écran, si le cycle est commun ou non. C'est de l'état sans
signification observable — précisément ce qu'un manager doit supprimer.

Un compteur partagé retire, par balle et par trame : un `inc`, un `andb`, un
`stb`, une lecture de table et un `std image_set`. Et il rend la pose commune
à toutes les balles, donc **une seule adresse de routine compilée à charger
pour tout le lot**.

## 5. Les conditions et les limites

1. **Une page pour toutes les images de tirs.** C'est la condition qui
   supprime les montages : `BuildSprites` monte la page d'images de l'objet
   avant d'appeler sa routine de dessin, donc le code du manager *et* tout
   ce qu'il dessine doivent partager la page. Il faut donc **mesurer** ce que
   pèsent ensemble `foefire`, `scantfire` et les tirs candidats. Si ça
   déborde, le manager se scinde par page — un montage par *groupe*, pas par
   balle : le gain reste.
2. **Le mode overlay est ce qui rend la chose possible.** Pas de sauvegarde
   ni de restauration de fond par sprite : le manager peut blitter
   directement, comme `flamemgr.DrawAll`. En mode background-erase, non.
3. **Il peint sans trier.** Toutes les balles à une seule priorité, la
   dernière dessinée passe devant. Pour des balles identiques, invisible.
4. **N'y mettre que ce qui est vraiment une balle** : « va tout droit,
   s'anime, meurt au contact ». Le laser de capsule, le ground laser et les
   détachables ont des comportements propres et restent des objets.
5. **Perte d'observabilité** : les balles sortent de l'OST, donc des vues
   objets de wddebug. Compromis déjà accepté pour l'outslay et les gerbes.

## 6. Sur les images de tuiles — ce que le manager ne résout pas

Le manager ne change rien au **coût de dessin lui-même** : une routine
compilée écrit ses pixels, et c'est le poste incompressible. Il retire
l'enveloppe (dispatch, montage, décodage), pas le contenu. Sur des balles de
8×8 l'enveloppe pèse **proportionnellement très lourd** — c'est ce qui rend
le cas favorable. Sur de gros sprites elle serait négligeable.

C'est aussi pourquoi il ne faut pas généraliser à tous les objets : le patron
paie sur **beaucoup de petites choses identiques**, et perd son intérêt dès
que les instances sont peu nombreuses ou grosses.

## 7. Ce qu'il reste à mesurer avant de coder

Cette analyse est structurelle ; elle ne contient volontairement **aucune
prévision de fps chiffrée**, parce qu'aucune mesure ne la soutiendrait.

Deux mesures à faire, dans cet ordre :

1. **Le profil.** `profile_start` / `profile_top` sous toje, sur le stage 3
   à un moment chargé en tirs : quelle part de trame prend l'`Object` de
   `foefire` ? C'est la réponse directe à « combien ça rapporte », et ça coûte
   une après-midi contre une semaine de travail.
2. **Le compte réel de balles simultanées.** Le gain est *proportionnel* au
   nombre de balles vivantes : à 5 balles c'est du bruit, à 20 c'est
   substantiel. **Attention à la méthode** : le pool vit en `$4000`, dans la
   demi-page 0 — de la RAM écran épinglée par le PRC. Une lecture non
   intrusive à cette adresse retourne l'autre banc et donne **zéro** ; une
   tentative de recensement a échoué ainsi le 29/08/2026. Il faut passer par
   une routine injectée dans le jeu, ou compter à la source (au moment où le
   tir est engendré).

## 8. Ce que la mise en oeuvre a appris (29/08/2026)

Le manager est en place. Quatre choses ont ete apprises en le faisant, dont
trois ne se devinaient pas depuis l'analyse.

**Le point de bascule etait unique, et c'est ce qui rend la migration
indolore.** Les neuf familles d'ennemis qui tirent passent toutes par
`tryFoeFire` puis `createFoeFire` : reecrire ce seul point suffit, aucun code
d'ennemi ne change. L'identifiant non plus — `foefire.Object` designe
desormais le manager, et les neuf tables d'index de stage pointaient deja le
bon symbole. UNE exception a fait tout le mal : la tourelle multiple du
vaisseau posait `ObjID_foefire` DIRECTEMENT dans un OST qu'elle allouait, en
court-circuitant createFoeFire. Chacun de ses tirs creait donc un MANAGER de
plus — jusqu'a six, chacun deplacant toutes les balles a chaque trame, d'ou
des balles six fois trop rapides. Avant de rerouter un identifiant, chercher
qui le pose a la main.

**Les boites de collision ne peuvent pas vivre dans une page montee.**
`Collision_Do` les parcourt avec la page de collisionpass montee : une boite en
fenetre cartouche fait lire les octets d'une AUTRE page et suivre des pointeurs
pourris, avec ecriture a travers eux. La table a fini en RAM residente — la
raison exacte, comprise apres coup, pour laquelle `outslay.boxes` y vit deja.

**`Collision_AddAABB` attend une boite aux liens VIERGES.** Il insere en queue
et ne touche pas `next` ; les objets du pool l'ont gratuitement (LoadObject
zere leur OST), mais un slot de manager se REUTILISE et `RemoveAABB` laisse les
vieux pointeurs. Reinsere sans nettoyage : liste circulaire, et Collision_Do ne
rend plus jamais la main. C'est le contrat implicite a retenir pour tout futur
manager qui possede ses boites.

**Le gain de cadence est marginal, le gain de place ne l'est pas.** Jeu reel
6,62 -> 6,73 fps sur le stage 3 (+0,1 a +0,36 selon la tranche de camera) :
conforme au SS7, le gain est proportionnel au nombre de balles vivantes et ce
stage n'en tient que 8 a 16. Ce qu'il rapporte vraiment ici est 24 SLOTS
D'OBJETS RENDUS AU POOL — 21 octets residents par balle au lieu d'un OST de
117 — sur un stage dont le vaisseau seul culmine a 44 pieces sur 60 slots.

**Couverture** : stages 1, 3, 4, 5, 6, 7, 8 joues sans gel, 5 a 8 s'enchainant
jusqu'au retour title. Le stage 2 n'a PAS pu etre exerce : le chargement de sa
scene echoue en `tlsf OUT_OF_MEMORY` — defaut PREEXISTANT, reproduit a
l'identique sur master par le cheat et par le handover reel du stage 1.

## 9. Recommandation

Trois étapes, chacune livrable et mesurable :

1. **Le gain gratuit** : `layer.AddPos` à la place des boucles de
   compensation dans `foefire` et `scantfire`. Mesurer.
2. **Le profil** : savoir ce que les tirs coûtent vraiment.
3. **Le manager**, borné à `foefire` + `scantfire` d'abord, sur le patron
   `outslay.Render` / `flamemgr` : table de slots compacte, compteur
   d'animation partagé, test joueur fait par le manager, blit direct.

Le patron est éprouvé (20 segments de serpent, 8 gerbes) ; le risque n'est
pas dans la technique, il est dans le périmètre. Le tenir serré.
