* ===========================================================================
* log - PROGRAM code registry (r-type)
* ===========================================================================
* The $40-$7F origin range belongs to the program: the engine never uses it.
* Layout of the code word is engine/log/log.const.asm ; the class bit is set
* by the _log.error macro, never here.
*
* EVERY code documents what D/X/Y/U hold at the site. That is the reading
* contract for whoever inspects the block.

 IFNDEF rtype.log.const.asm
rtype.log.const.asm equ 1

* --- program domains ---
* $40 stage (opening, hand over)

log.stage.SETUP     equ $4001  ; stage.setup reached ; D=stage.wave address

 ENDC
