;*******************************************************************************
; Fast keyboard routines
;
;
; ------------------------------------------------------------------------------
;
;*******************************************************************************

 INCLUDE "engine/system/to8/controller/keyboard.fast.macro.asm"

keyboard.fast.check       EXPORT
keyboard.fast.timed.check EXPORT
keyboard.fast.held        EXPORT
keyboard.fast.pressed     EXPORT

;*******************************************************************************
; Constants
;*******************************************************************************
KEYBOARD_FIRST_DELAY  equ   16+1  ; Number of calls to ignore for first delay (800ms at 50Hz)
KEYBOARD_REPEAT_DELAY equ   1+1   ; Number of calls to ignore for repeat delay (70ms at 50Hz)

 SECTION code

keyboard.fast.state
keyboard.fast.held    fcb   0 
keyboard.fast.pressed fcb   0
keyboard.fast.timer   fcb   0 ; Counter for skiping calls

;*******************************************************************************
; keyboard.fast.timed.check
; 
; Manages timing intervals for keyboard checks
; - First check is immediate
; - After key press, ignores next 16 calls (800ms at 50Hz)
; - Then ignores 1 call between checks (100ms at 50Hz)
;
; NOTE: This timing system is mandatory for proper held state computation.
; Without delays, the held state would be lost immediately on the second call,
; preventing the distinction between a single press and a held key.
; The delays ensure that held state is only set after the key has been
; physically held for the appropriate duration, as hardware push the key with
; autorepeat.
;*******************************************************************************
keyboard.fast.timed.check
        jmp   .initial_check
.phase  equ   *-2

.initial_check
        jsr   keyboard.fast.check
        beq   >
        ldd   #.first_delay
        std   .phase
        lda   #KEYBOARD_FIRST_DELAY
        sta   keyboard.fast.timer
!       rts

.first_delay
        dec   keyboard.fast.timer
        bne   @rts
        jsr   keyboard.fast.check
        beq   >
        ldd   #.repeat_delay
        std   .phase
        lda   #KEYBOARD_REPEAT_DELAY
        sta   keyboard.fast.timer
@rts    rts
!       ldd   #.first_delay
        std   .phase
        clra
        rts

.repeat_delay
        dec   keyboard.fast.timer
        bne   @rts
        jsr   keyboard.fast.check
        beq   >
        lda   #KEYBOARD_REPEAT_DELAY
        sta   keyboard.fast.timer
@rts    rts
!       ldd   #.initial_check
        std   .phase
        clra
        rts

;*******************************************************************************
; keyboard.fast.check
; 
; Direct keyboard check (without delay management)
; OUTPUT :
; - flag Z set if key pressed
;*******************************************************************************
keyboard.fast.check
        clr   keyboard.fast.pressed     ; reset pressed state
        _keyboard.fast.ktst
        bcs   >                         ; continue if key pressed
        clr   keyboard.fast.held        ; also reinit held state
        rts                             ; and quit
!       _keyboard.fast.flush            ; flush any keyboard key pressed
        tst   keyboard.fast.held
        bne   >                         ; Return if key is already held, Press was cleared, but not Held
        ldd   #$ffff                    ; first time key pressed
        std   keyboard.fast.state       ; set pressed and held to $ff
!       rts

 ENDSECTION

; ONE DAY ... it will read key codes ...
; for reference, here is the code to read the keyboard:

* F0AD 5F         CLRB                       2 compteur temps à data recu à 0
* F0AE 8602       LDA    #$02                2
* F0B0 B5E7C0     BITA   $E7C0               5 Attente que PC3 passe
* F0B3 27FB       BEQ    $F0B0               3 à zéro
* F0B5 B6E7C3     LDA    $E7C3               5 tempo ?
* F0B8 B6E7C1     LDA    $E7C1               5
* F0BB 84FD       ANDA   #$FD                2
* F0BD B7E7C1     STA    $E7C1               5   Passage à 0 du P5 6848.. lui indiquant qu'on attend ses 9 bits
* F0C0 8602       LDA    #$02                2
* F0C2 5C         INCB                       2 \
* F0C3 B5E7C0     BITA   $E7C0               5  | compte dans B le temps où on est à 0 (boucle = 10 cycles)
* F0C6 27FA       BEQ    $F0C2               3  /
* F0C8 B6E7C3     LDA    $E7C3               5 tempo ?
* F0CB C103       CMPB   #$03                2 <40 µs ?
* F0CD 2404       BCC    $F0D3               3 non => (lu un 1)
* F0CF 1CFE       ANDCC  #$FE                3 oui => lu un 0 (carry=0)
* F0D1 2002       BRA    $F0D5               3
* F0D3 1A01       ORCC   #$01                3 carry=1
* F0D5 0D6D       TST    <$6D                6 a t'on lu plus de 8 bits ?
* F0D7 2608       BNE    $F0E1               3 oui => alors enreg sur 16bits
* F0D9 096C       ROL    <$6C                6 non enregistre les 8 premiers bits série en $606C
* F0DB 24C8       BCC    $F0A5               3 ca deborde pas => rebouclage bits suivants
* F0DD 0A6D       DEC    <$6D                6 oops ca déborde => passage à 16 bits signalé
* F0DF 20C4       BRA    $F0A5               3 rebouclage bit suivant
* F0E1 096C       ROL    <$6C                6 debordement (9e bit) sur $6D
* F0E3 096D       ROL    <$6D                6
* F0E5 B6E7C3     LDA    $E7C3               5 fin de la communication
* F0E8 8A20       ORA    #$20                2
* F0EA B7E7C3     STA    $E7C3               5
* F0ED B6E7C1     LDA    $E7C1               5 
* F0F0 84FD       ANDA   #$FD                2
* F0F2 8A01       ORA    #$01                2
* F0F4 B7E7C1     STA    $E7C1               5 on dit au 6804 qu'on a bien tout recu et qu'il peut reprendre son scann clavier
* F0F7 966C       LDA    <$6C                4 lecture des 8 bits de poids faibles: shift + numéro de touche
* F0F9 8580       BITA   #$80                2 shift appuyé ?
* F0FB 2605       BNE    $F102               3
* F0FD 8EF24E     LDX    #$F24E              3 non => tableau décodage num-touche --> ascii sans shift
* F100 2005       BRA    $F107               3
* F102 8EF29E     LDX    #$F29E              3 oui => tableau décodage num-touche --> ascii shifté !
* F105 847F       ANDA   #$7F                2 masquage du bit "shift"
* F107 E686       LDB    A,X                 5 décodage numéro-touche->ascii via tableau en rom
* (suite du traitement pour les touches accentuées, les touches de fonctions et le pavé numérique..  je détaille pas, on s'en fiche ici)