loader data entry for a filegroup (6 or 12 bytes):

[0]         - compression [0:none, 1:packed]
[00]        - <free>
[0000]      - disk [0-15]
[0]         - face [0-1]
[0000 0000] - track [0-255]
[0000 0000] - sector [0-255]
[0000 0000] - [start offset in first sector] (0 means no partial sector at beginning)
[0000 0000] - [nb full sectors to read]
[0000 0000] - [nb of bytes in last sector] (0 means no partial sector at ending)

Option (6 bytes)
[0000 0000] [0000 0000] - offset to compressed data
[0000 0000] [0000 0000] [0000 0000] [0000 0000] - end data (zx0)

Pour gérer les deux types de longueur : on saute un id quand on a un filegroup compressé
ex :
filegroup non compressé id 0
filegroup non compressé id 1
filegroup non compressé id 2
filegroup compressé id 3
filegroup compressé id 5
filegroup compressé id 7
...

la numérotation filegroup est sur 16 bits
pour multiplier par 6 on fait :
- asld
- std @d
- asld
- addd #0
- @d equ *-2

No compression
--------------
When first or last sector is partial, data is first loaded in a buffer of 256 bytes.
Otherwise, for full sectors, copy is made directly to destination in RAM.

Packed
------

                       |------------------|    compressed data
    |---------------------------------|       decompressed data
  start >>                            <--->
                                      delta

Test à la compression (sortie en erreur en demandant de passer en mode non compressé pour ce filegroup) :
- si le fichier a compresser est <= 4 : 
- si le fichier diminué de 4 compressé est plus grand que l'original

File compressed from 16384 to 12269 bytes! (delta 3) (end data 0)
File compressed from 16381 to 12266 bytes! (delta 4) (end data 3)
File compressed from 16380 to 12265 bytes! (delta 4) (end data 4) => OK ! (end data >= delta)
