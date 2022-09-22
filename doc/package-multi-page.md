
/[readme]/[build-a-game]/package-multi-page

# Package: multi-page

## Description

A multi-page package defines a set of code and data that can be loaded together in ram in a continuous page range.  
At build stage, .asm and .bin files will be automatically rearranged to fill ram pages with the least amount of lost space (Knapsack problem).

At runtime, the package will be loaded at the desired page in ram.
To be able to resolve page id of a specific resource in the package, a [runtime link][runtime-link] is opered after the loading stage.

Here is an illustration of a "3 page" package loaded to page 5 at runtime:

![package-element][package-element]

As the package spread over multiple pages, the package can only be relocated in different pages, not at different addresses.

## File structure

**package.xml**

    <package id="1" name="pkg_gfx" type="multi-page" compression="zx0" ram="$0000-3FFF" org-offset="$0" cluster-size="$2000">
        <asm name="obj01">src/gfx/object/obj01/obj01.asm</asm>
        <asm name="obj02">src/gfx/object/obj02/obj02.asm</asm>
        <asm name="obj03">src/gfx/object/obj03/obj03.asm</asm>
        <bin name="gfx01">src/gfx/object/obj01/gfx01.bin</bin>
    </package>

## Runtime usage

            lda   #pkg_gfx ; package id
            ldb   #5       ; page id
            jsr   LoadMultiPagePackage

## Parameters
### id
---

The package id is manually set and must be unique in your project.
This id is used when you request the loading at runtime.

### name
---

The name must be unique in your project. It can be used as an symbol instead of the [id](#id).

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

### ram
---

The ram parameter is a range expressed in hexadecimal with a hyphen as separator. This value is the expected running location range for the code.

The parameter is used to :
- set the destination location in the package index.  
- give the destination page size that is used to split the package into pages.

### org-offset
---

This parameter sets the package origin address inside the page. This value is an offset of the package ram address.

It is used :
- to assemble the code at an absolute address
- to know where the package should be loaded at runtime

The value should be expressed in hexadecimal.

### cluster-size
---

The cluster size allows you to load a page in smaller parts than a whole page.  
The value should be expressed in hexadecimal.

Use case with the TO8 Thomson :

There is a distortion between RAM locations in the TO8 memory management.  
Here is the correspondence between the two locations :  
cartridge|data
-|-
$0000-$1FFF|$C000-DFFF
$2000-$3FFF|$A000-BFFF

Builder strategy
- the package is builded in a 16KiB space :  

        ram="$0000-3FFF"

- and clustered in 8KiB :

        cluster-size="$2000"

- the builder will write an index with two 8KiB entries for the loader

Loader strategy
- the loader will handle address translation and invert the two 8KiB bank, based on destination provided by the index

### asm and bin files
----

The package contains files, declared into asm or bin tags :
- asm files will be assembled, linked and included as binaries into the package.
- bin files will be included in the package.

The path of each file must be relative to the game project base directory.  

The name parameter is mandatory for asm and bin tags. The builder will generate a symbol that references the page for each resource. For bin tags, the builder will also generate a symbol for the starting address of the bin data.
Those symbols will be generated in a single file for all the project, this file will be overwrite at each build.

ex :

    <asm name="obj01">src/gfx/object/obj01/obj01.asm</asm>
    <bin name="gfx01">src/gfx/object/obj01/gfx01.bin</bin>

will produce those symbols:

    pge_obj01 equ <relative page in package>
    pge_gfx01 equ <relative page in package>
    adr_gfx01 equ <absolute address>

The pge_ symbol is involved in [runtime link][runtime-link]
At runtime the linker will add to the pge_ value, the one used to load the package.
The adr_ symbol is not involved in runtime link, this package is using absolute addressing so this external symbol will be resolved by lwlink at build stage.

Those symbols are global, it is recommended to prefix the name with the package name for multiple package projects.

[runtime-link]: build-a-game.md#runtime-linking
[package-element]: package-element.png
[package-relocatable]: package-relocatable.md
[package-absolute]: package-absolute.md
[package-multi-page]: package-multi-page.md

[readme]: ../readme.md
[build-a-game]: build-a-game.md