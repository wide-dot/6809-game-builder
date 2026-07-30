        ; main scene : game mode + two marker files
        fdb   $4000+3                  ; [type | nb files] (0: end marker)

        fcb   $01                      ; [destination - page id]
        fdb   $6100                    ; [destination - address]
        fdb   assets.gm.loaderut       ; [file id]

        fcb   $06                      ; [destination - page id]
        fdb   $0000                    ; [destination - address]
        fdb   data.marker.aa           ; [file id]

        fcb   $06                      ; [destination - page id]
        fdb   $0800                    ; [destination - address]
        fdb   data.marker.bb           ; [file id]

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)
