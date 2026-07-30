        ; second scene : load marker cc OVER marker bb location
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $0800                    ; [destination - address]
        fdb   data.marker.cc           ; [file id]

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)
