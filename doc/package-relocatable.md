/[readme]/[build-a-game]/package-relocatable

# Package: relocatable

## Description

A relocatable package defines a set of code and data that can be loaded together in ram at any address.  
The code should not use absolute addressing at all.

To be able to resolve page id and address of a specific resource in the package, a [runtime link][runtime-link] is opered after the loading stage.

## File structure

**package.xml**

    <package id="0" name="pkg_data" type="relocatable" compression="zx0">
        <asm>src/data/code.asm</asm>
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

The name must be unique in your project. It can be used as an equate instead of the [id](#id).

### type
---

The type can be set between those three values :
- [relocatable][package-relocatable]
- [absolute][package-absolute]
- [multi-page][package-multi-page]

### compression
---
The package content may be compressed or not. The compression is done on a whole page, or by [cluster-size](#cluster-size) if this parameter is set.
When no compression is set (none), data is rearranged to be loaded by stackblast copy, the fastest available copy method.

value|version|description|direction
-|-|-|-
none|1|stack blast copy (preprocessed data)|backward
exo|2|exomizer|backward
zx0|1|zx0|forward

### cluster-size (optional)
---

The cluster size allows you to load data in smaller parts than the whole package size.  
The value should be expressed in hexadecimal.

### asm and bin files
----

The package contains files, declared into asm or bin tags :
- asm files will be assembled, linked and included as binaries into the package.
- bin files will be included in the package.

The path of each file must be relative to the game project base directory.  

Adding an "equ" parameter to the asm or bin tag will tell the builder to automatically generate two equates, to be able to reference address and page for this resource. Those equates will be generated in a single file for all the project, this file will be overwrite at each build.

ex :

        <bin name="data">src/data/data.bin</bin>

will produce those equates:

    pge_data equ 0
    adr_data equ <relative address>

The pge_ and adr_ equates are involved in [runtime link][runtime-link].  
At runtime the linker will add to those values, the one used to load the package.

To be able to reference routines and data inside an asm file (not only the begining of the file), all symbols that are declared with the "export" directive will also produce pge_ and adr_ equates. The same link process will be handled at runtime.

Those equates are global, it is recommended to prefix the name with the package name for multiple package projects.

[package-relocatable]: package-relocatable.md
[package-absolute]: package-absolute.md
[package-multi-page]: package-multi-page.md

[readme]: ../readme.md
[build-a-game]: build-a-game.md