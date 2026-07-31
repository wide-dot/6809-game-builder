# Scènes et régions déclaratives — plan de conception (juillet 2026)

Statut : **conception — rien d'implémenté**. Décisions du 31/07 consignées
au §10 (reste à choisir : le nom du flag de région à chargement unique).
Suivi : `TODO.md` à la racine.

## 1. Objectif

Aujourd'hui une scène est une table écrite à la main en assembleur
(`src/scenes/<machine>/<nom>/scene.asm`) : des triplets page/adresse/file-id.
Une page ou une adresse fausse ne produit aucune erreur au build — juste une
corruption mémoire au runtime. Et le modèle « couches/régions à adresses fixes,
le différentiel c'est l'authoring » (cf. `docs/lang/en/groups.md`) repose
entièrement sur la discipline du développeur : rien ne vérifie que deux
variantes d'une même région visent la même destination, ni qu'une scène ne
mord pas sur le résident.

But : déclarer les scènes et les régions dans le config.xml, laisser le builder
**générer** les tables et **vérifier** la cohérence au build, avec des erreurs
fichier:ligne. C'est aussi le socle du futur éditeur graphique : un GUI éditera
ces déclarations, pas de l'asm.

## 2. État des lieux (ce que le code fait réellement)

Constats vérifiés dans `loader.asm` et sur le corpus (`examples/loader-ut`,
`examples/sound`) :

- **Une scène est un direntry ordinaire** (`section="SCENE"`, lwasm
  `format="raw"`, non compressé). `loader.scene.load` la charge dans le pool
  TLSF, l'applique en 3 passes (load disque groupé → décompression → link data),
  relink global, puis libère la table.
- **Trois types de blocs** dans une table (`loader.scene.apply`) :
  - `%01` (`$4000+n`) : n triplets explicites `[page][adresse][file id]` —
    le type standard, utilisé partout pour les fichiers avec données ;
  - `%10` (`$8000+n`) : une destination de base + n file ids, empilés au
    runtime selon la taille de chaque fichier (avec débordement de page).
    **Usage réel constaté : uniquement des lots de fichiers export-only à
    (0,0)** (link data seule, taille nulle — ex. `ym.const`+`sn.const` de
    sound, les 16 `pad.*` du stress test) ;
  - `%11` (`$C000+n`) : ids consécutifs auto-empilés — **jamais utilisé** dans
    le corpus.
- **Le builder génère déjà un prélude d'equates** dans le `gensource` de chaque
  direntry (`data.marker.aa equ 7`…) : les `fdb <file id>` des tables sont
  résolus à l'assemblage, sans link data. Limite actuelle : le prélude ne
  contient que les fichiers **de la disquette courante** — une table manuscrite
  ne peut pas référencer un fichier d'une autre disquette par son nom.
- Les file ids sont **globaux à un target** depuis le 30/07/2026
  (`dir.header.baseId`) : un id identifie un fichier sans ambiguïté entre
  disquettes.
- L'**unload implicite** de l'index de link data ne couvre que la destination
  *exacte* (page+adresse). Un recouvrement partiel laisse un slot périmé que le
  relink global exploiterait — c'est LA contrainte structurante du design.

## 3. Principes de conception

1. **Zéro changement ASM.** Le loader consomme des tables identiques à celles
   d'aujourd'hui. Tout se joue côté builder.
2. **Le déclaratif génère exactement ce qu'on écrit à la main.** Critère de
   migration : chaque scène convertie produit une image **identique octet pour
   octet** à la version manuscrite.
3. **Une région = une destination fixe = un direntry par scène.** Le
   multi-parties se fait par direntry multi-asm (le modèle « group », débloqué
   par la phase 2 de la revue Java, validé par T16). Conséquence structurelle :
   toutes les variantes d'une région atterrissent à la même adresse → l'unload
   implicite fonctionne toujours, le trou du recouvrement partiel est
   inatteignable par construction.
4. **Les types de blocs ne sont jamais authorés : le générateur choisit.**
   Les trois types restent dans le loader (inchangé) mais n'apparaissent pas
   dans la syntaxe — voir §5. L'empilage runtime de fichiers *non vides* reste
   inexprimable (voir pièges §7.3) : ce n'est pas un type qu'on cache, c'est
   une sémantique de placement qu'on exclut.

## 4. Syntaxe proposée

### 4.1 Exemple réaliste : `examples/sound` TO8 (title + level1)

Version actuelle : deux tables manuscrites de 24 et 8 lignes, adresses en dur.
Version déclarative :

```xml
<target name="fd">

  <!-- La carte mémoire : les couches du jeu, déclarées une fois.       -->
  <!-- Les tailles sont des budgets : le build vérifie que chaque       -->
  <!-- variante tient dedans.                                          -->
  <layout>
    <region name="gamemode"   page="1" address="$6100" size="$1F00"/>
    <region name="ymm.player" page="6" address="$0000" size="$0400"/>
    <region name="ymm.data"   page="6" address="$0400" size="$3C00"/>
    <region name="vgc.player" page="7" address="$0000" size="$0A80"/>
    <region name="vgc.data"   page="7" address="$0A80" size="$3580"/>
  </layout>

  <floppydisk model="fd640">
    <directory>
      <section name="SCENE">

        <scene name="scenes.title">
          <load name="assets.gm.title"         region="gamemode"/>
          <load name="engine.object.sound.ymm" region="ymm.player"/>
          <load name="engine.object.sound.vgc" region="vgc.player"/>
          <load name="assets.sounds.title.ymm" region="ymm.data"/>
          <load name="assets.sounds.title.vgc" region="vgc.data"/>
          <!-- link data seule (fichiers export-only) : pas de région -->
          <load name="engine.system.to8.sound.ym.const"/>
          <load name="engine.system.to8.sound.sn.const"/>
        </scene>

        <!-- Le « différentiel authoring » du modèle couches/régions :     -->
        <!-- level1 ne recharge que ce qui change. Même région = même      -->
        <!-- destination que title → éviction implicite propre, garantie.  -->
        <scene name="scenes.level1">
          <load name="assets.gm.level1"         region="gamemode"/>
          <load name="assets.sounds.level1.ymm" region="ymm.data"/>
        </scene>

      </section>
      <!-- ... les direntries de données restent déclarés comme aujourd'hui -->
    </directory>
  </floppydisk>
</target>
```

Table générée pour `scenes.title` (identique à la manuscrite actuelle) :
un bloc `$4000+5` avec les cinq triplets aux adresses des régions, puis un bloc
`$8000+2` à (0,0) avec les deux ids export-only, puis le marqueur de fin.

### 4.2 Multi-disquette (`examples/loader-ut`, disque 1)

```xml
<scene name="d1.scenes.main">
  <load name="d1.marker" region="stress.d1"/>
</scene>
```

Rien de spécial : une scène vit sur sa disquette, ses `<load>` référencent
n'importe quel direntry du target (les ids sont globaux). Le générateur émet
dans le prélude les equates de **tous les fichiers référencés**, y compris
ceux d'autres disquettes — ce que les tables manuscrites ne peuvent pas faire
aujourd'hui. Un *warning* signale une scène qui mélange des fichiers de
plusieurs disquettes (prompts « Insert disk » en plein chargement).

### 4.3 Échappatoire : destination brute

```xml
<scene name="scenes.debug">
  <load name="data.marker.zz" page="$06" address="$1000"/>
</scene>
```

`page`/`address` restent autorisés (migration progressive, cas particuliers) —
sans les garanties des régions. Le validateur émet un warning si une
destination brute chevauche une région déclarée (c'est précisément une
collision qu'on veut voir).

### 4.4 Ce qui n'est PAS authorable

- Deux `<load>` avec région dans la même région d'une même scène : **erreur**.
  Le multi-parties = un direntry multi-asm (group).
- L'empilage runtime (`%10`/`%11`) pour des fichiers non vides : non exposé
  (voir §7.3).
- `region` + `page`/`address` sur le même `<load>` : erreur (l'un ou l'autre).

## 5. Sémantique de génération

- `<scene>` se comporte comme un `<direntry>` : mêmes attributs de base
  (`name`, `section`), et le plugin synthétise en interne le nœud
  `direntry > lwasm(format=raw, gensource=gen/scenes/<nom>.asm) > asm` en
  écrivant d'abord la table dans `gen/scenes/`. On réutilise tel quel le
  pipeline direntry existant (ids, prélude, écriture disquette) — le
  générateur ne fait *que* produire le fichier asm.
- Ordre des entrées = ordre des `<load>` dans le XML. Les `<load>` avec
  destination (région ou brute) forment le bloc `%01` ; les export-only sont
  regroupés, dans leur ordre d'apparition, en un bloc `%10` à (0,0) émis après.
  C'est exactement la structure du corpus (nécessaire à l'identité binaire).
- **Sélection automatique du type de bloc.** Le choix `%01`/`%10` ci-dessus est
  déjà une sélection automatique : destination explicite → `%01`, export-only →
  `%10` (2 octets/fichier au lieu de 5 — écrire (0,0) n fois n'a pas de sens).
  Optimisation ultérieure (post-migration) : émettre `%11` quand les fichiers
  d'un lot export-only ont des ids qui forment exactement la chaîne que le
  loader parcourt (id suivant = id + 1 + flag compressé + flag linké — le
  builder numérote précisément ainsi les direntries déclarés à la suite).
  Gain : un bloc de 7 octets fixes au lieu de 5+2n (les 16 `pad.*` du stress
  test : 37 → 7 octets). Vérifié à chaque build, repli silencieux sur `%10` si
  la chaîne se brise (réordonnancement du config). Sémantiquement identique ;
  activée seulement après la migration, car elle change les octets des tables.
- Le nom du `<load>` est le nom du direntry référencé ; le nom de la scène
  devient lui-même un file id utilisable (charger une scène par
  `ldx #scenes.level1` + `jsr loader.scene.load`, comme aujourd'hui).

## 6. Vérifications au build

À la génération (positions fichier:ligne via SourceMap, toutes les erreurs
d'un coup, comme le Validator) :

1. Chaque `<load name>` référence un direntry existant du target.
2. `<load>` sans région ⇔ direntry export-only (aucune donnée), dans les deux
   sens : un fichier avec données sans destination est une erreur, un fichier
   vide avec région aussi.
3. Une seule `<load>` par région et par scène.
4. `region` inconnue, `region`+`page` simultanés : erreurs.
5. Non-chevauchement des régions entre elles (même page).
6. Nom de scène/direntry = symbole lwasm valide.

En passe finale, une fois tous les direntries construits (les tailles ne sont
connues qu'après build) :

7. Taille **décompressée** de chaque direntry ≤ `size` de sa région (région
   sans `size` : warning « non vérifiée »).
8. Warning : destination brute chevauchant une région déclarée.
9. Warning : scène mélangeant des fichiers de plusieurs disquettes.

La cohérence inter-variantes (toutes les variantes d'une région à la même
destination) n'a **pas besoin d'être vérifiée** : elle est garantie par
construction, la destination est celle de la région.

## 7. Pièges identifiés et parades

1. **Ordre de build vs tailles.** Le prélude d'equates prouve que les ids sont
   pré-assignés, mais les tailles n'existent qu'après build des direntries de
   données. → Les vérifications 7–9 tournent en passe finale, après le build
   du média et avant l'écriture des images ; la génération de la table, elle,
   n'a besoin que des ids et destinations.
2. **Identité binaire pendant la migration.** Le moindre écart d'ordre
   (entrées, blocs) change l'image. → Le générateur reproduit la structure du
   corpus (bloc `%01` puis bloc `%10`), l'ordre XML fait foi, et chaque scène
   migrée est validée image contre image avant de supprimer sa table
   manuscrite.
3. **L'empilage runtime (`%10` non vide, `%11`) est un piège structurel** : la
   destination de chaque fichier dépend de la taille des précédents, donc
   change d'un build à l'autre → destinations non fixes → l'unload implicite
   (destination exacte) ne retrouve plus les slots → link data périmées +
   relink global = corruption différée. C'est exactement le trou « recouvrement
   partiel » documenté. → Non exposé dans la syntaxe. Si un vrai besoin
   apparaît, il faudra d'abord le suivi des tailles dans l'index (différé
   loader).
4. **Chargements hors scène invisibles.** Le jeu peut appeler
   `loader.file.load` directement ; les régions ne couvrent que le déclaré.
   → Limite documentée ; la discipline projet est de passer par les scènes.
5. **Vérifier la bonne taille.** Le budget région se compare à la taille
   *décompressée* (`dir.entry.sizeu`), pas à la taille sur disque — l'erreur
   serait silencieusement optimiste. Le comportement de décompression en place
   du loader est inchangé (aucune nouvelle contrainte).
6. **TO8 vs MO6.** Les cartes mémoire diffèrent → `<layout>` est déclaré par
   target, pas de partage implicite entre configs.
7. **Prélude inter-disquettes.** Les tables manuscrites ne peuvent référencer
   que les fichiers de leur disquette (portée actuelle du prélude). Le
   générateur émet les equates de tout fichier référencé — c'est un *plus*,
   mais la valeur de l'equ doit être l'id **global** (base comprise), pas
   l'index local : à tester explicitement dans loader-ut (une scène disque 0
   référençant un fichier disque 1).
8. **Nouveau vocabulaire = nouveau contrat.** `<layout>`, `<region>`,
   `<scene>`, `<load>` entrent dans les specs (`Handlers`), le Validator les
   couvre automatiquement, et le XSD doit être **régénéré et commité**
   (`-x docs/schema/gamebuilder.xsd`) — sinon les éditeurs signaleront les
   nouveaux éléments comme invalides.
9. **La scène par défaut** (`loader.DEFAULT_SCENE_FILE_ID`) reste un define du
   projet : rien ne change, mais vérifier pendant la migration qu'il pointe
   toujours le bon id (les ids ne bougent pas si l'ordre de déclaration ne
   bouge pas — cf. piège 2).
10. **Nom d'élément.** Tranché le 31/07/2026 : `<load>` (explicite — la ligne
    dit ce qu'elle fait — et sans collision dans les specs actuelles).

## 8. Plan d'exécution

- **Phase A — génération** (le cœur). Specs des 4 éléments ; générateur de
  table (`SceneGenerator`, pur : déclarations → texte asm, testable
  unitairement) ; plugin `<scene>` qui écrit `gen/scenes/<nom>.asm` et délègue
  au pipeline direntry. Pilote : les 2 scènes d'`examples/sound` TO8 migrées,
  **image identique octet pour octet**, exécution vérifiée sous toje
  (changement de scène à chaud title→level1).
- **Phase B — vérifications.** Les 9 contrôles du §6 (génération + passe
  finale) ; tests JUnit sur corpus de configs volontairement cassées (région
  inconnue, chevauchement, budget dépassé, export-only avec région, deux
  fichiers même région…).
- **Phase C — migration complète.** `loader-ut` (10 scènes, dont stress et
  disque 1 — le banc le plus exigeant) et `sound` MO6 ; images identiques ;
  toje 16/16 ; ajout d'un test de référence inter-disquettes dans une table
  générée (piège 7) ; suppression des tables manuscrites.
- **Phase D — documentation.** `groups.md` (lien modèle couches/régions ↔
  syntaxe), `docs/lang/en/scenes.md` (la doc vide existante), XSD régénéré,
  CLAUDE.md, TODO.md.

Chaque phase = un commit, validé par la méthode standard (8 configs
octet pour octet, loader-ut sous toje, JUnit, CI).

## 9. Non-objectifs

- Aucun changement au loader ASM (ni `loadDelta` : abandonné, cf. groups.md).
- Pas d'empilage runtime authorable, pas de `%11`.
- Pas de génération des *appels* de scène côté jeu (le gm garde ses
  `ldx #scenes.x` / `jsr loader.scene.load`).
- Le GUI d'édition : plus tard, sur cette base.

## 10. Décisions (31/07/2026)

1. **`<layout>` conteneur** sous `<target>` : validé.
2. **`<load>`** comme élément enfant de `<scene>` : validé.
3. **Flag « chargée une fois »** : validé sur le principe, mais pas le mot
   `resident` (collision avec la notion de page résidente). Sémantique retenue :
   une région marquée n'accepte qu'**un seul direntry** sur tout le target —
   plusieurs scènes peuvent le recharger (la dédup gère), mais y charger un
   fichier *différent* est une erreur de build. Le flag documente l'intention
   et transforme un écrasement accidentel du player en erreur fichier:ligne.
   Nom à choisir : `permanent` (recommandé — dit la durée de vie),
   `pinned` (épinglée), `locked`, `once`.

## 11. Réflexion : phases de jeu, régions multiples, overlays

Le doute soulevé (« on a plusieurs phases — title, stages — le flag est-il
pertinent ? ») touche le vrai sujet : **le cycle de vie des régions à travers
les phases**.

**Le cas nominal : un layout partagé, des régions réutilisées.** C'est le
pattern d'`examples/sound` (title et level1 se passent le relais dans
`gamemode` et `ymm.data`) et c'est le seul qui soit *gratuit* : même
destination → éviction implicite propre, aucune gestion. La doctrine par
défaut est donc : **les phases partagent le layout, et une région est
précisément le point de passage entre phases**. Dans ce monde, la plupart des
régions sont multi-variantes par nature, et le flag « chargée une fois » ne
concerne que les briques moteur chargées au boot (players, tables) — peu de
régions, mais le flag y est utile justement parce que tout le reste bouge.

**Le cas divergent : des phases aux cartes mémoire différentes** (le title
utilise la page 6 pour un logo plein écran, le jeu y met la tilemap). Deux
régions qui se chevauchent seraient alors *légitimes* — mais notre contrôle
de non-chevauchement les rejette, et surtout **le loader ne suit pas** : les
slots de link data de la phase sortante restent indexés à leurs anciennes
destinations ; au premier relink global, ils patchent la mémoire réutilisée →
corruption différée. Changer de carte mémoire exige donc un **unload explicite
de la phase sortante**, aujourd'hui fichier par fichier.

Deux extensions cohérentes, **différées** jusqu'au besoin réel (le portage
R-Type le dira) :

- *Côté builder* : des groupes d'exclusion — `<region ... overlay="title"/>` —
  deux régions d'overlays différents peuvent se chevaucher, deux régions du
  même overlay non. Le vocabulaire classique des linkers pour exactement ce
  problème.
- *Côté loader* (petit ajout ASM, à chiffrer) : `linkData.unloadAll` (ou un
  unload par plage de pages) pour rendre la transition de phase sûre en un
  appel, au lieu de n appels `linkData.unload`. Ajouté aux différés loader
  dans `TODO.md`.

En attendant, la phase A s'en tient au layout unique et au non-chevauchement
strict : c'est le modèle sûr, et il couvre le corpus entier.
