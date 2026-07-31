 ifndef irq.const.asm
irq.const.asm equ 1

irq.ONE_LINE  equ 64                   ; cycles per line
irq.ONE_FRAME equ 312*irq.ONE_LINE-1   ; cycles per frame (lines*cycles_per_lines-1), timer launch at -1

 endc