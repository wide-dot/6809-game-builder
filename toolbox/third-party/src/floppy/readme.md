# HxCFloppyEmulator — sources et binaires

`hxcfe` convertit une image disquette brute en `.hfe`, le format lu par les
émulateurs de lecteur HxC. C'est l'outil derrière l'élément `<hfe/>` du
config.xml.

Même règle que [lwtools](../asm/readme.md) : **sources et binaires versionnés**.
Le binaire seul n'est pas reproductible, la source seule imposerait une chaîne
de compilation à tout contributeur.

## Origine

- Amont : <https://github.com/jfdelnero/HxCFloppyEmulator>
- Commit vendorisé : **`b1eee4cd73391ceaf2ad4ac57e28bf11c91333ba`** (2026-07-23)
- Version : **2.16.15.2**
- Licence : **GPLv3** (`HxCFloppyEmulator/*/COPYING`). Outil **invoqué** par le
  build, pas une bibliothèque liée : le code du projet n'en dérive pas.

## Ce qui est vendorisé, et ce qui ne l'est pas

Seul ce qu'il faut pour construire l'outil en ligne de commande :

| Vendorisé | Écarté | Pourquoi |
|---|---|---|
| `build/`, `libhxcadaptor/`, `libhxcfe/`, `libusbhxcfe/`, `HxCFloppyEmulator_cmdline/` | `HxCFloppyEmulator_software/` (4,5 Mo, GUI FLTK) | on n'utilise que la CLI |
| | `tests/` (1,9 Mo), `doc/` (552 Ko) | non nécessaires au build |

32 Mo sur disque, ~6 Mo dans l'historique git (le gros est du XML, qui
compresse bien) : `libhxcfe/sources/xml_disk` (15 Mo de définitions de
formats, **compilées en en-têtes** par le Makefile — pas élagables sans
amputer les formats reconnus) et `thirdpartylibs` (12 Mo, zlib + expat
embarqués par l'amont).

**Conséquence de l'élagage** : la cible `all` du Makefile amont référence la
GUI, absente ici. Construire les cibles explicitement (voir ci-dessous).

L'arbre est un miroir fidèle des fichiers **suivis par l'amont** au commit
ci-dessus (obtenu par `git archive`, pas par une copie de répertoire de
travail : le `make clean` amont laisse des exécutables et des en-têtes
générés). Il contient donc aussi ce que l'amont versionne lui-même — 84
en-têtes `data_DiskLayout_*_xml.h` pré-générés et un `libadf.a` Linux. Un seul
fichier a dû être forcé, `libusbhxcfe/sources/win32/d30104.zip` (kit FTDI
D2XX, 31 Ko, nécessaire au build Windows) : la règle `*.zip` de notre
`.gitignore` l'écartait en silence.

## Versions par plateforme

| Plateforme | Version | Architecture | Origine |
|---|---|---|---|
| `bin/macos` | **2.16.15.2** | universel (x86_64 + arm64) | compilé ici, 08/2026 |
| `bin/win` | amont | x86 | binaire amont (`hxcfe.exe` + `libhxcfe.dll`, `libusbhxcfe.dll`, `zlib1.dll`) |
| `bin/linux-arm` | amont | arm | binaire amont |
| `bin/linux` | — | — | **absent** |

## Reconstruire (macOS)

L'amont produit **déjà un binaire universel** sur macOS (`-arch arm64
-arch x86_64` dans ses Makefiles) : rien à faire de particulier.

```bash
cd toolbox/third-party/src/floppy/HxCFloppyEmulator/build
make libhxcfe HxCFloppyEmulator_cmdline

# notre bin/macos est PLAT, alors que l'amont vise une disposition en bundle
# (@rpath → ../Frameworks, ../lib) : il faut pouvoir charger les dylibs
# posées à côté de l'exécutable.
install_name_tool -add_rpath @executable_path hxcfe
codesign -f -s - hxcfe          # obligatoire : modifier le rpath casse la signature

cp hxcfe libhxcfe.dylib libusbhxcfe.dylib ../../../../bin/macos/
make clean                      # ne pas committer d'artefacts de build
```

Les trois fichiers vont ensemble : `hxcfe` ne démarre pas sans ses deux
`.dylib` dans le même répertoire.

Vérifier avec une vraie conversion, pas seulement `--version` :

```bash
toolbox/third-party/bin/macos/hxcfe -finput:<une image>.fd -conv:HXC_HFE -foutput:/tmp/v.hfe
xxd /tmp/v.hfe | head -1     # doit commencer par « HXCPICFE »
```

## Reconstruire (Windows)

Les sources sont là pour ça. L'amont fournit des Makefile MinGW ; suivre son
`readme.md`. Déposer ensuite `hxcfe.exe` et ses DLL dans
`toolbox/third-party/bin/win/`, et mettre à jour le tableau ci-dessus.

## Comment le build le trouve

Par `ThirdPartyTools.resolve("hxcfe")`, comme lwasm : `-Dhxcfe.path` →
variable d'environnement `HXCFE` → `<basedir>/toolbox/third-party/bin/<os>/`
→ `<basedir>/bin/` (distribution) → le PATH.
