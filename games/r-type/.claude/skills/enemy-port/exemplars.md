# Les exemplaires — quel ennemi opérationnel copier

Neuf ennemis tournent (portés de la v1, tous validés sous toje). Ils
encodent le patron v2 et les conventions maison. **Choisir ici le bon
modèle au lieu de parcourir le code de tous les objets** ; les tailles
donnent l'ordre de grandeur de l'effort.

## Le patron minimal — TOUJOURS partir de là

**`src/enemies/pata-pata/obj.asm` (138 l.)** — le canon complet en une page :

- layout `ext_variables` en équates nommées (`AABB_0 equ ext_variables`,
  puis les variables propres) ;
- dispatch `routine,u` → `Routines` (fdb Init / Live / AlreadyDeleted) ;
- Init : position depuis caméra + subtype (preset Y, `_loadFirePreset`),
  `priority,u`, `render_flags`, `_Collision_AddAABB`, script d'anim,
  consommation du `wave_frame_drop` (`moveByScript.runByB`) ;
- Live : `runByFrameDrop`, `tryFoeFire`, test `AABB.p` = 0 → mort,
  recopie `cx`/`cy`, `image_set` depuis `ImageIndex`, `jmp DisplaySprite` ;
- mort : `AwardScore`, spawn d'explosion (`LoadObject_x` +
  `ObjID_explosion`), `_Collision_RemoveAABB`, `DeleteObject`.

## Par forme d'ennemi

| Forme | Exemplaire | Ce qu'on y prend |
|---|---|---|
| Marcheur au sol, ancré terrain, cadence de tir | `tabrok/` (1818 l. + canon) | `terrainCollision`, tir sur horloge (`FIX #5`), style de commentaire arcade, journal `FIX #n`, enfant projectile (`canon.asm` + unité) |
| Tourelle qui vise et spawne des projectiles | `scant/` (528 l. + fire) | `setDirectionTo`, spawn d'enfants (`scantfire`, `emitter_flash`) via `Obj_Index_Page/Address` déclarés EXTERNAL dans l'unité |
| Mouvement circulaire / sinus, trajectoire géométrique | `shell/` (990 l.) | `circleCenter`, `terrainCollision.update`, effaceur dédié (`shelleraser`), `sinus.xlsx` pour dériver une table |
| Poursuite du joueur, réactivité | `cancer/` (746 l.) | bits de direction, degré de réactivité, cap de durée de vie (exemple d'écart assumé `V2-DEVIATION`) |
| Chaîne de segments (serpent) | `p-staff/` (543 l.) | la marche des segments liés — le modèle pour **outslay** |
| Suiveurs par HISTORIQUE du parent | `forcepods/obj_reboundlaser.asm` (953 l.) | LE pattern « un seul interprète, N suiveurs » : le parent seul calcule sa trajectoire (et collisionne) et pousse (x, y, image_set) dans un anneau en plans parallèles (`ALIGN 32`, wrap par `andb`), UNE entrée par TRAME VIDÉO (poussées dans sa boucle de frame drop — l'espacement des suiveurs survit au drop). Un enfant = lire `bufferIndex` du parent, soustraire son retard (`childId*4+6`), masquer, copier trois mots, `DisplaySprite` — ~20 instructions, zéro interprétation. Et il VALIDE son parent avant lecture (`id` + `routine`), ce qui règle le pointeur d'aîné périmé. À réutiliser pour le moveByScript de l'outslay |
| Boss multi-parties | `dobkeratops/` (515 l. + 6 unités) | découpage en unités (jaw/saw/tail/monster/explosion), gestionnaire de queue — le modèle pour **gomander**, plus tard |
| Petit volant simple | `bink/`, `blaster/` | variantes compactes du patron minimal |

Correspondances du cast stage 2 : **gouger** ← tabrok (ancrage
plafond/sol, jaillissement) sur base pata-pata ; **wick** ← l'émetteur est
un objet invisible qui spawne (scant), l'individu est un pata-pata ondulant ;
**brood** ← tourelle fixe + ponte périodique (scant), ses **zoid** sont des
pata-pata-like ; **outslay** ← p-staff.

## Le mobilier partagé (`_shared/` et `common/`)

- `_shared/foefire` — LE projectile ennemi standard (l'arcade « bydo shot ») ;
  `_shared/commonmissile` (+`flame`) — missile ennemi ; `emitter-flash` —
  l'éclat de bouche de tir.
- `src/common/fx/explosion/` — l'explosion générique (`ObjID_explosion`,
  subtypes small/smallx2/…) ; `bossmusic`, `pow`, `checkpoint` sont des
  objets communs déjà en place.
- `src/common/lib/presets/` — les tables arcade importées (nommées par
  adresse) : presets Y, XY, tir, vélocité de tir.
- `src/common/lib/scale.asm` — l'échelle arcade→TO8 en 8.8.

## L'unité hôte et le group du cast

- **Unité individuelle** : `scant/scant.unit.asm` est le modèle — entrée
  exportée EN PREMIER OCTET (code d'abord, tables ensuite, cf.
  `docs/lang/en/migration/unit-entry-point.md`), `INCLUDE api.asm`,
  en-têtes communs, `objid.const.asm` du stage, table de liaison
  `Img_<nom> equ set_<nom>` .
- **Group de cast** (stages 2+) : UN direntry pour tout le cast —
  `src/stages/02/cast.unit.asm` inclut chaque `obj.asm` et exporte chaque
  entrée ; le répertoire disque est la denrée rare, ne pas revenir à un
  direntry par ennemi. Le bouchon `stage2.cast.stub` disparaît membre par
  membre au fil des implémentations (les témoins `bench.spawns` restent
  tant que le banc en a besoin).
- **Images** : `images/` = les PNG convertis que le build lit (déclarés en
  `<images>` sous `<gfxcomp>` dans le config) ; `images/original/` = les
  sprites arcade par pose (`<pose>/<n>_<adresse rom>.png`), référence
  seulement. `mirror="x"` et `shifts=` démultiplient un même PNG.
