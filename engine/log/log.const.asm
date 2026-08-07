* ===========================================================================
* log - resident event block and code registry (engine side)
* ===========================================================================
* One gesture to report an event from anywhere: a probe site writes the
* normalized block below, and an external supervisor (emulator watchpoint
* on log.code) reads it. Without a supervisor an info costs ~90 cycles and
* is overwritten by the next one; an error freezes the machine on log.halt.
*
* Code word layout (16 bits):
*   bit 15    class    0=info 1=error - set by _log.error, NEVER in a registry
*   bit 14    origin   0=engine 1=program
*   bits 13-8 domain   engine domains $01-$3F, program domains $40-$7F
*   bits 7-0  cause
* $0000 is reserved and means "no event".
*
* A code only exists if declared in a registry: HERE for the engine, in the
* program's own registry file for the $40-$7F range - the engine never uses
* that range. EVERY code documents what D/X/Y/U mean at the site: that is
* the supervisor's reading contract.

 IFNDEF engine.log.const.asm
engine.log.const.asm equ 1

* The block: 13 bytes of always-mapped resident RAM, right under the direct
* page. The stack tops just below it (glb_system_stack = dp-16). Nobody
* clears it: it is only ever READ after a watchpoint hit, so the power-on
* garbage is never interpreted - an init would be worse, its writes would
* fire the supervisor's watchpoint with a phantom event at boot.
* log.BLOCK is ABSOLUTE, not derived from dp: the BOOT SECTOR needs it too
* and it does not include the engine constants. This file is the single
* source of truth; the guard at the end checks every other view against it.
log.BLOCK       equ $9EF0          ; = dp-16, checked below
log.code        equ log.BLOCK+0    ; fdb - written LAST: THE watchpoint signal
log.page        equ log.BLOCK+2    ; fcb - mounted cartridge page at the site
log.pc          equ log.BLOCK+3    ; fdb - site+5, the instruction after
log.d           equ log.BLOCK+5    ; fdb - D,X,Y,U photographed as they were
log.x           equ log.BLOCK+7    ; fdb   when the site was reached
log.y           equ log.BLOCK+9    ; fdb
log.u           equ log.BLOCK+11   ; fdb
                                   ; +13..+15 spare

* --- engine domains ---
* $01 tlsf   $02 loader   $03 scene   $04 objects   $05 sound   $06 gfx
* $07 ram (banking)

* tlsf reports through its historical tlsf.err byte: one code is enough,
* the legacy value travels in the photograph.
log.tlsf.ERROR      equ $0101  ; A=legacy tlsf.err code (1..7, see tlsf.asm)

* ram.set was asked to reach an address outside every known space.
log.ram.SET_RANGE   equ $0701  ; B=requested page, U=destination address

* A file was loaded over bytes another INDEXED file still occupies. The scene
* that ended did not declare its unload, so the global re-link would patch the
* occupant's stale offsets over the new binary. Only files that CARRY link
* data are indexed, so this sees the exchange of scenes, not every write.
log.scene.LOAD_OVERLAP equ $0301  ; B=destination page, X=file id loaded,
                                  ; Y=destination address, U=occupant file id


* Cross-check: whoever also computes the block or the stack top must agree
* with the address above. Two anchors that drift silently is exactly how the
* boot sector came to push its stack into this block (measured 2026-08-07).
 IFDEF glb_system_stack
  IFNE log.BLOCK-glb_system_stack
        ERROR "log.BLOCK and glb_system_stack disagree"
  ENDC
 ENDC
 IFDEF dp
  IFNE log.BLOCK-(dp-16)
        ERROR "log.BLOCK is not dp-16"
  ENDC
 ENDC

 ENDC
