/[readme]/[build-a-game]/package-relocatable

# Package: relocatable

## Description

A relocatable package defines a set of code and data that can be loaded together in ram at any address.  
The code should not use absolute addressing at all.

To be able to resolve page id and address of a specific resource in the package, a [runtime link][runtime-link] is opered after the loading stage.

## File structure

**package.xml**

    <package id="0" name="pkg_data" type="relocatable" compression="zx0">
        <asm name="code">src/data/code.asm</asm>
        <bin name="data">src/data/data.bin</bin>
    </package>

## Runtime usage

If the relocatable package is loaded in a commutable memory :

            lda   #pkg_data ; package id
            ldb   #4        ; page id
            ldx   #$1000    ; address
            jsr   LoadRelocatablePackage

If the relocatable package is loaded in the non-commutable memory :

            lda   #pkg_data ; package id
            ldx   #$8000    ; address
            jsr   LoadRelocatablePackage_nc

## Parameters
### id
---

The package id is manually set and must be unique in your project.
This id is used when you request the loading at runtime.

### name
---

The name must be unique in your project. It can be used as a symbol instead of the [id](#id).

### type
---

The type can be set between those three values :
- [relocatable][package-relocatable]
- [absolute][package-absolute]
- [multi-page][package-multi-page]

### compression
---
The package content may be compressed or not. The compression is done on a whole page, or by [cluster-size](#cluster-size) if this parameter is set.
When no compression is used, data of each package is padded to a sector size.

value|version|description|direction
-|-|-|-
none|-|uncompressed|-
exo|2|exomizer|backward
zx0|1|zx0|forward

### cluster-size (optional)
---

The cluster size allows you to load data in smaller parts than the whole package size.  
The value should be expressed in hexadecimal.

### asm and bin files
----

The package contains files, declared into asm, bin or fileset tags :
- asm files will be assembled, linked and included as binaries into the package.
- bin files will be included in the package.

The path of each file must be relative to the game project base directory.  

The name parameter is mandatory for asm and bin tags. The builder will generate a symbol that references the page for each resource. For bin tags, the builder will also generate a symbol for the starting address of the bin data.
Those symbols will be generated in a single file for all the project, this file will be overwrite at each build.

ex :

    <asm name="code">src/data/code.asm</asm>
    <bin name="data">src/data/data.bin</bin>

will produce those symbols:

    pge_code equ 0
    pge_data equ 0
    adr_data equ <relative address in package>

The pge_ symbol is involved in [runtime link][runtime-link]
At runtime the linker will add to the pge_ value, the one used to load the package.
The adr_ symbol is not involved in runtime link, multi-page is intended to be absolute code so this external symbol will be resolved by lwlink at build stage.

To be able to reference routines and data inside an asm file (not only the begining of the file), all symbols that are declared with the "export" directive will also produce adr_ symbols. The same link process will be handled at runtime. This mechanism is only applicable to the asm files in relocatable package (other packages use absolute addressing).

Those symbols are global, it is recommended to prefix the name with the package name for multiple package projects.

[runtime-link]: build-a-game.md#runtime-linking
[package-relocatable]: package-relocatable.md
[package-absolute]: package-absolute.md
[package-multi-page]: package-multi-page.md

[readme]: ../readme.md
[build-a-game]: build-a-game.md