         ; type of scene
        fdb   $4000+2                      ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $01                          ; [destination - page id]
        fdb   $6100                        ; [destination - address]
        fdb   engine.memory.malloc.tlsf.ut ; [file id]

        ; another type of scene
        ; or 0 if end
        fdb   0                            ; [type | nb files] (0: end marker)
 