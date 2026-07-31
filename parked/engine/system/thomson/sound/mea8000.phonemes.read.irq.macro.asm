; ============================================================================
; MEA8000 Phonemes IRQ Reader - Macros
; ============================================================================
; Simplified macros with maximum parameters - no conditional logic
; ============================================================================

; External variable for optimized macros
mea8000.phonemes.read.irq.activeFlag EXTERNAL

; ============================================================================
; _mea8000.phonemes.read.irq.startReading
; Start asynchronous phoneme reading
; \1 = text to read (address)
; \2 = tonality (value)
; \3 = phoneme table (address)
; ============================================================================
_mea8000.phonemes.read.irq.startReading MACRO
        ldy   \1                    ; Load text address
        lda   \2                    ; Load tonality
        ldx   \3                    ; Load table address
        jsr   mea8000.phonemes.read.irq.startReading
 ENDM

; ============================================================================
; _mea8000.phonemes.read.irq.stopReading
; Stop current synthesis
; ============================================================================
_mea8000.phonemes.read.irq.stopReading MACRO
        jsr   mea8000.phonemes.read.irq.stopReading
 ENDM

; ============================================================================
; _mea8000.phonemes.read.irq.waitComplete
; Wait for synthesis completion (blocking version)
; ============================================================================
_mea8000.phonemes.read.irq.waitComplete MACRO
        jsr   mea8000.phonemes.read.irq.waitComplete
 ENDM

; ============================================================================
; _mea8000.phonemes.read.irq.checkActive
; Test if synthesis is in progress (optimized inline version)
; Output: Z=1 if finished, Z=0 if in progress
; ============================================================================
_mea8000.phonemes.read.irq.checkActive MACRO
        tst   mea8000.phonemes.read.irq.activeFlag
 ENDM

; ============================================================================
; _mea8000.phonemes.read.irq.readBlocking
; Blocking version that starts and waits for completion
; \1 = text to read (address)
; \2 = tonality (value)
; \3 = phoneme table (address)
; ============================================================================
_mea8000.phonemes.read.irq.readBlocking MACRO
        ldy   \1                    ; Load text address
        lda   \2                    ; Load tonality
        ldx   \3                    ; Load table address
        jsr   mea8000.phonemes.read.irq.startReading
        jsr   mea8000.phonemes.read.irq.waitComplete
 ENDM

; ============================================================================
; _mea8000.phonemes.read.irq.checkAndWait
; Wait loop with possibility to execute code during waiting
; \1 = label to branch to during wait (required)
; ============================================================================
_mea8000.phonemes.read.irq.checkAndWait MACRO
wait_loop@
        tst   mea8000.phonemes.read.irq.activeFlag
        beq   done@
        jsr   \1                    ; Execute user code
        bra   wait_loop@
done@   equ   *
 ENDM
