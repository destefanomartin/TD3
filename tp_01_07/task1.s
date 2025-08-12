.global task1
.global init_t1


.extern __stack_task1_end
.extern __stack_task2end



.equ addr_start, 0x70A00000
.equ addr_end, 0x70A0FFFF
.equ ref_value, 0x55AA55AA


.section .t1_text, "ax"   
task1: 
    LDR R0, =addr_start
    LDR R1, =addr_end
    LDR R2, =ref_value

loop: 
    STR R2, [R0]      
    LDR R3, [R0]
    CMP R3, R2
    BNE error
    ADD R0, R0, #4
    CMP R0, R1
    BLT loop
    BLX LR

error:
    B error


.section .task1_data, "wa"
    SP1: .space 4 
    .global SP1

.section .task1_bss, "wa"
