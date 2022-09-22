/[readme]/[build-a-game]/package-absolute

# Package: absolute

## Description

An absolute package defines a set of code and data that can be loaded together in ram at a specific address, the one that was used at assembly stage.

To be able to resolve page id of a specific resource in the package, a [runtime link][runtime-link] is opered after the loading stage.

## File structure

**package.xml**

    <package id="0" name="main" type="absolute" compression="zx0" org="$6100">
        <asm>src/hello-world/main.asm</asm>
    </package>

## Runtime usage

If the relocatable package is loaded in a commutable memory :

            lda   #main  ; package id
            ldb   #4     ; page id
            jsr   LoadAbsolutePackage

If the relocatable package is loaded in the non-commutable memory :

            lda   #main  ; package id
            jsr   LoadAbsolutePackage_nc

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

### org
---

This parameter sets the package absolute origin address.

It is used :
- to assemble the code at an absolute address
- to know where the package should be loaded at runtime

The value should be expressed in hexadecimal.

### asm and bin files
----

The package contains files, declared into asm or bin tags :
- asm files will be assembled, linked and included as binaries into the package.
- bin files will be included in the package.

The path of each file must be relative to the game project base directory.  

Adding an "equ" parameter to the asm or bin tag will tell the builder to automatically generate two equates, to be able to reference address and page for this resource. Those equates will be generated in a single file for all the project, this file will be overwrite at each build.

ex :

        <asm name="hello">src/hello-world/main.asm</asm>

will produce those equates:

    pge_hello equ 0
    adr_hello equ <absolute address>

The pge_ equate is involved in [runtime link][runtime-link]
At runtime the linker will add to the pge_ value, the one used to load the package.

Those equates are global, it is recommended to prefix the name with the package name for multiple package projects.

[package-relocatable]: package-relocatable.md
[package-absolute]: package-absolute.md
[package-multi-page]: package-multi-page.md

[readme]: ../readme.md
[build-a-game]: build-a-game.md