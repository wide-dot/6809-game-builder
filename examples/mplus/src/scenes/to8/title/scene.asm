        ; new subscene
        fdb   $4000+3                  ; [type | nb files] (0: end marker)

        ; subscene data
        fcb   $01                      ; [destination - page id]
        fdb   $6100                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        fcb   $00                      ; [destination - page id] lower:0 or upper:1 half page
        fdb   $4000                    ; [destination - address] in half page
        fdb   dummyfile                ; used to switch page at load time, see next file

        fcb   $05                      ; [destination - page id]
        fdb   $0000                    ; [destination - address] in half page
        fdb   assets.samples           ; will write 24Ko from $0000 up to $5FFF

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)