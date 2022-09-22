Build a game
=

## Description

Building a game is the process of assembling all source code of a game and encode the result in a storage media for a dedicated system.

## Systems

The game builder support the following 6809 systems :

system|clock|manufacturer|year
-|-|-|-
to8|1 MHz|Thomson|1986
to8d|1 MHz|Thomson|1987
to9+|1 MHz|Thomson|1986

## Storage media

The builder handle several media types, all are specific to a system or a system familly.

system|storage media|max. size|file extension
-|-|-|-
to8, to8d, to9+|floppy disk|640 KiB|.fd, .hfe
to8, to8d, to9+|[SDDRIVE] (sd card)|16 GiB|.sd
to8, to8d, to9+|[Megarom T.2] (rom)|2 GiB|.rom (loader in .sd)

## Usage

The builder needs an input file that provide :
- target system
- storage media type and name
- the source code for boot and loader
- packages configuration files

**fd.xml**

    <system>to8</system>
    
    <output-file>
        <name>hello-world</name>
        <type>fd</type>
    </output-file>
    
    <asm>
        <boot>engine/system/to8/boot/boot-fd.asm</boot>
        <loader>engine/system/to8/ram/ram-loader-fd.asm</loader>
        <index>package-index.asm</index>
    </asm>
    
    <packages>
        <boot>src/package/hello-world.xml</boot>
        <package>src/package/obj-01.xml</package>
        <package>src/package/obj-02.xml</package>
    </packages>

the boot tag in packages tells the builder wich package to load and execute after the boot sequence.

## Package definition
---

The purpose of a package is to be able to load a group of data and code in RAM by only using an id.

There are three types of packages:
- [relocatable][package-relocatable]
- [absolute][package-absolute]
- [multi-page][package-multi-page]

### Runtime linking
A [multi-page package][package-multi-page] is assembled with absolute addressing, thus the loader will always load a package at the same ram address, but it may be loaded in different ram pages.  

To be able to resolve the page id of each ressource at runtime, a link task is executed after loading all the required packaging in ram. The linker will get the page offset of the ressource and add the page number used to load the package. All references to this variable will then be updated in memory.

The dynamic link will also update page id references to [relocatable][package-relocatable] and [absolute][package-absolute] packages.


[SDDRIVE]: http://dcmoto.free.fr/bricolage/sddrive/index.html
[Megarom T.2]: https://megarom.forler.ch/fr/

[package-relocatable]: package-relocatable.md
[package-absolute]: package-absolute.md
[package-multi-page]: package-multi-page.md