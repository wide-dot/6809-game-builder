         ; type of scene
        fdb   $4000+1                      ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $01                          ; [destination - page id]
        fdb   $6100                        ; [destination - address]
        fdb   fileid.tlsf.ut               ; [file id]

        ; another type of scene
        ; or 0 if end
        fdb   0                            ; [type | nb files] (0: end marker)
 