# Plan — l'écran LOADING entre les chargements disquette (06/09/2026)

Objectif : retrouver l'écran de chargement à **chaque** transition disque,
comme la v1, en le rendant **auto-porteur** : un seul fichier qui se charge
dans une page écran et emporte son image, sa palette et le code qui l'affiche,
sans rien écraser de ce que le jeu utilise et sans rien ajouter aux arènes ni
au résident au-delà de quelques octets de séquence.

Rien n'est codé. Ce document fixe les faits, le principe, la séquence, les
étapes, et les décisions qui restent à l'auteur.

---

## 1. Les faits, tels qu'ils sont dans le code aujourd'hui

### 1.1 Comment la v1 fait

LOADING est un **game mode** (`GmID_loading`). Qui veut changer de mode pose sa
cible dans `globals.nextGameMode` et charge ce mode : il affiche l'image, la
laisse vivre dix trames, puis appelle `LoadGameModeNow` sur la cible. Deux
appelants dans r-type v1 : le title au départ, et l'objet de fin de stage.

La v1 ajoute une **ruse de page** parce que son chargeur disque saccage la page
pointée par `$E7E5` : elle épingle l'image sur l'autre page (2) et donne la
page 3 au chargeur comme brouillon.

### 1.2 Ce qu'en a gardé la v2

Le module est porté (`src/common/flow/loading/`), mais avec **un seul
appelant** : le title au press start (`src/title/main.asm`). L'entête de
l'unité le dit : « paginée dans l'arène title, son consommateur actuel ».
L'appel de fin de stage est **commenté depuis le 07/08/2026** avec un écart
assumé (« la v2 n'a pas de modes de jeu, on sort d'un stage en changeant de
scène ») et n'a jamais été rebranché. Ce n'est pas une régression.

### 1.3 La carte mémoire v2 (`to8.config.xml`, `machine.xml`)

| quoi | où | note |
|---|---|---|
| Loader | page **4**, `$C000`, fenêtre DATA (`loader.PAGE`/`loader.ADDRESS`, `<reserved name="loader">` $2000) | il n'écrit **jamais** par sa propre fenêtre (refusé au build) : il atteint les autres pages par la fenêtre **cartouche** `$0000-$3FFF` (`$E7E6`) |
| Tampons écran | pages **2 et 3** : `framebuffer.N.color` `$A000` et `framebuffer.N.form` `$C000`, taille **$1F40** chacun | visible = SYS2 `$E7DD` : `$80` page 2, `$C0` page 3 (bits 0-3 = bordure) ; dessin = DATA `$E7E5` |
| Vue cartouche d'une page écran | color `$0000-$1F3F`, form `$2000-$3F3F` | c'est par là que le loader y écrirait |
| Les queues | `$1F40-$1FFF` et `$3F40-$3FFF`, **192 o chacune**, non déclarées, jamais affichées | vue DATA : `$BF40-$BFFF`, `$DF40-$DFFF` |
| Page 0 | demi-page 1 = pool d'objets (RAM), demi-page 0 = ruban du stage 4 | seule autre page affichable (SYS2 choisit parmi 0-3) — **écarter** : on écraserait le pool |

**Ce qui touche les queues.** Le blast plein écran (`clearblast.asm`) part de
`$BF41` et ne dépose que son octet en trop sur `$BF40` : pendant le jeu, **191
octets** par banc sont intacts (`$xF41-$xFFF`). Mais `checkpoint.clearData` =
`ClearDataMem` efface **toute** la fenêtre `$A010-$DFFF`, queues comprises, à
chaque ouverture de stage et à chaque rechargement de checkpoint. Conséquence
utile : les queues ne peuvent porter qu'un contenu **de transition** — c'est
exactement la durée de vie d'un écran de chargement.

### 1.4 Le séquenceur unique : `game.stage.switch` (résident, `engine.asm`)

```
        jsr   IrqOff                       ; le chargement parle au contrôleur
        _ram.data.set #loader.PAGE         ; monter la page du loader (DATA)
        ...état cible...
        jsr   loader.ADDRESS+loader.composition.load.IDX
        jmp   stage.main
```

**Tous** les changements disque passent par lui : title → stage (via
`title.cheat.launch`), stage → stage (`stage.handOver`), game over → title.
Le classement, le continue et le checkpoint ne chargent rien. C'est **le**
point de branchement, et un seul.

Autre fait décisif : l'IRQ est **coupée** avant le chargement. Aucun effet ne
peut tourner *pendant* la lecture disque ; *avant*, oui.

### 1.5 Les compositions

`<composition name="stageN">` = liste de scènes ; « un état décrit toute la
RAM ». Le loader lâche ce que la cible ne tient pas, charge ce qui manque,
garde l'intersection sans relecture. Dix compositions aujourd'hui.

### 1.6 Les briques déjà là

- `paged.call` : A = page (`map.RAM_OVER_CART+N`), X = adresse ; réentrant ;
  indépendant de `$E7E5` — on peut exécuter du code en fenêtre cartouche
  **pendant que la page du loader reste montée en DATA**.
- `<png2bin>` : un banc vidéo par déclaration (`videomode="bm16"`,
  `plane="0|1"`), déjà consommé par `examples/hscroll`. Jamais encore utilisé
  pour un écran plein.
- `<png2pal>` : la palette d'un PNG dans une section.
- `WaitVBL` (`engine/graphics/vbl/WaitVBL.asm`) : attente par **scrutation** de
  `$E7E7`, donc utilisable IRQ coupée.
- Le loader décompresse ZX0 **en place** à la destination.

---

## 2. Le principe

> **L'écran de chargement est un fichier de 16 Ko qui se charge dans la
> page 3 entière, vue cartouche, et qui emporte tout ce qu'il lui faut.**

```
$0000  ┌──────────────────────────┐
       │ banc couleur   8 000 o   │  <png2bin plane="0">
$1F40  ├──────────────────────────┤
       │ queue A          192 o   │  +0 sacrifié au blast ; +1 : palette (32 o),
       │                          │  puis l'ENTRÉE : SYS2 := page 3, palette
$2000  ├──────────────────────────┤
       │ banc forme     8 000 o   │  <png2bin plane="1">
$3F40  ├──────────────────────────┤
       │ queue B          192 o   │  suite du code (fondu), si la queue A déborde
$4000  └──────────────────────────┘
```

- **Normalisation.** La page de l'écran est **fixe : la page 3**. Le loader est
  déjà fixe (page 4, hors des pages écran — la ruse v1 est sans objet). « L'autre
  page » n'est donc pas relative au loader mais un choix : on prend la 3 une
  fois pour toutes. Une destination fixe = un fichier que le loader **déduplique**
  à chaque recharge (même fichier, même place = même slot), et une place
  déclarable dans la carte.
- **Pourquoi pas « la page visible du moment ».** À l'arrivée dans le
  séquenceur la palette est **noire** (l'endstage la noircit avant de partir,
  le title coupe, le game over aussi — à garantir pour chacun, cf. §6). Charger
  dans la 3 est donc invisible quoi qu'elle affiche ; puis SYS2 := `$C0` et
  palette : un cut propre, jamais une image qui se remplit secteur par secteur.
- **Rien à écraser.** La page 3 est un tampon du stage sortant, dont les objets
  sont morts et la palette éteinte. Les queues n'appartiennent à personne. Le
  résident ne gagne que la séquence (~30 octets ; marge mesurée aujourd'hui :
  266 octets sous le lecteur YMM). Le module objet/gfxcomp/`Pal_loading` de
  l'arène title **disparaît** et rend ses octets.
- **Compressé.** Le direntry passe l'écran au ZX0 : un écran presque noir avec
  un vaisseau et un mot fait quelques centaines d'octets sur disquette, et se
  décompresse en place dans la page 3 par la fenêtre cartouche.

---

## 3. La séquence, dans `game.stage.switch`

```
        jsr   IrqOff
        _ram.data.set #loader.PAGE
        ; --- l'écran de chargement, AVANT la cible ---------------------------
        (1) charger le fichier loading.screen dans la page 3
        (2) lda #map.RAM_OVER_CART+3 / ldx #$1F41+32 / jsr paged.call
              → la queue : SYS2 := $C0 (bordure 0), palette posée
                (ou fondue en N trames par WaitVBL — IRQ coupée, scrutation)
        ; --- puis ce qu'on faisait déjà --------------------------------------
        ...état cible...
        jsr   loader.ADDRESS+loader.composition.load.IDX
        jmp   stage.main
```

L'image reste à l'écran pendant tout le chargement synchrone, jusqu'à ce que
l'ouverture du stage efface les deux tampons — le même mécanisme qui la fait
disparaître aujourd'hui depuis le title. Le title devient un appelant ordinaire :
`title.clearBuffers`, l'objet loading, les deux trames et `Pal_loading` sortent
de `src/title/main.asm`.

### 3.1 Comment charger l'écran : deux voies, une recommandée

**(a) Un état « loading ».** `<composition name="loading">` = `scenes.boot` +
l'écran ; on converge vers lui, on affiche, on converge vers la cible. Propre
dans le modèle, mais la première convergence **lâche** tout ce que l'état
sortant partage avec la cible et qui n'est pas dans « loading » (les lots
d'ennemis communs à deux stages consécutifs) : on perd « zéro relecture pour
l'intersection ». Coût mesurable dans `seek-report`.

**(d) Un fichier seul, par `loader.file.load` (entrée 12).** L'écran n'est pas
un état : un fichier à une destination fixe que personne d'autre n'occupe, sans
symbole à lier. Aucune convergence intermédiaire, l'intersection stage → stage
reste intacte. C'est la voie recommandée. Elle demande de vérifier deux choses
(§6) : qu'un fichier sans link data ne laisse pas de slot d'index qui gênerait
`LOAD_OVERLAP`, et que le contrôle de composition accepte un fichier posé sur
les `<reserved framebuffer.3.*>` — sinon la page 3 se déclare comme une
`<region>` de $4000 portant ce fichier, à la place des deux `reserved`.

---

## 4. La queue : 191 octets, et ce qu'on y met

| offset (vue cartouche) | contenu | taille |
|---|---|---|
| `$1F40` | l'octet que le blast plein écran écrase — **inutilisable** | 1 |
| `$1F41` | la palette, `<png2pal>` de l'image | 32 |
| `$1F61` | l'entrée : `lda #$C0` / `sta $E7DD` ; boucle de 16 écritures `$E7DA/$E7DB` | ~40 |
| suite | option **fondu** : 4 à 8 pas, `WaitVBL` par scrutation entre chaque, palette atténuée par masque de bits | ~80 |
| `$3F41` | débord éventuel du fondu (queue B) | 191 |

Contraintes vérifiées :
- le code s'exécute **en fenêtre cartouche** (`$E7E6` = page 3) via
  `paged.call`, la page du loader restant montée en DATA — aucune RAM de
  travail hors la pile ;
- il ne touche que `$E7DD`, `$E7DA/$E7DB`, `$E7E7` (lecture) ;
- il tourne **avant** le chargement de la cible, IRQ coupée, donc toute attente
  est une scrutation ;
- la **bordure** : SYS2 porte aussi la couleur de bord (`gfxlock.screenBorder.color`,
  auto-modifié dans le résident). La queue ne connaît pas cette adresse et
  `paged.call` détruit B : on fixe la bordure à **0 pendant le chargement**,
  le stage la reposera à sa première bascule.

---

## 5. Les étapes

**E0 — décisions auteur** (§7).

**E1 — le fichier écran, côté builder.**
- Composer l'image 320×200 (fond noir + l'art actuel de
  `src/common/flow/loading/images/00.png` posé en 80,100 comme le fait l'objet).
- `<png2bin plane="0">` et `plane="1"` → deux bancs de 8 000 o. **À vérifier** :
  l'attribut `buffer` a une valeur « plan brut » (hscroll utilise
  `buffer="hscroll"`).
- Une source lwasm qui assemble `[banc][queue A][banc][queue B]` : `INCLUDEBIN`
  des deux bancs, `<png2pal>` dans la queue A, le code de la queue, padding
  explicite jusqu'à `$4000`.
- `<file name="loading.screen" page="$03" address="$0000">` : `$4000` en
  `$0000` remplit exactement la fenêtre cartouche, le contrôle de fenêtre passe.
- Régler la question `reserved` vs fichier (§3.1 d).

**E2 — le code de la queue.** Écrit à la main dans la même source. Banc : une
scène de test qui charge l'écran seul et l'affiche sous toje ; vérifier que
`$BF41-$BFFF` et `$DF41-$DFFF` sont bien intacts après un blast plein écran.

**E3 — le séquenceur.** Les deux gestes dans `game.stage.switch` (§3). Retirer :
le chemin spécial du title, `src/common/flow/loading/`, `title.loading` et
`Pal_loading` du config, `ObjID_loading` (36) du title. Chaque appelant garantit
la palette noire avant d'entrer (§6).

**E4 — validation.** `rtype_bench` 7/7 (title→1→2→3→4 et game over→title
passent tous par le séquenceur) ; vidéo title→stage 1→stage 2 pour voir l'écran
à chaque transition ; corpus (seul r-type change) ; rapport d'occupation :
l'arène title rend les octets de `title.loading`.

**E5 — doc.** Un cas dans `docs/lang/en/migration/` (« le game mode loading
v1 devient un fichier écran auto-porteur ») et le journal de ce plan.

---

## 6. Risques et points à vérifier avant E1

1. **Index du loader.** Que fait `loader.file.load` d'un fichier sans link
   data ? S'il l'indexe, la recharge au même endroit est une déduplication
   (acquis du 30/07) ; s'assurer qu'aucun `LOAD_OVERLAP` ne se déclenche parce
   que la page 3 serait vue comme « encore indexée » par un état suivant.
2. **`reserved` vs fichier.** Le contrôle de composition accepte-t-il un
   fichier sur `framebuffer.3.*` ? Sinon, `<region>` de la page 3 (§3.1).
3. **Palette noire à l'entrée**, pour chaque appelant : l'endstage la pose
   (`Pal_black` puis `PalUpdateNow`) ; le title pose aujourd'hui `Pal_loading`
   → poser le noir à la place ; le game over → à lire.
4. **`png2bin`** : sortie plan brut de 8 000 o, ordre des bancs (couleur/forme)
   conforme à `framebuffer.N.color` = `$A000` et `.form` = `$C000`.
5. **Vitesse de décompression** : 16 Ko de sortie ZX0 en place ; à mesurer, mais
   l'écran est presque vide et le décompresseur copie des runs.
6. **Bordure** fixée à 0 pendant le chargement (§4).
7. **MO6** : hors périmètre (r-type est TO8), mais la fenêtre vidéo MO6 diffère
   (video `$0000`, data `$6000`) — le fichier écran ne suppose que la vue
   cartouche et deux registres du TO8 ; à paramétrer par machine le jour venu.

---

## 7. Ce qui reste à l'auteur

- **La page** : 3 (proposé) ou 2.
- **La voie de chargement** : fichier seul (d, recommandé) ou état « loading » (a).
- **Palette sèche ou fondu** : le fondu tient dans la queue, mais il coûte des
  trames à chaque transition (v1 : dix trames).
- **L'image** : reprendre l'art actuel tel quel, ou une composition plein écran.
- **Le title** : montrer aussi l'écran au retour du game over vers le title
  (le séquenceur le ferait par défaut), ou l'en exempter.

---

## 8. Réflexion, second tour (06/09/2026) — page 3 à l'écran, page 2 qui exécute

Proposition auteur : **page 3 = la page montée à l'écran pendant tout
chargement ; page 2 = une page qui exécute du code entre deux stages**, sans
effet sur leur enchaînement. Pour cela, un chargement de composition devrait
pouvoir désigner une adresse d'exécution, aujourd'hui figée.

### 8.1 Ce qui existe déjà, et qu'il suffit de généraliser

Le loader connaît **déjà** un point d'exécution « page + adresse », mais pour
le seul boot (`loader.asm`, l. 190-205) :

```
        ldb   #loader.DEFAULT_SCENE_EXEC_PAGE      ; = 1        (config, l. 4977)
        ldu   #loader.DEFAULT_SCENE_EXEC_ADDR      ; = $6100    (config, l. 4982)
        jsr   ram.set                              ; monte la page dans LA fenêtre
        ...                                        ;   que l'adresse désigne
        jmp   loader.DEFAULT_SCENE_EXEC_ADDR
```

`ram.set` (B = page, U = adresse) déduit la fenêtre de l'adresse, comme le
modèle mémoire le veut. Le « $6100 figé » est donc cette paire de constantes,
pour le boot ; ensuite `game.stage.switch` saute en dur sur `stage.main`
(région `stage`, `$7C00`). Et le boot lui-même **passe par le séquenceur** :
`boot.entry` fait `clrb / jmp game.stage.switch` (état 0 = title).

**La généralisation tient en une colonne de table.** `game.stage.states`
(`engine.asm` l. 404) est aujourd'hui une liste de pointeurs de compositions ;
chaque entrée gagne une **page et une adresse d'entrée**, écrites par le builder
depuis un attribut de `<composition>` (`entry="page:adresse"` ou le symbole
d'une unité). Le séquenceur finit alors par `ram.set` + `jmp` au lieu de
`jmp stage.main`. Title, stages et un éventuel état « loading » deviennent
uniformes ; `stage.main` cesse d'être la dernière adresse en dur du jeu, et
le boot n'est plus qu'un état parmi les autres.

### 8.2 Ce qui a pu échapper — les contraintes vérifiées dans le code

1. **Le loader ne rend pas la fenêtre cartouche.** Il monte la page de chaque
   destination par `ram.set` et ne restaure rien au retour (aucune sauvegarde de
   `$E7E6` dans `loader.asm`). Du code qui s'exécute en page 2 *par la fenêtre
   cartouche* ne peut donc **pas appeler le loader et revenir** : à la fin du
   chargement la fenêtre montre une autre page, et le `rts` retombe dans
   n'importe quoi. Deux issues : (a) le code de la page 2 **ne charge rien** —
   il est entré *après* les chargements de transition et **sort par un saut**
   vers le résident, qui charge la cible et saute à son entrée ; (b) donner au
   loader une sauvegarde/restauration de `$E7E6` autour d'un chargement
   (quelques octets), ce qui autoriserait la page 2 à orchestrer elle-même.
   La voie (a) suffit et ne touche pas au loader.
2. **L'ordre des chargements de transition.** L'image (page 3) et le code
   (page 2) passent tous deux par la fenêtre cartouche : les charger **avant**
   de monter la page 2 pour l'exécuter. Trivial, mais cela interdit « la page 2
   charge sa propre image ».
3. **Pas de `paged.call` depuis la page 2** : monter une autre page dans la
   fenêtre cartouche démonte l'appelant. Tout ce que le code de transition
   appelle est **résident**, ou dans la page 2 elle-même.
4. **La musique est compatible.** Le tick du lecteur YMM sauve et restaure la
   page cartouche autour de son travail (`ymm.asm` l. 173-191,
   `_GetCartPageA`/`_SetCartPageA`) : une IRQ active pendant la phase de
   transition ne casse pas la page 2. Mais le chargement disque coupe l'IRQ ;
   un jingle ne jouerait que **pendant l'attente avant** la lecture, et ses
   données devraient être présentes (page 26, avec les musiques communes).
   L'arcade est silencieuse pendant le chargement : à trancher.
5. **La page 2 dessine dans la page 3.** Par la fenêtre DATA (`$E7E5` = 3,
   `$A000-$DFFF`), le code de transition dispose d'une **vraie surface** :
   « STAGE 2 », une barre, une animation, avec ses propres routines (pas de
   sprites paginés). Il remet `$E7E5` sur `loader.PAGE` avant de sortir — le
   séquenceur résident le refait de toute façon.
6. **L'effacement vient tout seul.** L'ouverture du stage cible efface les
   deux tampons (`ClearDataMem`, `$A010-$DFFF`) : le code de la page 2 et
   l'image de la page 3 disparaissent sans geste. Ne reste que la question de
   l'**index du loader** (§6.1) : les deux fichiers de transition ne doivent
   pas laisser de slot qui déclencherait `LOAD_OVERLAP` ; sans link data ils ne
   devraient pas en avoir, à vérifier.
7. **La parité de départ, normalisée gratis.** « Page 3 à l'écran » oblige le
   séquenceur à poser `gfxlock.backBuffer.status` en cohérence (`$FF` ⇒ SYS2
   `$C0`). Tous les stages démarrent alors avec la **même parité de tampons**
   (3 visible, 2 en arrière), là où elle dépend aujourd'hui de l'historique.
   Effet secondaire utile : les premières trames du stage se dessinent en
   page 2 pendant que la page 3 montre encore l'écran de chargement, jusqu'à
   l'effacement d'ouverture.
8. **Le boot montrerait l'écran** avant le title, puisqu'il passe par le même
   séquenceur. Et le game over → title aussi. Le checkpoint (mort) et le
   classement ne passent pas par le séquenceur : pas d'écran, ce qui est juste.
9. **Les queues de 192 octets deviennent inutiles** : la page 2 porte tout le
   code et la palette ; la page 3 n'est plus qu'un bitmap. Le fichier écran se
   réduit à deux `<png2bin>`.
10. **Les compositions ne voient ni la page 2 ni la 3.** Deux options, et le
    dilemme du §3.1 reste : (a) un état `loading` = boot + les deux fichiers de
    transition, avec son entrée en page 2 — propre, mais la convergence vers
    cet état lâche l'intersection entre deux stages consécutifs ; (d) deux
    `loader.file.load` par le séquenceur, sans état — l'intersection est
    préservée, les fichiers de transition vivent dans une `<region
    name="transition">` sur les pages 2-3 pour que le contrôle de composition
    sache que rien d'autre n'y charge. La généralisation de l'entrée (§8.1)
    vaut dans les deux cas.
11. **Coût disque.** Deux fichiers par transition, quelques secteurs chacun ;
    les poser sur la piste du répertoire ou de `scenes.boot` pour ne pas payer
    un déplacement de tête (`seek-report`).

### 8.3 La séquence, révisée

```
game.stage.switch (B = cible)
        stb   game.stage.target
        jsr   IrqOff
        _ram.data.set #loader.PAGE
        charger loading.code  → page 2  (fenêtre cartouche)
        charger loading.screen→ page 3  (fenêtre cartouche)
        backBuffer.status := $FF ; SYS2 := $C0 (bordure 0) ; palette encore noire
        ram.set(page 2, $0000) ; jmp $0000        ← le MODE DE TRANSITION

    (page 2, fenêtre cartouche, tout est à lui)
        palette : fondu ou pose sèche ; « STAGE N » dessiné en page 3 par DATA ;
        attente ; éventuellement IRQ + jingle ; puis, sans retour :
        jmp   game.state.enter

game.state.enter (résident, ~20 octets)
        _ram.data.set #loader.PAGE
        composition.load(game.stage.target)
        ram.set(entree.page, entree.adresse)        ← la colonne ajoutée à la table
        jmp   [entree]
```

Le résident perd le chemin spécial du title et ne gagne qu'une vingtaine
d'octets ; la page 2 offre 16 Ko de code et de données de transition, libres
à chaque passage, effacés par le stage qui arrive. C'est, à la lettre, le game
mode `loading` de la v1 — sans lui coûter une place dans la carte.

### 8.4 Décisions supplémentaires pour l'auteur

- Voie (a) contre (b) au point 1 : la page 2 orchestre-t-elle le chargement
  (il faut alors que le loader rende `$E7E6`), ou se contente-t-elle du saut
  final vers le résident ? Recommandation : (a), le loader reste tel quel.
- Un jingle pendant l'attente avant la lecture, ou le silence de l'arcade.
- L'écran au boot et au retour du game over : oui par défaut, ou exempter.
- Voie (a) contre (d) au point 10 : état `loading` ou deux fichiers.

---

## 9. Les points à trancher (06/09/2026, consolidés)

Deux précisions de modèle d'abord, vérifiées dans `loader.asm`.

**Le boot ne charge pas une composition.** Il charge une **scène** —
`loader.scene.load(DEFAULT_SCENE_FILE_ID)`, c'est-à-dire `scenes.boot` — puis
monte la page d'exécution par défaut et saute en `$6100`. La première
composition est le title, chargée par la première instruction du moteur
(`boot.entry` : `clrb / jmp game.stage.switch`). La composition `boot` du
config décrit cet état pour le contrôle du builder et pour le pointeur d'état
courant du loader (`composition.current`, un pointeur sur la table résidente),
elle n'est pas ce que le boot exécute.

**Le point d'entrée, aujourd'hui, n'appartient ni à la scène ni à la
composition : il appartient à la région.** `stage.main` est exporté par
chacune des neuf alternatives de la région `stage` (le title compris,
`src/title/main.asm` l. 74) et le séquenceur y saute par le lien. Le boot
seul a un point d'entrée déclaré (page + adresse), en deux constantes
manuscrites du config.

### 9.1 Modèle

1. **Où déclarer le point d'entrée.** Trois options :
   - *sur la région* (statu quo) : un symbole commun, résolu par le lien ;
     impossible pour un état dont le code n'est pas dans la région `stage`
     (la transition en page 2) ;
   - *sur la composition* : un état = une entrée ; simple, mais la même entrée
     se répète dans chaque état qui embarque la même scène exécutable ;
   - *sur la scène* (**recommandé**) : la scène qui apporte le code déclare
     son entrée (`entry="symbole"`), le builder la résout contre le placement
     (page + adresse) et l'écrit dans la table de l'état ; il **vérifie qu'un
     état n'a qu'une scène à entrée**. Cette forme absorbe
     `DEFAULT_SCENE_EXEC_PAGE/ADDR`, déjà déclarées par scène pour le boot, et
     supprime les deux `<asm>` manuscrits du config.
2. **La transition est-elle un état.** Une composition `loading` (= boot +
   scènes de transition), entrée en page 2 : uniforme, mais la convergence
   vers cet état **lâche l'intersection** entre deux stages consécutifs (les
   lots communs) — à mesurer dans `seek-report` avant de trancher. Sinon, deux
   `loader.file.load` par le séquenceur, hors état, intersection préservée.
3. **Qui orchestre.** La page 2 sort par un saut vers le résident qui charge la
   cible (**recommandé**, loader intact) ; ou le loader rend `$E7E6` après un
   chargement et la page 2 charge elle-même.

### 9.2 Pages et affichage

4. Page 3 à l'écran, page 2 pour le code — ou l'inverse.
5. Parité de départ posée par le séquenceur (`backBuffer.status` `$FF`, SYS2
   `$C0`) : tous les stages démarrent pareil. Implique la bordure 0 pendant la
   transition.
6. Palette sèche ou fondu ; attente minimale (v1 : dix trames) ou aucune —
   l'écran reste de toute façon le temps du chargement.

### 9.3 Contenu de la transition

7. Image fixe (l'art actuel recomposé en 320×200), texte dessiné par la page 2
   (« STAGE N »), ou les deux.
8. Jingle pendant l'attente avant la lecture (données à placer en page
   commune), ou le silence de l'arcade.

### 9.4 Couverture

9. Boot → title : montrer l'écran (le boot passe par le même séquenceur).
10. Game over → title : montrer (la v1 le faisait, faute de stage 2).
11. Checkpoint et continue : rien (pas de disque) — à confirmer.

### 9.5 Builder et carte mémoire

12. Déclarer les pages 2-3 : les `<reserved framebuffer.*>` laissent-ils la
    place à une `<region name="transition">` portant les fichiers de
    transition ? Le contrôle de composition doit admettre que les stages y
    **dessinent** sans y **charger**.
13. Index du loader : un fichier sans link data laisse-t-il un slot ? Sinon
    `unload` explicite dans la convergence.
14. `png2bin` : sortie « plan brut » de 8 000 o, à confirmer ou à ajouter.
15. Emplacement disque des fichiers de transition (piste du répertoire ou de
    `scenes.boot`, pour ne pas payer de déplacement de tête).

### 9.6 Nettoyage

16. Retirer `src/common/flow/loading/`, `title.loading`, `Pal_loading`,
    `ObjID_loading` (36) et le chemin spécial du title.

---

## 10. Premier pas : le fondu de boot (07/09/2026)

**Le défaut.** Le moniteur affiche la page 0 avec sa palette. Tout ce qui
s'écrit en page 0 avant la première bascule du jeu vers les pages 2/3 se voit
comme du bruit. Or `scenes.boot` y charge `common.ranking` (arène `ranking`,
page 0 demi-page 1 `$51C0`, 3 648 o), et l'init du title y efface le pool
d'objets et les tirs. Le title pose bien `Pal_black` en première instruction
(`src/title/main.asm` l. 99), mais **après** les chargements de `scenes.boot`
et `scenes.title` : la fenêtre de bruit couvre les deux.

**La solution : une scène de fondu, scène par défaut du loader.**

- `scenes.fade`, un fichier `boot.fade` d'une centaine d'octets, **entrée à
  l'offset zéro**, dans la région `stage` (`$7C00`, page 1) — le seul créneau
  libre au boot ; page 1 (moteur, YMM, région stage) et page 4 (loader,
  forcepod) sont pleines.
- Config : `DEFAULT_SCENE_FILE_ID equ scenes.fade`, `EXEC_PAGE equ 1`,
  `EXEC_ADDR equ stage.address` (déjà dans `gen/layout.asm`). **Aucune
  modification du loader.** C'est le premier usage de « l'entrée par scène »
  (§9.1), sans la généraliser encore.
- Le code :
  1. lire les 16 couleurs courantes (la lecture de `$E7DA` avance le pointeur ;
     `$E7DB` = l'index) — ou coder en dur la palette du moniteur ;
  2. huit pas d'un nibble par composante vers zéro, un `WaitVBL` par pas
     (scrutation de `$E7E7` : pas d'IRQ jeu à ce stade) — ~160 ms ;
  3. `ldx #scenes.boot / jsr loader.scene.load` (le loader est en DATA page 4,
     laissée montée ; ses entrées gèrent DP eux-mêmes) ;
  4. **rendre sa place** : `scene.unload` sur `scenes.fade` — au boot
     `composition.current` vaut 0 (`loader.asm` l. 433), la convergence vers le
     title ne décharge rien, et `title.main` tombe sur `$7C00` : sans ce geste,
     `LOAD_OVERLAP`. Inutile si un fichier sans link data n'est pas indexé
     (§6.1, à vérifier dans `scene.apply`) ;
  5. `jmp engine.address` → `boot.entry` → `game.stage.switch(title)`, inchangé.
- Le title trouve le noir déjà posé, efface, bascule sur 2/3 (l. 200), puis
  `Pal_title` (l. 217) : plus rien de la page 0 n'est jamais visible.

**Voie écartée** : le noir dans le bootloader ou le loader (trente octets pour
un noir sec). Générique, donc imposé à tout le corpus, et ne construit rien
du modèle de transition. Le fondu en scène reste dans r-type.

**Ce que ce premier pas prépare** : une scène exécutable autre que le title et
les stages, avec son entrée déclarée ; la place de l'écran de chargement au
boot (§9.9) est ce même créneau, une fois le §8 en place.

**Fait le 07/09/2026 — le module.** `engine/palette/palette-fade.asm` :
`palette.fade` (U = palette de travail, A|B = cible ; scrutation VBL, 40
lignes de bordure, un cran par composante et par trame, pile seulement, DP
intact) et `palette.to8.monitor` (la table v1 dépliée en 16 entrées). Prouvé
sur `examples/tilescroll` sous toje : 15 trames du menu TO8 au noir, bordure
comprise. Cas : `docs/lang/en/migration/boot-palette-fade.md`. La scène de
fondu du boot (ci-dessus) se réduit désormais à trois gestes : `ldu
#palette.to8.monitor / ldd #0 / jsr palette.fade`, puis `scene.load(boot)`
et le saut — reste la question de sa place et de son `unload`.

**Rectifié le 07/09/2026 (auteur).** Deux points du §10 tombent :
- *« rendre sa place »* : la scène de fondu est **cuite** (`bake`), sans link
  data — elle ne référence que des absolus (registres, `loader.ADDRESS` + index,
  `engine.address`, l'id de `scenes.boot`). Aucun slot dans l'index du loader,
  donc ni `scene.unload` ni `LOAD_OVERLAP`. Le §6.1 est sans objet ici ;
- *« le seul créneau libre »* : faux. Au boot toute la RAM est libre ; la
  vraie contrainte est « plus exécuté quand le chargement suivant l'écrase ».
  Elle se satisfait **partout** en ne rappelant jamais la scène après le
  chargement : on *saute* dans `scene.load` avec `engine.address` empilé comme
  adresse de retour, au lieu de l'appeler.

```
        ldu   #palette.to8.monitor
        ldd   #0
        jsr   palette.fade
        ldx   #engine.address          ; le « retour » de scene.load : boot.entry
        pshs  x
        ldx   #scenes.boot
        jmp   loader.ADDRESS+loader.scene.load.IDX
```

Le fondu est le dernier code exécuté avant le chargement ; le moteur recouvre
ses octets ; le `rts` du loader tombe sur `boot.entry`. D'où la place la plus
simple : **la région `engine` elle-même, `$6100`**, comme alternative du moteur
(elle n'est dans aucune composition, n'exporte rien, la région n'est pas une
interface). Seule `DEFAULT_SCENE_FILE_ID` change (→ `scenes.fade`) ; page et
adresse d'exécution restent `1` / `engine.address`. Interdit : `jsr` puis `jmp`
— l'instruction d'après le retour serait déjà du moteur. La région `stage`
reste possible avec un appel ordinaire, `scenes.boot` n'y écrivant pas.

**FAIT le 07/09/2026 — la scène de fondu du boot.**
`src/common/flow/bootfade.unit.asm`, fichier `boot.fade` cuit, sans link data,
région `engine` (`$6100`, 191 octets, recouvert par les 5 618 du moteur), scène
`scenes.fade` seule dans sa composition `fade` — le builder exige qu'une scène
dise ce qui est en RAM à côté d'elle, « même si la réponse est cette scène
seule ». `loader.DEFAULT_SCENE_FILE_ID` → `scenes.fade`, page et adresse
d'exécution inchangées. Mesuré sous toje, une capture toutes les dix trames
depuis l'amorçage : menu TO8 (181) → noir à la trame 60 → **noir absolu
jusqu'à la trame 2880** → le title se révèle. Plus aucun bruit de page 0.
`rtype_bench` 7/7, passation title → stage 1 à la même trame qu'avant (4415).

**FAIT le 07/09/2026 — « WIDE DOT presents », la scène entre le fondu et le
moteur.** `src/common/flow/splash.unit.asm` + `boot.splash.a/.b` (les deux
plans BM16 par `<png2bin>`, placeholder généré par
`tools/gen_splash_placeholder.py`) + `boot.splash` (le code, `Pal_splash` par
`<png2pal>`), scène `scenes.splash`, composition `splash` (seule). Chaîne :
`scenes.fade` (à `$6100`) saute dans `scene.load(scenes.splash)` avec
`engine.address` empilé → le splash prend la même place, monte la page 3 à
l'écran, pose le mode BM16, fondu d'entrée du noir vers `Pal_splash`
(`palette.fade.to`, X = palette cible), puis saute dans `scene.load(scenes.boot)`
avec `engine.address` empilé → le moteur. L'image reste pendant tout le
chargement ; le title la noircit et se révèle.

Ce qu'il a fallu régler, et qui vaut pour la suite du §8 :
- **la page 3 se déclare en vue cartouche** : deux `<region>` `framebuffer.3.form`
  (`$0000`) et `.color` (`$2000`) remplacent les `<reserved>` ($C000/$A000
  désigneraient la fenêtre DATA, celle du loader : refusé). Le jeu y dessine
  comme avant ; la page 2 garde ses `reserved`. `png2bin plane="0"` → forme
  (position `$0000`), `plane="1"` → couleur (`$2000`) — vérifié à l'écran ;
- **le mode vidéo** : la machine est encore en COL40 au boot, le splash pose
  `_gfxmode.setBM16` (le piège de `migration/video-mode.md`) ;
- **l'index 0 d'un PNG est la transparence** pour toute la chaîne (`png2pal`
  part de l'index 1, `png2bin` décale d'un cran) : un écran plein n'utilise
  que les index 1 à 16, index 1 = noir = entrée 0 = la bordure ;
- **`png2bin` veut un PNG à 8 bits par pixel** : PIL sauve 4 bits sous 16
  couleurs, et la soustraction de transparence, faite octet par octet, donne
  `$11 → $10` sur chaque paire de pixels de fond — des rayures verticales.
  `im.save(..., bits=8)` ;
- **le répertoire de la disquette 0** a grossi de cinq entrées et débordait
  sur `INDEX1` (piste 0 face 1) : `INDEX1` passe du secteur 10 au 11.

Disque : `boot.fade`, les trois fichiers du splash puis `scenes.boot`, tous en
**piste 8**, la première piste de données, où la tête va de toute façon
(pistes 1 et 2 : les tables de scènes et de lien, lues au boot aussi).
Mesuré : menu (181) → noir à la trame 60 → splash révélé de 130 à 150 → tenu
jusqu'à 3010 → title. Le title n'arrive pas plus tard qu'avant.

**Régression trouvée le même jour, deux causes emboîtées.** `rtype_bench`
tombait à C1 « title never handed over » : après le chargement du stage 1,
le loader tournait sans fin dans `linkData.symbol.search`, sur un compteur
de symboles aberrant, et `stage.main` se résolvait à zéro.

*Première cause, réelle mais pas suffisante — le tas du loader.* Avec le
splash, le répertoire de la disquette 0 passait de six à sept secteurs. Le
tampon de répertoire du loader est dimensionné au plus gros répertoire
(`loader.dir.buffer.SECTORS`) et pris sur son tas (`$C000 − $D0FF + $2000` =
3 841 o) : 256 o de moins pour l'index de lien et les données de lien, sur
un tas qui n'a **pas de marge** (la convergence title → stage 1 lie 24
fichiers, 1 224 o). Correctif : les scènes d'amorçage (fondu, splash) dans
**leur propre répertoire**, id 9, section `INDEX9`, un secteur en piste 0
face 1 ; le répertoire 0 retrouve six secteurs. Le splash remonte le
répertoire 0 (`loader.dir.load`) avant `scene.load(scenes.boot)`, le loader
lit la scène par défaut dans les entrées du répertoire 9. Le banc restait
rouge.

*Seconde cause, celle qui comptait — `tlsf.realloc`.* L'index de lien
grandit par `tlsf.realloc` (8 → 16 → 24 slots). `tlsf.realloc.do` libère
l'ancien bloc **avant** d'appeler `malloc` — à dessein, pour que le bloc
puisse revenir fusionné avec ses voisins libres quand rien d'autre ne
convient. Libéré, l'index fusionnait avec le trou libre qui le précédait
(les tables de scènes du fondu et du splash, allouées puis libérées en tête
du tas — c'est ce que le splash a changé), `malloc` rendait ce bloc
fusionné, 108 octets plus bas, et le **découpait** : l'en-tête du reste et
ses liens de liste libre étaient écrits au milieu des slots pas encore
copiés. Lu à l'index : le slot 11 (`stage1.endstage`) valait
`FF FFFF FF 3C5D D71D`, un en-tête de bloc libre. Aucune erreur TLSF, rien
dans le bloc de log.

Correctif retenu (décision auteur : l'ordre free/malloc reste, pour la
pointe mémoire) dans `engine/memory/malloc/tlsf-realloc.asm` : une
**garde** sur le point de coupe. Le découpage de `malloc` se fait à
`données + demande brute`, donc l'adresse est connue avant l'appel : si le
bloc fusionné commence avant les anciennes données et que la coupe tombe
dedans, les 8 octets sont sauvés et remis après la copie, quoi que `malloc`
décide. Une comparaison dans le cas courant, une quarantaine de cycles en
cas de fusion, 27 octets de code. Au passage, un bloc de 4 octets déplacé
perdait ses 4 octets (le branchement de « rien à copier » sautait aussi
leur restauration). Tests unitaires `tlsf.ut.realloc.merge` (coupe dans les
données, coupe dans le trou, bloc de 4 octets) : piège sur l'ancien code,
vert sur le nouveau ; `examples/tlsf-ut` vert, `loader-ut` 17/17 + T18,
`rtype_bench` **7/7**. Étude des alternatives (malloc d'abord : +140 o de
transitoire au pire moment ; prise du bloc fusionné sans malloc) dans
`engine/memory/malloc/doc/tlsf.md`.

À retenir : **le tas du loader n'a toujours pas de marge**, et le bug de
realloc dormait depuis l'origine — il ne se déclenche que si un trou libre
précède l'index au moment où il grandit, ce que l'ordre des chargements de
r-type n'avait jamais produit avant le splash. Un garde-fou au build (tas
− tampon − lien de l'état le plus gourmand − index) vaudrait toujours la
peine.
