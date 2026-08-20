# Le pilotage caméra du battleship (stage 3 arcade) — analyse pour le portage mscroll

20/08/2026. Sources : base Ghidra `maincpu` via asm-ark (adresses citées),
octets intégrés depuis `re.arcade.r-type/out/rom/maincpu.bin`. Deux erreurs
des plate comments corrigées par lecture du code (§2). Objectif : décider
comment porter le pilotage de la couche battleship sur mscroll v2.

## 1. L'architecture arcade — un objet de wave qui confisque le scroll

Le vaisseau est un **objet ordinaire du système d'acteurs, instancié par la
wave globale** comme n'importe quel ennemi : `create_warship` (0x40:c46e),
priorité 0xff00 (la plus haute du jeu), spawné au temps de wave $0100 — notre
export de wave stage 3 contient déjà la ligne
(`$01,$00,ObjID_warship_core,$00,$00`, commentée dans
`games/r-type-overlay/src/stages/03/wave.asm`).

Son tick maître (`tick_warship_master`, 0x40:c4bc) fait tout, chaque trame :

1. **Confisque le scroll global** : il écrit les vitesses du segment courant
   de son script dans les registres de vitesse de la couche background
   (`[0x2EF4]` = X, `[0x2EF8]` = Y). Le moteur de scroll générique
   (`auto_scroll`, 0x40:0467) intègre ces vitesses en 8.8 dans les caméras
   de couche — le vaisseau ne bouge jamais la caméra lui-même, il pilote des
   consignes de vitesse.
2. **Se colle à sa couche** : il ajoute à sa propre position les deltas
   par-trame que le moteur de scroll dérive (`[0x2ED4]`/`[0x2ED6]`) — tout
   l'arbre d'objets (tourelles, réacteurs…) suit la carte du vaisseau.
3. **Fait avancer le script de spawn positionnel** (`warship_scrolling_spawner`,
   0x40:c61f) : 68 entrées de 10 octets (`0x1000:6ce0`), déclenchées par
   seuil sur le **scroll horizontal accumulé** (16..641 px) — chaque entrée
   pose une sous-partie du vaisseau (27) ou un ennemi externe (~40).
4. **Cadence la chorégraphie** : décrémente le compteur du segment ; à zéro,
   `warship_inner_script_step` (0x40:c5f8) charge l'entrée suivante ;
   fin de script (octet 3 = 0x80) → fade-out → init du stage 4.

## 2. Le script de chorégraphie (0x1000:6f8a) — mesuré

**296 entrées de 3 octets (888 o)**, terminées par octet3 = 0x80.

Format d'une entrée — ATTENTION, les plates Ghidra inversent les axes, le
code du tick (c4e1 : `[+0x20]` → 0x2EF4 ; c4f5 : `[+0x22]` → 0x2EF8) et le
step (octet 0 → `[+0x22]`, octet 1 → `[+0x20]`) sont formels :

| Octet | Rôle | Unité |
|---|---|---|
| 0 | vitesse **Y** de la couche (signée) | 1/16 px/trame (le tick fait `<<4` vers un accumulateur 8.8) |
| 1 | vitesse **X** de la couche (signée) | idem |
| 2 | durée du segment, ou 0x80 = fin | trames vidéo (55 Hz) |

Vitesses observées : ±4 max sur les deux axes = **±0,25 px/trame** — une
chorégraphie lente et majestueuse, très en deçà des vitesses validées au
banc mscroll.

Intégration exacte (script complet, axes corrigés) :

- **Durée totale : 9 280 trames ≈ 2 min 49 s** à 55 Hz.
- **X : course 0 → ~760 px arcade** (net +740, le vaisseau défile vers la
  gauche — cohérent avec les seuils de spawn 16..641).
- **Y : excursion [−50..+88] px** autour de l'ancrage (les passages
  dessus/dessous la coque).

La couche background arcade wrappe verticalement sur 512 px et **ne streame
des tuiles qu'en X** (la pompe `[0x2EEA]` n'est battue que par les
franchissements de 64 px horizontaux) : la carte virtuelle du vaisseau est
longue horizontalement, haute d'au plus 512 px, et le wrap vertical est
invisible (du ciel au-dessus et en dessous). C'est **exactement le modèle
mscroll** : feed horizontal par colonnes, wrap vertical mod hauteur.

## 3. Dimensions v2 (échelles 0.375 / 0.75 d'arcade-to-v2.md)

| Grandeur | Arcade | v2 |
|---|---|---|
| Carte virtuelle, largeur | ~760 + 384 (écran) ≈ 1150 px | **≈ 432 px** (54 colonnes de 8) |
| Carte, hauteur | 512 px (wrap) | **384 px** (24 rangées de 16, wrap ✓) |
| Vitesse X max | 0,25 px/trame | 8.8 : `vx_arcade × 6` (≈ $0018 pour ±4) |
| Vitesse Y max | 0,25 px/trame | 8.8 : `vy_arcade × 12`, **signe inversé** (axe Y arcade vers le haut) |
| Durées | trames 55 Hz | inchangées (convention actée : comptes gardés tels quels) |

Tout tient largement dans les limites mscroll (≤ 2048 px de large, ≤ 4080 de
haut, vitesses sous-pixel gérées par les accumulateurs 8.8).

## 4. Correspondance v2 — ce que devient chaque pièce

| Arcade | v2 |
|---|---|
| Entrée de wave → `create_warship` | Entrée de wave stage 3 → `ObjID_warship_core` (déjà exportée) — **aucun mécanisme d'instanciation spécifique stage 3** |
| `tick_warship_master` | Objet pilote du cast stage 3 (code paginé avec le stage, patron enemy-port) |
| Écriture de `[0x2EF4]/[0x2EF8]` chaque trame | Écriture de `mscroll.camera.speedx`/`speed` **au changement de segment seulement** (mscroll intègre, compensation frame-drop incluse) |
| `auto_scroll` (intégration 8.8) | `mscroll.move` (existant) |
| Position du maître collée aux deltas de couche | `mscroll.camera.x/y` EST la position — le pilote la lit au lieu de l'intégrer |
| Script interne 296×3 | Table convertie générée par un **exporteur re.arcade.r-type** (règle du rejouable), dans le pageset stage 3 |
| Script de spawn 68×10 à seuil de scroll | Table + marcheur à seuil sur `mscroll.camera.x` (phase 2 : les 27 parties = campagne enemy-port à part) |
| Fin de script → fade → stage 4 | Fin de table → séquence de fin de stage v2 |

## 5. Points de décision — ARBITRÉS par l'auteur (20/08/2026)

1. **mscroll devient RÉSIDENT, financé par la demi-page 0.** Depuis le
   passage en overlay, $4000-$5FFF (les cellules de backup du
   background-erase, page $00) n'a plus d'usager : la zone réservée saute,
   le pool d'objets s'y déplace et passe à **60 slots dynamiques + 3 slots
   d'armement statiques** (63 × 117 = 7 371 o, tient dans les 8 Ko). La
   page 1 récupère ~5 Ko : mscroll permanent + la zone par-stage regagne de
   la place. **Préalable vérifié et corrigé** : `_gfxlock.on` posait PRC
   bit 0 sur la parité buffer à chaque boucle (la demi-page alternait — un
   OST n'y aurait existé qu'une trame sur deux) ; sous `OverlayMode` le bit
   est désormais épinglé une fois dans `_gfxlock.init` (gfxlock.macro.asm,
   écart au manifest).
2. **Hauteur de bande : 180 lignes** (le viewport r-type), positionnée dans
   le masque HUD existant, **+1 ligne trash cachée en haut** (le masque haut
   la couvre) → BUFFER_LINES = 181.
3. **Nuages = tilemap de stage ordinaire** (DrawTiles), transparence par la
   convention existante `tools/sky_transparent.py` : blocs de **3×6 px**
   (l'équivalent TO8 d'une tuile arcade 8×8) entièrement à l'index 1 →
   index 0 transparent. Les deux plans du stage 3 sont déjà exportés
   (`out/tiles/level3_f.png` nuages, `level3_b.png` battleship, 3072×240).
4. **Ordre de rendu spécifique : mscroll AVANT la tilemap** — battleship en
   fond, tilemap par-dessus, comme l'arcade. Sur les autres stages mscroll
   reste présent mais désactivé (réutilisable plus tard pour des fonds).
5. **Outils faits** dans re.arcade.r-type (`--extract-warship`,
   `extractor/Warship.java`) : `out/warship/warship-camera-script.asm`
   (295 entrées converties 8.8 + stats intégrées), `.csv` d'inspection,
   `warship-spawn-script.asm` (squelette, ObjID à brancher au portage des
   parties) + `.csv`.

## 5bis. Points restants (avant arbitrage)

1. **Où vit mscroll dans la carte mémoire r-type.** Les 2 pages de buffers,
   les tilesets et la carte sont des données de scène par-stage (chargées au
   stage 3 seulement) — mais le **code** mscroll ne peut pas vivre dans une
   page qu'il commute lui-même en espace cartouche (do/move montent les
   buffers là). Résident (~2 Ko de code + ~700 o de variables/caches) ou
   page du main stage 3 si elle n'est pas commutée pendant le rendu — la
   512K est quasi pleine, à voir avec l'auteur (levier connu : la queue de
   $17).
2. **Hauteur de bande** : pleine hauteur playfield ou bande réduite — le
   blast est linéaire en lignes (mesuré ~56 k cycles à 200 lignes), c'est LE
   levier de cadence prévu au M4.
3. **La couche nuages** (le fg arcade pendant le stage 3) : hscroll (bande
   bouclée, l'outil existe), statique, ou rien.
4. **DrawTiles par-dessus** : le plan initial mscroll prévoit le tilemap
   actuel en seconde couche (sol/plafond) — le stage 3 arcade n'a pas de
   terrain fg pendant le combat ; à trancher.
5. **Exporteurs à créer** dans re.arcade.r-type : script interne → table
   .asm convertie ; carte bg virtuelle stage 3 → PNG pour `<mscroll>` ;
   script de spawn → table .asm. (Le PNG passe ensuite par l'élément
   `<mscroll>` du builder, opérationnel depuis le 20/08.)

## 5ter. La table de checkpoint — l'amorce manquante (20/08/2026)

Découverte en enquêtant sur « le vaisseau apparaît trop tard » (6 s arcade
mesurés vidéo contre 24 s v2) : le master ne fait PAS toute l'approche —
**l'entrée de stage sème déjà une vitesse caméra bg**.

`handle_stage_init_event` (0x40:f01b) lit la table de checkpoint à
**0x1000:87FA** (entrées de 14 octets : timestamp, curseur flux fg, curseur
flux bg, vitesse fg, vitesse bg, palette/musique, n° de stage). L'entrée du
stage 3 (cp6) :

| champ | valeur | sens |
|---|---|---|
| timestamp | 0x1F80 | = lvlTimeStart[3], confirme l'ancrage wave |
| bg_params | 0x0528 | curseur flux tuiles bg (base 0x10D68F) |
| **v_bg** | **0x0080** | **0.5 px/trame dès l'entrée du stage** |

Trois verrous qui en découlent :

1. **Le crop v2 est enregistré à l'identique** : 0xD68F + 0x0528 = 0xDBB7 =
   `levelBackgroundLoc[2]` de l'extracteur — le flux du stage 3 démarre
   exactement à la colonne 0 de `level3_b.png`. Caméra 0 = colonne 0 de la
   carte mscroll, aucun offset de recalage. (Format du flux : un
   enregistrement de 10 octets par colonne de 64 px = 5 mots, un par groupe
   8×6 empilé — hauteur 240 = 5×48.)
2. **La chronologie arcade** : autoscroll 0.5 px/trame dès l'entrée ; le
   master spawne à ts 0x2000 (ev 0x5C00 — idx 0x5C de la table de routines
   de wave 0x1B8A3 = 0xc46e, et idx 0x5E = f01b, double confirmation), soit
   256 trames v2 → wave `$01,$00` correcte ; le premier segment du script
   est (8,0,16) = 0.5 px/trame — **le script prolonge l'autoscroll sans
   couture**. Vaisseau à l'écran (caméra 192 px) à t=384 trames = 7,0 s
   arcade, 7,7 s v2 à 50 Hz.
3. **Le correctif v2** est une seule amorce : `mscroll.camera.speedx = $0030`
   ($0080 × 0.375) posée par stage.setup après `mscroll.setup` — le pilote
   écrase ensuite cette vitesse par celles du script, comme le master
   arcade. La wave et le crop ne bougent pas.

## 6. Ce que l'analyse verrouille

- La wave instancie le pilote : **fidèle à l'arcade, rien de spécial à
  inventer** — le pilote est un objet comme un autre, son code est
  stage-3-spécifique comme tout ennemi l'est.
- Le pilotage est un **script de consignes de vitesse par segments** — le
  modèle mscroll (consignes 8.8 + intégration engine) est un sur-ensemble
  direct : le pilote v2 est minuscule (charger un segment, poser deux
  vitesses, décompter, spawner au seuil).
- Les données sont petites : 888 o de chorégraphie + 682 o de spawn script
  avant conversion — négligeables dans le pageset stage 3.
