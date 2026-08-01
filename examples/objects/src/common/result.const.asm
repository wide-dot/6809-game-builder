* ===========================================================================
* Result table, loader-ut convention : a fixed RAM address an emulator or a
* debugger can read without the program having to display anything.
*
* Shared by the game mode and by the paged object unit, because a test whose
* two halves live in different pages has to agree on where to write.
* ===========================================================================

result              equ $9C00

result.MAGIC        equ $CA       ; +0, written once the game mode runs
result.DONE_OK      equ $0D       ; +31, every test passed
result.DONE_KO      equ $E0       ; +31, $E0+n : n test(s) failed

* what the paged unit writes, so the game mode can tell one from the other
result.paged        equ result+9  ; T9  : the object that lives in its own page
result.pgsub        equ result+12 ; T12 : RunPgSubRoutine
