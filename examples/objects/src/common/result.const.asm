* ===========================================================================
* Witnesses, the bench convention (docs/lang/en/benches.md) : a fixed RAM
* block toje reads without the program displaying anything.
*
* Shared by the game mode and by the paged object unit, because a test whose
* two halves live in different pages has to agree on where to write.
* ===========================================================================

TESTS               equ 31

result              equ $9C00
res.magic           equ result        ; $CA once the game mode runs
res.count           equ result+1      ; TESTS
res.done            equ result+2      ; $0D once the sequence completed
res.base            equ result+3      ; test n writes $01 at res.base+n-1
res.sums            equ res.base+TESTS ; a word per test : a value it recorded

result.MAGIC        equ $CA
result.DONE         equ $0D

* what the paged unit writes, so the game mode can tell one from the other
result.paged        equ $9CF0         ; T9  : the object that lives in its own page
result.pgsub        equ $9CF2         ; T12 : RunPgSubRoutine, its magic then its parameter
