        INCLUDE "engine/sound/ymm.external.asm"
        INCLUDE "engine/sound/vgc.external.asm"

sn76489.init       EXTERNAL
ym2413.init        EXTERNAL
scenes.level1      EXTERNAL
sounds.title.ymm   EXTERNAL
sounds.title.vgc   EXTERNAL
sounds.level1.ymm  EXTERNAL
sounds.level1.vgc  EXTERNAL

 SECTION code

        ; v2 compatibility bridge : the kept-v2 sound players resolve
        ; irq.on/irq.off at load time. The wrappers live AFTER the main
        ; loop — the scene jumps to this unit's first byte, so main has to
        ; be the first thing emitted. See the definition below for why a
        ; bare equ on IrqOn/IrqOff is not enough.
irq.on  EXPORT
irq.off EXPORT

        ; v1 engine dialect (1:1 imported files)
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"

        ; v2 kept features : loader/scenes, ram paging, sound players
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/pack/vgc.asm"

page.ymm equ map.RAM_OVER_CART+6  ; ram page that contains ymm player and sound data (as defined in scene file)
page.vgc equ map.RAM_OVER_CART+7

 opt c,ct

; ------------------------------------------------------------------------------
init
        jsr   InitGlobals         ; clean dp variables (v1)
        ldd   #userIRQ
        std   Irq_user_routine    ; user routine called by IrqManager (v1)
        jsr   IrqInit
        jsr   IrqSet50Hz          ; arm + enable EARLY (v2 order) : with the
                                  ; user hook active from here on, the
                                  ; monitor's default timer handler never
                                  ; runs (it would park the floppy drive,
                                  ; leaving DK.OPC unusable) ; the players'
                                  ; obj.play guard themselves with irq.off
        jsr   PalUpdateNow        ; apply the default black palette (PalRefresh=$FF at init)
        _gfxlock.init

        _ram.cart.set  #page.ymm   ; mount ram page that contains player and sound data
        _ymm.obj.play #page.ymm,#sounds.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _ram.cart.set  #page.vgc
        _vgc.obj.play #page.vgc,#sounds.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        jsr   IrqOn                ; the obj.play calls masked interrupts
                                   ; (their internal irq.off) — re-enable
                                   ; now that both players are primed

        lda   #$7B                 ; switch to 160x200x16c mode (v1 style)
        sta   CF74021.LGAMOD

        ldb   #%00000010           ; init video buffer page 2 (v1 style)
        stb   map.CF74021.DATA
        ldx   #0
        jsr   ClearDataMem
        ldb   #%00000011           ; init video buffer page 3
        stb   map.CF74021.DATA
        ldx   #0
        jsr   ClearDataMem

; ------------------------------------------------------------------------------
mainLoop
        ; bench hook (loader-ut convention) : the test harness pokes $9C00
        ; to request the scene swap — hardware-independent under emulation
        tst   $9C00
        beq   @noPoke
        clr   $9C00
        bra   @doSwap
@noPoke
        ; real-machine trigger, R-Type style : KTEST hardware bit
        ; (PIA $E7C8 bit 0 = a key is down), edge-detected
        lda   map.MC6821.PRA
        lsra
        bcs   @keyDown
        clr   keydown             ; key released : re-arm the trigger
        bra   >
@keyDown
        tst   keydown
        bne   >                   ; still held : one swap per press
        inc   keydown
@doSwap

        jsr   IrqOff
        _ram.cart.set  #page.vgc
        _sn76489.init
        _ram.cart.set  #page.ymm
        _ym2413.init

        _ram.data.set #loader.PAGE ; load a new song from disk
        _loader.scene.load #scenes.level1

        _ram.cart.set  #page.ymm
        _ymm.obj.play #page.ymm,#sounds.level1.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _ram.cart.set  #page.vgc
        _vgc.obj.play #page.vgc,#sounds.level1.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        jsr   IrqOn
!

        _gfxlock.on
        ; all writes to gfx buffer should be placed here for double buffering
        ; ...
        _gfxlock.off

        _gfxlock.loop
        jmp   mainLoop           ; infinite loop

; ------------------------------------------------------------------------------
keydown fcb   0                       ; bench trigger edge state

; ------------------------------------------------------------------------------
; irq.on / irq.off — the v2-contract bridge over the v1 IrqOn/IrqOff.
; A bare equ holds the promise of the NAME without the promise of the
; CONTRACT : the v2 irq.on/irq.off PRESERVE REGISTERS
; (engine/system/to8/irq/irq.asm), while the v1 routines read the STATUS
; byte through A. The YMM player calls irq.off in the middle of the
; sequence where A carries the music data page, right before
; sta ymm.data.page : with the bare alias it stored the STATUS residue
; ($00), and every frame.play then remounted the cartridge window on
; page 0 WHILE EXECUTING FROM THE WINDOW — the ground vanished under the
; PC. See docs/lang/en/migration/irq-bridge.md.
; ------------------------------------------------------------------------------
irq.on  pshs  a
        jsr   IrqOn
        puls  a,pc

irq.off pshs  a
        jsr   IrqOff
        puls  a,pc

userIRQ
        jsr   PalUpdateNow              ; self-skips when PalRefresh is 0
        jsr   gfxlock.bufferSwap.check
        _ymm.frame.play #page.ymm
        _vgc.frame.play #page.vgc
        rts

; ------------------------------------------------------------------------------
        ; v1 engine routines (1:1) — v1 files carry no SECTION of their own
        ; (raw build model), so they are included inside the code section
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/ram/ClearDataMemory.asm"

 ENDSECTION
