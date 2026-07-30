        ; disk 1 scene : the disk 1 marker
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $1800                    ; [destination - address]
        fdb   d1.marker                ; [file id, in DISK 1 numbering]

        fdb   0                        ; end marker
