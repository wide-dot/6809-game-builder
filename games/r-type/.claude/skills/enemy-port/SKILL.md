---
name: enemy-port
description: Portage d'un ennemi R-Type depuis la référence arcade (Ghidra via asm-ark) vers le runtime v2 — extraction de la spec, traduction par la table arcade→v2, patron d'objet, intégration au stage, validation toje. À suivre pour tout ennemi des stages 2-8 sans source v1 (gouger, wick, brood, zoid, outslay, geld, mikun, win, slither, compiler, bosses…).
---

# Porter un ennemi depuis l'arcade — mode opératoire

## Périmètre

Ce skill couvre les ennemis SANS source v1 : la v1 ne portait que le stage 1.
Un ennemi qui a un original v1 suit l'autre voie (readme.md § « Porter un
ennemi » + skill `v1-migration`). Les deux voies convergent sur la même
intégration (unité hôte, ObjID, index, config) — seule la source de vérité
change : ici c'est la base Ghidra arcade, pas un fichier v1.

Fichiers compagnons de ce skill — les lire avant d'écrire une ligne :
- [arcade-to-v2.md](arcade-to-v2.md) — la table de correspondance
  (ObjectRecord ↔ OST, coordonnées, rythme, dégâts, score, SFX, enfants).
- [exemplars.md](exemplars.md) — quel ennemi opérationnel copier selon la
  forme de l'ennemi à porter. NE PAS parcourir tous les objets du repo :
  ce fichier donne le bon exemplaire directement.

## Les sources de vérité, par ordre

1. **La base Ghidra `maincpu`** (arcade, V30/x86 16 bits, code seg `0x40`,
   données seg `0x1000`). **Toute consultation du code arcade passe par le
   MCP `asm-ark`** — jamais par un désassemblage local ou de mémoire :
   - `bridge_ping` puis `bridge_platform_info` en début de session ;
   - la fiche de l'ennemi : `bridge_knowledge_index(system="actor")` — chaque
     ennemi est un subsystem (`enemy_gouger`, `wick`, `enemy_brood`,
     `outslay`, `gomander`…) listant ses routines avec leur rôle ;
   - **la spec est dans les plate comments** : `bridge_annotations(addr)` sur
     chaque membre rend une description complète et agnostique du moteur
     (états, champs `+0xNN`, px/trame, périodes, HP, ids SFX, pointeur de
     score). C'est le cahier des charges — le désassemblage
     (`bridge_listing`) ne sert qu'à vérifier une constante exacte ;
   - les tables de données (seg `0x1000`) : `bridge_data_peek` /
     `bridge_hexdump`.
2. **`re.arcade.r-type`** (projet voisin) : `data/routines.yaml` (adresse
   d'entrée par ennemi), `data/catalog.yaml` (sprites : poses, nb_frames,
   frame_duration, palette, adresses des meta-sprites), et les **exports
   rejouables de `out/`** — `sprites/` (source des `images/original/`),
   `presets/`, `object-wave/`, `tiles/`, `tileset/`, `palette/`,
   `animation/`, `sound/`.
3. **`doc/arcade-combat-reference.md`** — le modèle de dégâts arcade
   (armes, PV, absorption) et **`doc/arcade-scoring-reference.md`** — la
   table des récompenses (`0x86E8 + idx*4`). Les deux sont déjà écrits :
   ne pas re-déduire ce qu'ils établissent.
4. **Le squelette existant** `src/enemies/<nom>/obj.asm` : son en-tête cite
   la routine arcade, l'entité du catalog et le comportement du bestiaire.
   C'est l'ancre — l'implémentation le remplace mais son en-tête s'enrichit
   (voir Conventions).

## Quand l'export amont manque : faire évoluer l'outil, pas copier à la main

`bridge_data_peek`/`bridge_hexdump` servent à INSPECTER une table arcade.
Mais une donnée qui devient une entrée de build ou une table asm committée
doit sortir d'un **export rejouable** — une transcription à la main ne se
rejoue pas et ne se vérifie pas (même philosophie que l'art généré des
exemples et les sorties leanscroll : l'outil et son invocation sont la
source, le fichier n'est que le résultat).

Si l'ennemi à porter a besoin d'une table, d'un sprite ou d'un format que
`out/` ne fournit pas encore, **faire évoluer `re.arcade.r-type`** (Java,
Maven, JDK ≥ 23 ; packages `com.widedot.arcade.rtype.{extractor,catalog,routine}`) :
ajouter l'entrée de catalog ou le décodeur manquant, relancer, consommer
depuis `out/`. Trous connus au 18/08/2026 :
- **gomander** : au catalog mais son moteur de rendu `tile_grid indirect`
  n'est pas décodé par l'extracteur de sprites — à implémenter côté
  extracteur le jour du boss ;
- **bellmite** (5), **bronco** (7), **bydo** (8) : routine identifiée mais
  aucune entrée de catalog ;
- toute nouvelle famille de tables du seg `0x1000` (scripts d'émission,
  recettes de sprites, vélocités…) repérée dans les plates : si elle entre
  dans le jeu, elle mérite son exporteur.

## La démarche en cinq temps

### 1. Extraire la spec
Depuis les plates Ghidra, relever pour l'ennemi : la liste de ses états
(chaque réécriture du tick-handler `+0x00` = un état), les champs `+0xNN`
utilisés et leur rôle, les constantes (vitesses px/trame, périodes en
trames, HP `+0x2F`, pointeur de score `0x86xx`, ids SFX), les tables de
données, et les objets enfants qu'il spawne (un enfant = un objet v2 à part
entière, avec son ObjID). Ne pas oublier les couplages : certains ennemis
lisent l'état d'un autre (ex. outslay lit le mot d'état de gomander).

### 2. Traduire
Appliquer [arcade-to-v2.md](arcade-to-v2.md) : chaque idiome arcade y a son
équivalent v2 et sa règle de conversion (échelle de coordonnées, modèle de
dégâts inversé, score, sons, politique de difficulté…). Ce qui n'a pas
d'entrée dans la table est une décision nouvelle : la prendre, puis
**l'ajouter à la table** — elle sert tous les portages suivants.

### 3. Écrire
Choisir l'exemplaire le plus proche dans [exemplars.md](exemplars.md) et
calquer sa structure. Le patron : `obj.asm` (dispatch `routine,u` →
`Routines`, Init/Live/Delete, AABB, `DisplaySprite`), l'objet vit dans
`src/enemies/<nom>/`, ses enfants (tirs, pontes) dans leur propre
sous-dossier ou `_shared/`.

### 4. Intégrer (checklist)
- [ ] **Images** : PNG convertis dans `src/enemies/<nom>/images/` —
  `images/original/` (sprites arcade par pose) est une référence, jamais une
  entrée de build. Contrainte : la palette du stage = 12 cases communes +
  4 propres (`arcade_to_in.py` mode pal-next) — les sprites du cast doivent
  y tenir.
- [ ] **Config** (`to8.config.xml`) : le cast d'un stage est UN direntry
  (group multi-asm, ex. `stage2.cast` → `src/stages/02/cast.unit.asm`).
  Ajouter `linkdata="LINK"` au `<file>` quand la première implémentation
  réelle arrive, et les blocs `<gfxcomp>`/`<images>` sur le modèle de
  `lib.scant`.
- [ ] **Ids** : `src/stages/NN/objid.const.asm` (id N = ligne N),
  `objid.index.asm` (page + adresse), l'EXPORT dans `cast.unit.asm`.
  Les enfants spawnés à l'exécution ont besoin des trois aussi.
- [ ] **Properties** : `src/enemies/enemies_properties.asm` — les 4 équates
  `<nom>_scoreIdx` / `hitbox_x` / `hitbox_y` / `hitdamage`.
- [ ] **api.asm** : n'y toucher QUE si l'ennemi franchit une frontière
  moteur↔stage nouvelle — chaque nom coûte 4 octets de link data et une
  recherche linéaire au chargement.
- [ ] **RAM** : vérifier que les variables tiennent dans `ext_variables`
  (budget `ext_variables_size`). La carte mémoire est PLEINE — tout besoin
  de page ou d'arène nouvelle se valide avec l'auteur avant d'écrire.

### 5. Valider
- Build : `java -Dbasedir=<racine> -cp "../../repo/*"
  com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml` depuis
  `games/r-type/`.
- Le banc toje du jeu (`ci/toje-bench/`, banc r-type) doit rester vert : les
  témoins `bench.spawns`/`bench.spawnStage` comptent les spawns du cast.
- Vérification visuelle sous toje (skills `toje-boot` / `toje-shot`) : le
  comportement se compare aux plates Ghidra (trajectoire, cadence, mort) et,
  au besoin, à MAME côté arcade.
- Les timestamps de wave sont ceux de l'arcade : un ennemi implémenté doit
  apparaître au même moment de jeu qu'en arcade (horloge `frame.gameCount`).

## Conventions d'écriture

- **Citer l'arcade dans le code** : au-dessus d'une séquence traduite, la
  ligne arcade en commentaire (`; 6fb2 MOV byte ptr [SI+0x2f],0xa`) — c'est
  le style maison de tabrok/scant, et ce qui rend le diff de comportement
  auditable. Les décisions correctives se journalisent en `; FIX #n :`.
- **L'en-tête du fichier est la fiche de portage** : adresses arcade de
  chaque routine/état, constantes converties (avec la valeur arcade en
  regard), écarts assumés. Le squelette en donne le début, l'implémentation
  le complète.
- **Ce qui est abandonné se voit** : un appel arcade sans équivalent v2
  (palette par objet, table de difficulté) reste en commentaire à sa place,
  comme dans les ports v1.
- Une table de données arcade importée se nomme par son adresse
  (`18db0_preset-y.asm`) et vit dans `src/common/lib/presets/` si elle est
  partagée, dans le dossier de l'ennemi sinon — et elle vient d'un export
  `out/` de re.arcade.r-type (voir « Quand l'export amont manque »), pas
  d'une recopie de hexdump.
