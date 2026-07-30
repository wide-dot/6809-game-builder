        ; stress scene : 6 export-only interface files (link data only)
        ; grows the link data index beyond its initial 8 slots (realloc path)
        fdb   $8000+6                  ; [type | nb files] (0: end marker)

        fcb   0                        ; [destination - page id]
        fdb   0                        ; [destination - address]
        fdb   iface.a                  ; [file id] - n times
        fdb   iface.b
        fdb   iface.c
        fdb   iface.d
        fdb   iface.e
        fdb   iface.f

        fdb   0                        ; end marker
