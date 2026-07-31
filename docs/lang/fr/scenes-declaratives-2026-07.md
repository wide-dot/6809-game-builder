# Scènes et régions déclaratives — plan de conception (juillet 2026)

Statut : **campagne close le 31/07/2026** — phases A, B, C, D réalisées, plus
l'encodage `%11` automatique et les equates de layout. Corpus 17/17
déclaratif. La doctrine finale (composition vs enchaînements, `bulk`) vit dans
[`modele-regions-2026-07.md`](modele-regions-2026-07.md), la référence
utilisateur dans [`docs/lang/en/scenes.md`](../en/scenes.md). Ce document
reste le journal de conception ; certains paragraphes (§7.3, §12) décrivent
des positions intermédiaires depuis révisées.

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
    Usage majoritaire : des lots de fichiers export-only à (0,0) (link data
    seule, taille nulle — ex. `ym.const`+`sn.const` de sound, les 16 `pad.*`
    du stress test). **Correction du 31/07 : ce n'est PAS le seul usage** —
    `examples/mplus` (to8/mo6-mplus-test) empile 9 fichiers *avec données*
    (jusqu'à 6 Ko) à une destination réelle (page $05, $0000). Voir §12 ;
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

Version d'origine : deux tables manuscrites de 24 et 8 lignes, adresses en dur.
Version déclarative (celle du pilote migré ; `section` est un attribut, comme
sur `direntry` — l'élément `<section>` reste la déclaration de zone du média) :

```xml
<target name="fd">

  <!-- La carte mémoire : les couches du jeu, déclarées une fois.  -->
  <!-- Les tailles sont des budgets (vérifiés en phase B).         -->
  <layout>
    <region name="gamemode"   page="$01" address="$6100" size="$1F00"/>
    <region name="ymm.player" page="$06" address="$0000" size="$0400"/>
    <region name="ymm.data"   page="$06" address="$0400" size="$3C00"/>
    <region name="vgc.player" page="$07" address="$0000" size="$0A80"/>
    <region name="vgc.data"   page="$07" address="$0A80" size="$3580"/>
  </layout>

  <floppydisk model="fd640">
    <directory id="0" ...>
      <!-- ... les direntries de données, déclarés comme aujourd'hui ... -->

      <scene name="scenes.title" section="SCENE" gensource="gen/scenes/title.asm">
        <load name="assets.gm.title"         region="gamemode"/>
        <load name="engine.object.sound.ymm" region="ymm.player"/>
        <load name="engine.object.sound.vgc" region="vgc.player"/>
        <load name="assets.sounds.title.ymm" region="ymm.data"/>
        <load name="assets.sounds.title.vgc" region="vgc.data"/>
        <!-- link data seule (fichiers export-only) : pas de région -->
        <load name="engine.system.to8.sound.ym.const"/>
        <load name="engine.system.to8.sound.sn.const"/>
      </scene>

      <!-- Le « différentiel authoring » du modèle couches/régions :  -->
      <!-- level1 ne recharge que ce qui change. Même région = même   -->
      <!-- destination que title → éviction implicite garantie.       -->
      <scene name="scenes.level1" section="SCENE" gensource="gen/scenes/level1.asm">
        <load name="assets.sounds.level1.ymm" region="ymm.data"/>
        <load name="assets.sounds.level1.vgc" region="vgc.data"/>
      </scene>
    </directory>
  </floppydisk>
</target>
```

Table générée pour `scenes.title` (identique à la manuscrite actuelle) :
un bloc `$4000+5` avec les cinq triplets aux adresses des régions, puis un bloc
`$8000+2` à (0,0) avec les deux ids export-only, puis le marqueur de fin.

### 4.2 Multi-disquette (`examples/loader-ut`, disque 1)

```xml
<scene name="d1.scenes.main" section="SCENE" gensource="gen/scenes/d1-main.asm">
  <load name="d1.marker" region="disk1.marker"/>
</scene>
```

Une scène vit sur sa disquette et le `<layout>` est déclaré au niveau du
target, donc partagé par toutes les disquettes — `disk1.marker` est une région
comme les autres. **État réel après la phase C** : les `<load>` sont résolus
contre les noms du répertoire courant, donc une scène référence les fichiers de
sa propre disquette (c'est le cas de tout le corpus). Le prélude d'equates
inter-disquettes reste une extension possible, non nécessaire aujourd'hui ; le
warning « scène mélangeant plusieurs disquettes » est reporté en phase B.

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
   partiel » documenté. → Non exposé dans la syntaxe. **Mais le corpus s'en
   sert** (§12) : la décision tient pour les scènes qu'on échange, pas pour
   le chargement unique au boot.
4. **Chargements hors scène invisibles.** Le jeu peut appeler
   `loader.file.load` directement ; les régions ne couvrent que le déclaré.
   → Limite documentée ; la discipline projet est de passer par les scènes.
5. **Vérifier la bonne taille.** Le budget région se compare à la taille
   *décompressée* (`dir.entry.sizeu`), pas à la taille sur disque — l'erreur
   serait silencieusement optimiste. Le comportement de décompression en place
   du loader est inchangé (aucune nouvelle contrainte).
6. **TO8 vs MO6.** Les cartes mémoire diffèrent → `<layout>` est déclaré par
   target, pas de partage implicite entre configs.
7. **Prélude inter-disquettes.** ~~Le générateur émet les equates de tout
   fichier référencé.~~ **Revu en phase C** : le générateur réutilise le
   prélude du répertoire courant (le fichier `gensymbols`), donc la portée
   reste celle d'aujourd'hui — une scène référence les fichiers de sa
   disquette. Aucune scène du corpus n'en demande davantage, et s'en tenir là
   a permis de prouver l'identité binaire sans toucher au câblage des equates.
   L'extension (equates de tout fichier référencé, valeur = id **global**)
   reste ouverte si un projet en a besoin.
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

- **Phase A — génération** (le cœur). ✅ **Faite le 31/07/2026.** Specs des
  4 éléments ; `SceneGenerator` (pur, testé unitairement) ; `ScenePlugin`
  écrit `gen/scenes/<nom>.table.asm` et délègue au pipeline direntry
  (`LayoutPlugin` porte les régions dans le contexte, `DirectoryPlugin`
  réserve les ids des scènes et fournit gensymbols + les noms du répertoire).
  Trois contrôles actifs dès la génération : référence inconnue, région
  inconnue/en double, destination région+brute. Pilote : les 2 scènes
  d'`examples/sound` TO8 migrées, **images identiques octet pour octet**,
  validé sous toje (title vérifié en RAM, changement de scène à chaud vers
  level1 vérifié en RAM, loader-ut rejoué 16/16).
- **Phase B — vérifications.** Les 9 contrôles du §6 (génération + passe
  finale) ; tests JUnit sur corpus de configs volontairement cassées (région
  inconnue, chevauchement, budget dépassé, export-only avec région, deux
  fichiers même région…).
- **Phase C — migration complète.** ✅ **Faite le 31/07/2026** (avant la
  phase B, sur décision : migrer d'abord donne de la matière réelle aux
  vérifications). 15 tables migrées sur 17 : `loader-ut` (10, dont le stress
  et la disquette 1), `sound` MO6 (2), `tlsf-ut` TO8+MO6 (2), `mplus-pcm` (1,
  premier usage de la destination brute — le `dummyfile` qui force un
  changement de page). Les 8 images **identiques octet pour octet**, y compris
  après reconstruction complète avec `gen/` effacé ; `loader-ut` rejoué sous
  toje : **16/16**, statut final $0D. Les 15 tables manuscrites sont
  supprimées. Restent manuscrites : les 2 scènes `mplus-test` (§12).
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
3. **Flag « chargée une fois »** : envisagé (`permanent`, après rejet de
   « resident »), implémenté en phase A, puis **RETIRÉ le 31/07** avec la
   doctrine « le builder vérifie une composition, pas les enchaînements »
   (cf. `modele-regions-2026-07.md` §1) : le builder ne fige pas des
   intentions de durée de vie qu'il ne peut pas vérifier.

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

## 12. Limite découverte à la migration (31/07/2026)

Mon relevé initial (§2) affirmait que le corpus n'utilisait `%10` que pour des
lots export-only à (0,0). **C'est faux** : `examples/mplus/to8-mplus-test` et
`mo6-mplus-test` empilent 9 fichiers **avec données réelles** (5994, 1946, 807,
293, 176, 113, 87, 18 octets, plus un export-only) à une destination réelle
(page $05, adresse $0000). C'est exactement l'empilage runtime que la syntaxe
n'expose pas — ces deux scènes restent donc manuscrites, sous la forme
`<direntry>` + table à la main, qui fonctionne toujours.

L'usage est légitime et lisible : « charge-moi ces 9 blocs de données son à la
suite dans la page 5 », sans calculer les adresses à la main ni les recalculer
quand un VGM change de taille. Et le danger que j'ai décrit ne se matérialise
pas ici : cette scène est chargée **une seule fois au boot**
(`loader.DEFAULT_SCENE_FILE_ID`), jamais échangée — donc pas de slot périmé, pas
de relink sur une destination réutilisée.

Le danger est réel pour une scène qu'on **échange** : les destinations dérivent
avec les tailles, l'unload implicite (destination exacte) ne retrouve plus les
slots. La distinction utile n'est donc pas « empilage = interdit » mais
**« empilage = chargement unique »**.

Trois options, à trancher (aucune n'est engagée) :

1. **Statu quo** : ces deux scènes restent manuscrites. Coût : le corpus n'est
   pas homogène, et la doc doit expliquer pourquoi.
2. **Exposer l'empilage avec une garde** : un conteneur `<stack region="...">`
   groupant des `<load>` sans destination propre, **refusé** si la région n'est
   pas `permanent` (donc réservé au chargement unique, là où c'est sûr). C'est
   l'option qui capture l'intention réelle et rend la règle vérifiable. La
   destination de base vient de la région ; le générateur émet le bloc `%10`.
3. **Suivre les tailles dans l'index côté loader** (différé loader) : lève la
   contrainte à la racine, mais change le format de l'index (pas d'index ≠ 8)
   et le coût runtime. Disproportionné pour ce besoin.

Recommandation : **option 2**, en phase B — la garde `permanent` s'appuie sur un
attribut qui existe déjà, et la vérification est exactement celle qui manque.
