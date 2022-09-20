Build a game
=


## Package definition
---

The purpose of a package is to be able to load a group of data and code in RAM by only using an id and a destination page. The package content will fill one or more RAM pages. The package can also be loaded in the resident memory, in this case the page number will be ignored by the loader.   
A package defines a set of package element.

**Use case**  
At runtime, the main programm is able to load several packages in RAM.
Here is a use case of package organization in ram during a game :

![package][package]

In this configuration, packages may be loaded in different page locations.
This is the case for the **character 2** package.  

**Dynamic linking**  
A package is assembled with absolute addressing, thus the loader will always load a package at the same ram address, but it may be in a different ram page.  
To be able to resolve the page id of each ressource at runtime, a link task is executed after loading all the required packaging.

## Package element definition
---

A package element is a set of assembly files that will be assembled to make a binary. This binary will be loaded in a countiguous RAM space at runtime.

![package-element][package-element]

## File structure

parameter name|description|sample values
-|-|-
compression|storage compression type|none
cluster-size|maximum uncompressed data size for each loading step (in Bytes)|$2000
location|runtime location in ram (also gives page size)|$0000-$3FFF
org|start location inside the first page|$100
files|a list of .asm files|src/levels/lvl01.asm  src/ennemies/ennemy01.asm

### Compression
---

value|version|description|direction
-|-|-|-
none|1|stack blast copy (preprocessed data)|backward
exo|2|exomizer|backward
zx0|1|zx0|forward

### Cluster size
---

The cluster size allows you to load a page in several steps.   
Here are some use cases :

**Thomson TO8**

There is a distortion between RAM locations in the TO8 memory management.  
Here is the correspondence between the two locations :  
cartridge|data
-|-
$0000-$1FFF|$C000-DFFF
$2000-$3FFF|$A000-BFFF

Loader strategy
- the loader set compressed data in the cartridge space (whether it's a ROM or RAM page).  
- data is then uncompressed to his destination in the data location.  
- by clustering the 16KiB pages defined in the packages in two parts (8KiB), it allows the loader to send the data in the appropriate location.

Package configuration file :  

    compression=zx0
    cluster-size=$2000
    location=$0000;$3FFF
    org=$0

**Thomson MO5**

The buffer used to store compressed data is located in $0000-$1FFF (8KiB).
It should be enought to fill a 16KiB page, as the usual compression ratio for exomizer or zx0 is 1:3
However, placing also the loader and the package index in this location lower the available space. It may be needed to use 8KiB cluster size.

Package configuration file :  

    compression=zx0
    cluster-size=$2000
    location=$B000;$EFFF
    org=$0

**Tandy CoCo3**

The memory management unit allows to map every 8KiB of the first 64KiB to any RAM location in steps of 8KiB. Thus there is no standard page size.  
The loader should be able to load a large page (32KiB-64KiB) in several steps.  

### Location
---

The location is the expected running location for the code.

The location is used to :
- set the destination location in the package index.  
- give the destination page size, used to split the package into pages.

The value should be expressed in hexadecimal with an hyphen between the min and max value.  
example : $0000-$3FFF

### Org
---

The org sets the origin where the package begin, somewhere in a middle of a page. It is also used to assemble the code to the right location.

### Files
---

The last parameter in the package definition should be the file list.  
The syntax is :

    files=
    src/levels/lvl01.asm
    src/ennemies/ennemy01.asm
    src/ennemies/ennemy02.asm
    src/ennemies/ennemy03.asm

The path of each file must be relative to the game project base directory.  

The builder will report a fatal error if the binary produced for the package exceed the size declared by the end location minus the org starting position.

[package]: package.png
[package-element]: package-element.png