.global task1


.equ addr_start1, 0x70A00000
.equ addr_end1, 0x70A0FFFF
.equ ref_value, 0x55AA55AA


.section .t1_text, "ax"   
task1: 
    LDR R0, =addr_start1
    LDR R1, =addr_end1
    LDR R2, =ref_value
    

loop: 
    STR R2, [R0]      
    LDR R3, [R0]
    CMP R3, R2
    BNE error
    ADD R0, R0, #4
    CMP R0, R1
    BLT loop
    B task1
error:
    B error


.section .task1_data, "wa" // Definido para que cree espacio en el stack. 
    .word 0x70A00000

.section .task1_bss, "wa"

.end
