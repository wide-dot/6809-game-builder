# stm2bin
## Description
Convert Tilemaps produced by Pro Motion NG (Cosmigo) into usable assembly data and code.
## Features
* extract stm header informations and produce an asm equate file
* convert tile id from little endian to big endian
* adjust tile id byte depth to desired size
* produce a binary file that contains only the tileid
* split binary files based on a max size (ex: to fit a memory page)

## Usage
### typical

    stm2bin <input directory> <input tile id byte size> <ouput tile id byte size> <max output file size>

### no parameters

    stm2bin

If no parameters are set, the tool will run with the default values (see parameters).

### examples

Convert the tilemap to a 8 bit array and split data in 16Ko bin files :

    stm2bin ./ 4 1 16384

Convert the tilemap to a 16 bit array and split data in 16Ko bin files :

    stm2bin ./ 4 2 16384
## Parameters
### input directory
*default value :* ./

Process all [.stm][file-format-stm] files of the input directory.

### input tile id byte size
*default value : 4*

Pro Motion NG .stm file actually use 4 byte for each tile.
This parameter will always be 4, unless you are dealing with a custom input file format.
 
### ouput tile id byte size
*default value : 2*

Use this parameter to set the tile id byte size that will be used in output bin files.

### max output file size
*default value : 16384*

Use this parameter to cap the maximum output file size.
It is generally used to limit data size to fit a RAM page size.

## Sample Test
### input
china.stm

    53 54 4D 50 14 00 01 00 01 00 00 00 02 00 00 00
    03 00 00 00 04 00 00 00 05 00 00 00 06 00 00 00
    07 00 00 00 08 00 00 00 09 00 00 00 0A 00 00 00
    0B 00 00 00 0C 00 00 00 0D 00 00 00 0E 00 00 00
    0F 00 00 00 10 00 00 00 11 00 00 00 12 00 00 00
    13 00 00 00 14 00 00 00

### command

    stm2bin.bat ./ 4 2 16384

### output
china.equ

    china.width equ 20
    china.height equ 1
    china.bytedepth equ 2

china.bin

    00 01 00 02 00 03 00 04 00 05 00 06 00 07 00 08
    00 09 00 0A 00 0B 00 0C 00 0D 00 0E 00 0F 00 10
    00 11 00 12 00 13 00 14

[file-format-stm]: ../../../../doc/file-format-stm.md