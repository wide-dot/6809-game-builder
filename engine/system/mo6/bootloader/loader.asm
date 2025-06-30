;*******************************************************************************
; FD File loader
; Benoit Rousseau 07/2023
; Based on loader from Prehisto (file load routine)
; ------------------------------------------------------------------------------
; A fully featured boot/file loader
; - zx0 compressed files
; - dynamic link of lwasm obj files
; - scene management
; - directory management
; - multiple floppy management
;
; - TODO :
;   - split this code in two part : common and specific (mo/to)
;   - add unload link data routine
;
;*******************************************************************************
 SETDP $ff ; prevents lwasm from using direct address mode
        INCLUDE "engine/global/glb.const.asm"
        INCLUDE "engine/6809/macros.asm"
        INCLUDE "engine/6809/types.const.asm"
        INCLUDE "engine/system/mo6/map.const.asm"
        INCLUDE "engine/system/mo6/monitor/monitor.macro.asm"
        INCLUDE "engine/system/mo6/bootloader/loader.const.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.asm"
        INCLUDE "engine/system/mo6/ram/ram.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.memoryPool.asm"