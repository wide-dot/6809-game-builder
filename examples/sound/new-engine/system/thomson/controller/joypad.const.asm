; dedicated ctrl mask
c1_button_up_mask            equ   %00000001 
c1_button_down_mask          equ   %00000010 
c1_button_left_mask          equ   %00000100 
c1_button_right_mask         equ   %00001000 
c1_button_A_mask             equ   %01000000 
c1_button_B_mask             equ   %00000100 

c2_button_up_mask            equ   %00010000 
c2_button_down_mask          equ   %00100000  
c2_button_left_mask          equ   %01000000 
c2_button_right_mask         equ   %10000000 
c2_button_A_mask             equ   %10000000 
c2_button_B_mask             equ   %00001000 

; common ctrl mask
c_button_up_mask             equ   %00010001 
c_button_down_mask           equ   %00100010 
c_button_left_mask           equ   %01000100 
c_button_right_mask          equ   %10001000 
c_button_A_mask              equ   %11000000 
c_button_B_mask              equ   %00001100 

; player mask
c1_dpad                      equ   %00001111 
c2_dpad                      equ   %11110000
c1_butn                      equ   %01000100 
c2_butn                      equ   %10001000 