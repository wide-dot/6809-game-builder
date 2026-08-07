* ===========================================================================
* log - probe site macros
* ===========================================================================
* A site is 5 bytes and destroys NOTHING: no register, no flag. The code
* travels inline behind the jsr - the monitor's own swi/fcb convention,
* transposed. Place the site where D/X/Y/U expose the interesting values,
* BEFORE they are consumed, and document them next to the code declaration.

 IFNDEF engine.log.macro.asm
engine.log.macro.asm equ 1

_log.info MACRO              ; compiled only when LOG_INFO is defined
 IFDEF LOG_INFO
        jsr   log.write
        fdb   \1
 ENDC
 ENDM

_log.error MACRO             ; ALWAYS compiled: this is the fatal check
        jsr   log.write
        fdb   (\1)|$8000     ; the class is the sign bit
 ENDM

 ENDC
