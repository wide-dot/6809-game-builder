# lwtools — sources et binaires

L'assembleur 6809 du projet. Les **sources** vivent ici, les **binaires
compilés** dans `toolbox/third-party/bin/<os>/`, comme pour
[`../audio/dpcm`](../audio/dpcm/readme.md).

Les deux sont versionnés, et c'est voulu : un contributeur qui clone doit
pouvoir builder sans rien installer, et un mainteneur doit pouvoir
reconstruire le binaire de sa plateforme sans chasser une archive sur
Internet. Le binaire seul n'est pas reproductible ; la source seule impose
une chaîne de compilation à tout le monde.

## Version

| Plateforme | Version | Architecture | Origine |
|---|---|---|---|
| `bin/macos` | **4.25** | universel (x86_64 + arm64) | compilé depuis `lwtools-4.25/` |
| `bin/win` | 4.22 | x86 | binaire amont |
| `bin/linux` | 4.18 | x86_64 | binaire amont |
| `bin/linux-arm` | 4.18 | arm | binaire amont |

**Minimum requis : 4.22.** En dessous, les labels locaux `@` utilisés dans les
macros de l'engine ne sont pas compris. Le 4.18 de macOS ne le permettait pas
et obligeait chaque poste à installer sa propre copie — c'est ce qui a motivé
le passage à 4.25.

Les autres plateformes restent sur leur binaire amont : `jpackage` et les
compilateurs croisés ne produisent pas d'exécutable Linux ou Windows depuis un
Mac. À reconstruire sur la plateforme cible quand l'occasion se présente.

## Reconstruire (macOS, binaire universel)

Le Makefile amont refuse `-arch` multiple (la génération de dépendances
n'accepte qu'une architecture), donc on compile deux fois et on fusionne :

```bash
cd toolbox/third-party/src/asm/lwtools-4.25
for arch in x86_64 arm64; do
  make clean
  make CC="clang -arch $arch" all lwobjdump
  mkdir -p /tmp/lw/$arch
  cp lwasm/lwasm lwlink/lwlink lwar/lwar lwlink/lwobjdump /tmp/lw/$arch/
done
for t in lwasm lwlink lwar lwobjdump; do
  lipo -create -output ../../../bin/macos/$t /tmp/lw/x86_64/$t /tmp/lw/arm64/$t
done
make clean   # ne pas committer d'artefacts de build
```

`lwobjdump` n'est pas dans la cible par défaut, d'où le `all lwobjdump`.
Vérifier ensuite `lipo -archs` et `--version` sur chaque binaire.

## Comment le build les trouve

`ThirdPartyTools.resolve(...)` (module `util`) cherche, dans l'ordre :
`-D<outil>.path` → variable d'environnement `<OUTIL>` →
`<basedir>/toolbox/third-party/bin/<os>/` → `<basedir>/bin/` (distribution) →
le PATH. `basedir` est posé par le lanceur de la distribution, et par
l'invocation `java -Dbasedir=<racine>` documentée dans le CLAUDE.md.

Aucun shim n'est nécessaire, sur aucune plateforme.

## Licence

lwtools est sous GPLv3 — voir `lwtools-4.25/COPYING` et `lwtools-4.25/GPL3`.
C'est un outil **invoqué** par le build, pas une bibliothèque liée : le code du
projet n'en dérive pas.
