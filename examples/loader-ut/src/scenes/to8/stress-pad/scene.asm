        ; stress scene : 16 export-only padding files (link data only)
        ; combined with scenes.stress.iface this pushes the index through
        ; several realloc steps (8 -> 16 -> 24 -> 32 slots)
        fdb   $8000+16                 ; [type | nb files] (0: end marker)

        fcb   0                        ; [destination - page id]
        fdb   0                        ; [destination - address]
        fdb   pad.a                    ; [file id] - n times
        fdb   pad.b
        fdb   pad.c
        fdb   pad.d
        fdb   pad.e
        fdb   pad.f
        fdb   pad.g
        fdb   pad.h
        fdb   pad.i
        fdb   pad.j
        fdb   pad.k
        fdb   pad.l
        fdb   pad.m
        fdb   pad.n
        fdb   pad.o
        fdb   pad.p

        fdb   0                        ; end marker
