# Revue de code & architecture — builder Java (30/07/2026)

Périmètre : `toolbox/gamebuilder` (core/spi/util), plugins embarqués (directory,
direntry, lwasm, floppydisk, fd/sap/sd, cksumfd640…), plugins de conversion
(vgm2*, pcm, png2pal, phoneme, txt2bas), poms, CI, packaging. Trois passes de
revue croisées. Aucun code modifié.

## Verdict d'ensemble

Le socle est sain dans ses intentions : SPI isolé, plugins ServiceLoader,
pipeline média par sections, load-time linker complet. Trois faiblesses
structurelles le fragilisent : (1) **état statique global** partout (Settings,
LinkSymbols, FileIds, plugins à méthodes statiques) → non-réentrant, non
parallélisable, non testable, et déjà source d'un bug de reproductibilité ;
(2) **double source de vérité** pour l'arithmétique des ids/tailles de
direntries (DirectoryPlugin prédit depuis le XML ce que DirEntryPlugin décide
en émettant) → la classe de bugs la plus dangereuse du projet (index runtime
décalés) ; (3) **zéro test** et un build qui **retourne toujours 0**, même en
échec d'écriture → rien ne protège les invariants.

## Bugs avérés (corruption ou build faux)

| # | Sév. | Où | Quoi |
|---|---|---|---|
| B1 | critique | `DirEntryPlugin.java:74` | Clé de defaults `directory.maxsize` au lieu de `direntry.maxsize` : le garde 16 Ko est **inactif dans tous les projets** ; un direntry > 16384 octets encode une taille tronquée à 14 bits (`:216`) → image silencieusement fausse |
| B2 | critique | `Target.java:66` | `LinkSymbols.clear()` hors de la boucle des targets (contrairement à `FileIds.clear()`) : les ids de symboles dépendent des targets déjà traitées → `-t fd` ≠ `-t sd,fd` pour la même image. Build non reproductible |
| B3 | critique | `SapType.java:6` | `*` au lieu de `+` : le format SAP 2 (40 pistes/128 o.) est invalide. + `Sap.java:42-52` foulée de détection des drives fausse, `Sap.java:105` deux drives non contigus écrivent le même fichier |
| B4 | critique | `LwObject.java:551-609` | `getIntern()` ignore `reloc.flags` : une relocation interne **8 bits** est émise comme intern **16 bits** → le loader écrase l'octet suivant. + extern16 ne filtre pas `$PAGE` (`:688`), résolution silencieuse à 0 |
| B5 | critique | `MainCommand.java:56` + `FdPlugin.java:40`, `SdPlugin.java:55`, `Sap.java:121` | Erreurs d'écriture avalées (`printStackTrace`) et code retour picocli ignoré : **un build cassé sort avec exit 0** |
| B6 | important | `DirectoryPlugin.java:63-86` vs `DirEntryPlugin.java:206-235` | Réservation d'ids (pré-passe XML) et émission réelle des blocs calculées séparément ; ne coïncident que par accident (`hasLinkData` toujours vrai car LinkData émet ≥ 12 octets d'en-têtes). Toute divergence décale tous les fichiers suivants au runtime |
| B7 | important | `FdUtil.java:233-239` | `getIndex()` avec constantes 327680/4096/256 en dur : toute géométrie ≠ 80/16/256 déclarée dans storage.xml écrit au mauvais endroit |
| B8 | important | `LwObject.java` multi-section/multi-objet | Offsets de reloc jamais rebasés lors de la concaténation des sections et des objets — ne tient que par convention (section `constant` vide, objet `label` de 0 octet en tête). **C'est le verrou réel du « group = direntry multi-asm »** : un 2ᵉ objet exportant du code produit des link data fausses |
| B9 | important | `DirEntryPlugin.java:154` | 3ᵉ arg de `Optimizer.optimize` = fenêtre zx0, pas une taille max : on y passe `maxsize`. + `threads=8` en dur, pool contre-productif sur < 16 Ko |
| B10 | mineur (mine) | `DirEntryPlugin.java:220` | `direntry[i++] = (byte)(direntry[i] \| …)` lit l'index déjà incrémenté ; inoffensif aujourd'hui, corrompra l'octet de taille à la première réorganisation |
| B11 | mineur (mine) | `loader.asm:54` | `lsize rmb types.BYTE` alors que le format écrit 2 octets — struct `dir.entry` fausse, sans effet car les champs `l*` ne sont jamais adressés par nom |
| B12 | mineur | `DirEntryDecoder.java:89` | masque `0x3fff` appliqué après le `+1` : l'outil de diagnostic affiche 0 pour un fichier de 16384 — il ment précisément au cas limite |
| B13 | mineur | `Attribute.java:60` | `getIntegerOpt` → NPE si absent (jamais appelé) ; `getBoolean` : tout sauf "true" = false silencieux. Namespaces d'attributs incohérents (`directory.*` vs `direntry.*`, `defines.value`) |
| B14 | mineur | `PluginClassLoader.java:57-60` | `loadClass` retourne `null` au lieu de propager → NPE/NoClassDefFoundError sans le nom de la classe. `SHARED_PACKAGES` en dur (dont `com.caoccao.javet`, reliquat) |
| B15 | mineur | `package/` | `tools-linux-arm.zip` absent de `jar-with-dependencies.xml` → NPE au premier lancement sur Linux ARM ; `Startup.java:66` sans `REPLACE_EXISTING` → relance = crash ; zip-slip non contrôlé ; `createTemporaryDirectory(erase=true)` peut `deleteDirectory(".")` (non appelé — à supprimer) |

## Dépendances & build

- **`phoneme/src/main/resources/openipa/` : une appli Next.js complète vendorisée
  (8,8 Mo, 237 fichiers, `package.json` + `pnpm-lock.yaml` de 2023 avec Next
  13.5.4, sharp, supabase…). Dependabot scanne tous les manifestes : c'est
  l'origine très probable de l'écrasante majorité des 194 alertes** (dont les
  critiques). Le code Java ne lit que `fr.json`/`fr.csv`. Jar phoneme : 7,5 Mo
  au lieu de ~50 Ko.
- **`jython-standalone` 2.7.3 (47 Mo)** en scope compile dans `util/pom.xml`
  → hérité par quasi tous les modules, alors que seul `vgm2vgc` l'utilise
  (scripts Python 2 vendorisés `vgmpacker`). À déplacer dans vgm2vgc, puis à
  réécrire en Java (~LZ4+Huffman, quelques centaines de lignes).
- **Versions en plages ouvertes** (`[3.12.0,)` etc., `pom.xml:20-29`) : build
  non reproductible, Dependabot inopérant, ingestion automatique de toute
  release amont. Seul pin existant : `logback 1.5.3` — précisément vulnérable
  (CVE-2024-12798/12801, corrigés en 1.5.13).
- `java.version=23` vs `release=11` (release gagne) ; CI JDK 11, compile+package
  seulement, aucun test ; pas de `dependabot.yml`.
- `libtiled` global pour un seul fichier hors build ; pile JAXB entière traînée
  pour rien. `commons-beanutils` déclaré sans usage direct.
- **Modules morts à supprimer** : `toolbox/audio/psg`, `toolbox/audio/smps`
  (pom copié de psg, package declaration fausse, ne compile pas),
  `toolbox/graphics/tilemap/tmx-animation-lean` (1 fichier, ne compile pas,
  seul consommateur de libtiled).
- Poms : ~60 lignes appassembler/jar-plugin dupliquées ×11, `maven-jar-plugin`
  2.3.1 (2011), `launch4j` **sans version** (casse sous Maven 4), jars écrits
  hors de `target/` (`plugins/`, non nettoyés par clean).
- **Packaging** : 6 mécanismes empilés (appassembler → 5 assemblies → zips
  dans un jar → really-executable-jar → launch4j → auto-extraction MainProg)
  pour un résultat qu'un zip/tar.gz par plateforme couvrirait, en supprimant
  tout `package/` sauf les descripteurs. jlink inapplicable (URLClassLoader,
  pas de modules).

## Qualité / testabilité

- **Aucun test dans tout le repo** (pas de `src/test`, pas de JUnit).
  Fonctions déjà pures et rentables à tester en premier : `Sap`/`SapType`
  (attrape B3), `Cksumfd640.checksum`, `FdUtil` (placement disque),
  `Interleave`, aller-retour `DirEntryPlugin`→`DirEntryDecoder` (attrape B1,
  B6, B10, B12), `Attribute`. Puis un golden master config→`.fd` versionné.
- Duplication : boucle « instancier les plugins enfants » ×6 ; quadruplet
  Plugin/Factory/Impl ×16 (3 fichiers sur 4 de pur boilerplate) ; `Binary.java`
  ×8 ; `getIntern/getExtern8/getExtern16/getExternPage` = 4× le même corps
  (~290 lignes) — les faire converger corrige B4 au passage ;
  `LinkData.process()` 6 blocs identiques ; 2 PluginLoaders identiques.
- Code mort : `FileIds.allocate()`, `Attribute.getIntegerOpt`, `Fat` (parsée,
  obligatoire, jamais exploitée — et `[sectorperblock]` sans `@` jamais lu),
  `Ext.java`, option `--clean` qui ne fait rien, `LwUtil.countCycles/countSize`
  (regex fausse), `log4j2.xml` livré alors que le projet est sous Logback.
- Perf : `AsmSourceCode` et `LwObject.LogText` en concaténation String O(n²) ;
  fichiers `gen/unnamed/<nanoTime>.asm` jamais nettoyés (non déterministes —
  un hash de contenu serait déduplicant) ; `Optimizer` 8 threads en dur,
  probablement plus lent que 1 sur des entrées < 16 Ko (à mesurer) ;
  assemblage lwasm strictement séquentiel (poste dominant du build) — la
  parallélisation a pour prérequis B2 + tri des ids de symboles.
- Contrats non tenus vs `dynamic-link-data.md` : ids de symboles **non triés
  alphabétiquement** (requis pour les interfaces/instances de groups, et pour
  le déterminisme), unicité des exports non vérifiée au build (le runtime
  prend le premier trouvé).

## Plan d'action recommandé

**Phase 0 — filet de sécurité (1 jour)**
1. Build faillible : propager les IOException, `System.exit(cmdLine.execute())`,
   `Callable<Integer>` (B5).
2. JUnit + 4 tests sur les fonctions pures : SAP, checksum, aller-retour
   direntry encode/décode, Attribute. Golden master `.fd` sur loader-ut.
3. CI : ajouter `mvn test`.

**Phase 1 — bugs de format (1 jour)**
4. B1 (clé maxsize + contrôle dur 14 bits), B3 (SAP), B7 (getIndex dérivé du
   segment), B9 (offsetLimit=32640, threads mesurés), B10, B11, B12, bornes
   manquantes (track≤127, secteurs≤255, dir≤255 secteurs, delta==6).
5. B2 : `LinkSymbols.clear()` par target + `defines.newValues.clear()` +
   tri de `listFiles()`.

**Phase 2 — verrous d'évolution (2-3 jours)**
6. B6 : source unique du calcul de taille d'entrée + assertion croisée
   `somme(tailles émises) == ids réservés × 8`.
7. B4/B8 : factoriser `evalReloc()` dans LwObject (flags, multiplicité,
   `$PAGE`, bornes d'opérateurs), puis **rebaser les offsets multi-section et
   multi-objet** — c'est le déverrouillage réel des groups multi-asm.
8. Tri alphabétique des ids LinkSymbols + unicité des exports (contrat doc,
   prérequis parallélisation et interfaces de groups).

**Phase 3 — hygiène deps/build (1 jour)**
9. Sortir `openipa/` des resources (vérifier le compteur Dependabot après),
   figer toutes les versions, logback ≥ 1.5.13, `dependabot.yml`.
10. Jython → vgm2vgc (6 lignes), supprimer psg/smps/tmx-animation-lean puis
    libtiled+JAXB, pluginManagement racine (jar-plugin 3.4.x, launch4j versionné,
    fix tools-linux-arm).

**Phase 4 — de fond, au fil de l'eau**
11. Objet `BuildContext` (settings, defines, ids, loaders) passé en paramètre —
    supprime l'état statique, ouvre parallélisation et tests d'intégration.
12. Boilerplate SPI : defaults dans `ObjectDataInterface`, `SimpleObjectFactory`,
    fusion des 2 PluginLoaders, `ChildRunner` commun aux 6 conteneurs.
13. Packaging : zip/tar.gz par plateforme, suppression de l'auto-extracteur.
14. Erreurs : hiérarchie d'exceptions + localisation XML (fichier/élément)
    dans les messages d'`Attribute`.
