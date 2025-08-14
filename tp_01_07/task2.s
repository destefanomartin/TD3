.global task2


.equ addr_start2, 0x70A10000
.equ addr_end2, 0x70A1FFFF



.section .t2_text, "ax"
task2:
    LDR R0, =addr_start2
    LDR R1, =addr_end2

loop:     
    LDR R2, [R0]
    MVN R3, R2
    STR R3, [R0]
    ADD R0, R0, #4
    CMP R0, R1
    BLT loop    
    B task2


.section .task2_data, "wa" // Definido para que cree espacio en el stack. 
    .word 0x70A10000
    .word 0x70A1FFFF

.section .task1_bss, "wa"


.end
