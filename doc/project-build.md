/[readme]/project-build

Build a game project
=

## Description

Building a game is the process of assembling all source code of a game and encode the result in a storage media for a dedicated system.

The builder handles the assembly of 6809/6309 asm source code and generates media images.

Produced binaries can be raw or compressed by zx0 and located anywhere on destination media.

### Systems

The game builder support the following 6809 systems :

system|clock|manufacturer|year
-|-|-|-
to8|1 MHz|Thomson|1986
to8d|1 MHz|Thomson|1987
to9+|1 MHz|Thomson|1986

### Storage media

The builder handle several media types, all are specific to a system or a system familly.

system|storage media|max. size|file extension
-|-|-|-
to8, to8d, to9+|floppy disk|640 KiB|.sap, .hfe, .fd
to8, to8d, to9+|[SDDRIVE] (sd card)|16 GiB|.sd
to8, to8d, to9+|[Megarom T.2] (rom)|2 MiB|.rom (loader in .sd)

## Configuration

The builder process targets defined in an xml configuration file:
- if specific targets are requested at build stage, they will be processed in the request order
- if no target are requested, the builder will process all targets in the order of apparition in the configuration file

## target

For each target, you must specify:
- one or more storage
- one or more media

The Builder will process all media definition, build the source code and produce the media image file based on storage definition.

Here is an example:

```xml
<configuration>
    <target name="fd">
        <storage>new-engine/config/storage.xml</storage>
        <media storage="THOMSON FD640K BOOT">
            <entry section="BOOT">new-engine/system/to8/bootloader/filegroup-boot.xml</entry>
            <entry section="LOAD">new-engine/system/to8/bootloader/filegroup-loader.xml</entry>
            <toc section="TOC" symbol="media.toc.0">
                <entry section="DATA" codec="zx0" name="assets.main.game">src/assets/main/filegroup-game.xml</entry>
            </toc>
        </media>
    </target>
</configuration>

```

In this configuration, the builder will produce a floppy disk image, based on the storage profile "THOMSON FD640K BOOT":

- two entry filegroups will be assembled and written to media (filegroup_boot and filegroup-loader).

- one entry filegroup will be assembled as an LW Object file (filegroup-main), and a loader index (Table Of Content) will be generated. Both will be added to media.

A section parameter for each entry and toc tells the builder where to write data on media. The builder will use the storage configuration to resolve sections.

### storage

```xml
<configuration>

    <interleave name="thomson" softskip="2" softskew="4" hardskip="7"/>

    <storage name="THOMSON FD640K BOOT" type="floppydisk" ext=".fd">
        <segment faces="2" tracks="80" sectors="16" sectorSize="256" interleave="thomson"/>
        <section name="BOOT"  face="0" track="0" sector="1"/>
        <section name="LOAD"  face="0" track="0" sector="2"/>
        <section name="SCENE" face="0" track="0" sector="9"/>
        <section name="TOC"   face="1" track="0" sector="1"/>
        <section name="DATA"  face="0" track="1" sector="1"/>
    </storage>

</configuration>
```

### entry

An entry defines a group of source code or data that will be assembled to a LW object.
The builder will generate metadata for the load time linker.

### filegroup

A filegroup is defined by a name and hold a list of asm files or other filegroups.
```xml
<configuration>
    <filegroup name="assets.main.game">
        <asm>game.asm</asm>
    </filegroup>
</configuration>
```

### table of content (toc)

The buider is able to generate many file indexes called TOC (for Table Of Content). Each TOC is referenced by a symbol that is used to load the TOC to RAM before running the loader.

The section parameter defines where the data must be stored to media.
```xml
<toc section="TOC" symbol="media.toc.0">
    <entry ...>...</entry>
    ...
</toc>
```
The builder will produce the toc as an asm file and a bin file named after the symbol.

Ex : symbol="media.toc.0" will produce data in "media/toc/0.asm" and "media/toc/0.bin"

### Load time linker metadata

The builder is also able to produce binaries that will be load time linked, it allows you to load your code or data anywhere on RAM.
This runtime link is based on LWASM object output information that is generated for each "entry" spcified in the builder configuration file (not only the toc entrie, all entries).

***todo***


## Usage

Process all configuration files located in a directory :

`gamebuilder -d /mydir/newproject`

Process a specific configuration file :

`gamebuilder -f /mydir/newproject/config.xml`

These two commands will process all target, if you want to build a specific target, you must add the -t option :

`gamebuilder -f /mydir/newproject/config.xml -t fd`

You can also build a list a targets, by specifying a comma separated list of targets :

`gamebuilder -f /mydir/newproject/config.xml -t fd,t2`

Additionnal parameters :

`    -v (verbose mode, output detailled logs and working files)`

`    -c (clean build)`


---------------------------
WORK IN PROGRESS

ADDITIONNAL NOTES ON LOAD TIME LINKER DATA

```linker.entry.page 04 ; [page]
linker.entry.addr 0C00 ; [address]
linker.entry.size equ 3 ; allocated space for array is based on used defined equate (2+linker.entry.size*10)
(04 0C00) 0003 ; [nb of elements]
0000 04 0000 03 0100 ; [entry:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
0000 04 123C 03 0200 ; [entry:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
0000 05 2F10 03 0300 ; [entry:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
...
```

page and address is updated at load time by the file loader

[SDDRIVE]: http://dcmoto.free.fr/bricolage/sddrive/index.html
[Megarom T.2]: https://megarom.forler.ch/fr/

[readme]: ../readme.md
[build-a-game]: build-a-game.md