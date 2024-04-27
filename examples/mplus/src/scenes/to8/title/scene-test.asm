        ; new subscene
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        ; subscene data
        fcb   $01                      ; [destination - page id]
        fdb   $6300                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)