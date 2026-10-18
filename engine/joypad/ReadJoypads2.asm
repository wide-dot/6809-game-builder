********************************************************************************
* ReadJoypads (version 2) - both joypads, a byte each : its directions and
* buttons held (Ctrl_n_Held) and pressed since the last call (Ctrl_n_Press)
* ; X kept, D trashed
* V2-DEVIATION : the inputs complemented first, bits 0-1 of a result 0 (v1
* left them at 1) ; no self-modifying code.
* ------------------------------------------------------------------------------
*
* Joypads Direction
* -----------------
* Register: $E7CC (8bits)
*
* Joypad2     Joypad1
* 1111        1111 (0: press | 1: release)
* ||||_Up     ||||_Up
* |||__Down   |||__Down
* ||___Left   ||___Left
* |____Right  |____Right
*
* Joypads Buttons
* ----------------
* Register: $E7CD (8bits)
*
*   [------] 6 bits DAC
* 11 001100 (0: press | 1: release)
* ||   ||
* ||   ||_ Btn B Joypad1
* ||   |__ Btn B Joypad2
* ||
* ||______ Btn A Joypad1
* |_______ Btn A Joypad2
*
* Result values: Ctrl_1, Ctrl_2 ([held][pressed])
* --------------------------------------------
* Joypad1
* 0000        0000 (0: release | 1: press)
* ||||_Up     ||
* |||__Down   ||
* ||___Left   ||___Btn B
* |____Right  |____Btn A
*
* Joypad2
* 0000        0000 (0: release | 1: press)
* ||||_Up     ||
* |||__Down   ||
* ||___Left   ||___Btn B
* |____Right  |____Btn A
*
********************************************************************************

; ---------------------------------------------------------------------------
; Controller Buttons
;
; Buttons bit numbers
button_up                equ   4
button_down              equ   5
button_left              equ   6
button_right             equ   7
button_B                 equ   2
button_C                 equ   3
button_A                 equ   3
button_start             equ   3
; Buttons masks
button_up_mask           equ   %00010000
button_down_mask         equ   %00100000
button_left_mask         equ   %01000000
button_right_mask        equ   %10000000
button_B_mask            equ   %00000100
button_C_mask            equ   %00001000
button_A_mask            equ   %00001000
button_start_mask        equ   %00001000

Ctrl_1_Logical
Ctrl_1_Held_Logical      fcb   0
Ctrl_1_Press_Logical     fcb   0
Ctrl_1
Ctrl_1_Held              fcb   0
Ctrl_1_Press             fcb   0
Ctrl_2
Ctrl_2_Held              fcb   0
Ctrl_2_Press             fcb   0

ReadJoypads
        pshs  x
        ldd   $E7CC                    ; A the directions, B the buttons
        coma
        comb                           ; 1 : pressed
        std   ReadJoypads.raw
        anda  #%00001111               ; joypad 1 : its directions to bits 4-7
        lsla
        lsla
        lsla
        lsla
        bitb  #%01000000
        beq   >
        ora   #button_A_mask           ; A : bit 6
!       bitb  #%00000100
        beq   >
        ora   #button_B_mask           ; B : bit 2
!       ldx   #Ctrl_1
        bsr   ReadJoypads.edge
        ldd   ReadJoypads.raw
        anda  #%11110000               ; joypad 2 : its directions in place
        bitb  #%10000000
        beq   >
        ora   #button_A_mask           ; A : bit 7
!       bitb  #%00001000
        beq   >
        ora   #button_B_mask           ; B : bit 3
!       ldx   #Ctrl_2
        bsr   ReadJoypads.edge
        puls  x,pc

* A a joypad held now, X its [held][pressed] : pressed, held now and not before
ReadJoypads.edge
        ldb   ,x
        comb
        pshs  a
        andb  ,s+
        std   ,x
        rts

ReadJoypads.raw fdb 0
