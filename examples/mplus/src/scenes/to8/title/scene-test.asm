        ; new subscene
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        ; subscene data
        fcb   $01                      ; [destination - page id]
        fdb   $6300                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        ; new subscene
        fdb   $8000+3                  ; [type | nb files] (0: end marker)

        fcb   $05                      ; [destination - page id]
        fdb   $0000                    ; [destination - address] in half page
        fdb   assets.sounds.samples    ; [file id]
        fdb   assets.sounds.ym
        fdb   assets.sounds.sn

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)