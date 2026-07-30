        ; stress scene : variant dd over the shared destination
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $1000                    ; [destination - address]
        fdb   data.marker.dd           ; [file id]

        fdb   0                        ; end marker
