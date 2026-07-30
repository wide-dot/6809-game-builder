        ; stress scene : stable hub file
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $0C00                    ; [destination - address]
        fdb   data.marker.hub          ; [file id]

        fdb   0                        ; end marker
