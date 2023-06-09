
"Interleave" refers to the ordering of sectors on the same track. Processing a read sector took so much time that the start of the next sector on the track would already have passed the read/write head by the time the processor came back to look for it, so it had to wait an entire disk revolution to see it again. So sectors where ordered alternatingly like 1 - 14 - 2 - 15 - 3 - 16 - ... giving the processor the time to process sector 1 while sector 14 flew by and finishing in time for sector 2 to arrive. If this interleave factor of 2 wasn't enough you could go to interleave factor 3 (1 - 10 - 19 - 2 - 11 - 20 - ...) giving two sectors' time for the processing of one sector, and so on.

"Skew" refers to the placement of sectors on adjacent tracks. When reading data sequentially and reaching the end of one track, the stepper motor would move the read/write head to the next track. Ideally, the first sector of the new track should arrive under the head just when it had settled on that track. To achieve this, sector 1 of each track would not be placed at the same angular position, but skewed from one track to the next by the angle the disk would advance in the time the head needed to step from one track to the next.


The Skip Factor is the number of physical sectors “skipped” between logical sectors. A Skip Factor of 4 looks like this on the disk:

01 12 05 13 09 02 14 06 15 10 03 16 07 17 11 04 18 08

---------------------------------------

le builder produit une structure de données basée sur des secteurs logiques 1, 2, 3 ...

Un fichier .fd est considéré comme ayant un entrelacement implicite de 0 (secteurs physiques et logiques identiques).
Au moment de créer une image disquette .fd, les secteurs logiques sont positionnés de manière a créer l'entrelacement demandé dans la configuration.

Au runtime, les secteurs sont lus les uns à la suite des autres (1, 2, 3, ...)
