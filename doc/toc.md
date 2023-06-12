loader data entry for a filegroup (7 or 14 bytes):

[0] [000 0000] - [compression 0:none, 1:packed] [free]
[0000 000] [0] [0000 0000] - [track 0-128] [face 0-1] [sector 0-255]
[0000 0000] [0000 0000] - [bytes in first sector] [start offset in first sector (0: no sector)]
[0000 0000] - [full sectors to read]
[0000 0000] - [bytes in last sector (0: no sector)]

Option (7 bytes)
[0000 0000] [0000 0000] - [offset to write compressed data]
[0000 0000] [0000 0000] [0000 0000] [0000 0000] [0000 0000] - [end data to write over delta (zx0)]

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

Test à la compression, en retirant les 4 derniers octets du fichier a compresser (sortie en erreur en demandant de passer en mode non compressé pour ce filegroup) :
- si le fichier a compresser est <= 4 : 
- si le fichier diminué de 4 compressé est plus grand que l'original
- Si le delta est > 4

File compressed from 16384 to 12269 bytes! (delta 3) (end data 0)
File compressed from 16381 to 12266 bytes! (delta 4) (end data 3)
File compressed from 16380 to 12265 bytes! (delta 4) (end data 4) => OK ! (end data >= delta)
