Header (4 bytes)
[I] [D] [X] : [tag]
[0000 0000] : [disk id 0-255]
[0000 0000] : [nb of sectors to load for this index]

loader data entry for a file (7, 14 or 21 bytes):

[0] [0] [00 0000] - [compression 0:none, 1:packed] [load time linker 0:no, 1:yes] [free]
[0000 000] [0] [0000 0000] - [track 0-128] [face 0-1] [sector 0-255]
[0000 0000] [0000 0000] - [bytes in first sector] [start offset in first sector (0: no sector)]
[0000 0000] - [full sectors to read]
[0000 0000] - [bytes in last sector (0: no sector)]

Option (7 bytes) - compression
[0000 0000] [0000 0000] - [offset to write compressed data]
[0000 0000] [0000 0000] [0000 0000] [0000 0000] [0000 0000] - [end data to write over delta (zx0)]

Option (7 bytes) - load time linker data
[0000 000] [0] [0000 0000] - [track 0-128] [face 0-1] [sector 0-255]
[0000 0000] [0000 0000] - [bytes in first sector] [start offset in first sector (0: no sector)]
[0000 0000] - [full sectors to read]
[0000 0000] - [bytes in last sector (0: no sector)]
[0000 0000] - [free]

Pour gérer les types de longueur : on saute un id quand on a un file compressé ou un load time linker
ex :
file non compressé id 0
file non compressé id 1
file non compressé id 2
file compressé id 3
file compressé id 5
file compressé id 7
...

-----------------------------------------------------------------
Au chargement on indique le fichier a charger, sa destination et la destination des link data
l'index de runtime est maintenu ailleurs (info de qui est chargé ou) c'est aussi un param d'entrée
ces infos en param du loader peuvent etre stockées dans une scene ... et le chargement commandé par le scene loader
Par opposition au chargement d'un seul fichier.

Attention le mieux est de charger tous les fichiers en RAM, puis de carger toutes les link data et enfin faire le dynamic link
ça veut dire charger l'index en RAM forcement ...

Cas d'un chargement d'un fichier sur autre disquette : 
chargement index 0 en zone TMP
chargement de tous les fichiers en RAM
chargement de toutes les link data en RAM
maj du tableau de chargement
indication changement de disquette
chargement index 1 en zone TMP
chargement de tous les fichiers en RAM
chargement de toutes les link data en RAM
maj du tableau de chargement
lancement du load time link qui reprocess tout

en fonction des chargements en cours de jeu : on peut supprimer les links data si plus besoin

-----------------------------------------------------------------

répéter un index similaire à ci dessus pour les link data ?
ou données contigues sur disque et mutualiser l'index ?

index size :
[0000 0000] : nb of sectors to read

link index data (trié dans l'ordre des file id)
[0000 0000] [0000 0000] : 0 = pas de donnée de link
[0000 0000] [0000 0100] : 4 = file id 1 est situé en +$0004

données de file id 1 :

- exported constant

03 0100 :    0002                             ; [nb of elements]
             0003                             ; value of symbol 1
             0004                             ; value of symbol 2

- exported

03 0106 :    0001                             ; [nb of elements]
             0586                             ; value of symbol 0 (should add section base address to this value before applying)
             
- local
            
03 010A :    0001                             ; [nb of elements]
             0162 00C3                        ; [dest offset] [val offset] - example : internal ( I16=195 IS=\02code OP=PLUS ) @ 0162

- incomplete (8bit)
             
03 0122 :    0001                             ; [nb of elements]
             0014 0000 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014

- incomplete (16bit)
             
03 0110 :    0002                             ; [nb of elements]
             0001 FFF4 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
             003E 0000 0003 0002              ;                                                            external ( ES=ymm.music.processFrame ) @ 003E



la numérotation group est sur 16 bits
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

Test à la compression, en retirant les 5 derniers octets du fichier a compresser (sortie en erreur en demandant de passer en mode non compressé pour ce group) :
- si le fichier a compresser est <= 5 : 
- si le fichier diminué de 5 compressé est plus grand que l'original
- Si le delta est > 5

File compressed from 16384 to 12269 bytes! (delta 3) (end data 0)
File compressed from 16381 to 12266 bytes! (delta 4) (end data 3)
File compressed from 16380 to 12265 bytes! (delta 4) (end data 4) => OK ! (end data >= delta)
