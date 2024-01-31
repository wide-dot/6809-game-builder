/[index]/[toolbox]/stm2bin

[index]: ../../../../readme.md
[toolbox]: ../../../../docs/toolbox.md

# stm2bin
## Description
Convert [.stm][file-format-stm] Tilemaps produced by Pro Motion NG (Cosmigo) into usable assembly data and code.
## Features
* extract stm header informations and produce an asm equate file
* convert tile id from little endian to big endian
* adjust tile id byte depth to desired size
* produce a binary file that contains only the tileid
* split binary files based on a max size (ex: to fit a memory page)

## Usage

(for Windows users, add .bat to the script name)

    stm2bin [-ibd=Input byte depth] [-obd=Output byte depth] [-oms=Output file max size] (-d=Input   directory | -f=Input file)

    simple tile map to binary converter
        -d, --dir=Input directory
        -f, --file=Input file
        -ibd, --in-byte-depth=Input byte depth          (default: 4)
        -obd, --out-byte-depth=Output byte depth        (default: 2)
        -oms, --out-max-size=Output file max size       (default: 16384)


### Examples

Convert all .stm tilemaps in current directory to a 8 bit array and split data in 16Ko bin files :

    stm2bin -d=./ -ibd=4 -obd=1 -oms=16384

Convert the tilemap china.stm to a 16 bit array and split data in 16Ko bin files :

    stm2bin -f=china.stm -odb=2

## Sample Test
### Input
china.stm

    53 54 4D 50 14 00 01 00 01 00 00 00 02 00 00 00
    03 00 00 00 04 00 00 00 05 00 00 00 06 00 00 00
    07 00 00 00 08 00 00 00 09 00 00 00 0A 00 00 00
    0B 00 00 00 0C 00 00 00 0D 00 00 00 0E 00 00 00
    0F 00 00 00 10 00 00 00 11 00 00 00 12 00 00 00
    13 00 00 00 14 00 00 00

### Command

    stm2bin -f=china.stm -odb=2

### Output
china.equ

    china.width equ 20
    china.height equ 1
    china.bytedepth equ 2

china.bin

    00 01 00 02 00 03 00 04 00 05 00 06 00 07 00 08
    00 09 00 0A 00 0B 00 0C 00 0D 00 0E 00 0F 00 10
    00 11 00 12 00 13 00 14

[file-format-stm]: ../../../../doc/file-format-stm.md